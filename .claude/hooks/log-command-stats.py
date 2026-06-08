#!/usr/bin/env python3
"""
.claude/hooks/log-command-stats.py
-----------------------------------------------------------------------------
Claude Code Stop hook — log model + duration + token usage cho mỗi turn.

Cách hoạt động:
1. Hook nhận JSON qua stdin: {"session_id", "transcript_path", "cwd", "hook_event_name", ...}
2. Đọc transcript JSONL tại transcript_path
3. Xác định "turn boundary": từ user message external mới nhất → cuối file
4. Aggregate trong turn:
   - Model: model phổ biến nhất trong assistant messages main-agent
   - Tokens: sum usage (input + output + cache_creation + cache_read), tách main vs sub-agent
   - Duration: (last assistant timestamp) - (first user timestamp)
   - Command: parse từ text user message đầu turn (nếu bắt đầu bằng "/" → command name)
5. In stats ra stderr (terminal thấy) + append vào .claude/logs/command-stats.log

Exit code:
- 0: thành công (hook không block turn)
- 0 (không return 2): tránh block stop sequence

Caveat: keep nhanh (<2s), không call external API.
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from collections import Counter


# Slash command được Claude Code expand trong transcript thành block mở đầu bằng
# <command-message>…</command-message><command-name>/spec</command-name>… (KHÔNG bắt đầu bằng "/")
# → ưu tiên parse tag <command-name> để nhận đúng tên command.
_COMMAND_TAG_RE = re.compile(r"<command-name>\s*(/?[A-Za-z0-9:_-]+)\s*</command-name>")


def iso_to_dt(s):
    """Parse ISO 8601 timestamp '2026-05-29T09:57:09.397Z' → datetime."""
    if not s:
        return None
    try:
        # Python <3.11 không parse 'Z' suffix → thay bằng '+00:00'
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def format_duration(seconds):
    """Format giây thành '1h 23m 45s' hoặc '23m 45s' hoặc '45s'."""
    if seconds is None or seconds < 0:
        return "n/a"
    seconds = int(seconds)
    if seconds < 60:
        return f"{seconds}s"
    minutes, sec = divmod(seconds, 60)
    if minutes < 60:
        return f"{minutes}m {sec}s"
    hours, minutes = divmod(minutes, 60)
    return f"{hours}h {minutes}m {sec}s"


def format_number(n):
    """Format số với dấu phẩy phân nghìn."""
    return f"{n:,}"


def extract_command_name(text):
    """Trả về tên command (vd '/spec'), ngược lại None.

    1. Ưu tiên tag <command-name>/spec</command-name> — cách Claude Code expand slash command
       trong transcript (block này KHÔNG bắt đầu bằng '/').
    2. Fallback: text gõ thẳng bắt đầu bằng '/'.
    """
    if not text:
        return None
    # 1. Slash command đã expand → đọc tag <command-name>
    m = _COMMAND_TAG_RE.search(text)
    if m:
        name = m.group(1)
        return name if name.startswith("/") else f"/{name}"
    # 2. Fallback: text bắt đầu bằng "/"
    stripped = text.lstrip()
    if not stripped.startswith("/"):
        return None
    first_line = stripped.split("\n", 1)[0]
    parts = first_line.split(None, 1)
    return parts[0] if parts else None


def get_user_text(message):
    """Lấy text content từ user message (skip system-reminder, ide_opened_file tags)."""
    content = message.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                t = item.get("text", "")
                # Skip pure system tags
                if t.strip().startswith("<system-reminder>") and t.strip().endswith("</system-reminder>"):
                    continue
                if t.strip().startswith("<ide_") and t.strip().endswith(">"):
                    continue
                texts.append(t)
        return "\n".join(texts)
    return ""


def parse_transcript(transcript_path):
    """
    Đọc transcript JSONL, trả về dict stats cho turn mới nhất.
    """
    entries = []
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                # Bỏ qua queue-operation và metadata không liên quan
                if obj.get("type") in ("user", "assistant"):
                    entries.append(obj)
    except (OSError, FileNotFoundError):
        return None

    if not entries:
        return None

    # Tìm turn boundary: last external user message (non-sidechain)
    turn_start_idx = None
    for i in range(len(entries) - 1, -1, -1):
        e = entries[i]
        if (e.get("type") == "user"
                and e.get("userType") == "external"
                and not e.get("isSidechain", False)):
            turn_start_idx = i
            break

    if turn_start_idx is None:
        return None

    turn_entries = entries[turn_start_idx:]
    user_msg = turn_entries[0]

    # Parse command name từ user text
    user_text = get_user_text(user_msg.get("message", {}))
    command_name = extract_command_name(user_text) or "(free-text)"
    user_text_preview = user_text.strip().split("\n")[0][:80] if user_text.strip() else ""

    # Aggregate assistant messages
    main_models = Counter()
    main_usage = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    sub_usage = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    main_msg_count = 0
    sub_msg_count = 0
    last_timestamp = None

    for e in turn_entries:
        if e.get("type") != "assistant":
            continue
        msg = e.get("message", {})
        usage = msg.get("usage", {})
        model = msg.get("model", "unknown")
        is_sub = e.get("isSidechain", False)

        target = sub_usage if is_sub else main_usage
        target["input"] += usage.get("input_tokens", 0)
        target["output"] += usage.get("output_tokens", 0)
        target["cache_read"] += usage.get("cache_read_input_tokens", 0)
        target["cache_creation"] += usage.get("cache_creation_input_tokens", 0)

        if is_sub:
            sub_msg_count += 1
        else:
            main_msg_count += 1
            main_models[model] += 1

        ts = iso_to_dt(e.get("timestamp"))
        if ts and (last_timestamp is None or ts > last_timestamp):
            last_timestamp = ts

    # Model phổ biến nhất trong main agent
    primary_model = main_models.most_common(1)[0][0] if main_models else "unknown"

    # Duration
    start_ts = iso_to_dt(user_msg.get("timestamp"))
    duration_sec = (last_timestamp - start_ts).total_seconds() if (start_ts and last_timestamp) else None

    return {
        "command": command_name,
        "user_text_preview": user_text_preview,
        "model": primary_model,
        "duration_sec": duration_sec,
        "main_usage": main_usage,
        "sub_usage": sub_usage,
        "main_msg_count": main_msg_count,
        "sub_msg_count": sub_msg_count,
        "start_ts": start_ts,
        "end_ts": last_timestamp,
    }


def print_stats(stats, log_file_path):
    """In stats ra stderr + append vào log file."""
    if not stats:
        return

    mu = stats["main_usage"]
    su = stats["sub_usage"]
    total_main = sum(mu.values())
    total_sub = sum(su.values())
    total_all = total_main + total_sub

    # Pretty print ra stderr (Claude Code display)
    lines = [
        "",
        "─" * 70,
        f" Command: {stats['command']}",
    ]
    if stats["user_text_preview"] and stats["command"] == "(free-text)":
        lines.append(f" Prompt:  {stats['user_text_preview']}")
    lines.extend([
        f" Model:   {stats['model']}",
        f" Time:    {format_duration(stats['duration_sec'])}",
        f" Tokens (main agent, {stats['main_msg_count']} msg):",
        f"   input          {format_number(mu['input']):>10}",
        f"   output         {format_number(mu['output']):>10}",
        f"   cache_read     {format_number(mu['cache_read']):>10}",
        f"   cache_creation {format_number(mu['cache_creation']):>10}",
        f"   ────────────────────────",
        f"   subtotal       {format_number(total_main):>10}",
    ])
    if stats["sub_msg_count"] > 0:
        lines.extend([
            f" Tokens (sub-agents, {stats['sub_msg_count']} msg):",
            f"   input          {format_number(su['input']):>10}",
            f"   output         {format_number(su['output']):>10}",
            f"   cache_read     {format_number(su['cache_read']):>10}",
            f"   cache_creation {format_number(su['cache_creation']):>10}",
            f"   ────────────────────────",
            f"   subtotal       {format_number(total_sub):>10}",
        ])
    lines.extend([
        f" TOTAL:           {format_number(total_all):>10} tokens",
        "─" * 70,
        "",
    ])
    print("\n".join(lines), file=sys.stderr)

    # Append log line (CSV-ish, dễ grep/parse)
    end_ts = stats["end_ts"]
    log_ts = end_ts.strftime("%Y-%m-%d %H:%M:%S") if end_ts else datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_line = (
        f"{log_ts} | {stats['command']:<20} | {stats['model']:<20} | "
        f"{format_duration(stats['duration_sec']):>10} | "
        f"main_in={mu['input']} out={mu['output']} "
        f"cache_r={mu['cache_read']} cache_c={mu['cache_creation']} | "
        f"sub_in={su['input']} out={su['output']} "
        f"cache_r={su['cache_read']} cache_c={su['cache_creation']} | "
        f"total={total_all}\n"
    )
    try:
        log_file_path.parent.mkdir(parents=True, exist_ok=True)
        with open(log_file_path, "a", encoding="utf-8") as f:
            f.write(log_line)
    except OSError as e:
        print(f"[log-command-stats] warn: cannot write log file: {e}", file=sys.stderr)


def main():
    # Đọc hook payload qua stdin
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Không có stdin valid — không phải hook context, exit silent
        sys.exit(0)

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        sys.exit(0)

    # Xác định project dir để biết log file ở đâu
    cwd = payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or "."
    log_file = Path(cwd) / ".claude" / "logs" / "command-stats.log"

    stats = parse_transcript(transcript_path)
    if stats:
        print_stats(stats, log_file)

    sys.exit(0)


if __name__ == "__main__":
    main()

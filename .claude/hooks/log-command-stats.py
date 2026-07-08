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
   - Prompt: preview <=120 ký tự nội dung prompt user (slash command → '/tên args'), sanitize cho log
5. In stats ra stderr (terminal thấy) + append 1 dòng vào .claude/logs/command-stats.log
   (cột: ts | command | model | duration | input | cache_creation | cache_read | output | total | cost | prompt)

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

# <command-args>…</command-args> giữ phần user gõ sau tên lệnh (vd '/model default' → args 'default').
_COMMAND_ARGS_RE = re.compile(r"<command-args>\s*(.*?)\s*</command-args>", re.DOTALL)

# Khi command file (.claude/commands/*.md) được gọi như Skill, transcript inline NGUYÊN
# thân file làm prompt — KHÔNG có tag <command-name> và KHÔNG bắt đầu bằng '/'. Dòng H1 đầu
# tiên của mọi command file có dạng "# /spec — …" → parse slash token từ heading này.
_COMMAND_HEADING_RE = re.compile(r"^\s*#\s*(/[A-Za-z0-9:_-]+)\b")

# Giới hạn độ dài prompt preview ghi vào log (tránh phình file khi user dán cả khối text lớn).
_PROMPT_PREVIEW_MAX = 120


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


def format_tokens(n):
    """Rút gọn token cho log: <1000 giữ số thô; ≥1e3 → K; ≥1e6 → M; ≥1e9 → B.
    Bỏ số 0 thừa sau dấu thập phân: 384→'384', 29616→'29.6K', 4763973→'4.76M', 120000→'120K'."""
    if n is None:
        return "0"
    n = int(n)
    if n < 1000:
        return str(n)
    for div, suffix, decimals in ((1_000_000_000, "B", 2), (1_000_000, "M", 2), (1000, "K", 1)):
        if n >= div:
            num = f"{n / div:.{decimals}f}".rstrip("0").rstrip(".")
            return f"{num}{suffix}"
    return str(n)  # không tới được (n ≥ 1000 luôn khớp nhánh K)


# Đơn giá API list-price ($/1M token): (input, output). Khớp theo prefix để chịu ID có hậu tố ngày.
# Model lạ → None (bỏ cột cost). Cache suy ra từ input: creation ≈ 1.25×input (TTL 5'), read ≈ 0.1×input.
def _price_for(model):
    m = model or ""
    if m.startswith("claude-opus-4"):
        return (5.0, 25.0)
    if m.startswith("claude-fable-5") or m.startswith("claude-mythos-5"):
        return (10.0, 50.0)
    if m.startswith("claude-sonnet"):
        return (3.0, 15.0)
    if m.startswith("claude-haiku"):
        return (1.0, 5.0)
    return None


def estimate_cost_usd(model, inp, cache_creation, cache_read, output):
    """Ước tính chi phí lượt theo API list-price; None nếu chưa biết đơn giá model.
    ƯỚC TÍNH: cache_creation giả định TTL 5' (×1.25 — thực tế có thể ×2 nếu TTL 1h, nhưng
    khoản này nhỏ); token sub-agent tính theo đơn giá model chính. Vì vậy là 'cost≈'."""
    price = _price_for(model)
    if price is None:
        return None
    in_rate, out_rate = price
    return (
        inp * in_rate
        + cache_creation * in_rate * 1.25
        + cache_read * in_rate * 0.1
        + output * out_rate
    ) / 1_000_000


def format_cost(usd):
    """'$3.22'; < 1 cent → '<$0.01'; None → 'n/a'."""
    if usd is None:
        return "n/a"
    if usd < 0.005:
        return "<$0.01"
    return f"${usd:.2f}"


def extract_command_name(text):
    """Trả về tên command (vd '/spec'), ngược lại None.

    1. Ưu tiên tag <command-name>/spec</command-name> — cách Claude Code expand slash command
       trong transcript (block này KHÔNG bắt đầu bằng '/').
    2. Skill/expanded-body: command file inline làm prompt, H1 đầu là "# /spec — …".
    3. Fallback: text gõ thẳng bắt đầu bằng '/'.
    """
    if not text:
        return None
    # 1. Slash command đã expand → đọc tag <command-name>
    m = _COMMAND_TAG_RE.search(text)
    if m:
        name = m.group(1)
        return name if name.startswith("/") else f"/{name}"
    stripped = text.lstrip()
    # 2. Command file inline (gọi như Skill) → H1 đầu "# /spec — …"
    m2 = _COMMAND_HEADING_RE.match(stripped)
    if m2:
        return m2.group(1)
    # 3. Fallback: text bắt đầu bằng "/"
    if not stripped.startswith("/"):
        return None
    first_line = stripped.split("\n", 1)[0]
    parts = first_line.split(None, 1)
    return parts[0] if parts else None


def build_prompt_preview(text, max_len=_PROMPT_PREVIEW_MAX):
    """Preview 1-dòng, an toàn cho log pipe-delimited, của prompt user.

    - Slash command (Claude Code expand thành block <command-*>): tái dựng thành
      '/tên args' đúng như user gõ (vd '/spec', '/model default') — bỏ XML wrapper +
      <command-message> (chỉ lặp lại tên lệnh, là noise).
    - Free-text: lấy nguyên text.
    - Mọi trường hợp: gộp whitespace/newline về 1 space, thay '|' (tránh phá cột log),
      cắt còn <=max_len ký tự (thêm '…' nếu bị cắt).
    """
    if not text:
        return ""
    name_m = _COMMAND_TAG_RE.search(text)
    if name_m:
        # Slash command → '/tên' + args (nếu có), bỏ qua wrapper XML.
        name = name_m.group(1)
        if not name.startswith("/"):
            name = f"/{name}"
        args_m = _COMMAND_ARGS_RE.search(text)
        args = args_m.group(1).strip() if args_m else ""
        preview = f"{name} {args}".strip()
    else:
        preview = text
    # Chuẩn hoá an toàn cho log: gộp whitespace, thay ký tự phá cột.
    preview = " ".join(preview.split()).replace("|", "¦")
    if len(preview) > max_len:
        preview = preview[:max_len].rstrip() + "…"
    return preview


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

    # Tìm turn boundary: external user message (non-sidechain) GẦN NHẤT có text thật.
    # Lưu ý: tool_result (kết quả Bash/Edit/…) cũng là type=user + userType=external +
    # isSidechain=false → nếu không lọc, vòng này vớ phải tool_result cuối thay vì prompt
    # → prompt rỗng, token đếm thiếu, command mất (thành "(free-text)"). Điều kiện
    # get_user_text(...).strip() khác rỗng đảm bảo chỉ đáp đúng vào prompt / slash command.
    turn_start_idx = None
    for i in range(len(entries) - 1, -1, -1):
        e = entries[i]
        if (e.get("type") == "user"
                and e.get("userType") == "external"
                and not e.get("isSidechain", False)
                and get_user_text(e.get("message", {})).strip()):
            turn_start_idx = i
            break

    if turn_start_idx is None:
        return None

    turn_entries = entries[turn_start_idx:]
    user_msg = turn_entries[0]

    # Parse command name từ user text
    user_text = get_user_text(user_msg.get("message", {}))
    command_name = extract_command_name(user_text) or "(free-text)"
    user_text_preview = build_prompt_preview(user_text)

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

    # Turn rỗng: message "user" chỉ là context IDE (mở file/selection) hoặc lệnh local,
    # không kèm lượt trả lời nào của model → không có model/token/thời gian để log. Bỏ qua
    # (tránh các dòng noise "unknown | total=0"). main() đã guard `if stats:` nên None = không ghi.
    if main_msg_count == 0 and sub_msg_count == 0:
        return None

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
    """In stats ra stderr + append 1 dòng vào log file."""
    if not stats:
        return

    mu = stats["main_usage"]
    su = stats["sub_usage"]
    total_main = sum(mu.values())
    total_sub = sum(su.values())
    total_all = total_main + total_sub
    total_output = mu["output"] + su["output"]  # output token (main+sub)
    # Combined main+sub cho từng loại token — mỗi cột log = TỔNG toàn lệnh (main + mọi sub-agent).
    all_input = mu["input"] + su["input"]
    all_cache_read = mu["cache_read"] + su["cache_read"]
    all_cache_creation = mu["cache_creation"] + su["cache_creation"]

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
    # end_ts là datetime aware-UTC (parse từ transcript có hậu tố 'Z'). .astimezone() (không
    # tham số) đổi về múi giờ hệ thống → log hiện giờ local, nhất quán với nhánh fallback now().
    _dt = end_ts.astimezone() if end_ts else datetime.now()
    log_ts = _dt.strftime("%Y-%m-%d %H:%M")  # năm đủ 4 chữ số + HH:MM (bỏ giây; tránh đọc nhầm '26-07-04')
    # Bản log (pipe-delimited): ts | command | model | duration |
    #   input | cache_creation | cache_read | output | total | prompt
    # Mỗi cột token = TỔNG toàn lệnh (main-agent + mọi sub-agent), KHÔNG tách riêng sub.
    # total = input + cache_creation + cache_read + output (== tổng usage main+sub).
    # Token rút gọn bằng format_tokens: <1000 số thô, ≥1e3→K, ≥1e6→M, ≥1e9→B (vd 4763973→4.76M).
    #   total humanize từ giá trị CHÍNH XÁC rồi mới rút gọn → có thể lệch vài đơn vị so với
    #   cộng tay các cột đã rút gọn (do làm tròn). Breakdown chính xác + tách main/sub ở stderr.
    # cost = ước tính USD theo API list-price (estimate_cost_usd); 'n/a' nếu chưa biết đơn giá model.
    # ts: YYYY-MM-DD HH:MM (năm đủ 4 chữ số, chỉ bỏ giây). Token-col width 7 (đủ cho '999.99M').
    cost = estimate_cost_usd(stats["model"], all_input, all_cache_creation, all_cache_read, total_output)
    log_line = (
        f"{log_ts} | {stats['command']:<12} | {stats['model']:<15} | "
        f"{format_duration(stats['duration_sec']):>8} | "
        f"input={format_tokens(all_input):>7} | "
        f"cache_creation={format_tokens(all_cache_creation):>7} | "
        f"cache_read={format_tokens(all_cache_read):>7} | "
        f"output={format_tokens(total_output):>7} | "
        f"total={format_tokens(total_all):>7} | "
        f"cost={format_cost(cost):>7} | "
        f"prompt=\"{stats['user_text_preview']}\"\n"
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

    # Xác định project dir để biết log file ở đâu.
    # CLAUDE_PROJECT_DIR luôn là project root (Claude Code export cho hook process);
    # payload["cwd"] là thư mục làm việc HIỆN TẠI của phiên — thay đổi khi user/agent
    # `cd` đi nơi khác → từng gây ra log file lồng nhầm (.claude/rules/.claude/logs/…).
    # Chỉ dùng cwd làm fallback khi env var vắng mặt.
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."
    log_file = Path(project_dir) / ".claude" / "logs" / "command-stats.log"

    stats = parse_transcript(transcript_path)
    if stats:
        print_stats(stats, log_file)

    sys.exit(0)


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
# .claude/scripts/scan-all.sh
# ----------------------------------------------------------------------------
# Mục đích: Orchestrator — auto-detect tech stack trong repo và dispatch
#           scanner phù hợp (dotnet, nodejs, python, docker, ...).
# Output:   structured files trong security/{sast-results,dependency-audit,
#           container-scan}/ + SCAN_SUMMARY.json tổng hợp.
#
# Cách dùng: bash .claude/scripts/scan-all.sh
# Exit code: 0 nếu chạy xong; 1 nếu lỗi nội bộ.
#
# Cấu trúc:
#   scan-all.sh                   ← orchestrator (file này)
#   scan-summarize.py             ← merge output thành SCAN_SUMMARY.json
#   scanners/
#     _common.sh                  ← shared utils + universal secrets scan
#     dotnet.sh                   ← scan_dotnet()
#     nodejs.sh                   ← scan_nodejs()
#     python.sh                   ← scan_python()
#     docker.sh                   ← scan_docker()
#
# Mở rộng cho stack mới: tạo scanners/<stack>.sh định nghĩa function scan_<stack>()
#                        rồi thêm vào detect_stacks() trong _common.sh + case dispatch dưới.
# ----------------------------------------------------------------------------

set -uo pipefail

# Đi tới repo root (thư mục cha của .claude/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNERS_DIR="$SCRIPT_DIR/scanners"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Output dirs
mkdir -p security/sast-results security/dependency-audit security/container-scan

LOG_FILE="security/sast-results/scan-all.log"
TOOL_FILE="security/sast-results/tooling-availability.txt"
: > "$LOG_FILE"

# Source common utilities (log, has, scan_secrets, write_tool_inventory, detect_stacks)
# shellcheck source=scanners/_common.sh
source "$SCANNERS_DIR/_common.sh"

log "=== scan-all.sh started ==="
log "Repo root: $REPO_ROOT"
if [ -n "${SCAN_DIFF_BASE:-}" ]; then
    log "Mode: DIFF-SCOPED semgrep vs $SCAN_DIFF_BASE (SCA + secrets + Roslyn + ESLint + grep remain whole-repo)"
else
    log "Mode: WHOLE-REPO (full scan)"
fi

# ---------------------------------------------------------------------------
# Phase 1: Tool inventory + stack auto-detect
# ---------------------------------------------------------------------------
log "Phase 1: tool inventory → $TOOL_FILE"
write_tool_inventory "$TOOL_FILE"

log "Phase 1: stack auto-detect"
# Compatible với macOS bash 3.2 (không có mapfile)
DETECTED_STACKS=()
while IFS= read -r line; do
    [ -n "$line" ] && DETECTED_STACKS+=("$line")
done < <(detect_stacks)
if [ ${#DETECTED_STACKS[@]} -eq 0 ]; then
    log "  WARNING: no recognized stack found in repo. Will run universal scans only."
else
    log "  Detected stacks: ${DETECTED_STACKS[*]}"
fi

# ---------------------------------------------------------------------------
# Phase 2: Universal — secrets scan (always runs, every stack)
# ---------------------------------------------------------------------------
log "Phase 2: universal scans"
scan_secrets

# ---------------------------------------------------------------------------
# Phase 3: Per-stack scans (dispatch theo stack detected)
# ---------------------------------------------------------------------------
log "Phase 3: per-stack scans"
# Safe array iteration với bash strict mode (handle empty array)
for stack in "${DETECTED_STACKS[@]+"${DETECTED_STACKS[@]}"}"; do
    plugin="$SCANNERS_DIR/${stack}.sh"
    if [ -f "$plugin" ]; then
        # shellcheck disable=SC1090
        source "$plugin"
        # Function name convention: scan_<stack>
        if declare -f "scan_${stack}" >/dev/null; then
            "scan_${stack}"
        else
            log "  [${stack}] plugin loaded but scan_${stack}() not defined — skipping"
        fi
    else
        log "  [${stack}] no plugin at $plugin — skipping (extend by creating scanners/${stack}.sh)"
    fi
done

# ---------------------------------------------------------------------------
# Phase 4: Summarize → SCAN_SUMMARY.json
# ---------------------------------------------------------------------------
log "Phase 4: aggregating findings → security/SCAN_SUMMARY.json"
if has python3; then
    python3 "$SCRIPT_DIR/scan-summarize.py" > security/SCAN_SUMMARY.json
    log "  summary written. Severity counts:"
    python3 -c "
import json, sys
try:
    with open('security/SCAN_SUMMARY.json') as f:
        s = json.load(f)
    totals = s.get('totals', {})
    print(f\"    Critical: {totals.get('critical', 0)}\")
    print(f\"    High:     {totals.get('high', 0)}\")
    print(f\"    Medium:   {totals.get('medium', 0)}\")
    print(f\"    Low:      {totals.get('low', 0)}\")
    print(f\"    Total findings: {s.get('findings_count', 0)}\")
    print(f\"    Stacks scanned: {s.get('stacks_scanned', [])}\")
except Exception as e:
    print(f'  error reading summary: {e}', file=sys.stderr)
" 2>&1 | tee -a "$LOG_FILE"
else
    log "  python3 MISSING — SCAN_SUMMARY.json not generated, agent must aggregate manually"
fi

log "=== scan-all.sh done ==="
log "Next: agent /scan reads security/SCAN_SUMMARY.json + verifies STRIDE matrix"

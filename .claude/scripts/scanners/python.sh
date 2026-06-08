#!/usr/bin/env bash
# .claude/scripts/scanners/python.sh
# Scanner cho Python projects (Django / Flask / FastAPI).
# Sourced bởi scan-all.sh. Yêu cầu: _common.sh đã sourced trước.
#
# Status: placeholder skeleton — extend khi cần dùng cho Python project.
# Toolset suggested: pip-audit (deps CVE), safety (deps CVE alt), bandit (SAST),
# ruff (lint security rules), mypy (type check).

scan_python() {
    log "[python] starting"

    # pip-audit — production dependencies
    if has pip-audit; then
        log "  pip-audit (requirements + lock files)"
        if [ -f requirements.txt ]; then
            pip-audit -r requirements.txt --format json > security/dependency-audit/pip-audit.json 2>&1 || true
        fi
        if [ -f pyproject.toml ] || [ -f poetry.lock ]; then
            pip-audit --format json > security/dependency-audit/pip-audit-project.json 2>&1 || true
        fi
    else
        log "  pip-audit MISSING — install: pipx install pip-audit"
    fi

    # safety — alternative CVE scanner
    if has safety; then
        log "  safety check"
        safety check --json > security/dependency-audit/safety.json 2>&1 || true
    fi

    # bandit — SAST
    if has bandit; then
        log "  bandit (SAST)"
        bandit -r . -f json -o security/sast-results/bandit.json \
            --exclude .venv,venv,node_modules,tests 2>&1 | tee -a "$LOG_FILE" || true
    else
        log "  bandit MISSING — install: pipx install bandit"
    fi

    # ruff — fast linter với security rules
    if has ruff; then
        log "  ruff check (security rules: S = bandit-like)"
        ruff check --select S --output-format json . > security/sast-results/ruff-security.json 2>&1 || true
    fi

    # Semgrep python rules
    if has semgrep; then
        log "  semgrep python + security-audit + owasp-top-ten"
        semgrep --config=p/python --config=p/security-audit --config=p/owasp-top-ten \
            --json --output security/sast-results/semgrep-python.json . 2>&1 | tee -a "$LOG_FILE" || true
    fi

    log "[python] done"
}

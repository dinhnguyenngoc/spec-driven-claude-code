#!/usr/bin/env bash
# .claude/scripts/scanners/_common.sh
# Shared utilities + universal scans (secrets) — sourced bởi scan-all.sh
# KHÔNG executable trực tiếp.

# ----------------------------------------------------------------------------
# Logging (assumes LOG_FILE set by parent)
# ----------------------------------------------------------------------------
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "${LOG_FILE:-/dev/null}"; }
has() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# Universal: secrets scan (chạy bất kể stack nào)
# ----------------------------------------------------------------------------
scan_secrets() {
    log "[common] secrets scan"
    if has gitleaks; then
        gitleaks detect --source . --no-banner --report-format json \
            --report-path security/sast-results/gitleaks.json 2>&1 | tee -a "$LOG_FILE" || true
    else
        log "  gitleaks MISSING — fallback regex grep"
        grep -rnE '(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
            --include="*.cs" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
            --include="*.py" --include="*.java" --include="*.go" --include="*.rb" --include="*.php" \
            --include="*.json" --include="*.yml" --include="*.yaml" --include="*.env*" \
            --exclude-dir=node_modules --exclude-dir=bin --exclude-dir=obj \
            --exclude-dir=.git --exclude-dir=vendor --exclude-dir=target --exclude-dir=__pycache__ \
            . > security/sast-results/secrets-grep.txt 2>/dev/null || true
    fi
}

# ----------------------------------------------------------------------------
# Tool inventory writer
# ----------------------------------------------------------------------------
write_tool_inventory() {
    local out="$1"
    {
        for tool in gitleaks semgrep trufflehog snyk trivy hadolint \
                    dotnet npm node pip pip-audit safety bandit \
                    mvn gradle govulncheck staticcheck gosec \
                    bundler-audit brakeman composer \
                    jq python3 docker; do
            if has "$tool"; then
                echo "$tool: installed ($(command -v "$tool"))"
            else
                echo "$tool: MISSING"
            fi
        done
    } > "$out"
}

# ----------------------------------------------------------------------------
# Stack auto-detect (echo tên các stack có trong repo)
# ----------------------------------------------------------------------------
detect_stacks() {
    local stacks=()

    # .NET — có .csproj hoặc .sln
    if compgen -G "*.sln" >/dev/null 2>&1 || \
       find . -maxdepth 4 -name "*.csproj" -not -path "*/node_modules/*" -not -path "*/bin/*" -not -path "*/obj/*" 2>/dev/null | head -1 | grep -q .; then
        stacks+=("dotnet")
    fi

    # Node.js — có package.json (loại trừ node_modules)
    if find . -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
        stacks+=("nodejs")
    fi

    # Python — có pyproject.toml / requirements.txt / setup.py
    if find . -maxdepth 4 \( -name "pyproject.toml" -o -name "requirements*.txt" -o -name "setup.py" \) \
       -not -path "*/node_modules/*" -not -path "*/.venv/*" -not -path "*/venv/*" 2>/dev/null | head -1 | grep -q .; then
        stacks+=("python")
    fi

    # Java — có pom.xml / build.gradle / build.gradle.kts
    if find . -maxdepth 4 \( -name "pom.xml" -o -name "build.gradle" -o -name "build.gradle.kts" \) \
       -not -path "*/node_modules/*" -not -path "*/target/*" 2>/dev/null | head -1 | grep -q .; then
        stacks+=("java")
    fi

    # Go — có go.mod
    if [ -f go.mod ]; then
        stacks+=("go")
    fi

    # Ruby — có Gemfile
    if [ -f Gemfile ]; then
        stacks+=("ruby")
    fi

    # PHP — có composer.json
    if [ -f composer.json ]; then
        stacks+=("php")
    fi

    # Docker — có Dockerfile (root hoặc docker/)
    if [ -f Dockerfile ] || [ -f docker/Dockerfile ] || find . -maxdepth 3 -name "Dockerfile*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
        stacks+=("docker")
    fi

    printf "%s\n" "${stacks[@]}"
}

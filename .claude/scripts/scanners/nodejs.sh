#!/usr/bin/env bash
# .claude/scripts/scanners/nodejs.sh
# Scanner cho Node.js projects (Express / NestJS / Fastify + Next.js frontend).
# Sourced bởi scan-all.sh. Yêu cầu: _common.sh đã được sourced trước.

scan_nodejs() {
    log "[nodejs] starting"
    if ! has npm; then
        log "  npm MISSING — skipping Node.js scan"
        return
    fi

    # Tìm tất cả package.json (bỏ qua node_modules)
    local pkg_dirs=()
    while IFS= read -r pkg; do
        pkg_dirs+=("$(dirname "$pkg")")
    done < <(find . -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null)

    if [ ${#pkg_dirs[@]} -eq 0 ]; then
        log "  No package.json found — skipping"
        return
    fi

    log "  Found ${#pkg_dirs[@]} package.json location(s): ${pkg_dirs[*]}"

    local idx=0
    for pkg_dir in "${pkg_dirs[@]}"; do
        idx=$((idx + 1))
        local safe_name
        safe_name=$(echo "$pkg_dir" | sed 's|^\./||; s|/|_|g; s|^\.$|root|')
        log "  [${idx}/${#pkg_dirs[@]}] scanning: $pkg_dir"

        # Dependency vulnerabilities — production runtime (block-relevant)
        (cd "$pkg_dir" && npm audit --omit=dev --json) \
            > "security/dependency-audit/npm-audit-${safe_name}.json" 2>&1 || true

        # Full audit (incl. dev — informational)
        (cd "$pkg_dir" && npm audit --json) \
            > "security/dependency-audit/npm-audit-full-${safe_name}.json" 2>&1 || true

        # Outdated packages
        (cd "$pkg_dir" && npm outdated --json) \
            > "security/dependency-audit/npm-outdated-${safe_name}.json" 2>&1 || true

        # ESLint với security plugin (nếu có config)
        if [ -f "$pkg_dir/eslint.config.js" ] || [ -f "$pkg_dir/eslint.config.mjs" ] || \
           [ -f "$pkg_dir/.eslintrc.json" ] || [ -f "$pkg_dir/.eslintrc.js" ] || \
           [ -f "$pkg_dir/.eslintrc.cjs" ]; then
            log "    eslint --max-warnings=0 (security-focused)"
            (cd "$pkg_dir" && npx --no-install eslint . --max-warnings=0 --format json) \
                > "security/sast-results/eslint-${safe_name}.json" 2>&1 || true
        else
            log "    no eslint config — skipping ESLint"
        fi

        # TypeScript type check (nếu có tsconfig)
        if [ -f "$pkg_dir/tsconfig.json" ]; then
            log "    tsc --noEmit (type check)"
            (cd "$pkg_dir" && npx --no-install tsc --noEmit) \
                > "security/sast-results/tsc-${safe_name}.log" 2>&1 || true
        fi

        # retire.js — vulnerable JS lib detection (nếu có)
        if has retire; then
            log "    retire.js scan"
            (cd "$pkg_dir" && retire --outputformat json --outputpath "/tmp/retire-${safe_name}.json") 2>&1 | tee -a "$LOG_FILE" || true
            mv "/tmp/retire-${safe_name}.json" "security/sast-results/retire-${safe_name}.json" 2>/dev/null || true
        fi
    done

    # Semgrep (nếu có) cho JS/TS rules
    if has semgrep; then
        log "  semgrep javascript + typescript + security-audit + owasp-top-ten"
        semgrep --config=p/javascript --config=p/typescript \
                --config=p/security-audit --config=p/owasp-top-ten \
                --json --output security/sast-results/semgrep-nodejs.json . 2>&1 | tee -a "$LOG_FILE" || true
    fi

    # XSS pattern grep — toàn bộ frontend code
    log "  XSS pattern grep across all .ts/.tsx/.js/.jsx"
    {
        echo "=== dangerouslySetInnerHTML / .innerHTML = ==="
        grep -rnE "dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=" \
            --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
            --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== inline <script> tags ==="
        grep -rnE "<script>[^<]+</script>" \
            --include="*.html" --include="*.tsx" --include="*.jsx" \
            --exclude-dir=node_modules \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== scattered localStorage token writes (should be in central module) ==="
        grep -rnE "localStorage\.setItem\([^)]*token" \
            --include="*.ts" --include="*.tsx" --include="*.js" \
            --exclude-dir=node_modules \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== eval / new Function (RCE risk) ==="
        grep -rnE "\beval\s*\(|new[[:space:]]+Function[[:space:]]*\(" \
            --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
            --exclude-dir=node_modules --exclude-dir=dist \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== child_process exec / execSync với template literal (cmd injection risk) ==="
        grep -rnE "(exec|execSync|spawn)\s*\(\s*\`" \
            --include="*.ts" --include="*.js" \
            --exclude-dir=node_modules \
            . 2>/dev/null || echo "(none)"
    } > security/sast-results/frontend-xss-grep.txt

    log "[nodejs] done"
}

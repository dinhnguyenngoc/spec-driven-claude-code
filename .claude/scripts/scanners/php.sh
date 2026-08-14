#!/usr/bin/env bash
# .claude/scripts/scanners/php.sh
# Scanner cho PHP projects (Laravel / Symfony / legacy PHP).
# Sourced bởi scan-all.sh. Yêu cầu: _common.sh đã được sourced trước.

scan_php() {
    log "[php] starting"
    if ! has composer; then
        log "  composer MISSING — skipping dependency audit (grep-based checks still run)"
    fi

    # Tìm tất cả composer.json (bỏ qua vendor/node_modules)
    local pkg_dirs=()
    while IFS= read -r pkg; do
        pkg_dirs+=("$(dirname "$pkg")")
    done < <(find . -maxdepth 4 -name "composer.json" -not -path "*/vendor/*" -not -path "*/node_modules/*" 2>/dev/null)

    if [ ${#pkg_dirs[@]} -eq 0 ]; then
        log "  No composer.json found — skipping"
        return
    fi

    log "  Found ${#pkg_dirs[@]} composer.json location(s): ${pkg_dirs[*]}"

    local idx=0
    for pkg_dir in "${pkg_dirs[@]}"; do
        idx=$((idx + 1))
        local safe_name
        safe_name=$(echo "$pkg_dir" | sed 's|^\./||; s|/|_|g; s|^\.$|root|')
        log "  [${idx}/${#pkg_dirs[@]}] scanning: $pkg_dir"

        if has composer; then
            # Dependency vulnerabilities — production runtime (block-relevant)
            (cd "$pkg_dir" && composer audit --no-dev --format=json) \
                > "security/dependency-audit/composer-audit-${safe_name}.json" 2>&1 || true

            # Full audit (incl. dev — informational)
            (cd "$pkg_dir" && composer audit --format=json) \
                > "security/dependency-audit/composer-audit-full-${safe_name}.json" 2>&1 || true

            # Outdated packages (direct only — informational)
            (cd "$pkg_dir" && composer outdated --direct --format=json) \
                > "security/dependency-audit/composer-outdated-${safe_name}.json" 2>&1 || true
        fi

        # PHPStan / Larastan (nếu repo có config + binary đã cài qua composer)
        if [ -f "$pkg_dir/phpstan.neon" ] || [ -f "$pkg_dir/phpstan.neon.dist" ] || [ -f "$pkg_dir/phpstan.dist.neon" ]; then
            if [ -x "$pkg_dir/vendor/bin/phpstan" ]; then
                log "    phpstan analyse (error-format=json)"
                (cd "$pkg_dir" && ./vendor/bin/phpstan analyse --no-progress --error-format=json) \
                    > "security/sast-results/phpstan-${safe_name}.json" 2>&1 || true
            else
                log "    phpstan config found but vendor/bin/phpstan missing — run composer install first"
            fi
        fi
    done

    # Semgrep (nếu có) cho PHP rules — diff-scoped khi SCAN_DIFF_BASE set (brownfield per-change)
    if has semgrep; then
        local sg_out="security/sast-results/semgrep-php.json"
        local sg_cfg=(--config=p/php --config=p/security-audit --config=p/owasp-top-ten)
        if scan_diff_mode; then
            local php_files; php_files=$(changed_files '\.php$')
            if [ "$php_files" = "__GIT_ERROR__" ]; then
                log "  semgrep: diff base unresolved → FALLBACK whole-repo"
                semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
            elif [ -n "$php_files" ]; then
                local files=(); while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done <<< "$php_files"
                if [ ${#files[@]} -gt 500 ]; then
                    log "  semgrep: ${#files[@]} changed PHP files (>500) → FALLBACK whole-repo"
                    semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
                else
                    log "  semgrep (diff vs $SCAN_DIFF_BASE) on ${#files[@]} changed PHP file(s)"
                    semgrep "${sg_cfg[@]}" --json --output "$sg_out" "${files[@]}" 2>&1 | tee -a "$LOG_FILE" || true
                fi
            else
                log "  semgrep: no changed PHP files (diff mode) — empty result"
                echo '{"results":[],"errors":[]}' > "$sg_out"
            fi
        else
            log "  semgrep php + security-audit + owasp-top-ten (whole repo)"
            semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
        fi
    fi

    # PHP dangerous-pattern grep
    log "  dangerous-pattern grep across all .php / .blade.php"
    {
        echo "=== eval / assert(\$var) / create_function (RCE risk) ==="
        grep -rnE "\beval[[:space:]]*\(|\bassert[[:space:]]*\([[:space:]]*\\\$|create_function[[:space:]]*\(" \
            --include="*.php" \
            --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=storage \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== exec / shell_exec / system / passthru / popen / proc_open với biến (cmd injection risk) ==="
        grep -rnE "(exec|shell_exec|system|passthru|popen|proc_open)[[:space:]]*\([^)]*\\\$" \
            --include="*.php" \
            --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=storage \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== unserialize trên user input (object injection) ==="
        grep -rnE "unserialize[[:space:]]*\([[:space:]]*\\\$(_(GET|POST|REQUEST|COOKIE)|request)" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== DB::raw / whereRaw / selectRaw / orderByRaw / havingRaw chứa biến (SQL injection risk) ==="
        grep -rnE "(DB::raw|whereRaw|selectRaw|orderByRaw|havingRaw)[[:space:]]*\([^)]*\\\$" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== {!! !!} unescaped Blade output (XSS risk — mỗi chỗ phải có lý do) ==="
        grep -rnE "\{!!" \
            --include="*.blade.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== \$request->all() vào create/update/fill (mass assignment risk) ==="
        grep -rnE "(create|update|fill|forceFill)[[:space:]]*\([[:space:]]*\\\$request->all\(\)" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== \$guarded = [] (mass assignment wide-open) ==="
        grep -rnE "\\\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== md5 / sha1 cho password (weak hashing) ==="
        grep -rnE "(md5|sha1)[[:space:]]*\([^)]*(pass|pwd)" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
        echo
        echo "=== extract() trên user input (variable injection) ==="
        grep -rnE "extract[[:space:]]*\([[:space:]]*\\\$(_(GET|POST|REQUEST)|request)" \
            --include="*.php" \
            --exclude-dir=vendor \
            . 2>/dev/null || echo "(none)"
    } > security/sast-results/php-dangerous-grep.txt

    log "[php] done"
}

#!/usr/bin/env bash
# .claude/scripts/scanners/dotnet.sh
# Scanner cho .NET / ASP.NET Core projects.
# Sourced bởi scan-all.sh. Yêu cầu: _common.sh đã được sourced trước.

scan_dotnet() {
    log "[dotnet] starting"
    if ! has dotnet; then
        log "  dotnet MISSING — skipping .NET scan"
        return
    fi

    # Dependency vulnerabilities — solution-level nếu có .sln, ngược lại loop .csproj
    if compgen -G "*.sln" >/dev/null 2>&1; then
        log "  dotnet list package --vulnerable (solution-level)"
        dotnet list package --vulnerable --include-transitive --format json \
            > security/dependency-audit/nuget-vulnerable.json 2>&1 || true
    else
        log "  No .sln found — looping per .csproj (brownfield mode)"
        : > security/dependency-audit/nuget-vulnerable.json
        while IFS= read -r csproj; do
            log "    scanning $csproj"
            dotnet list "$csproj" package --vulnerable --include-transitive --format json \
                >> security/dependency-audit/nuget-vulnerable.json 2>&1 || true
        done < <(find . -name "*.csproj" -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/node_modules/*")
    fi

    dotnet list package --outdated > security/dependency-audit/nuget-outdated.txt 2>&1 || true

    # SAST — Roslyn analyzers via build
    log "  Roslyn analyzers via dotnet build -warnaserror"
    dotnet build /p:RunAnalyzers=true -warnaserror \
        > security/sast-results/roslyn.log 2>&1 || true

    # Semgrep (nếu có) cho C# rules — diff-scoped khi SCAN_DIFF_BASE set (brownfield per-change)
    if has semgrep; then
        local sg_out="security/sast-results/semgrep-dotnet.json"
        local sg_cfg=(--config=p/csharp --config=p/security-audit --config=p/owasp-top-ten)
        if scan_diff_mode; then
            local cs_files; cs_files=$(changed_files '\.cs$')
            if [ "$cs_files" = "__GIT_ERROR__" ]; then
                log "  semgrep: diff base unresolved → FALLBACK whole-repo"
                semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
            elif [ -n "$cs_files" ]; then
                local files=(); while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done <<< "$cs_files"
                if [ ${#files[@]} -gt 500 ]; then
                    log "  semgrep: ${#files[@]} changed .cs files (>500) → FALLBACK whole-repo"
                    semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
                else
                    log "  semgrep (diff vs $SCAN_DIFF_BASE) on ${#files[@]} changed .cs file(s)"
                    semgrep "${sg_cfg[@]}" --json --output "$sg_out" "${files[@]}" 2>&1 | tee -a "$LOG_FILE" || true
                fi
            else
                log "  semgrep: no changed .cs files (diff mode) — empty result"
                echo '{"results":[],"errors":[]}' > "$sg_out"
            fi
        else
            log "  semgrep csharp + security-audit + owasp-top-ten (whole repo)"
            semgrep "${sg_cfg[@]}" --json --output "$sg_out" . 2>&1 | tee -a "$LOG_FILE" || true
        fi
    fi

    log "[dotnet] done"
}

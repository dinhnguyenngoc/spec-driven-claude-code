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

    # Semgrep (nếu có) cho C# rules
    if has semgrep; then
        log "  semgrep csharp + security-audit + owasp-top-ten"
        semgrep --config=p/csharp --config=p/security-audit --config=p/owasp-top-ten \
            --json --output security/sast-results/semgrep-dotnet.json . 2>&1 | tee -a "$LOG_FILE" || true
    fi

    log "[dotnet] done"
}

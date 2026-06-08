#!/usr/bin/env bash
# .claude/scripts/scanners/docker.sh
# Container + Dockerfile scanner.
# Sourced bởi scan-all.sh. Yêu cầu: _common.sh đã sourced trước.

scan_docker() {
    log "[docker] starting"

    # Trivy filesystem scan (luôn chạy nếu có trivy — không cần image)
    if has trivy; then
        log "  trivy fs (filesystem CVE scan)"
        trivy fs --format json --output security/container-scan/trivy-fs.json . 2>&1 | tee -a "$LOG_FILE" || true

        # Trivy image scan (chỉ nếu image đã build)
        if has docker; then
            local repo_name
            repo_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')
            local images
            images=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null \
                | grep -iE "^${repo_name}(-api|-web|-frontend|-backend)?:" \
                | grep -v "<none>" | head -5)
            if [ -n "$images" ]; then
                echo "$images" | while read -r img; do
                    local safe
                    safe=$(echo "$img" | tr ':/' '__')
                    log "  trivy image $img"
                    trivy image --format json --output "security/container-scan/trivy-image-${safe}.json" "$img" \
                        2>&1 | tee -a "$LOG_FILE" || true
                done
            else
                log "  no project image in docker registry — skipping trivy image scan"
            fi
        fi
    else
        log "  trivy MISSING — compensating control: defer to /infra Docker build step"
    fi

    # Hadolint cho Dockerfile
    if has hadolint; then
        # Tìm mọi Dockerfile trong repo
        local dockerfiles=()
        while IFS= read -r df; do
            dockerfiles+=("$df")
        done < <(find . -maxdepth 4 \( -name "Dockerfile" -o -name "Dockerfile.*" \) \
                 -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

        if [ ${#dockerfiles[@]} -gt 0 ]; then
            for df in "${dockerfiles[@]}"; do
                local safe
                safe=$(echo "$df" | sed 's|^\./||; s|/|_|g')
                log "  hadolint $df"
                hadolint --format json "$df" > "security/sast-results/hadolint-${safe}.json" 2>&1 || true
            done
        else
            log "  no Dockerfile found"
        fi
    elif find . -maxdepth 4 -name "Dockerfile*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
        log "  hadolint MISSING — manual review against .claude/references/docker-patterns.md needed"
    fi

    log "[docker] done"
}

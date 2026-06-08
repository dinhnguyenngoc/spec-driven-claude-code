---
name: deploy
description: Build, test, deploy with staged rollout
---

# /deploy — Release & Deployment

> "Ship with confidence."

## Purpose

Execute deployment to Docker Desktop: build images, run containers, verify health, rollback if needed.

> **Note**: Dockerfile and docker-compose are created in `/infra`. This command **executes** deployment.

> **Stack Profile note:** the `sqlcmd`/DB commands below use the **default profile** (SQL Server). If `Project Profile` declares Oracle/MySQL → swap to the corresponding client (`sqlplus`/`mysql`) per `rules/overrides/database-*.md`.

> **`/verify` policy:** `/verify` is **step optional · BLOCKING if run** (Gate 11). Strongly recommended before production promote (especially brownfield, or releases with infra/config changes). **Required when `/deploy` is invoked from the `/hotfix` orchestrator** — hotfix Step 4 requires re-verify on the patched digest. If `/verify` runs, `/deploy` may only promote a digest with a VERIFY_REPORT PASS for **that exact digest** (digest match enforced).

## Scope Clarification

| Command | Responsibility |
|---------|----------------|
| `/infra` | **Setup** — Dockerfile, docker-compose.yml, env config |
| `/deploy` | **Execute** — Build, run, verify, rollback |

## Prerequisites

**Required:**
- Docker Desktop running
- All tests pass (`/test` done)
- Infrastructure ready (`/infra` done)

**Optional (if available):**
- Security scan passed (`security/SCAN_REPORT.md` from `/scan`)
- Documentation complete (`docs/` from `/docs`)
- Real-environment verification (`reports/VERIFY_REPORT.md` from `/verify`) — strongly recommended; **required** when invoked via `/hotfix`

## Pre-Deploy Checklist

```markdown
- [ ] Docker Desktop is running
- [ ] `docker/Dockerfile` exists
- [ ] `docker-compose.yml` exists at repo root (build context `.`)
- [ ] `.env` file configured (copy from `.env.example`)
- [ ] `reports/CODE_REVIEW.md` marked PASS
- [ ] `security/SCAN_REPORT.md` has zero open P0 / Critical items
- [ ] `docs/deployment.md` exists (runbook to reference)
- [ ] `CHANGELOG.md` updated with the version being released
- [ ] Database migrations reviewed; backup/snapshot point identified
- [ ] Previous image tag noted (for rollback)
- [ ] **Every service in `docker compose config --services` has a `HEALTHCHECK`** (verify with `docker compose config | grep -c healthcheck` ≥ number of services). Services WITHOUT a healthcheck must be in the `DEPLOY_SERVICES_WITHOUT_HEALTHCHECK` whitelist with an explicit reason — the Step 4 gate uses healthcheck state to distinguish PASS/FAIL.
```

---

## Deployment Workflow

### Step 1: Pre-Deploy Verification

```bash
# Verify Docker Desktop is running
docker info > /dev/null 2>&1 && echo "✓ Docker is running"

# Verify required artifacts exist (docker-compose.yml is at repo ROOT, not in docker/)
[ -f docker/Dockerfile ]      && echo "✓ Dockerfile"
[ -f docker-compose.yml ]     && echo "✓ docker-compose.yml (root)"
[ -f .dockerignore ]          && echo "✓ .dockerignore (root)"
[ -f .env ]                   && echo "✓ .env file"

# Verify prior quality gates have produced their artifacts
[ -f reports/CODE_REVIEW.md ]      && echo "✓ Code review present"
[ -f security/SCAN_REPORT.md ]     && echo "✓ Scan report present"
[ -f docs/deployment.md ]          && echo "✓ Deployment doc present"
[ -f CHANGELOG.md ]                && echo "✓ CHANGELOG present"
[ -f reports/VERIFY_REPORT.md ]    && echo "✓ Verify report present" \
                                  || echo "⚠ No VERIFY_REPORT — /verify skipped (optional in standard pipeline, REQUIRED if invoked from /hotfix)"

# When deploy is invoked from /hotfix, VERIFY_REPORT.md is mandatory.
# Caller (hotfix orchestrator) sets HOTFIX_MODE=1 to enforce the gate.
if [ "${HOTFIX_MODE:-0}" = "1" ] && [ ! -f reports/VERIFY_REPORT.md ]; then
    echo "✗ Hotfix mode requires /verify to have run on the patched digest"
    exit 1
fi

# Block deploy if SCAN_REPORT.md still has open P0 / Critical items
if grep -qE '^\s*-\s*\[ \].*(P0|Critical)' security/SCAN_REPORT.md; then
    echo "✗ Open P0/Critical security items — refuse to deploy"
    exit 1
fi

# Note current running image tag (for rollback) — replace <api-image> with your registry name
PREV_TAG=$(docker inspect --format='{{.Config.Image}}' "$(docker-compose ps -q api 2>/dev/null)" 2>/dev/null || echo "none")
echo "Previous image: ${PREV_TAG}"

# Review pending migrations
dotnet ef migrations list --project src/MyApp.Infrastructure --startup-project src/MyApp.Api
```

### Step 2: Tag & Build

```bash
# 1. Pick the semver — derive from CHANGELOG.md (next [Unreleased] heading) or bump from last git tag
export VERSION="v1.2.0"          # MAJOR.MINOR.PATCH — never deploy :latest beyond a dev laptop

# 2. Create the git tag (annotated, signed if possible)
git tag -a "${VERSION}" -m "Release ${VERSION}"
git push origin "${VERSION}"

# 3. Build with explicit image tag (compose reads docker-compose.yml from REPO ROOT)
IMAGE_TAG="${VERSION}" docker-compose build --no-cache

# 4. (Optional) push to registry before rolling out
# docker push <registry>/<api-image>:${VERSION}

# 5. Start all services (detached) with the tagged images
IMAGE_TAG="${VERSION}" docker-compose up -d
```

> **`IMAGE_TAG` requirement:** `docker-compose.yml` must reference `image: <name>:${IMAGE_TAG:-dev}` for each service so the same compose file produces tagged images at deploy time and `:dev` during local development. If your compose still hardcodes tags, fix it in `/infra` before deploying.

### Step 3: Monitor Startup

```bash
# Watch container status
docker-compose ps

# Watch logs (all services)
docker-compose logs -f

# Watch logs (API only)
docker-compose logs -f api

# Check for errors
docker-compose logs api | grep -i error
```

### Step 4: Post-Deploy Verification

> **Gate rule (BLOCKING):** every service in `docker compose config --services` must reach `Up (healthy)` before proceeding to Step 5 (apply migrations) and before tagging/pushing the image. If **any** service is not healthy → **REFUSE** tag/release, dump logs of each failing service, exit non-zero.
>
> A service with no `HEALTHCHECK` defined (Docker shows state `Up` without `(healthy)`) is only accepted when explicitly **opted in** via `DEPLOY_SERVICES_WITHOUT_HEALTHCHECK="<svc1> <svc2>"` (explicit whitelist). All other services must have a healthcheck — push that responsibility back to `/infra` to define.

```bash
# Wait for services to start (initial settle — healthcheck will gate the real readiness below)
sleep 10

# 1) Enumerate every service declared in compose
SERVICES=$(docker compose config --services)
echo "Services to verify: ${SERVICES}"

# 2) Iterate — every service must reach Up (healthy)
FAILED_SERVICES=""
MAX_WAIT=120   # seconds — total budget for slowest service to converge
DEADLINE=$(( $(date +%s) + MAX_WAIT ))

for svc in $SERVICES; do
    while :; do
        # Health column from compose ps (Docker 24+); fall back to `Status` text match
        STATUS=$(docker compose ps "$svc" --format '{{.Status}}' 2>/dev/null || echo "")
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose ps -q "$svc" 2>/dev/null)" 2>/dev/null || echo "none")

        if [ "$HEALTH" = "healthy" ]; then
            echo "✓ ${svc}: healthy"
            break
        fi

        # No healthcheck defined → only accept if explicitly whitelisted
        if [ "$HEALTH" = "none" ]; then
            if echo " ${DEPLOY_SERVICES_WITHOUT_HEALTHCHECK:-} " | grep -q " ${svc} "; then
                if echo "$STATUS" | grep -q "^Up"; then
                    echo "⚠ ${svc}: Up (no healthcheck — opt-in whitelisted)"
                    break
                fi
            else
                echo "✗ ${svc}: no HEALTHCHECK defined and not whitelisted — refuse to gate-pass"
                FAILED_SERVICES="${FAILED_SERVICES} ${svc}"
                break
            fi
        fi

        if [ "$HEALTH" = "unhealthy" ]; then
            echo "✗ ${svc}: unhealthy"
            FAILED_SERVICES="${FAILED_SERVICES} ${svc}"
            break
        fi

        # Still 'starting' — keep waiting until deadline
        if [ "$(date +%s)" -ge "$DEADLINE" ]; then
            echo "✗ ${svc}: timed out (last state: ${HEALTH:-unknown} / ${STATUS:-unknown})"
            FAILED_SERVICES="${FAILED_SERVICES} ${svc}"
            break
        fi
        sleep 3
    done
done

# 3) Hard gate — dump logs of every failed service for postmortem, then exit
if [ -n "$FAILED_SERVICES" ]; then
    echo "✗ Failed services:${FAILED_SERVICES}"
    for svc in $FAILED_SERVICES; do
        echo "===== logs for ${svc} (last 50 lines) ====="
        docker compose logs --tail=50 "$svc"
    done
    echo "✗ Refuse to tag/release — fix the failing services or run partial deploy (see Common Operations §Partial deploy)."
    exit 1
fi

# 4) Smoke verification — only after all services healthy
curl -f http://localhost:${API_PORT}/health         && echo "✓ Health OK"
curl -f http://localhost:${API_PORT}/health/ready   && echo "✓ Ready"     # if defined
curl -s http://localhost:${API_PORT}/api/v1/status | jq                    # or your smoke endpoint

# 5) Snapshot final container state (paste into DEPLOY_RUNBOOK §3)
docker compose ps
```

> **Why all-or-nothing by default:** a service that silently fails (e.g., `web` lockfile drift, frontend bundle built against the wrong env) won't be detected by `curl /health` on the API — the deploy would still be reported successful and the image would be tagged. Consequence: release notes say PASS but end users cannot access the product. This gate is the final safeguard.

### Step 5: Apply Migrations (if needed)

```bash
# Run migrations against containerized database
dotnet ef database update \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Api

# Or exec into API container
docker-compose exec api dotnet ef database update
```

---

## Rollback Procedures

> **Target: < 1 minute.** Rollback restarts containers with the *previously tagged image* — it never rebuilds from source. If you find yourself needing `git checkout` + rebuild, the deploy did not produce a proper tag and the audit trail is broken.

### Quick Rollback (< 1 min) — image-tag based

```bash
# 1. Set previous version (captured by Step 1 Pre-Deploy Verification as PREV_TAG, or read from CHANGELOG.md)
export PREV_VERSION="v1.1.9"

# 2. Pull the previous image (no-op if already cached locally)
# docker pull <registry>/<api-image>:${PREV_VERSION}

# 3. Restart only the changed services with the previous tag (other services keep state)
IMAGE_TAG="${PREV_VERSION}" docker-compose up -d --no-deps api

# 4. Re-run smoke pack — rollback is NOT complete until smoke passes
curl -f http://localhost:${API_PORT}/health
curl -f http://localhost:${API_PORT}/health/ready
```

### Database Rollback

> **Pre-deploy backup is mandatory** when a migration is included. Take it in Step 5 before applying.

```bash
# Option A — revert via EF migrations (only if migration was reversible)
dotnet ef database update <PreviousMigrationName> \
  --project src/MyApp.Infrastructure \
  --startup-project src/MyApp.Api

# Option B — restore from the snapshot taken before Step 5
# sqlcmd -S <host> -d <db> -Q "RESTORE DATABASE [MyApp] FROM DISK = N'/backups/pre-${VERSION}.bak' WITH REPLACE"
```

### Delete the bad tag (optional cleanup)

```bash
git tag -d "${VERSION}"
git push origin --delete "${VERSION}"
```

---

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f sqlserver
docker-compose logs -f redis

# Last 100 lines
docker-compose logs --tail=100 api
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart api

# Recreate containers (picks up config changes)
docker-compose up -d --force-recreate
```

### Stop & Cleanup

```bash
# Stop all services (keep data)
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v

# Remove unused images
docker image prune -f
```

### Partial deploy (escape hatch — opt-in only)

> By default `/deploy` enforces **all-or-nothing**: every service in compose must be healthy before tag/release (Step 4). Partial deploy is allowed **only when** there is an explicit reason (e.g., outage recovery needing only API + DB while the frontend is still being fixed; init job to seed data; smoke debugging an individual service).

```bash
# 1) Declare the subset to deploy
export DEPLOY_SUBSET="api sqlserver"

# 2) Build + up only the subset (compose pulls dependencies automatically via depends_on; add --no-deps to isolate)
docker compose up -d $DEPLOY_SUBSET

# 3) Step 4 gate verifies only the subset
for svc in $DEPLOY_SUBSET; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose ps -q "$svc")" 2>/dev/null)
    [ "$HEALTH" = "healthy" ] && echo "✓ $svc healthy" || { echo "✗ $svc: $HEALTH"; exit 1; }
done

# 4) DO NOT tag a full release. Use a pre-release semver image tag: vX.Y.Z-partial.<subset-hash>
# Release notes Status = "PARTIAL DEPLOY" + list excluded services + reason.
```

**Requirements for a partial deploy:**
- Release notes must include a dedicated "Partial deploy rationale" section with reason + ETA for the excluded service
- DO NOT use a plain semver tag (`v1.2.0`) — enforce a pre-release suffix (`v1.2.0-partial.api-db`)
- DO NOT mark `SUCCEEDED` in RELEASE_NOTES — use `PARTIAL` or `DEV BUILD`

### Access Container Shell

```bash
# API container
docker-compose exec api /bin/sh

# SQL Server
docker-compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$DB_PASSWORD"

# Redis
docker-compose exec redis redis-cli
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker-compose ps

# Check logs for errors
docker-compose logs api

# Common issues:
# - Port already in use: stop other services on 5000, 1433, 6379
# - Missing .env file: copy from .env.example
# - Docker not running: start Docker Desktop
```

### Database Connection Failed

```bash
# Check SQL Server is running
docker-compose ps sqlserver

# Check SQL Server logs
docker-compose logs sqlserver

# Test connection
docker-compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P "$DB_PASSWORD" -Q "SELECT 1"

# Common issues:
# - Password doesn't meet complexity requirements
# - Container still initializing (wait 30s)
```

### Health Check Fails

```bash
# Check health endpoint directly
curl -v http://localhost:5000/health

# Check ready endpoint (shows dependency status)
curl http://localhost:5000/health/ready | jq

# Common issues:
# - Database not ready yet
# - Redis connection refused
# - Wrong connection string in .env
```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :5000
lsof -i :1433
lsof -i :6379

# Kill the process or change ports in docker-compose.yml
```

---

## Deployment Checklist

### Before Deploy
- [ ] Docker Desktop running
- [ ] Artifacts verified (`docker/Dockerfile`, `docker-compose.yml`)
- [ ] `.env` file configured
- [ ] `security/SCAN_REPORT.md` reviewed

### During Deploy
- [ ] `docker compose build` successful
- [ ] `docker compose up -d` successful
- [ ] **Every service in compose reaches `Up (healthy)`** — verify via the Step 4 loop (`docker inspect --format='{{.State.Health.Status}}'` for each service ID). Any unhealthy service → block tag/release.
- [ ] No errors in logs

### After Deploy
- [ ] Health check passing (`/health`)
- [ ] Ready check passing (`/health/ready`)
- [ ] API responds correctly
- [ ] Database migrations applied

---

## Output

### Runtime state
- All containers running on Docker Desktop
- Health checks passing
- API accessible at `http://localhost:${API_PORT}` (replace with the host port from `docker/docker-compose.yml` — commonly `5050` or `5000`)
- Swagger UI at `http://localhost:${API_PORT}/swagger` (only when `ASPNETCORE_ENVIRONMENT=Development`)

### Required artifacts (MANDATORY)

`/deploy` MUST produce the following files. These are the audit trail and operator handoff — without them, the deploy is incomplete.

**1. `reports/DEPLOY_RUNBOOK.md`** — operator-facing procedure. Minimum 7 sections:

```markdown
# Deploy Runbook — <product> v<X.Y.Z>

## 1. Pre-deploy checklist
Docker daemon up, `.env` present, /scan P0 items implemented, current image tags noted for rollback.

## 2. Deploy
Exact build + up commands. Image tagging with `:v<X.Y.Z>` (never `:latest`).

## 3. Post-deploy smoke verification
**Explicitly list every service** in compose + expected status (`Up (healthy)` or `Up` + whitelist note). This section MUST contain a table with columns `Service | Image tag | Expected status | Actual status | Healthcheck command`. A missing service = deploy did not pass the gate, no "SUCCEEDED" release notes produced.

Then: concrete `curl` smoke commands hitting `/health`, `/health/ready`, `/api/v1/version` (or your project's smoke endpoint), and 1-2 happy-path API calls. Each with expected response.

## 4. Rollback (target < 1 minute)
Stop + restart with previous image tag. Database rollback notes (and pre-deploy backup pointer if migrations are involved). After rollback: re-run §3 smoke pack — rollback is not complete until smoke passes.

## 5. Common operations
Logs, restart, shell access, cleanup commands.

## 6. Troubleshooting
Top 3-5 known failure modes with diagnostic + fix. Link to `docs/troubleshooting.md` for developer-facing issues.

## 7. Escalation
On-call contact, severity thresholds, when to roll back vs hold.
```

**2. `reports/RELEASE_NOTES_v<X.Y.Z>.md`** — one file per release tag. Minimum 5 sections (the full Release Manager agent template adds more):

```markdown
# <product> — Release Notes v<X.Y.Z>

- **Version**: <X.Y.Z>
- **Release date**: YYYY-MM-DD
- **Container tags**: `<api-image>:<X.Y.Z>`, `<spa-image>:<X.Y.Z>` (etc.)
- **Status**: SUCCEEDED / FAILED / ROLLED-BACK

## 1. Summary
One paragraph: what this release ships, the MVP/scope boundary, what's NOT in it.

## 2. Quality gates passed
Reference each gate (1-10) with link to its artifact (`reports/CODE_REVIEW.md`, `reports/TEST_REPORT.md`, `security/SCAN_REPORT.md`, etc.). Note any documented exceptions.

## 3. Hardening landed in this release
List every P0/P1 item from `security/SCAN_REPORT.md` §Recommendations that this release implements. Cross-reference `F-#` IDs.

## 4. Rollback procedure
Image tags to revert to, DB rollback notes, smoke verification. Link to `reports/DEPLOY_RUNBOOK.md` §4.

## 5. Sign-off
Release Manager, Tech Lead, Security Auditor — each with date + decision.
```

**3. `CHANGELOG.md`** — updated with a new entry per release (Keep a Changelog format — Added / Changed / Fixed / Security). Acts as the rollup index over the per-release notes above.

**4. Tagged images** — every image built carries a semver tag (`<image>:v<X.Y.Z>`). Never deploy `:latest` to anything beyond a developer's laptop.

## Next Step

After deployment verified and health checks passing, monitor logs/metrics and start the next feature cycle with `/spec`.

## Agent

Invoke: **Release Manager**

```
"As Release Manager, build, deploy and verify the application with staged rollout"
```

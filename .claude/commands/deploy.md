---
name: deploy
description: Build, test, deploy with staged rollout
---

# /deploy — Release & Deployment (STAGING)

> "Ship with confidence."

## Purpose

Execute deployment to the **STAGING** environment (Docker Desktop / staging server): build images, run containers, verify health, rollback if needed.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

> **The kit's boundary (by design):** `/deploy` is the last automated step — it pushes the artifact to **staging** with Status = **`STAGED`**, NOT production. After `STAGED`: the human test team checks it manually on staging (using `reports/VERIFY_MATRIX.md` as the test script) → decides go/no-go → **promoting to production is a MANUAL step outside the kit**, carried out per `DEPLOY_RUNBOOK §8 Promote production`. The kit never needs (and should never have) production credentials — least privilege. If you want to automate further later → add a separate `/promote` command, do not extend this one.

> **Note**: Dockerfile and docker compose are created in `/infra`. This command **executes** deployment.

> **Stack Profile note:** the `sqlcmd`/DB and `dotnet ef` commands below use the **default profile** (C#/.NET + SQL Server). Read `Project Profile` first: Oracle → `sqlplus` · MySQL → `mysql` · PostgreSQL → `psql` · MongoDB → `mongosh` (per `rules/overrides/database-*.md`); **Core = Node.js** → the migration steps map to the declared tool (`prisma migrate deploy` / `migrate-mongo up`) instead of `dotnet ef`.

> **`/verify` policy:** `/verify` is **step optional · BLOCKING if run** (Gate 11). Strongly recommended before `/deploy` stages the artifact (especially brownfield, or releases with infra/config changes). **Required when `/deploy` is invoked from the `/hotfix` orchestrator** — hotfix Step 4 requires re-verify on the patched digest. If `/verify` runs, `/deploy` may only stage a digest with a VERIFY_REPORT PASS for **that exact digest** (digest match enforced). Run `/verify` with **staging-config** — the same env as `/deploy` ⇒ within the kit's scope the env always matches; differences between staging↔production belong to the manual checklist (RUNBOOK §8).

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
- [ ] `reports/CODE_REVIEW.md` marked PASS *(if `/review` was run — optional gate; skipped → note it in RELEASE_NOTES §2)*
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

# SCAN_REPORT: 3 states — do NOT lump "not scanned" together with "scan clean".
# (If the file is missing and you only grep, grep exits non-zero → if false → silently pass: that's a bug.
#  A SKIPped optional gate must be explicitly acknowledged, it must not look like a PASS.)
if [ ! -f security/SCAN_REPORT.md ]; then
    echo "⚠ /scan has NOT been run — no SCAN_REPORT (optional gate skipped)."
    if [ "${ACK_NO_SCAN:-0}" != "1" ]; then
        echo "✗ A no-scan deploy needs explicit acknowledgement: set ACK_NO_SCAN=1"
        echo "  (this will REQUIRE recording the exception 'security scan skipped' in RELEASE_NOTES §Known risks), or run /scan first."
        exit 1
    fi
    echo "  → acknowledged (ACK_NO_SCAN=1); RELEASE_NOTES MUST record the exception 'security scan skipped'."
elif grep -qE '^\s*-\s*\[ \].*(P0|Critical)' security/SCAN_REPORT.md; then
    # Block deploy if SCAN_REPORT.md still has open P0 / Critical items
    echo "✗ Open P0/Critical security items — refuse to deploy"
    exit 1
fi

# Note current running image tag (for rollback) — replace <api-image> with your registry name
PREV_TAG=$(docker inspect --format='{{.Config.Image}}' "$(docker compose ps -q api 2>/dev/null)" 2>/dev/null || echo "none")
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

# 3. Obtain the image to promote — honor /verify's digest lock (Gate 11) if it covers THIS candidate.
LOCK_VER=""; LOCK_DIG=""
[ -f reports/verify-artifact.lock ] && read -r LOCK_VER LOCK_DIG < reports/verify-artifact.lock

if [ "$LOCK_VER" = "$VERSION" ]; then
    # /verify ran for this candidate → promote the EXACT verified digest, do NOT rebuild
    # (rebuilding yields a new digest and VOIDS the verify verdict — verify.md Phase 0 invariant).
    PROMOTE=$(docker inspect --format='{{.Id}}' "<api-image>:${VERSION}" 2>/dev/null || echo "")
    [ "$PROMOTE" = "$LOCK_DIG" ] || { echo "✗ Digest mismatch — promote=$PROMOTE verified=$LOCK_DIG → REFUSE (Gate 11)"; exit 1; }
    echo "✓ Promoting verified digest ${LOCK_DIG} (no rebuild)."
elif [ "${HOTFIX_MODE:-0}" = "1" ]; then
    # hotfix → /verify on this candidate is REQUIRED
    echo "✗ Hotfix mode requires a verify lock for ${VERSION} (run /verify on the patched digest first)"; exit 1
else
    # /verify not run for this candidate (or only a stale lock) → optional path: build fresh
    [ -n "$LOCK_VER" ] && echo "⚠ verify lock is for ${LOCK_VER}, not ${VERSION} (stale) — deploying WITHOUT /verify."
    # --pull: refresh base images (guard a re-pushed base tag) but KEEP layer cache — reproducible
    # base + fast. Reproducibility comes from the digest lock (/verify path) + pinned base tags,
    # NOT from --no-cache. Use --no-cache only when you suspect cache corruption.
    IMAGE_TAG="${VERSION}" docker compose build --pull   # compose reads docker-compose.yml from REPO ROOT
fi

# 4. (Optional) push to registry before rolling out
# docker push <registry>/<api-image>:${VERSION}

# 5. Start all services (detached) with the tagged images
IMAGE_TAG="${VERSION}" docker compose up -d
```

> **`IMAGE_TAG` requirement:** `docker-compose.yml` must reference `image: <name>:${IMAGE_TAG:-dev}` for each service so the same compose file produces tagged images at deploy time and `:dev` during local development. If your compose still hardcodes tags, fix it in `/infra` before deploying.

### Step 3: Monitor Startup

```bash
# Watch container status
docker compose ps

# Watch logs (all services)
docker compose logs -f

# Watch logs (API only)
docker compose logs -f api

# Check for errors
docker compose logs api | grep -i error
```

### Step 4: Post-Deploy Verification

> **Gate rule (BLOCKING):** every service in `docker compose config --services` must reach `Up (healthy)` before proceeding to Step 5 (apply migrations) and before tagging/pushing the image. If **any** service is not healthy → **REFUSE** tag/release, dump logs of each failing service, exit non-zero.
>
> A service with no `HEALTHCHECK` defined (Docker shows state `Up` without `(healthy)`) is only accepted when explicitly **opted in** via `DEPLOY_SERVICES_WITHOUT_HEALTHCHECK="<svc1> <svc2>"` (explicit whitelist). All other services must have a healthcheck — push that responsibility back to `/infra` to define.

```bash
# Brief settle so container IDs are registered; the poll loop below does the real gating
# (no fixed long sleep — the loop already waits on 'starting' up to MAX_WAIT).
sleep 2

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
docker compose exec api dotnet ef database update
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
IMAGE_TAG="${PREV_VERSION}" docker compose up -d --no-deps api

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
docker compose logs -f

# Specific service
docker compose logs -f api
docker compose logs -f sqlserver
docker compose logs -f redis

# Last 100 lines
docker compose logs --tail=100 api
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart api

# Recreate containers (picks up config changes)
docker compose up -d --force-recreate
```

### Stop & Cleanup

```bash
# Stop all services (keep data)
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v

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
- DO NOT mark `STAGED` in RELEASE_NOTES — use `PARTIAL` or `DEV BUILD`

### Access Container Shell

```bash
# API container
docker compose exec api /bin/sh

# SQL Server
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$DB_PASSWORD"

# Redis
docker compose exec redis redis-cli
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker compose ps

# Check logs for errors
docker compose logs api

# Common issues:
# - Port already in use: stop other services on 5000, 1433, 6379
# - Missing .env file: copy from .env.example
# - Docker not running: start Docker Desktop
```

### Database Connection Failed

```bash
# Check SQL Server is running
docker compose ps sqlserver

# Check SQL Server logs
docker compose logs sqlserver

# Test connection
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
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

## Quality Gate — Exit Criteria (before declaring STAGED)

Per `CLAUDE.md` §Verification After Delegation, the **orchestrator re-runs the gate-deciding checks itself**: the Step-4 health loop (`docker compose ps` + `docker inspect` health states), the smoke pack, and the digest comparison against `verify-artifact.lock` — the sub-agent's report is not ground truth.

All boxes must be ticked. A deploy with any box open is **not done** and produces no "STAGED" release notes. (`STAGED` is the highest Status `/deploy` is allowed to declare — "SUCCEEDED (production)" is only filled in MANUALLY after the manual promote + prod smoke, see RUNBOOK §8):

- [ ] Every service in compose is `Up (healthy)` (or `Up` + documented whitelist note)
- [ ] Smoke pack passes (DEPLOY_RUNBOOK §3): `/health`, `/health/ready`, version endpoint + 1–2 happy-path calls
- [ ] Every image carries a semver tag `:vX.Y.Z` — no service running `:latest`
- [ ] Digest promoted == digest verified (`reports/verify-artifact.lock`) — if `/verify` was run (Gate 11)
- [ ] `reports/DEPLOY_RUNBOOK.md` complete (all 7 sections)
- [ ] `reports/RELEASE_NOTES_v<X.Y.Z>.md` complete (all 5 sections, correct Status)
- [ ] `CHANGELOG.md` has an entry for this release
- [ ] Rollback path ready: previous image tags recorded (runbook §1), procedure (§4) complete

---

## Output

### Runtime state
- All containers running on Docker Desktop
- Health checks passing
- API accessible at `http://localhost:${API_PORT}` (replace with the host port from `docker-compose.yml` at repo root — commonly `5050` or `5000`)
- Swagger UI at `http://localhost:${API_PORT}/swagger` (only when `ASPNETCORE_ENVIRONMENT=Development`)

### Required artifacts (MANDATORY)

`/deploy` MUST produce the following files. These are the audit trail and operator handoff — without them, the deploy is incomplete.

**1. `reports/DEPLOY_RUNBOOK.md`** — operator-facing procedure. Minimum **8 sections** — **skeleton: [`templates/RUNBOOK_RELEASE_TEMPLATE.md`](../templates/RUNBOOK_RELEASE_TEMPLATE.md) §A (fill-only, do NOT re-author):**
1 Pre-deploy checklist · 2 Deploy (semver tag, never `:latest`) · 3 Post-deploy smoke (**a table of EVERY service** `Service | Image tag | Expected | Actual | Healthcheck` + curl pack — a missing service = no "STAGED") · 4 Rollback < 1 minute (re-run §3 after rollback) · 5 Common operations · 6 Troubleshooting (top 3-5 failure modes) · 7 Escalation · **8 Promote production (MANUAL — handed off to a human: digest pin + no-rebuild + diff config + prod smoke + rollback)**.

**2. `reports/RELEASE_NOTES_v<X.Y.Z>.md`** — one file per release tag. **6 sections** (§1–5 filled by the kit at STAGED; §6 "Production promote (manual)" filled in MANUALLY later) — **skeleton: [`templates/RUNBOOK_RELEASE_TEMPLATE.md`](../templates/RUNBOOK_RELEASE_TEMPLATE.md) §B (fill-only):**
1 Summary (scope boundary, what's NOT in it) · 2 Quality gates passed (link artifacts, note exceptions) · 3 Hardening landed (every P0/P1 from SCAN_REPORT, cross-ref `F-#`) · 4 Rollback procedure (link RUNBOOK §4) · 5 Sign-off (Release Manager + Tech Lead + Security Auditor + **QA/UAT lead after the staging test round**, each with date + decision) — the kit's Status stops at **`STAGED`**; the "Production promote (manual)" section is filled in MANUALLY after the promote.

**3. `CHANGELOG.md`** — updated with a new entry per release (Keep a Changelog format — Added / Changed / Fixed / Security). Acts as the rollup index over the per-release notes above.

**4. Tagged images** — every image built carries a semver tag (`<image>:v<X.Y.Z>`). Never deploy `:latest` to anything beyond a developer's laptop.

## Agent

Invoke: **Release Manager**

**Phase ownership** — the Release Manager sub-agent cannot converse with the user: setting `ACK_NO_SCAN=1` (accepting a no-scan deploy is the **user's** risk decision), the RELEASE_NOTES §5 sign-off rows (Tech Lead / Security Auditor / QA-UAT are human signatures — self-filling them is fabricated sign-off), or overriding a Red-Flag block (e.g. Friday-afternoon deploy) → **return early** for the decision instead of deciding alone. The orchestrator obtains the ack/signatures, re-runs the exit-criteria checks, and declares `STAGED` in the main loop.

```text
"As Release Manager, build, deploy and verify the application with staged rollout.
Output language: Vietnamese for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After Status = `STAGED` (every service healthy + smoke pass):

1. **Hand off to the human test team:** provide the staging URL + `reports/VERIFY_MATRIX.md` (the test script keyed to `@US-XXX-Snn`) + the list of exceptions/known-risks in RELEASE_NOTES.
2. **The test team checks manually on staging** → decides go/no-go (recommended: record the result + signer in RELEASE_NOTES §5).
3. **Promoting to production = a MANUAL step outside the kit** — carried out per `DEPLOY_RUNBOOK §8` (keep exactly the approved digest, do NOT rebuild; diff config; prod smoke; fill in the "Production promote (manual)" section in RELEASE_NOTES).
4. Monitor logs/metrics, then start the next feature cycle with `/spec`.

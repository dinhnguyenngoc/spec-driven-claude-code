---
name: infra
description: Setup Docker infrastructure for local development
---

# /infra — Docker Infrastructure

> "Containerize everything."

## Purpose

Create Docker infrastructure for local development and deployment on Docker Desktop.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

> **Stack Profile note:** read `Project Profile` first. **Core = Node.js** → the Dockerfile swaps the dotnet images for a `node:20-alpine` multi-stage (`npm ci && npm run build` → pruned runtime via `npm ci --omit=dev`; same §4 must-haves apply: non-root, HEALTHCHECK, pinned tags — the icu-libs/invariant-mode block in the template is **.NET-only**, do not copy it into a node image), and the EF-migration notes map to the declared ORM's equivalent (`prisma migrate deploy` via a startup flag or migrator container). **Core = PHP** → pick ONE of the two sanctioned container shapes in [`rules/overrides/framework-php-laravel.md`](../rules/overrides/framework-php-laravel.md) §J and keep it for the whole repo: **php-fpm + nginx sidecar** (two compose services — the nginx container carries the `/health` HEALTHCHECK, fpm uses a FastCGI ping) or **FrankenPHP / Octane single container** (HEALTHCHECK hits `/health` directly). `.dockerignore` additionally excludes `vendor/`, `.env`, `storage/logs`; the EF-migration notes map to `php artisan migrate --force` (startup command or a one-shot migrator service); same §4 must-haves apply — non-root, pinned tags, HEALTHCHECK — and the icu-libs/invariant-mode block is **.NET-only**, never copied into a PHP image. **Database** → the DB service follows the Profile: SQL Server default (arm64: Azure SQL Edge) · Oracle / MySQL / PostgreSQL / MongoDB → corresponding image + healthcheck per `rules/overrides/database-*.md` (MongoDB: mind the replica-set requirement for transactions — override §F). Observability ELK → Elasticsearch/Kibana instead of Grafana/Prometheus (`rules/overrides/monitoring-elk.md`).

> **Brownfield-aware:** When `Project Profile → Mode: brownfield`, the skill runs in **REVERSE-BOOTSTRAP** mode (no Dockerfile/compose yet) or **CONFORMANCE-CHECK** mode (already present) — see §Brownfield Mode. The default template below applies only to greenfield.

## Scope Clarification

| Command | Responsibility |
|---------|----------------|
| `/infra` | **Setup** — Dockerfile, docker-compose.yml, env config |
| `/deploy` | **Execute** — Build, run, verify, rollback |

## Prerequisites

**Required:**
- Docker Desktop installed
- Application code complete

**Optional (if available):**
- Security scan passed (`security/SCAN_REPORT.md` from `/scan`) — **if `/scan` was run, Gate 8 must be green** (no open Critical / unapproved High, per `SCAN_SUMMARY.json` totals) before building images (Gate 8 is BLOCKING if run)

## Workflow

### Phase 1: Dockerfile

```dockerfile
# docker/Dockerfile
# Base images pinned to exact patch tags — standing /scan rule: no :latest,
# no floating tags. Bump deliberately during dependency upkeep, not implicitly.
FROM mcr.microsoft.com/dotnet/aspnet:8.0.10-alpine3.20 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0.404-alpine3.20 AS build
WORKDIR /src
COPY ["src/MyApp.Api/MyApp.Api.csproj", "src/MyApp.Api/"]
COPY ["src/MyApp.Core/MyApp.Core.csproj", "src/MyApp.Core/"]
COPY ["src/MyApp.Infrastructure/MyApp.Infrastructure.csproj", "src/MyApp.Infrastructure/"]
RUN dotnet restore "src/MyApp.Api/MyApp.Api.csproj"

COPY . .
WORKDIR "/src/src/MyApp.Api"
RUN dotnet build "MyApp.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MyApp.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app

# icu-libs + DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false: Alpine .NET defaults to invariant-mode →
# SqlClient/Npgsql CRASH on connect. Required for any DB driver. (wget: needed by the HEALTHCHECK below.)
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
RUN apk add --no-cache wget icu-libs tzdata && \
    addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser --ingroup appgroup
USER appuser

COPY --from=publish /app/publish .

# Self-describing health so the image works under raw `docker run`, podman, k8s —
# not only under compose (where the orchestrator can override this).
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=12 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "MyApp.Api.dll"]
```

### Phase 2: Docker Compose

```yaml
# docker-compose.yml (at repo root — `context: .` resolves to the repo)
# No top-level `version:` — obsolete in Compose v2 and emits a warning.

services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    # Named + parameterized tag: /deploy runs `IMAGE_TAG=vX.Y.Z docker compose build` to tag
    # the release; unset → :dev for local work. Digest lock + quick rollback BOTH depend on
    # this line (deploy.md §IMAGE_TAG requirement).
    image: myapp-api:${IMAGE_TAG:-dev}
    ports:
      - "5000:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=MyApp;User Id=sa;Password=${DB_PASSWORD};TrustServerCertificate=true
      # Include the Redis line only if an ADR keeps Redis in scope. See the Rejection
      # ADR pattern (arch.md §2.4) when an MVP intentionally drops it.
      # - ConnectionStrings__Redis=redis:6379
    depends_on:
      sqlserver:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    # Resource limits — Docker baseline must-have §4.2.7 (noisy-neighbor prevention).
    # Compose v2 applies deploy.resources.limits in plain `docker compose up` (non-swarm).
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M

  sqlserver:
    # NOTE — Apple Silicon / arm64: `mcr.microsoft.com/mssql/server` has NO arm64
    # image. Swap to `mcr.microsoft.com/azure-sql-edge:<pinned>` and update the
    # healthcheck (sqlcmd is not shipped in Edge — use a TCP listener probe).
    image: mcr.microsoft.com/mssql/server:2022-CU14-ubuntu-22.04
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=${DB_PASSWORD}
    ports:
      - "1433:1433"
    volumes:
      - sqlserver_data:/var/opt/mssql
    healthcheck:
      # mssql/server 2022 ships sqlcmd under mssql-tools18 and requires -C (TLS trust).
      test: /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -Q "SELECT 1"
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  sqlserver_data:
```

> **Apple Silicon (arm64) developers** — `mssql/server` is amd64-only and will run under emulation (slow, occasional crashes). Use `mcr.microsoft.com/azure-sql-edge:<pinned>` instead; replace the sqlcmd healthcheck with a TCP probe (`timeout 1 bash -c '</dev/tcp/localhost/1433' || exit 1`) because Edge does not ship sqlcmd. EF Core migrations have been verified to apply cleanly on Edge for our schema surface — if your schema uses features missing from Edge (e.g., certain CLR types), gate that behind an ADR.

> **Frontend (if `Project Profile → Frontend` ≠ none):** add a `web` service to the compose + `docker/Dockerfile.web` (multi-stage: `node:20-alpine` `npm ci && npm run build` → `nginx:<pinned>-alpine` serving `dist/`, non-root, SPA fallback `try_files $uri /index.html` + proxy `/api` → `http://api:8080` so the SPA is same-origin with the API — no CORS). nginx/networking detail: [`../references/docker-patterns.md`](../references/docker-patterns.md).
>
> ```yaml
>   web:
>     build: { context: ., dockerfile: docker/Dockerfile.web }
>     ports: ["3000:8080"]
>     depends_on: [api]
> ```

> **Migrations on first run (Gate 9):** the app must create its schema when the container starts. Apply migrations on startup behind a config flag — e.g. `Database:MigrateOnStartup=true` (set in `api.environment`), guarded by `db.Database.IsRelational()` so InMemory tests skip — **or** use a dedicated migrator / init container. Never bake `dotnet ef database update` into the image. Verify by hitting a DB-backed endpoint, not just `/health`.

### Phase 3: Environment Configuration

```bash
# .env.example (copy to .env and fill values)

# Database
DB_PASSWORD=YourStrong!Password123

# App
ASPNETCORE_ENVIRONMENT=Development
ASPNETCORE_URLS=http://+:8080

# JWT (for local development)
Jwt__Secret=your-local-dev-secret-key-minimum-32-characters
Jwt__Issuer=MyApp
Jwt__Audience=MyApp
Jwt__ExpiresInMinutes=60

# Logging
Serilog__MinimumLevel__Default=Debug
```

### Phase 4: Docker Ignore

> **MUST live at the repo root** (`.dockerignore`), NOT in `docker/`. Docker reads `.dockerignore` from the **build context root** — which is the repo root since compose builds use `context: ..`. A file at `docker/.dockerignore` is silently ignored. (BuildKit's per-Dockerfile variant `docker/Dockerfile.api.dockerignore` exists but is non-obvious; default to the root file.)

```gitignore
# .dockerignore (at repo root)
**/.git
**/.vs
**/.vscode
**/bin
**/obj
**/node_modules
**/.env
!**/.env.example
**/appsettings.Development.json
**/appsettings.*.json
!**/appsettings.json
*.md
*.txt
docker-compose*.yml
Dockerfile*

# SDLC artifacts — never shipped in any runtime image
specs
architecture
security
reports
plans
docs
.claude
```

---

## Output Structure

```text
docker/
└── Dockerfile               # Multi-stage production build

docker-compose.yml           # Base stack at repo root (so `context: .` is natural)
docker-compose.test.yml      # Optional: E2E overlay (ephemeral DB, SPA served by nginx)
docker-compose.deploy.yml    # Optional: release-tag pin overlay
.dockerignore                # MUST be at repo root (build context = .)
.env.example                 # Environment template (commit this)
.env                         # Actual values (DO NOT commit)
```

> **Why compose at repo root, not under `docker/`** — compose `context: .` reads the build context relative to the compose file. Keeping compose at root means a developer can run `docker compose up` from the directory they cloned into, with no `-f docker/docker-compose.yml` flag. The Dockerfile is referenced explicitly via `dockerfile: docker/Dockerfile`. Putting compose under `docker/` is acceptable but forces every command to pass `-f`.

---

## Checklist

> **Authoritative baseline:** [`rules/principles-and-practices.md`](../rules/principles-and-practices.md) §4 — Docker baseline **20 must-haves**. Must-haves 1–14 (image construction, runtime safety, health & observability hooks) are `/infra`'s responsibility — reject artifacts missing any. Must-haves 15–20 (timeout/retry/circuit-breaker/rate-limit, audit columns, optimistic concurrency) land in code during `/build` and are verified at `/review`. The checklist below is the quick view.

### Dockerfile
- [ ] Multi-stage build (smaller images)
- [ ] Non-root user for security
- [ ] Health check endpoint exposed
- [ ] Alpine-based images (smaller size)

### Docker Compose
- [ ] All services required by the architecture are defined (at minimum: `api`, a SQL engine; add `redis`/`kafka`/etc. only if an ADR keeps them in scope — see the Rejection ADR pattern in `arch.md` §2.4 for an explicit-rejection record)
- [ ] Health checks configured
- [ ] Resource limits set (cpus/memory) on app services — must-have §4.2.7
- [ ] Volumes for data persistence
- [ ] Environment variables via .env file
- [ ] Correct port mappings

### Environment
- [ ] `.env.example` created and committed
- [ ] `.env` added to `.gitignore`
- [ ] All required variables documented
- [ ] Passwords meet complexity requirements

## Quality Gate 9 — Verification

Per `CLAUDE.md` §Verification After Delegation, the **orchestrator re-runs the gate-deciding checks itself**: `docker compose build` + `docker compose up -d`, probe `/health` and one DB-backed endpoint, `docker exec <container> whoami` (non-root), and grep the Dockerfile/compose for `:latest` — read the real container states, don't trust the sub-agent's report.

Before proceeding to `/docs`:
- [ ] `docker compose build` succeeds without warnings
- [ ] `docker compose up -d` brings all services to `healthy` state
- [ ] API responds 200 on `/health` (and `/health/ready` if defined) after startup
- [ ] **EF Core migrations apply on first run** (verified by hitting a DB-backed endpoint, not just `/health`)
- [ ] **No secrets committed** — only `.env.example` shipped; `.env` is gitignored
- [ ] **Image runs as non-root** (`USER appuser` in Dockerfile; verify with `docker exec <c> whoami`)
- [ ] **All images pinned** to specific tags or digests — NO `:latest` anywhere (standing `/scan` rule)
- [ ] **App-built images carry `image: <name>:${IMAGE_TAG:-dev}`** — the parameterized tag that `/deploy`'s tagging, digest-lock and quick-rollback mechanics all depend on (`deploy.md` §IMAGE_TAG requirement); third-party images stay pinned to exact tags per the item above. Catch it HERE — discovered at deploy time it sends the user back to re-run `/infra`.
- [ ] **As-is refresh (KB sync)** — infrastructure state just changed, so sweep `architecture/ARCHITECTURE.md` + `architecture/diagrams/*` for statements this run invalidated: grep the backticked command name (`` `/infra` ``) and disposition EVERY hit — rewrite the statement to the new as-is (append an update note: date + `/infra`) or confirm it still holds; every `§Open Questions` row owned by `/infra` → resolved (date) or re-tagged with a reason. `adr/` is **exempt** — ADRs are decision records whose Context is historical (a state change that fires a v2-trigger takes the ADR-supersede path, never an in-place edit). Mechanical check: `` grep -rn "pre-`/infra`" architecture/ --exclude-dir=adr `` returns **0** after the sweep.
- [ ] **Compose self-containment** — run `docker compose config` (the rendered, env-interpolated view) and check two lists mechanically: ① every infra-class endpoint value (`ConnectionStrings__*`, `*_HOST`, `KAFKA*`, `REDIS*`, `DB_*`…) resolves to a compose service name or loopback — an external host in this class needs a documented exception; third-party API URLs (mail, storage…) are listed in the report, not failed; ② **override completeness** — every connection-class key in `docs/CODEBASE_MAP.md` §Connection inventory (or, when absent, derived from the production config baked into the image — `appsettings*.json`, `.env`) has a corresponding env override in the compose; a missing override means the container **silently falls back to the real endpoint inside the image**.

### Post-gate presentation (MANDATORY)

Gate 9 verification already brought the stack up (`docker compose up -d`) — **leave it running**: the whole point of `/infra` is a usable local environment, so don't tear down what the user is about to use. The orchestrator's final message MUST then present — from the REAL `docker compose ps` output and the port mappings in `docker-compose.yml`, never from memory:

1. **Stack state** — one line: services are UP and healthy right now (or the explicit exception list).
2. **Service & URL table**:

   | Service | State | Host port | URL | Health |
   |---------|-------|-----------|-----|--------|
   | api | Up (healthy) | 5000 | http://localhost:5000 | `/health` · `/health/ready` |

   Derive host ports mechanically from the compose file; list `/swagger` only when the running environment actually exposes it (`ASPNETCORE_ENVIRONMENT=Development`).
3. **Quick operations block** — the three commands the user needs next: `docker compose logs -f` (watch), `docker compose down` (stop), `docker compose up -d` (start again); everything else → §Common Commands below.

---

## Common Commands

```bash
# Compose v2 binary: `docker compose` (space). The legacy `docker-compose`
# (hyphen, v1) is EOL since 2023 — do not use in new projects.

# Build images
docker compose build

# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Stop and remove data
docker compose down -v

# Rebuild single service
docker compose up -d --build api
```

---

## Troubleshooting

### SQL Server / SQL Edge won't start

```bash
# Check logs
docker compose logs sqlserver

# Common issues:
# - Password doesn't meet complexity (uppercase, lowercase, number, special char, >=8 chars)
# - Not enough memory (mssql/server needs 2GB minimum; SQL Edge ~500MB)
# - On Apple Silicon: mssql/server runs under emulation — switch to azure-sql-edge
# - Healthcheck fails with "sqlcmd: not found" — you are on SQL Edge: use a TCP probe instead
```

### Port already in use

```bash
# Find what's using the port
lsof -i :5000
lsof -i :1433

# Change port in docker-compose.yml
ports:
  - "5001:8080"  # Use 5001 instead
```

### Build fails

```bash
# Clean build
docker compose build --no-cache

# Check Dockerfile path
# With compose at repo root: context: . and dockerfile: docker/Dockerfile
```

---

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

When the codebase already exists, `/infra` **auto-detects** behavior based on the presence of `docker/Dockerfile` and `docker-compose.yml`:

| Situation | Mode | Behavior |
|-----------|------|----------|
| Neither `docker/Dockerfile` nor `docker-compose.yml` exists (after `/discover`) | **REVERSE-BOOTSTRAP** | Discover actual code (csproj names, FE folder, host arch, ADR Rejection) → generate Dockerfile + compose that **match reality**. Do NOT render the default template. |
| `docker/Dockerfile` or `docker-compose.yml` already exists | **CONFORMANCE-CHECK** | Read existing artifacts, cross-check against actual code, FLAG drift to `reports/INFRA_DRIFT.md`. Do NOT modify existing infra since the team has committed it. |

**REVERSE-BOOTSTRAP — notes:**
- **Consume `/discover` artifacts first** — do NOT re-derive what they already declare:
  - DB engine → `Project Profile → Database` (not `grep Use<Db>`).
  - Frontend presence/stack → `Project Profile → Frontend` (not `[ -d web/ ]`).
  - Core language/framework + layering → `Project Profile → Core/Structure` + `docs/CODEBASE_MAP.md`.
  - csproj names / module layout → `docs/CODEBASE_MAP.md` module map.
  - Rejected components → the Rejection ADR (`architecture/adr/`), as before.
- **Probe directly only for what `/discover` does NOT capture:** `uname -m` (host arch), and exact csproj paths if the map lacks them.
- **Fallback:** if `Project Profile` / `CODEBASE_MAP.md` is missing or stale (no `/discover` run), fall back to the direct probes (`find src -name "*.csproj"`, `grep Use<Db>`, `[ -d web/ ]`) — do not block. A stale Profile that produces a wrong service is caught by **Gate 9** (compose won't reach `healthy`); log any code↔Profile disagreement to `reports/INFRA_ADAPTATIONS.md`.
- **arm64 host** (Apple Silicon, AWS Graviton) → DB image must be arm64-compatible: SQL Server → `azure-sql-edge` + TCP probe healthcheck (Edge has no sqlcmd); Oracle → arm64 tag.
- **.NET Alpine globalization**: Alpine base = invariant-mode → SqlClient/Npgsql crash on connect. Fix: `apk add --no-cache icu-libs` + `ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false`.
- **Multi-csproj without `.sln`** → COPY each csproj individually, then `dotnet restore <api>.csproj` (resolves transitive). Do NOT use the default template's `COPY *.sln && dotnet restore`.
- **Frontend Dockerfile** (not in the skill template): if the `web/` frontend folder is detected, generate a separate `docker/Dockerfile.web`. Next.js without `output: 'standalone'` → flag for user confirmation before modifying source code; if the user does not confirm → generate non-standalone (larger image, but works out-of-the-box).
- **ADR Rejection compliance**: honor Rejection ADRs (e.g. ADR-008 rejects Redis/Kafka/YARP/Hangfire/Polly). Do NOT add any service already rejected to compose, even if the default template includes it.
- **Migration strategy**: grep `Database.Migrate\|MigrateAsync` in `Program.cs` — if present → app self-applies (single-replica dev OK); if absent → suggest the user add it or use an init container. Do NOT modify source.
- Any adaptation that diverges from the default template → log to `reports/INFRA_ADAPTATIONS.md` (aspect | template | override | reason) for team review.

**CONFORMANCE-CHECK — notes:**
- Output a drift table in `reports/INFRA_DRIFT.md`: `Aspect | Existing artifact | Actual code | Drift? | Recommendation`.
- Derive the **"Actual code" column from `/discover` artifacts** where they cover it (Profile → Database/Frontend/Core; CODEBASE_MAP → modules; Rejection ADR → component scope); probe code directly only for aspects they don't capture (host arch, exact csproj paths). Fallback to direct inspection if artifacts are absent.
- Do NOT modify existing artifacts (the team has committed them); only flag for review.
- Serious drift (e.g. Dockerfile referencing a csproj that does not exist, compose containing a service rejected by ADR) → escalate to the user, recommend rerunning in REVERSE-BOOTSTRAP mode after the user removes the old artifacts.

## Agent

Invoke: **Backend Developer** (DevOps mode)

**Phase ownership** — the Backend Developer sub-agent cannot converse with the user: the two brownfield decision points — Next.js missing `output: 'standalone'` (user confirmation before touching source), and serious drift in CONFORMANCE-CHECK (user decides whether to remove committed artifacts and rerun REVERSE-BOOTSTRAP) → **return early** with the item instead of deciding alone. The orchestrator obtains the confirmation, re-runs the Gate 9 checks, and presents the result in the main loop.

```text
"Setup Docker infrastructure for the project.
Output language: <Output Language from Project Profile> for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After infrastructure ready, run `/docs` for documentation, then `/verify` to exercise every feature against the deployed artifact (Gate 11 — **step optional · BLOCKING if run**; **required inside `/hotfix`**), then `/deploy` to promote (with the verified digest if `/verify` was run).

---
name: infra
description: Setup Docker infrastructure for local development
---

# /infra — Docker Infrastructure

> "Containerize everything."

## Purpose

Create Docker infrastructure for local development and deployment on Docker Desktop.

> **Stack Profile note:** the DB service in `docker-compose.yml` follows the `Project Profile`. Default = SQL Server (arm64: Azure SQL Edge); Oracle/MySQL → corresponding image + healthcheck (`rules/overrides/database-*.md`). Observability ELK → add Elasticsearch/Kibana instead of Grafana/Prometheus (`rules/overrides/monitoring-elk.md`). Core images (`dotnet/aspnet`, `dotnet/sdk`) do not change.

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
- Security scan passed (`security/SCAN_REPORT.md` from `/scan`)

## Workflow

### Phase 1: Dockerfile

```dockerfile
# docker/Dockerfile
# Base images pinned to exact patch tags — carries F-L1 from /scan ("no :latest,
# no floating tags"). Bump deliberately during dependency upkeep, not implicitly.
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

# wget needed by the HEALTHCHECK below; full wget (not BusyBox) gives correct exit codes.
RUN apk add --no-cache wget && \
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
    ports:
      - "5000:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=MyApp;User Id=sa;Password=${DB_PASSWORD};TrustServerCertificate=true
      # Include the Redis line only if an ADR keeps Redis in scope. See ADR-009 for the
      # explicit-rejection pattern when an MVP intentionally drops it.
      # - ConnectionStrings__Redis=redis:6379
    depends_on:
      sqlserver:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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

```
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

```
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

### Dockerfile
- [ ] Multi-stage build (smaller images)
- [ ] Non-root user for security
- [ ] Health check endpoint exposed
- [ ] Alpine-based images (smaller size)

### Docker Compose
- [ ] All services required by the architecture are defined (at minimum: `api`, a SQL engine; add `redis`/`kafka`/etc. only if an ADR keeps them in scope — see ADR-009 template for an explicit-rejection record)
- [ ] Health checks configured
- [ ] Volumes for data persistence
- [ ] Environment variables via .env file
- [ ] Correct port mappings

### Environment
- [ ] `.env.example` created and committed
- [ ] `.env` added to `.gitignore`
- [ ] All required variables documented
- [ ] Passwords meet complexity requirements

### Quality Gate 9 — Verification

Before proceeding to `/docs`:
- [ ] `docker compose build` succeeds without warnings
- [ ] `docker compose up -d` brings all services to `healthy` state
- [ ] API responds 200 on `/health` (and `/health/ready` if defined) after startup
- [ ] **EF Core migrations apply on first run** (verified by hitting a DB-backed endpoint, not just `/health`)
- [ ] **No secrets committed** — only `.env.example` shipped; `.env` is gitignored
- [ ] **Image runs as non-root** (`USER appuser` in Dockerfile; verify with `docker exec <c> whoami`)
- [ ] **All images pinned** to specific tags or digests — NO `:latest` anywhere (carry F-L1 from `/scan`)

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
- Discovery replaces the template's hard-coded source. Minimum reads: `find src -name "*.csproj"` (naming), `[ -d web/ ] || [ -d client/ ] || [ -d frontend/ ]` (FE), `uname -m` (arch), `grep "UseSqlServer\|UseNpgsql\|UseMySql\|UseOracle" src/**/*.cs` (DB engine), `architecture/adr/*-no-*.md` or Rejection ADR (component scope).
- **arm64 host** (Apple Silicon, AWS Graviton) → DB image must be arm64-compatible: SQL Server → `azure-sql-edge` + TCP probe healthcheck (Edge has no sqlcmd); Oracle → arm64 tag.
- **.NET Alpine globalization**: Alpine base = invariant-mode → SqlClient/Npgsql crash on connect. Fix: `apk add --no-cache icu-libs` + `ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false`.
- **Multi-csproj without `.sln`** → COPY each csproj individually, then `dotnet restore <api>.csproj` (resolves transitive). Do NOT use the default template's `COPY *.sln && dotnet restore`.
- **Frontend Dockerfile** (not in the skill template): if a FE folder is detected, generate a separate `docker/Dockerfile.<fe-name>`. Next.js without `output: 'standalone'` → flag for user confirmation before modifying source code; if the user does not confirm → generate non-standalone (larger image, but works out-of-the-box).
- **ADR Rejection compliance**: honor Rejection ADRs (e.g. ADR-008 rejects Redis/Kafka/YARP/Hangfire/Polly). Do NOT add any service already rejected to compose, even if the default template includes it.
- **Migration strategy**: grep `Database.Migrate\|MigrateAsync` in `Program.cs` — if present → app self-applies (single-replica dev OK); if absent → suggest the user add it or use an init container. Do NOT modify source.
- Any adaptation that diverges from the default template → log to `reports/INFRA_ADAPTATIONS.md` (aspect | template | override | reason) for team review.

**CONFORMANCE-CHECK — notes:**
- Output a drift table in `reports/INFRA_DRIFT.md`: `Aspect | Existing artifact | Actual code | Drift? | Recommendation`.
- Do NOT modify existing artifacts (the team has committed them); only flag for review.
- Serious drift (e.g. Dockerfile referencing a csproj that does not exist, compose containing a service rejected by ADR) → escalate to the user, recommend rerunning in REVERSE-BOOTSTRAP mode after the user removes the old artifacts.

## Agent

Invoke: **Backend Developer** (DevOps mode)

```
"Setup Docker infrastructure for the project"
```

## Next Step

After infrastructure ready, run `/docs` for documentation, then `/verify` to exercise every feature against the deployed artifact (Gate 11 — **step optional · BLOCKING if run**; **required inside `/hotfix`**), then `/deploy` to promote (with the verified digest if `/verify` was run).

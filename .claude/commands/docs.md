---
name: docs
description: Generate comprehensive project documentation
---

# /docs — Documentation

> "If it's not documented, it doesn't exist."

## Purpose

Consolidate existing documentation and complete missing pieces before deployment. Ensure all technical artifacts from previous phases are properly linked and accessible.

> **Principle**: Don't duplicate — link and reference existing artifacts from `/spec`, `/arch`, `/secure`, `/infra`.

## Prerequisites

- Implementation complete (`/build` done)
- Infrastructure setup (`/infra` done)
- API contracts defined (`architecture/api/`)

## Workflow

> **Run mode — first-run vs incremental.**
> - `docs/` largely absent → **first-run:** generate the full set (Phases 1-6).
> - `docs/` already exists → **incremental:** update only the docs the change touched + `CHANGELOG.md`; leave unchanged docs alone. Delta → doc map:
>   - new/changed endpoint → `docs/api/` + `CHANGELOG.md`
>   - new env var → `configuration.md`
>   - fixed bug (BUG-### in `TEST_REPORT.md`) → `troubleshooting.md`
>   - setup / run / deploy steps changed → `getting-started.md` + `deployment.md`
>   - any release → `CHANGELOG.md`
> - **When unsure whether a doc is affected → regenerate it** (don't risk staleness).
> - **Before a major release, do a full-set pass** (treat as first-run) to catch drift.

### Phase 0: Audit Existing Documentation

Before creating new docs, review what already exists from previous phases:

| Source | Check | Reuse In |
|--------|-------|----------|
| `specs/SPEC.md` | PRD, features, scope | README features section |
| `architecture/ARCHITECTURE.md` | System design | `docs/architecture.md` |
| `architecture/adr/` | Decision records | Link from architecture.md |
| `architecture/api/` | API contracts | `docs/api/` |
| `docs/CODEBASE_MAP.md` (brownfield, from `/discover`) | API / module surface inventory | `docs/api/` + `docs/architecture.md` — use instead of re-reading every controller (consume-`/discover` chain) |
| `security/THREAT_MODEL.md` | Threats + STRIDE | `docs/security.md` |
| `security/SCAN_REPORT.md` | Accepted Risks + Findings (F-#) | `docs/deployment.md` Production hardening backlog |
| `reports/CODE_REVIEW.md` | Findings + carry-forward warnings | `docs/troubleshooting.md`, deployment backlog |
| `reports/TEST_REPORT.md` | Real bugs discovered (BUG-###) | `docs/troubleshooting.md` Symptom→Diagnostic→Fix entries |
| `reports/RELEASE_NOTES_*.md` | Per-release scope + smoke results | `CHANGELOG.md` |
| `reports/DEPLOY_RUNBOOK.md` | Operator procedures | Link from `docs/deployment.md` |
| `plans/todo.md` | Bug + hotfix audit trail, backlog | `docs/troubleshooting.md`, `CHANGELOG.md` |
| `docker-compose.yml` (repo root) | Service dependencies | `docs/deployment.md` |
| `docker/Dockerfile` + `docker-compose.yml` + `.env.example` | Platform/setup gotchas encoded in the build (DB image choice on arm64, Alpine globalization env, migration-on-first-run, DB volume + password) | `docs/getting-started.md` Prerequisites + `docs/troubleshooting.md` — surface the platform-specific setup steps a newcomer hits; **derive from the project's own build files, don't re-author** |
| Existing root `README.md` / `CHANGELOG.md` | Pre-existing? Framework-level? | **PRESERVE** if it serves a wider scope (monorepo / framework parent) — author product-level `docs/README.md` instead. Never blindly overwrite. |

### Phase 1: Documentation Inventory

| Document | Audience | Priority |
|----------|----------|----------|
| `docs/README.md` (documentation hub) | All audiences | Critical — navigation with explicit `Audience` column per doc |
| `README.md` (root) | All audiences | Critical (or PRESERVE if framework-level — see Phase 0) |
| Getting Started | New developer / operator | Critical |
| API Documentation | API consumer / integrator | Critical |
| Architecture | Engineer | High — one-pager; link to `architecture/ARCHITECTURE.md`, don't duplicate |
| Deployment Guide | Operator | High |
| Configuration reference | Operator / contributor | High — every env var the app reads |
| Security posture | Auditor / engineer | High — summary; link to `security/`, don't duplicate |
| Troubleshooting | On-call / contributor | Medium — `Symptom → Diagnostic → Fix` entries derived from real SDLC bugs |
| Contributing | Contributor | Medium |
| Changelog | All audiences | Medium |

### Documentation Categories

| Category | Audience | Focus |
|----------|----------|-------|
| **User Docs** | End users | Features, getting started, FAQ |
| **API Docs** | API consumers | Endpoints, auth, examples |
| **Developer Docs** | Contributors | Setup, architecture, contributing |
| **Operations Docs** | DevOps/SRE | Deployment, monitoring, troubleshooting |

> **Gate 10 minimum**: README, Getting Started, API Docs, Deployment Guide

### Phase 2: README.md Template

> **Template — example only.** Replace stack, commands, and structure with the project's actual choices. If a component listed below is intentionally absent (e.g., no Kafka, no Redis), remove it rather than carry it forward as aspiration.

```markdown
# Project Name

Brief description of what this project does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Tech Stack

- **Frontend**: Next.js 14, React, TypeScript
- **Backend**: ASP.NET Core 8, C# 12
- **Database**: SQL Server + EF Core
- **Cache**: Redis (StackExchange.Redis)
- **Queue**: Apache Kafka

## Quick Start

\`\`\`bash
# Clone
git clone <repo-url>
cd project-name

# Restore dependencies
dotnet restore

# Setup environment
cp appsettings.Development.example.json appsettings.Development.json

# Database migrations
dotnet ef database update --project src/MyApp.Infrastructure

# Run
dotnet run --project src/MyApp.Api
\`\`\`

## Documentation

- [Getting Started](docs/getting-started.md)
- [API Reference](docs/api/README.md)
- [Architecture](docs/architecture.md)
- [Deployment](docs/deployment.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT
```

### Phase 3: Documentation Structure

```text
docs/
├── getting-started.md       # Quick start guide
├── architecture.md          # Links to architecture/ARCHITECTURE.md
├── api/                     # API documentation
│   ├── README.md            # Overview, links to architecture/api/
│   ├── openapi.yaml         # Generated from Swagger
│   └── [resource].md        # Endpoint details
├── deployment.md            # References docker/
├── security.md              # Links to security/THREAT_MODEL.md
├── configuration.md         # Environment variables reference
├── troubleshooting.md       # Common issues and solutions
└── development.md           # Dev environment setup

CONTRIBUTING.md              # Contribution guidelines
CHANGELOG.md                 # Version history
LICENSE                      # License file
```

> **Note**: Use links (`[See Architecture](../architecture/ARCHITECTURE.md)`) instead of duplicating content.

### Phase 4: API Documentation

#### Option A: Auto-generate from OpenAPI
```bash
# Generate from openapi.yaml using Swashbuckle
dotnet build
# Swagger UI available at /swagger

# Export OpenAPI spec
curl http://localhost:5000/swagger/v1/swagger.json > docs/api/openapi.json

# Generate static docs
npx @redocly/cli build-docs docs/api/openapi.json -o docs/api/index.html
```

#### Option B: Manual Documentation
```markdown
# API Reference

## Authentication

### POST /api/v1/auth/login

Login and receive access token.

**Request Body:**
\`\`\`json
{
  "email": "user@example.com",
  "password": "password123"
}
\`\`\`

**Response (200):**
\`\`\`json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG...",
    "expiresIn": 900
  }
}
\`\`\`

**Errors:**
| Code | Message |
|------|---------|
| 401 | Invalid credentials |
| 400 | Validation failed |
```

### Phase 5: Changelog Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Feature X

### Changed
- Updated Y

### Fixed
- Bug Z

## [1.0.0] - 2026-05-08

### Added
- Initial release
- User authentication
- CRUD operations for resources
```

### Phase 6: Deployment Guide Template

> **Template — example only.** Replace topology, env vars, and observability surface with the project's actual setup. If a component is intentionally absent per an ADR (e.g., no Prometheus per its Rejection ADR, no Kubernetes for MVP), state that explicitly with the actual ADR reference — don't carry forward placeholder sections.

```markdown
# Deployment Guide

## Prerequisites

- Docker 24+
- SQL Server 2022+
- Redis 7+
- .NET 8 SDK (for manual deploy)

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| ASPNETCORE_ENVIRONMENT | Environment | Yes | Development |
| ConnectionStrings__DefaultConnection | SQL Server connection | Yes | - |
| ConnectionStrings__Redis | Redis connection | Yes | - |
| Jwt__Secret | JWT signing secret | Yes | - |
| Jwt__Issuer | JWT issuer | Yes | - |
| Jwt__Audience | JWT audience | Yes | - |

## Docker Deployment

\`\`\`bash
# Build (tag with semver — never deploy :latest beyond a dev laptop, see /deploy)
export VERSION="v1.0.0"
docker build -t app:${VERSION} -f docker/Dockerfile .

# Run (docker-compose.deploy.yml lives at repo root, alongside docker-compose.yml)
IMAGE_TAG=${VERSION} docker compose -f docker-compose.yml -f docker-compose.deploy.yml up -d
\`\`\`

## Manual Deployment

\`\`\`bash
# Restore dependencies
dotnet restore

# Build release
dotnet publish -c Release -o ./publish

# Run migrations — generate idempotent script, review, then apply (never `database update` straight to prod)
dotnet ef migrations script --idempotent --project src/MyApp.Infrastructure -o migrate.sql
# review migrate.sql → apply via DB tooling / CI

# Start
dotnet ./publish/MyApp.Api.dll
\`\`\`

## Health Checks

- `GET /health` — Basic liveness
- `GET /health/ready` — Readiness (DB, Redis connected)
- `GET /health/live` — Liveness probe

## Monitoring

- Metrics: `GET /metrics` (Prometheus format via OpenTelemetry)
- Logs: stdout in JSON format (Serilog)
- Tracing: OpenTelemetry → Jaeger
```

## Quality Gate 10 — Documentation Checklist

Before proceeding to `/deploy`:

> **Incremental run:** items already satisfied by a prior `/docs` run stay checked if still accurate; only re-verify the docs the change touched. The link-check + no-duplication (Integrity) below run over the **whole** set regardless — so integrity holds even when only part was regenerated.

### Audit (Phase 0)
- [ ] Reviewed `specs/SPEC.md` for features list
- [ ] Checked `architecture/` for design docs and ADRs
- [ ] Verified API contracts in `architecture/api/`
- [ ] Located security docs in `security/`
- [ ] Reviewed `docker/` for deployment info

### README.md
- [ ] Project description
- [ ] Features list
- [ ] Tech stack
- [ ] Quick start instructions
- [ ] Links to detailed docs
- [ ] License

### API Docs
- [ ] All endpoints documented
- [ ] Request/response examples
- [ ] Error codes explained
- [ ] Authentication explained

### Guides
- [ ] Getting started guide
- [ ] Deployment guide
- [ ] Configuration reference
- [ ] Troubleshooting guide
- [ ] **Observability surface declared** — what IS enabled (e.g., Serilog console JSON, `/health`) AND what is NOT (e.g., no Prometheus/Jaeger per ADR-xxx). On-call must not have to guess.

### Meta
- [ ] CONTRIBUTING.md
- [ ] CHANGELOG.md
- [ ] LICENSE

### Integrity
- [ ] **No broken internal links** — verify with `markdown-link-check '**/*.md'` or `lychee docs/ *.md` (exit code 0 = clean)
- [ ] **No duplication** — each fact lives in exactly one canonical place; other docs link to it
- [ ] **Output-style conformance** (`rules/output-style.md`) — each doc opens with a plain-language summary (what / why / for-whom); register matches its reader (getting-started/api = newcomer/dev; deployment/troubleshooting = operator, step-by-step); jargon defined on first use
- [ ] Existing root `README.md` / `CHANGELOG.md` preserved if framework-level (see Phase 0 last row)

## Auto-Generation Tools

```bash
# Generate XML documentation
dotnet build /p:GenerateDocumentationFile=true

# DocFX for .NET documentation
dotnet tool install -g docfx
docfx init -q
docfx docfx.json --serve

# Swagger/OpenAPI export
# Built-in via Swashbuckle.AspNetCore
```

## Agent

Invoke: **Technical Writer**

```text
"As Technical Writer, generate documentation for the project.
Output language: Vietnamese for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language).
Output clarity: follow rules/output-style.md — audience-first, plain-language summary, register per reader."
```

## Next Step

After documentation complete, run `/verify` (Gate 11 — **step optional · BLOCKING if run**; required inside `/hotfix` — exercise every feature against the real deployed artifact), then `/deploy` to promote (with the verified digest if `/verify` was run).

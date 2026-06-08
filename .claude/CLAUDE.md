# Spec-driven Development with Claude Code

## Overview

This project uses Claude AI as an intelligent development agent with structured workflows, specialized sub-agents, and mandatory coding standards.

---

## Output Language (MANDATORY)

> **Áp dụng cho mọi lệnh, mọi agent, mọi sub-agent — không có ngoại lệ trừ khi user yêu cầu rõ ràng bằng ngôn ngữ khác.**

### Ngôn ngữ tiếng Việt — bắt buộc

Mọi nội dung sau đây **PHẢI** được viết bằng **tiếng Việt**:

- **Hội thoại với user** — mọi câu trả lời, giải thích, câu hỏi xác nhận
- **Artifact của workflow SDLC**:
  - `specs/` — SPEC.md, user stories, acceptance criteria
  - `architecture/` — ARCHITECTURE.md, ADRs, mô tả diagram
  - `plans/` — sprint plans, plan.md, todo.md (tiêu đề task)
  - `security/` — THREAT_MODEL.md, PRE_DEV_REVIEW.md, SCAN_REPORT.md
  - `reports/` — CODE_REVIEW.md và các báo cáo khác
  - `docs/` — getting-started, deployment, troubleshooting, hướng dẫn
- **Báo cáo, summary, status update**
- **Commit message body** (phần mô tả chi tiết sau dòng tiêu đề)
- **PR description, release notes**
- **Comment giải thích logic nghiệp vụ** trong code (WHY)

### Giữ nguyên tiếng Anh — không dịch

Những thành phần sau **PHẢI giữ nguyên tiếng Anh** để đảm bảo tính chuẩn và khả năng tra cứu:

- **Code** — tên biến, hàm, class, interface, namespace, file name
- **Identifier kỹ thuật** — route URL, cache key, DB table/column, env var, Kafka topic
- **Keyword kỹ thuật / thuật ngữ chuẩn** — REST, JWT, OAuth2, Clean Architecture, SOLID, TDD, CQRS, CAP, RFC 7807, OWASP, STRIDE, EF Core, Dapper, v.v.
- **Tên công nghệ, framework, thư viện** — ASP.NET Core, Next.js, SQL Server, Redis, Kafka, Docker, Prometheus, Grafana
- **HTTP method, status code label** — `GET`, `POST`, `200 OK`, `404 Not Found`
- **Conventional Commit type** — `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`
- **Tiêu đề commit (dòng đầu tiên)** — theo Conventional Commits, viết bằng tiếng Anh
- **Code comment giải thích cú pháp / kỹ thuật thuần** — giữ tiếng Anh nếu là khái niệm chuẩn

### Quy tắc trộn ngôn ngữ

Khi viết artifact tiếng Việt có chứa thuật ngữ kỹ thuật, **không dịch** thuật ngữ — giữ nguyên trong ngữ cảnh tiếng Việt:

```markdown
✅ Đúng:
- Sử dụng pattern Repository để tách biệt tầng truy cập dữ liệu.
- Áp dụng JWT Bearer authentication với refresh token expire sau 7 ngày.
- Endpoint `POST /api/v1/users` trả về `201 Created` kèm Location header.

❌ Sai:
- Sử dụng mẫu Kho lưu trữ để tách biệt tầng truy cập dữ liệu.
- Áp dụng xác thực Mã thông báo Web JSON với mã thông báo làm mới hết hạn sau 7 ngày.
```

### Khi sub-agent được spawn

Khi orchestrator delegate task cho sub-agent (qua tool `Agent`), prompt gửi cho sub-agent **PHẢI** chỉ thị rõ ràng:
> "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

Để đảm bảo sub-agent không vô tình xuất tiếng Anh do prompt training mặc định.

---

## Project Mode & Profile

This kit supports **two modes**. The mode + peripheral technologies are declared in the `## Project Profile` section (placed directly below in each repo). If **no** Project Profile is present → defaults to **greenfield** + the default stack (`rules/tech-stack.md`).

| Mode | When | Pipeline |
|------|------|----------|
| **greenfield** | Building from scratch, no existing code | The 12-step linear pipeline below |
| **brownfield** | Legacy code already exists / is running in production | **Phase A discovery** (`/discover` → `/spec` reverse → `/arch` reverse) + branched development flows (B1–B5) |

**Brownfield activates:**
- `rules/brownfield.md` (legacy discipline: characterization test, backward-compat, ADR-to-change, measure-vs-verify).
- `/spec`, `/arch`, `/plan` read the Mode to change behavior (see §Brownfield Mode in each command).
- Peripheral technologies that differ from the default → `rules/overrides/*` per the Profile declaration.

**Project Profile template** (each repo fills this in; `/discover` generates it automatically for brownfield):

```markdown
## Project Profile
- Mode: greenfield | brownfield
- Core: C# 12 + ASP.NET Core 8 + EF Core 8
- Database: SQL Server (base) | Oracle → rules/overrides/database-oracle.md | MySQL → rules/overrides/database-mysql.md | PostgreSQL → rules/overrides/database-postgres.md | MongoDB → rules/overrides/database-mongodb.md
- Observability: Serilog/Grafana (base) | ELK → rules/overrides/monitoring-elk.md
- Structure: Clean Architecture | N-tier | monolith
- Frontend: <if any>
```

> **Brownfield pipeline summary:**
> - **Phase A (one-time):** `/discover` → `/spec` (reverse) → `/arch` (reverse) → `/infra` (reverse-bootstrap). `/scan` is recommended, independent. `/verify` and `/deploy` are **not part of Phase A** — they are execution commands for per-change work in Phase B (production deploy = touches production state, not baseline documentation).
> - **Phase B (iterative):** B1 new feature · B2 modify feature (characterization test first) · B3 `/fix-issue` · B4 `/hotfix` · B5 architecture upgrade (`/arch` redesign + ADR).
> - **Quick lookup of command order per flow:** [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md). Detailed discipline: [`rules/brownfield.md`](rules/brownfield.md).

---

## Project Profile

> **Greenfield** — xây LinkVault từ đầu. Repo **chưa có source code**; Profile này khai báo stack **mục tiêu** (intended), không phải hiện trạng. Nguồn requirements: [`README1.txt`](../README1.txt). Áp dụng pipeline greenfield 12 bước (`/spec` → `/arch` → … → `/deploy`); `rules/brownfield.md` **KHÔNG** áp dụng. Khi nào có code thật + chạy `/discover`, đổi `Mode` → brownfield và để `/discover` sinh lại Notes hiện trạng.

- **Mode:** greenfield
- **Core:** C# 12 + ASP.NET Core 8 (`net8.0`) + EF Core 8
- **Database:** SQL Server 2022 → base `rules/database.md` (no override). InMemory provider cho test/design-time.
- **Observability:** Serilog (structured JSON: Console + rolling File) → base `rules/monitoring.md`.
- **Structure:** Clean Architecture 3-layer (`LinkVault.Api` → `LinkVault.Core` ← `LinkVault.Infrastructure`).
- **Frontend:** Next.js 15 (App Router) + React 18 + TypeScript 5.x + Zustand + TanStack Query + React Hook Form + Zod + Tailwind + shadcn/ui (Radix UI primitives). Test: Vitest + Testing Library + jsdom.

---

## Development Workflow (AI SDLC)

Follow this **12-step workflow** (3 phases) for all feature development (greenfield mode; for brownfield see §Project Mode & Profile):

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 AI SDLC PIPELINE                                  │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 1: REQUIREMENTS & DESIGN                                             │  │
│  │                                                                             │  │
│  │  /spec ────→ /arch* ───→ /plan ────→ /secure*                               │  │
│  │    │           │           │            │                                   │  │
│  │   BA          SA          PM       SecArch                                  │  │
│  │    │           │           │            │                                   │  │
│  │  specs/    architecture/  plans/    security/                               │  │
│  │                                     PRE_DEV_REVIEW                          │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                         │
│                                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 2: DEVELOPMENT & QUALITY                                             │  │
│  │                                                                             │  │
│  │  /build ────→ /test ────→ /review*                                          │  │
│  │     │           │            │                                              │  │
│  │    Dev         QA       Reviewer                                            │  │
│  │     │           │            │                                              │  │
│  │   src/       tests/      reports/                                           │  │
│  │   tests/                 CODE_REVIEW                                        │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                         │
│                                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 3: SECURITY & DEPLOYMENT                                             │  │
│  │                                                                             │  │
│  │  /scan* ──→ /infra ──→ /docs* ──→ /verify* ──→ /deploy                      │  │
│  │     │          │          │          │           │                          │  │
│  │  SecScan    Backend    Writer       QA        Release                       │  │
│  │     │          │          │          │           │                          │  │
│  │  security/  docker/     docs/     reports/    DEPLOYED                       │  │
│  │  SCAN_REPORT                      VERIFY_REPORT                              │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘

Legend: * = Optional (other commands are required)
```

### Phase 1: Requirements & Design

| # | Command | Agent | Purpose | Output |
|---|---------|-------|---------|--------|
| 1 | `/spec` | Business Analyst | Spec before code — User Stories & Acceptance Criteria for new features | `specs/` |
| 2 | `/arch` | Systems Architect | Design system architecture with diagrams, ADRs, and API contracts | `architecture/` |
| 3 | `/plan` | Project Manager | Decompose specs into small, verifiable tasks with dependency ordering | `plans/` |
| 4 | `/secure` | Security Auditor | Pre-development security review with threat modeling (STRIDE) | `security/PRE_DEV_REVIEW` |

### Phase 2: Development & Quality

| # | Command | Agent | Purpose | Output | Docker |
|---|---------|-------|---------|--------|--------|
| 5 | `/build` | Frontend/Backend Dev | Implement tasks incrementally using TDD and vertical slices | `src/`, `tests/` | ❌ Not required |
| 6 | `/test` | Test Engineer | QA verification with real dependencies — the quality gate before review | `tests/` | ✅ Required |
| 7 | `/review` | Code Reviewer | Review a pull request or branch changes using the Five-Axis Framework | `reports/CODE_REVIEW` | — |

> **Testing Strategy:** `/build` uses Unit Tests (Mock) + Integration Tests (In-Memory) — Docker not required. `/test` uses TestContainers + E2E Tests — Docker required. See details in [`.claude/rules/testing.md`](rules/testing.md).

### Phase 3: Security & Deployment

| # | Command | Agent | Purpose | Output |
|---|---------|-------|---------|--------|
| 8 | `/scan` | Security Auditor | Post-development security scanning and vulnerability assessment | `security/SCAN_REPORT` |
| 9 | `/infra` | Backend Developer | Setup Docker infrastructure for local development | `docker/` |
| 10 | `/docs` | Technical Writer | Generate comprehensive project documentation | `docs/` |
| 11 | `/verify`\* | Test Engineer | Post-deploy verification — exercise every feature (acceptance criteria) against the real deployed artifact. **Step optional · BLOCKING if run.** Strongly recommended before production promote; required inside `/hotfix` orchestrator | `reports/VERIFY_REPORT` |
| 12 | `/deploy` | Release Manager | Promote the verified artifact with staged rollout | Production |

> **Why `/verify` is strongly recommended (but optional) before `/deploy`:** `/test` runs in a test environment over an in-process transport — it cannot exercise the production-config × real-network × real-client intersection where CORS, security headers, env-gating middleware, TLS, and container-networking bugs live. `/verify` runs the acceptance-criteria suite against the **exact artifact that will ship**. Step is **optional** in the standard pipeline, but **BLOCKING if run** — when `/verify` is executed, `/deploy` may only promote a digest with a passing report. `/verify` remains **required** inside the `/hotfix` orchestrator (Step 4 re-verify on patched digest). See [`.claude/commands/verify.md`](commands/verify.md).

### Supporting Commands

| Command | Purpose |
|---------|---------|
| `/discover` | **Brownfield Phase A** — onboard a legacy repo: survey stack/structure, verify build/run, snapshot health, generate the Project Profile (read-only) |
| `/debug` | Systematic debugging and error recovery — find root cause, not symptoms |
| `/simplify` | Reduce complexity without changing behavior — code simplification |
| `/fix-issue` | Analyze and fix a reported bug or issue systematically (dev-time, ends at `/review`) |
| `/hotfix` | Restore a live/released system — triage rollback vs fix-forward, patch, re-verify, redeploy with audit trail (incident-time) |

> **`/fix-issue` vs `/hotfix`:** `/fix-issue` fixes code during the dev cycle (not yet released, ends at `/review`). `/hotfix` is a **thin orchestrator** for an artifact that is **already live** — it triages rollback-vs-fix-forward, then reuses `/fix-issue` (the fix) + `/verify` (proves the patch on the real artifact) + `/deploy` (promotes rollback-ready), along with patch versioning + a post-incident runbook. See [`.claude/commands/hotfix.md`](commands/hotfix.md).

---

## Quality Gates

Each phase transition has mandatory quality gates:

```
┌─────────────────────────────────────────────────────────────────┐
│                       QUALITY GATES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  GATE 1: /spec → /arch                                          │
│  ✓ PRD approved by stakeholder                                  │
│  ✓ All user stories have acceptance criteria                   │
│                                                                 │
│  GATE 2: /arch → /plan                                          │
│  ✓ Architecture reviewed                                       │
│  ✓ ADRs documented for key decisions                           │
│  ✓ API contracts defined                                       │
│                                                                 │
│  GATE 3: /plan → /secure                                        │
│  ✓ Tasks broken into vertical slices                           │
│  ✓ Dependencies mapped                                         │
│                                                                 │
│  GATE 4: /secure → /build  (step optional · BLOCKING if run)    │
│  ✓ Threat model completed (if /secure run)                     │
│  ✓ Security requirements defined (if /secure run)              │
│  ✓ No critical security concerns (if /secure run)              │
│                                                                 │
│  GATE 5: /build → /test                                         │
│  ✓ All unit tests pass                                         │
│  ✓ Code compiles without errors                                │
│                                                                 │
│  GATE 6: /test → /review                                        │
│  ✓ Code coverage ≥ 80%                                         │
│  ✓ All tests pass                                              │
│                                                                 │
│  GATE 7: /review → /scan  (Optional)                            │
│  ✓ Five-axis review passed (if /review run)                    │
│  ✓ All critical feedback addressed (if /review run)            │
│                                                                 │
│  GATE 8: /scan → /infra  (step optional · BLOCKING if run)      │
│  ✓ No critical/high vulnerabilities (if /scan run)             │
│  ✓ OWASP Top 10 checks pass (if /scan run)                     │
│                                                                 │
│  GATE 9: /infra → /docs                                         │
│  ✓ Docker builds successfully                                  │
│  ✓ docker-compose up runs all services healthy                 │
│                                                                 │
│  GATE 10: /docs → /verify  (Optional)                           │
│  ✓ All documentation complete (if /docs run)                   │
│  ✓ README updated (if /docs run)                               │
│                                                                 │
│  GATE 11: /verify → /deploy  (step optional · BLOCKING if run) │
│  ✓ Artifact digest tested == digest promoted (if /verify run)  │
│  ✓ Liveness + API contract pass (if /verify run)               │
│  ✓ E2E journeys pass per user story (if UI, if /verify run)    │
│  ✓ NFRs measured against spec thresholds (if /verify run)      │
│  ✓ 100% AC scenarios have verify test (if /verify run)         │
│  Note: /verify remains REQUIRED inside /hotfix orchestrator    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Principles

### Code Quality
- **Test-Driven Development** — Write failing tests first, then implement
- **Incremental Implementation** — Small vertical slices, always buildable
- **Five-Axis Review** — Correctness, Readability, Architecture, Security, Performance

### Security First
- **Pre-Development Security** — Threat modeling before coding
- **Post-Development Security** — Vulnerability scanning before deploy
- **Security by Design** — Not afterthought

### Philosophy
- Progress over perfection
- Fix root causes, not symptoms
- The simplest thing that could work
- Tests are proof, not afterthought

---

## Mandatory Rules

All rules in `.claude/rules/` are **mandatory** and must be followed:

### Foundations (master reference)
| Rule | Description |
|------|-------------|
| `principles-and-practices.md` | **Master reference** — design principles (SOLID, YAGNI, KISS, DRY, Composition, Tell-Don't-Ask), best practices (TDD, code review, idempotency, ADR, postmortem), architecture default (Modular Monolith + Clean Architecture), Docker baseline (20 must-haves), NFR-dependent infrastructure (Redis/Kafka/sharding/CDN — opt-in by trigger). Referenced by every SDLC command. |

### Code Quality
| Rule | Description |
|------|-------------|
| `clean-code.md` | Variables, functions, SOLID, async/await |
| `code-style.md` | C# formatting, braces, `var` usage, file-scoped namespaces |
| `error-handling.md` | `AppException`, ProblemDetails (RFC 7807), global middleware |

### Architecture & Design
| Rule | Description |
|------|-------------|
| `tech-stack.md` | Approved technologies (ASP.NET Core 8, SQL Server, Redis, EF Core) |
| `system-design.md` | CAP theorem, caching, scaling, queues |
| `project-structure.md` | Clean Architecture, folder organization |
| `api-conventions.md` | REST standards, response envelopes |
| `frontend.md` | Next.js/React/TypeScript, Zustand, TanStack Query, Tailwind |

### Data & Naming
| Rule | Description |
|------|-------------|
| `naming-conventions.md` | Cache keys, DB, queues, env vars |
| `database.md` | EF Core + Dapper patterns, transactions, N+1 prevention |

### Operations
| Rule | Description |
|------|-------------|
| `security.md` | **CRITICAL** — Never violate security rules |
| `monitoring.md` | Prometheus, Grafana, logging, alerting (base; `overrides/monitoring-elk.md` when the Profile declares ELK) |
| `testing.md` | Coverage thresholds, test patterns |
| `git-workflow.md` | Branching strategy, conventional commits |
| `brownfield.md` | **Brownfield only** — legacy discipline: characterization test, backward-compat, ADR-to-change, measure-vs-verify (active when `Mode: brownfield`) |

---

## Available Agents

Invoke the right agent for each task type. Agent definitions are stored in `.claude/agents/`:

### Development Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 🖥️ **Frontend Developer** | `frontend-developer.md` | Expert frontend developer specializing in Next.js, React, TypeScript, and modern UI development | `/build` |
| 🔧 **Backend Developer** | `backend-developer.md` | Expert backend developer specializing in ASP.NET Core, Entity Framework Core, SQL Server, Redis, and REST API design | `/build`, `/infra` |
| 🏗️ **Systems Architect** | `systems-architect.md` | Principal systems architect who designs scalable, reliable system architectures | `/arch` |

### Quality Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 👀 **Code Reviewer** | `code-reviewer.md` | Senior Staff Engineer perspective for five-axis code review | `/review` |
| 🧪 **Test Engineer** | `test-engineer.md` | Senior SDET who owns end-to-end quality — test strategy, TDD coaching, coverage policy, TestContainers/E2E execution, and bug triage | `/test`, `/verify` |
| 🔒 **Security Auditor** | `security-auditor.md` | Security engineer for vulnerability detection and threat modeling | `/secure`, `/scan` |

### Product & Operations Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 📊 **Business Analyst** | `business-analyst.md` | Requirements engineer who elicits, analyzes, and documents what to build and why | `/spec` |
| 📋 **Project Manager** | `project-manager.md` | Strategic project manager who plans sprints, defines requirements, and ensures delivery | `/plan` |
| 🎨 **UI/UX Designer** | `ui-ux-designer.md` | Expert designer who creates intuitive, beautiful, and accessible user experiences | `/spec`, `/arch` |
| 📝 **Technical Writer** | `technical-writer.md` | Technical writer who produces developer-facing documentation — API references, getting-started guides, deployment runbooks, troubleshooting | `/docs` |
| 🚀 **Release Manager** | `release-manager.md` | Release engineer who owns build, staged rollout, version tagging, release notes, and post-deploy verification | `/deploy` |

> **Note:** `/infra` (local Docker) is owned by the Backend Developer agent. `/verify` (post-deploy verification on the real artifact) is owned by the Test Engineer agent, collaborating with the Release Manager. `/deploy` (production rollout) is owned by the Release Manager agent.

---

## Project Structure

```
project-root/
│
├── specs/                          # /spec output
│   ├── SPEC.md
│   └── user-stories/
│
├── architecture/                   # /arch output
│   ├── ARCHITECTURE.md
│   ├── adr/
│   ├── diagrams/
│   └── api/
│
├── plans/                          # /plan output
│   ├── sprint-*.md
│   ├── plan.md
│   └── todo.md
│
├── security/                       # /secure + /scan output
│   ├── THREAT_MODEL.md
│   ├── PRE_DEV_REVIEW.md
│   └── SCAN_REPORT.md
│
├── src/                            # /build output
│
├── tests/                          # /build + /test output
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── reports/                        # /review + /verify output
│   ├── CODE_REVIEW.md
│   ├── VERIFY_REPORT.md            # /verify — gate verdict for /deploy
│   ├── VERIFY_MATRIX.md            # /verify — acceptance-criteria → test traceability
│   └── verify-artifact.lock        # /verify — digest tested == digest promoted
│
├── docker/                         # /infra output — Dockerfile only
│   └── Dockerfile
├── docker-compose.yml              # /infra output — at repo root so `context: .` works
├── docker-compose.test.yml         # optional E2E overlay
├── docker-compose.deploy.yml       # optional release-tag overlay
├── .dockerignore                   # MUST be at repo root (build context)
│
├── docs/                           # /docs output
│   ├── getting-started.md
│   ├── api/
│   ├── deployment.md
│   └── troubleshooting.md
│
└── .claude/                        # AI Agent Configuration
    ├── agents/
    ├── commands/
    ├── rules/
    ├── skills/
    ├── references/
    └── CLAUDE.md
```

---

## Available Skills

Specialized skills for complex operations (stored in `.claude/skills/`):

| Skill | Description |
|-------|-------------|
| `tdd` | Write tests before code using RED-GREEN-REFACTOR cycle |
| `code-review` | Five-axis code review for comprehensive quality assessment |
| `incremental-implementation` | Build features in thin vertical slices with continuous verification |
| `security-review` | Skill to perform a thorough security audit of the codebase |

> **Note:** SDLC workflow commands (`/spec`, `/arch`, `/build`, etc.) are defined in `.claude/commands/`.

---

## Reference Checklists

Quick references in `.claude/references/`:

| Reference | Use For |
|-----------|---------|
| `security-checklist.md` | Pre-deploy security verification |
| `testing-patterns.md` | Test structure and anti-patterns |
| `performance-checklist.md` | Core Web Vitals, optimization |
| `accessibility-checklist.md` | WCAG 2.1 AA compliance |
| `ascii-diagram-guide.md` | ASCII diagram standards for architecture docs |
| `code-review-checklist.md` | Five-axis code review framework |
| `deployment-checklist.md` | Pre-deployment verification gates |
| `docker-patterns.md` | Dockerfile and docker-compose best practices |

---

## Agent Behavior Guidelines

1. **Follow the complete workflow** — `/spec` → `/arch` → `/plan` → `/secure` → `/build` → `/test` → `/review` → `/scan` → `/infra` → `/docs` → `/verify` → `/deploy`
2. **Respect quality gates** — Never skip blocking gates (security reviews)
3. **Apply mandatory rules** — All rules in `.claude/rules/` are non-negotiable
4. **Test first** — Write failing tests before implementing
5. **Security first** — Threat model before coding, scan before deploying
6. **Incremental changes** — Small commits, always buildable
7. **Explain before acting** — Describe changes before making them
8. **Fix root causes** — Don't patch symptoms
9. **Use the right agent** — Invoke specialized agents for their domains
10. **Document everything** — If it's not documented, it doesn't exist
11. **Keep `plans/todo.md` truthful** — Tick every completed task (`- [x]`) before reporting done. When work is delegated to sub-agents, the orchestrator owns the tick and applies it after the sub-agent's success report. A task without its tick is not done.


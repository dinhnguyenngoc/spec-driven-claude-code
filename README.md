# Spec-driven Development with Claude Code

> **Turn an idea into production-ready software — one command at a time.**
> A complete, opinionated SDLC kit for [Claude Code](https://claude.com/claude-code): specialized agents, slash-command workflows, mandatory engineering rules, and quality gates that keep AI honest from `/spec` to `/deploy`.

🌏 **[Tiếng Việt → README_VN.md](README_VN.md)**

---

## What is this?

This is **not** an application. It is a **`.claude/` configuration kit** you drop into any project so that Claude Code stops being a clever autocomplete and starts behaving like a disciplined engineering team.

Instead of asking the AI to "build me an app" and hoping for the best, you drive a **12-step pipeline** where each step:

- is owned by a **specialized agent** (Business Analyst, Architect, Backend Dev, Security Auditor, …),
- produces a **concrete artifact** (`specs/`, `architecture/`, `plans/`, `src/`, `tests/`, `reports/`…),
- and must pass a **quality gate** before the next step begins.

The result is the same discipline you'd expect from a real software team — requirements before code, tests before implementation, security before deploy — but executed by AI agents you orchestrate with a single slash command.

> 💡 **Inspired by** the agentic-workflow philosophy of [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), adapted into a strict, gate-driven SDLC for **C# / ASP.NET Core 8** (with first-class **Node.js / Next.js** overrides).

---

## Why use it?

| Without the kit | With the kit |
|-----------------|--------------|
| "Build me a bookmark app" → a wall of code, no plan | `/spec` → User Stories & Acceptance Criteria you approve first |
| AI invents its own structure each time | Every project follows the same **Clean Architecture** rules |
| Tests written last (or never) | **TDD enforced** — failing test first, ≥80% coverage gate |
| Security is an afterthought | **STRIDE threat model** before code, **OWASP scan** before deploy |
| "It works on my machine" | `/verify` runs against the **exact artifact** that ships |
| Inconsistent code style across sessions | 17 **mandatory rules** applied to every line |

---

## The 12-step pipeline

```
PHASE 1 — REQUIREMENTS & DESIGN        PHASE 2 — DEVELOPMENT & QUALITY      PHASE 3 — SECURITY & DEPLOY
┌─────────────────────────────┐        ┌──────────────────────────┐        ┌───────────────────────────────────┐
│ /spec  → Business Analyst   │        │ /build → Frontend/Backend│        │ /scan   → Security Auditor        │
│ /arch  → Systems Architect  │   ──▶  │ /test  → Test Engineer   │   ──▶  │ /infra  → Backend Developer       │
│ /plan  → Project Manager    │        │ /review→ Code Reviewer   │        │ /docs   → Technical Writer        │
│ /secure→ Security Auditor   │        │                          │        │ /verify → Test Engineer           │
└─────────────────────────────┘        └──────────────────────────┘        │ /deploy → Release Manager         │
        specs/ architecture/                  src/ tests/ reports/          └───────────────────────────────────┘
        plans/ security/                                                         security/ docker/ docs/ reports/
```

Each arrow is a **quality gate**. You can't promote a build that fails its tests, and you shouldn't `/deploy` an artifact `/verify` never blessed. (Optional steps are marked in the docs; security gates are blocking.)

---

## Quick start (the simplest path)

### 1. Get the kit into your project

```bash
# Option A — start a brand-new project from this kit
git clone <this-repo> my-new-project
cd my-new-project
rm -rf .git && git init        # make it your own

# Option B — copy the kit into an existing project
cp -r path/to/this-repo/.claude  my-existing-project/.claude
```

The only thing that matters is that the **`.claude/`** folder sits at your project root. Open the folder in Claude Code (CLI, VS Code, or JetBrains) and you're ready.

### 2. Tell it what you want to build

```text
/spec I want to build LinkVault — a personal bookmark manager where a user
can register, save bookmarks (URL, title, tags), search them, and mark favorites.
```

The **Business Analyst** agent will ask clarifying questions, then write `specs/SPEC.md` with User Stories and Acceptance Criteria. **Review and approve it** before moving on.

### 3. Walk the pipeline

Run the commands in order, reviewing each artifact as you go:

```text
/arch      → system design, ADRs, API contracts   → architecture/
/plan      → tasks broken into vertical slices     → plans/todo.md
/secure    → STRIDE threat model (optional)        → security/
/build     → TDD implementation                    → src/ + tests/
/test      → real-dependency QA gate               → tests/
/review    → five-axis code review                 → reports/
/scan      → vulnerability scan                     → security/
/infra     → Docker setup                          → docker/ + docker-compose.yml
/docs      → documentation                         → docs/
/verify    → exercise the real artifact            → reports/VERIFY_REPORT.md
/deploy    → staged production rollout             → 🚀
```

> **That's the whole loop.** For a quick prototype you can run just `/spec → /plan → /build → /test`. For production, walk the full 12 steps.

### 4. Keep the to-do list honest

Open [plans/todo.md](plans/todo.md) anytime to see what's done (`- [x]`) and what's next. The orchestrator ticks tasks only after they're verified.

---

## The commands

### Core SDLC pipeline

| # | Command | Agent | What it does | Output |
|---|---------|-------|--------------|--------|
| 1 | `/spec` | Business Analyst | User Stories & Acceptance Criteria **before** code | `specs/` |
| 2 | `/arch` | Systems Architect | Architecture, diagrams, ADRs, API contracts | `architecture/` |
| 3 | `/plan` | Project Manager | Decompose into small, dependency-ordered tasks | `plans/` |
| 4 | `/secure` ⃰ | Security Auditor | Pre-dev threat model (STRIDE) | `security/PRE_DEV_REVIEW` |
| 5 | `/build` | Frontend/Backend Dev | Implement with TDD, vertical slices | `src/`, `tests/` |
| 6 | `/test` | Test Engineer | QA with real dependencies (TestContainers) | `tests/` |
| 7 | `/review` ⃰ | Code Reviewer | Five-Axis review of the change | `reports/CODE_REVIEW` |
| 8 | `/scan` ⃰ | Security Auditor | Post-dev vulnerability scan | `security/SCAN_REPORT` |
| 9 | `/infra` | Backend Developer | Docker + docker-compose for local dev | `docker/` |
| 10 | `/docs` ⃰ | Technical Writer | Getting-started, API, deployment docs | `docs/` |
| 11 | `/verify` ⃰ | Test Engineer | Exercise every feature on the real artifact | `reports/VERIFY_REPORT` |
| 12 | `/deploy` | Release Manager | Promote the verified artifact, staged rollout | Production |

<sub>⃰ = optional step, but **blocking if run** (security gates are non-negotiable).</sub>

### Supporting commands

| Command | Purpose |
|---------|---------|
| `/discover` | **Brownfield onboarding** — survey an existing codebase, verify build/run, generate the Project Profile |
| `/debug` | Systematic debugging — find the root cause, not the symptom |
| `/simplify` | Reduce complexity without changing behavior |
| `/fix-issue` | Analyze and fix a reported bug during the dev cycle (ends at `/review`) |
| `/hotfix` | Restore a **live** system — triage rollback vs fix-forward, patch, re-verify, redeploy |

---

## The agents

Each command invokes a specialist with its own playbook (in [.claude/agents/](.claude/agents/)):

| Agent | Specialty |
|-------|-----------|
| 📊 **Business Analyst** | Requirements, user stories, acceptance criteria |
| 🏗️ **Systems Architect** | Scalable architecture, ADRs, API design |
| 📋 **Project Manager** | Sprint planning, task decomposition |
| 🔒 **Security Auditor** | Threat modeling (STRIDE), vulnerability assessment |
| 🔧 **Backend Developer** | ASP.NET Core, EF Core, SQL Server, Redis, REST |
| 🖥️ **Frontend Developer** | Next.js, React, TypeScript, modern UI |
| 🎨 **UI/UX Designer** | Intuitive, accessible user experiences |
| 🧪 **Test Engineer** | Test strategy, TDD, coverage, TestContainers, E2E |
| 👀 **Code Reviewer** | Five-axis review (Correctness, Readability, Architecture, Security, Performance) |
| 📝 **Technical Writer** | API references, runbooks, troubleshooting |
| 🚀 **Release Manager** | Build, staged rollout, versioning, release notes |

---

## Two modes: Greenfield & Brownfield

The kit auto-detects which situation you're in (see the `## Project Profile` block in [.claude/CLAUDE.md](.claude/CLAUDE.md)):

| Mode | When | How to start |
|------|------|--------------|
| 🌱 **Greenfield** | Building from scratch, no code yet | `/spec <your idea>` → walk the 12 steps |
| 🏚️ **Brownfield** | Legacy code already exists / runs in production | `/discover` first → reverse-`/spec` → reverse-`/arch` → then iterate |

**Brownfield discipline** (auto-activated): characterization tests before touching untested legacy code, backward-compatibility by default, ADR required to change architecture, and the strangler-fig pattern for upgrades. See [.claude/rules/brownfield.md](.claude/rules/brownfield.md).

---

## What gets enforced (the rules)

Every line of code obeys the **mandatory rules** in [.claude/rules/](.claude/rules/). Highlights:

- **Clean Architecture** — `Api → Core ← Infrastructure`, no cross-layer leaks
- **Clean Code & SOLID** — ≤3 params, single-purpose methods, no flag params, async correctness
- **TDD** — failing test first, ≥80% line / ≥75% branch coverage
- **Security first** — no hardcoded secrets, parameterized queries, JWT discipline, OWASP checks
- **RFC 7807 errors**, REST conventions, structured logging with correlation IDs
- **Docker baseline** — multi-stage build, non-root user, health checks, resource limits, image scanning

### Quality gates (you can't skip the blocking ones)

```
/spec → /arch     PRD approved · every story has acceptance criteria
/arch → /plan     architecture reviewed · ADRs documented · API contracts defined
/build → /test    all unit tests pass · code compiles
/test → /review   coverage ≥ 80% · all tests pass
/scan → /infra    no critical/high vulnerabilities (if /scan run)
/infra → /docs    docker builds · compose up healthy
/verify → /deploy artifact tested == artifact promoted (if /verify run)
```

---

## Customizing for your stack

The kit ships with a **default stack** (C# 12 + ASP.NET Core 8 + EF Core 8 + SQL Server + Next.js). To use a different peripheral technology, edit the `## Project Profile` in [.claude/CLAUDE.md](.claude/CLAUDE.md) and the matching **override** kicks in automatically:

| Want… | Declare in Profile | Override file |
|-------|--------------------|---------------|
| PostgreSQL / MySQL / Oracle / MongoDB | `Database: PostgreSQL` | [.claude/rules/overrides/database-*.md](.claude/rules/overrides/) |
| Node.js backend (Express/NestJS/Fastify) | `Core: Node.js + …` | [.claude/rules/overrides/lang-nodejs.md](.claude/rules/overrides/) |
| ELK observability | `Observability: ELK` | [.claude/rules/overrides/monitoring-elk.md](.claude/rules/overrides/) |

Overrides only replace the dialect/backend-specific parts — all agnostic principles (parameterized queries, structured logging, TDD…) stay the same.

---

## Repository layout

```
.claude/
├── CLAUDE.md          # The brain — pipeline, gates, Project Profile, rules index
├── commands/          # 17 slash-command workflows (/spec, /arch, /build, …)
├── agents/            # 11 specialized agent playbooks
├── rules/             # 17 mandatory engineering rules
│   └── overrides/     # 8 stack-specific overrides (Postgres, Node.js, ELK, …)
├── skills/            # Reusable techniques (tdd, code-review, …)
├── references/        # 10 checklists (security, testing, docker, a11y, …)
├── templates/         # STRIDE & OWASP templates
├── hooks/             # Lifecycle hooks (command stats)
└── scripts/           # Security scanners (dotnet, nodejs, python, docker)

# Generated as you work:
specs/  architecture/  plans/  security/  src/  tests/  reports/  docker/  docs/
```

> 📖 The single source of truth for the whole workflow is [.claude/CLAUDE.md](.claude/CLAUDE.md) — start there if you want the deep dive.

---

## A worked example: LinkVault

This kit ships with a sample brief, [README1.txt](README1.txt), for **LinkVault** — a personal bookmark manager (auth, bookmark CRUD, tags, search, simple web UI). It's the perfect first run:

```text
/spec        # paste the LinkVault requirements from README1.txt
/arch        # design the Clean Architecture solution + API
/plan        # break it into buildable slices
/build       # implement, test-first
/test        # prove it with real dependencies
```

By the end you'll have a working, tested, documented ASP.NET Core + Next.js app — and a feel for how the whole pipeline flows.

---

## FAQ

**Do I have to run all 12 steps?**
No. Required steps are `/spec`, `/arch`, `/plan`, `/build`, `/test`, `/infra`, `/deploy`. The rest (`/secure`, `/review`, `/scan`, `/docs`, `/verify`) are optional — but if you run them, their gates are blocking. For production, running them all is strongly recommended.

**Can I use it for languages other than C#?**
Yes — the kit has Node.js / TypeScript overrides today, and the architecture is designed so peripheral tech (DB, observability) swaps via the Project Profile.

**Where do I change the default model or behavior?**
[.claude/settings.json](.claude/settings.json) (model, permission mode, hooks).

**What's the difference between `/fix-issue` and `/hotfix`?**
`/fix-issue` fixes code during the dev cycle (not yet released). `/hotfix` restores something that's **already live** — it adds rollback triage, re-verification, and an incident runbook.

---

## License

See the repository for license details. The workflow philosophy draws inspiration from [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD).

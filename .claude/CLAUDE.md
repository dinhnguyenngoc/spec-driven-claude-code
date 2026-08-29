# SpecGate — Spec-driven SDLC kit for Claude Code

## Overview

This project uses Claude AI as an intelligent development agent with structured workflows, specialized sub-agents, and mandatory coding standards.

---

## Output Language (MANDATORY)

> **Applies to every command, every agent, every sub-agent — no exception unless the user explicitly requests another language ad hoc.**

### Language resolution

The working language is declared in the **Project Profile**:

```markdown
- Output Language: Vietnamese
```

- **Value** = the English name of the language (`Vietnamese`, `English`, `Japanese`, …).
- **Field missing / no Profile → defaults to `Vietnamese`** — backward compatibility: the field postdates repos configured under the older Vietnamese-only rule, and a kit upgrade must never silently flip an ongoing project's artifact language.
- **Workspace Mode:** one product = one artifact language — `/discover` Phase 0 asks once and writes the same value into the root + every member repo Profile; commands resolve it from the **target repo's** Profile.
- **`Output Language: English`** → write everything in English; the mixing rules below become moot.

### Content written in the declared language

When the declared language is NOT English, ALL of the following MUST be written in the declared language:

- **Conversation with the user** — every answer, explanation, confirmation question
- **User-visible tool metadata** — the description labels the chat window renders next to tool calls (Bash `description`, Agent `description`, TodoWrite items). The command text itself, tool output, and file contents are NOT in scope (they are code/output by nature)
- **SDLC workflow artifacts**:
  - `specs/` — SPEC.md, user stories, acceptance criteria
  - `architecture/` — ARCHITECTURE.md, ADRs, diagram descriptions
  - `plans/` — sprint plans, plan.md, todo.md (task titles)
  - `security/` — THREAT_MODEL.md, PRE_DEV_REVIEW.md, SCAN_REPORT.md
  - `reports/` — CODE_REVIEW.md and other reports
  - `docs/` — getting-started, deployment, troubleshooting, guides
- **Reports, summaries, status updates**
- **Commit message body** (the detailed description after the title line)
- **PR descriptions, release notes**
- **Code comments explaining business logic** (the WHY)

> **Anti-drift (command runs):** the closing summary a command run prints to the chat IS "conversation with the user" — it follows the declared language like any other answer. Known failure mode: after a run whose entire context is English (command definitions, code, sub-agent reports), the final summary drifts to English — re-resolve the declared language BEFORE writing any user-facing message, the final one especially. A slash command invoked with no user prose (`/discover`) is NOT a signal to answer in English; neither is having just written English artifacts or read English rules. **An unresolved `Output Language` is NOT a licence to write English.** Resolution never requires the user: a value in the Profile (including the kit's pre-filled one) is the answer, and a missing field falls back to `Vietnamese` per §Language resolution. So even the question *"which output language do you want?"* is itself written in the resolved language — asking about the language in English while the Profile declares another one is the exact drift this rule forbids.

### Always English — never translate

The following MUST stay in English regardless of the declared language, for standards compliance and searchability:

- **Code** — variable, function, class, interface, namespace, file names
- **Technical identifiers** — route URLs, cache keys, DB tables/columns, env vars, Kafka topics
- **Technical keywords / standard terms** — REST, JWT, OAuth2, Clean Architecture, SOLID, TDD, CQRS, CAP, RFC 7807, OWASP, STRIDE, EF Core, Dapper, etc.
- **Technology, framework, library names** — ASP.NET Core, Next.js, SQL Server, Redis, Kafka, Docker, Prometheus, Grafana
- **HTTP methods, status code labels** — `GET`, `POST`, `200 OK`, `404 Not Found`
- **Conventional Commit types** — `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`
- **Commit title (first line)** — Conventional Commits, written in English
- **Code comments explaining pure syntax / technique** — keep English when it is a standard concept

### Language-mixing rule

When an artifact in the declared language contains technical terms, do **NOT** translate the terms — keep them as-is inside the surrounding prose. Example with `Output Language: Vietnamese`:

```markdown
✅ Correct:
- Sử dụng pattern Repository để tách biệt tầng truy cập dữ liệu.
- Áp dụng JWT Bearer authentication với refresh token expire sau 7 ngày.
- Endpoint `POST /api/v1/users` trả về `201 Created` kèm Location header.

❌ Wrong:
- Sử dụng mẫu Kho lưu trữ để tách biệt tầng truy cập dữ liệu.
- Áp dụng xác thực Mã thông báo Web JSON với mã thông báo làm mới hết hạn sau 7 ngày.
```

### When a sub-agent is spawned

When the orchestrator delegates a task to a sub-agent (via the `Agent` tool), it MUST first resolve the declared language from the Project Profile, then state it explicitly in the prompt sent to the sub-agent:
> "Output language: **\<declared language\>** for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

This prevents sub-agents from accidentally emitting English due to default prompt-training bias.

---

## Output Clarity (MANDATORY)

> **Applies to every artifact of every command/agent.** Complements §Output Language (which governs *the language*) — this section governs *clarity*. Combined: the right **language** AND **coherent, easy to follow**.

Every SDLC artifact (`specs/`, `architecture/`, `plans/`, `security/`, `reports/`, `docs/`…) MUST read **clearly for its intended audience**:

- **Open with a plain-language summary** (*what / why / for whom*) before any detail.
- **Write for the reader:** SPEC / wireframe / release notes / exported PRD → **non-specialist stakeholder** (they know computers, not software engineering — the checkable floor is [`rules/output-style.md`](rules/output-style.md) §10); ARCHITECTURE / ADR / report → engineer (technical but still clear + explains *why*); runbook / troubleshooting → operator (step-by-step, unambiguous).
- **Define terms & acronyms** on first use (gloss in the artifact's Output Language) — a term that would need a long gloss is **replaced in the prose by a self-explanatory phrase** + the term in parentheses; **one-line rationale** for every decision + number/threshold; layer the content (summary → detail → reference); **bold the key decisions**.
- **Short, complete sentences** (no telegram fragments; an arrow chain depicting a real ordered flow — `spec → code → test` — is notation, not a fragment), tables/lists over dense prose; **concrete conditions over abstract adjectives** (*"`Mode: brownfield` does not match an empty repo"*, not *"the Profile is stale"*); **kit-internal vocabulary** (phase names, gate numbers) stays out of reader-facing prose — name the observable effect.
- Clarity does **NOT** mean dumbing down — keep precision + identifier/standard names (per §Output Language).

> Full standard + anti-patterns + self-check: [`rules/output-style.md`](rules/output-style.md). These are **checkable** criteria at DoR and `/review`.

---

## Progress Visibility (MANDATORY)

> **Applies to every multi-step SDLC command / command that spawns sub-agents** (`/spec`, `/arch`, `/plan`, `/build`, `/test`, `/review`, `/scan`, `/infra`, `/docs`, `/verify`, `/deploy`, `/discover`, `/fix-issue`, `/hotfix`…). Complements §Output Language + §Output Clarity (which govern *content*); this section governs *progress visibility in the chat*.

A sub-agent's internal output (the `Agent` tool) **does NOT stream to the user's chat** — it only returns to the orchestrator. If the orchestrator stays silent, the user has no idea what is happening for the whole time a sub-agent runs (often several minutes) → a "black box" experience. Therefore the orchestrator **MUST**:

1. **A live TodoWrite checklist** — at the start of every long command, create a todo list following the command's phases; update `in_progress` / `completed` at each step so the user can see progress.
2. **Narrate each step** — one line *before* each sub-agent/heavy step ("assigning the BA to write the SPEC…") and one line *after* receiving the result ("done → 9 stories, 38 scenarios").
3. **Keep sub-agents dedicated** — do NOT switch to running inline just to "make it visible"; the agent-per-command design is still correct (clean context), it just needs to be **wrapped in todos + narration**. A silent gap is allowed **only while a sub-agent is running**, once the user already knows what it is doing.

> Still keep the discipline of verifying on disk after a sub-agent reports done → see §Verification After Delegation just below.

---

## Verification After Delegation (MANDATORY)

> **Applies to every command that spawns sub-agents which make changes / perform verification** (`/build`, `/test`, `/infra`, `/verify`, `/deploy`, `/fix-issue`, `/hotfix`…). Commands outside this list apply the **same discipline at artifact level** via their own §Orchestrator disk-check — every quality gate in the kit now carries one.

**A sub-agent's "green" report is NOT ground truth.** Before declaring a gate/step PASS, the orchestrator **MUST re-run the *gate-deciding* checks on disk itself** and read the real result — do not blindly trust the sub-agent's summary:

1. **Re-run the canonical gate-deciding command** (only the commands that decide pass, not everything): `dotnet build -c Release` + `dotnet test` · `npm run typecheck && npm test && npm run build` · `php artisan test` / `vendor/bin/pest` · `docker compose up` + healthcheck + smoke. Read the **real exit code / test count / health**.
2. **Cross-check the key invariants on disk**: the artifact file exists in the right place, the digest matches the lock, no production file was modified out of scope, scenario coverage matches the numbers.
3. **On any mismatch** between the report and disk → trust the disk, surface it immediately, and fix it before moving on.

> **Why this is mandatory:** in a real pipeline, this discipline has caught *report-says-green-but-disk-is-red* bugs that no other gate caught — e.g. `npm test` went RED after adding Playwright (the sub-agent still reported PASS), and the API container crashed on restart (deploy reported SUCCEEDED). This is a deliberate trade-off: spend extra time re-running, in exchange for blocking **false-green**. Only re-run the *gate-deciding* checks; do not overuse full re-runs.

---

## Project Mode & Profile

This kit supports **two per-repo modes** (plus a **workspace meta-mode** for multi-repo products — see §Workspace Mode). The mode + peripheral technologies are declared in the `## Project Profile` section (placed directly below in each repo). If **no** Project Profile is present → defaults to **greenfield** + the default stack (`rules/tech-stack.md`). (The kit ships `.claude/PROJECT_PROFILE.md` pre-declaring `Mode: brownfield` — the common case when adopting the kit into an existing repo; switch it to `greenfield` for from-scratch builds, or delete the file to fall back to greenfield defaults.)

| Mode | When | Pipeline |
|------|------|----------|
| **greenfield** | Building from scratch, no existing code | The 12-step linear pipeline below |
| **brownfield** | Legacy code already exists / is running in production | **Phase A discovery** (`/discover` → `/spec` reverse → `/arch` reverse) + branched development flows (B1–B5) |
| **workspace** | Parent folder of a multi-repo product (meta-mode — member repos stay greenfield/brownfield) | §Workspace Mode: scope-resolve → run the per-repo pipeline inside each target repo |

**Mode lifecycle — greenfield ends at the first release.** `greenfield` is a birth phase, not a permanent identity: once the kit-built project ships its first staged release (or per-change work starts on the built code), it graduates to **brownfield** — backward-compat by default and ADR-to-change now apply, because clients and data now rely on what runs. Graduation is cheap and never re-documents: `/discover` detects the kit-built baseline (forward `SPEC.md` Approved + `architecture/`) and runs the inventory-only **§Graduation run** (`commands/discover.md`) — minting `docs/CODEBASE_MAP.md` and flipping `Mode:` with consent. The forward spec/architecture stay the baseline (never REVERSE over them); `/spec` continues in DELTA per its Phase 0.

**Brownfield activates:**
- `rules/brownfield.md` (legacy discipline: characterization test, backward-compat, ADR-to-change, measure-vs-verify).
- `/spec`, `/arch`, `/plan` read the Mode to change behavior (see §Brownfield Mode in each command).
- Peripheral technologies that differ from the default → `rules/overrides/*` per the Profile declaration.

> **Profile location (resolution rule — applies to EVERY command/rule that mentions "Project Profile"):** "Project Profile" = the file **`.claude/PROJECT_PROFILE.md`** (CONFIG layer, user-owned — kit upgrades never touch it). **Backward-compatible fallback:** a repo not yet migrated → read the `## Project Profile` block in `CLAUDE.md` as before. `/discover` generates/updates this file.

**Project Profile template** (each repo fills in `.claude/PROJECT_PROFILE.md`; `/discover` generates it automatically for brownfield):

```markdown
## Project Profile
- Mode: greenfield | brownfield
- Output Language: Vietnamese | English | <language name in English> — prose/artifact & conversation language; code + identifiers always English (§Output Language). Missing → Vietnamese
- Core: C# 12 + ASP.NET Core 8 + EF Core 8 (base) | Node.js → rules/overrides/lang-nodejs.md + framework-nodejs-web.md + test-nodejs.md | PHP → rules/overrides/lang-php.md + framework-php-laravel.md + test-php.md — multi-stack repo (e.g. C# API + Python worker): declare ALL, scoped by path, dominant first (`C# (src/) + Python (tools/etl/)`); each stack's overrides govern its own area — never pick-one-drop-one
- Database: SQL Server (base) | Oracle → rules/overrides/database-oracle.md | MySQL → rules/overrides/database-mysql.md | PostgreSQL → rules/overrides/database-postgres.md | MongoDB → rules/overrides/database-mongodb.md
- Observability: Serilog/Grafana (base) | ELK → rules/overrides/monitoring-elk.md
- Structure: Clean Architecture | N-tier | monolith
- Frontend: <if any>
- Service id: <multi-repo products only — unique key consumed by /discover-system; single-repo → omit>
```

> **Brownfield pipeline summary:**
> - **Phase A (one-time):** `/discover` → `/spec` (reverse) → `/arch` (reverse) → `/infra` (reverse-bootstrap). `/scan` is recommended, independent. `/verify` and `/deploy` are **not part of Phase A** — they are execution commands for per-change work in Phase B (production deploy = touches production state, not baseline documentation).
> - **Phase B (iterative):** B1 new feature · B2 modify feature (characterization test first) · B3 `/fix-issue` · B4 `/hotfix` · B5 architecture upgrade (`/arch` redesign + ADR).
> - **Scope per-change:** `/test`/`/verify` **WRITE per delta, RUN the whole** automated suite (regression net); `/review` reviews only the diff/slice of the change. Detailed table + a 9-situation decision tree: [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md) §Scope per-change.
> - **Quick lookup of command order per flow:** [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md). Detailed discipline: [`rules/brownfield.md`](rules/brownfield.md).

---

## Workspace Mode (multi-repo products)

> **Active only when the session root's Project Profile declares `Mode: workspace`.** Without that declaration nothing in this section applies — single-repo behavior is unchanged. This is a **meta-mode of the parent folder**: each member repo keeps its own per-repo Profile with `Mode: greenfield | brownfield` as usual.

**Layout** — ONE kit at the workspace root; member repos hold CONFIG only:

```text
myproject/                          # thin git repo (platform repo): version-controls kit + system layer
├── .claude/                        # the ONLY full kit (commands, rules, hooks, this CLAUDE.md)
│   └── PROJECT_PROFILE.md          # Mode: workspace + repo registry
├── architecture/system/            # /discover-system output
├── specs/system/                   # /discover-system output — generated requirements views
├── exports/                        # /export-docs — system-target renders (System Spec/SDD)
├── repo1/                          # independent git repo
│   ├── .claude/PROJECT_PROFILE.md  # CONFIG only (generated by /discover) — no commands/CLAUDE.md
│   └── specs/ · architecture/ · …  # per-repo artifacts, committed into repo1
└── repo2/                          # same
```

**Workspace Profile schema** (root `.claude/PROJECT_PROFILE.md`):

```markdown
## Project Profile
- Mode: workspace
- Repos:
  - <service-id> → ./<folder>
  - <service-id> → ./<folder>
```

**Scope resolution (MANDATORY — run BEFORE any command logic):**

1. **Determine the target repo(s):** (a) the user named it; (b) infer from the task + `architecture/system/service-catalog.md`; (c) still unsure → **ASK — never guess**.
2. **Read the target repo's Profile** (`<repo>/.claude/PROJECT_PROFILE.md`) before doing anything — it decides mode + overrides. No Profile yet → only `/discover` may proceed.
3. **Every artifact path and every git command resolves against the target repo**, not the session root.
4. **Cross-repo feature:** settle the contract first, then execute **provider → consumer** (API → gateway → web); each touched repo runs the full per-repo flow and receives its own outputs.

**Workspace disk-check** (append to every gate while this mode is active):
- No new artifact at the workspace root except `.claude/logs/`, `architecture/system/`, `specs/system/` (generated views — `/discover-system`), and `exports/` (system-target renders — `/export-docs`).
- `git status` of every NON-target repo is clean.

**Conventions:** one product, one model — with a workspace kit, member repos carry no full kit (CONFIG only) and sessions open at the workspace root. Single-repo products keep the kit inside the repo as before.

---

## Natural-Language Task Routing (entry point)

When the user describes a task in **plain language** ("add feature X", "modify feature Y", "fix bug Z", "there's a production incident", "upgrade <dependency/architecture>", "clean up the tech debt in area W"…), **BEFORE doing anything else**, respond in a 3-part format:

1. **Mode** — if the session root declares `Mode: workspace` → resolve the target repo(s) first (§Workspace Mode), then determine greenfield/brownfield from the **target repo's** Profile + its actual signals (does business source code already exist), **stating the basis explicitly**. If the Profile contradicts the actual state → warn and stop — never proceed on your own; propose the fix (`Mode:` → the resolved value) and update the Profile only with the user's explicit consent (same reconcile-persist discipline as `/spec` Phase 0). A kit-built repo (forward SPEC Approved + `architecture/` present, no CODEBASE_MAP) is NOT a Profile contradiction — it is a pending graduation: route the flow as B1/B2 with `/discover` (§Graduation run) as the first checklist item (§Mode lifecycle above).
2. **Flow** — name it: greenfield 12-step, or B1 / B2 / B3 / B4 / B5 / B5-lite / `/simplify` (decision tree: [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md)).
3. **Command checklist in order** + the flow's key discipline (e.g. B2 → characterization test BEFORE changing · B1 exposing an external surface → should run `/secure` · B5 → ADR + strangler-fig · scope: WRITE per delta, RUN the whole suite).

Then **ask the user to choose an execution mode** (by default, do NOT run anything before asking):
- **User-driven** — the user runs each command and approves each gate themselves.
- **Claude-driven** — Claude runs the commands sequentially but **stops at every Quality Gate** for approval; the points that require human sign-off (Gate 1 stakeholder approval, review verdict, promote production) **always** wait — regardless of mode.

> **Exception — current-state questions (not change requests):** when the user *asks* about existing state/features (e.g. *"is a newly added bookmark checked for duplicates?"*, *"how is X configured?"*) → **do NOT route into a B-flow / do not ask for an execution mode**. Answer read-only per the **output contract of [`/inspect`](commands/inspect.md)**: a 3-tier evidence table (records → code → live) + PROVEN/DESCRIBED rank + mismatch flags + citations of `@US-ID`/`file:line`/digest. The live tier is OFF by default (only probe when the user explicitly asks). If the question turns into a change/add request → return to the 3-part routing above.
>
> **Scope decides the branch, not the phrasing.** A current-state question about **one feature / one config** → the `/inspect` contract above. A "help me understand the whole repo" request on a codebase with **no `docs/CODEBASE_MAP.md` yet** (*"I just inherited this source code, help me see where it stands"*) is **not** an `/inspect` question — that IS Phase A onboarding: answer with the 3-part routing (Mode · flow = Phase A · checklist starting at `/discover`) and **do NOT survey the repo inline**. `/inspect`'s contract is built for a single feature; using it to describe an entire undocumented codebase produces an ad-hoc survey that `/discover` exists to do properly (and that nothing downstream can consume, because it never writes `CODEBASE_MAP.md`).

---

## Project Profile

@.claude/PROJECT_PROFILE.md

> The project's Profile lives in **`.claude/PROJECT_PROFILE.md`** (imported on the line above — its content is loaded into context each session). If the import is unavailable, **read that file at the start of the session**. Schema/template: §Project Mode & Profile. The file belongs to the user — kit upgrades never touch it.

---

## Kit Layering & Local Overrides

The kit layers its content by **owner** so that upgrading the version does not break the repo's customizations:

| Layer | Owner | Content | On kit upgrade |
|------|-----------|----------|-----------------|
| **CORE** | Kit | `commands/`, `agents/`, `rules/` (base + `overrides/` library), `references/`, `templates/`, `skills/`, `scripts/`, `hooks/`, `settings.json`, this `CLAUDE.md` | Replaced per release |
| **CONFIG** | Repo/user | `PROJECT_PROFILE.md`, `settings.local.json` | Never touched |
| **EXTENSION** | Repo/user | `local/` — team/company-specific rules, see [`local/README.md`](local/README.md) | Never touched |

**Precedence on conflict: `local/` > `PROJECT_PROFILE.md` > kit base** — same semantics as `rules/overrides/` (an override records only the differing parts; the base's agnostic principles still apply). At the start of a session, after loading this CLAUDE.md: read `local/CLAUDE.local.md` if it exists — its rules **win** when they collide with the kit base.

- **Repo-specific commands:** place them under `.claude/commands/` with a **dedicated prefix** (e.g. `my-*.md`, `<team>-*.md`) — the kit guarantees it will not ship a command with a colliding prefix; files outside the kit manifest (Phase 2) = user-owned, skipped on upgrade.
- **Must you modify a CORE file?** Three tiers: (1) try an override via `local/` first; (2) if it benefits everyone → send it upstream (a PR to the kit repo); (3) a deliberate fork → **record one line in [`local/KIT_DEVIATIONS.md`](local/KIT_DEVIATIONS.md)** (file · change · reason) so the next upgrade can re-apply it instead of losing it.
- Current kit version: the [`KIT_VERSION`](KIT_VERSION) file.

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
│  │  /spec ────→ /arch ────→ /plan ────→ /secure*                               │  │
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
│  │  security/  docker/     docs/     reports/    STAGED                        │  │
│  │  SCAN_REPORT                      VERIFY_REPORT                              │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                         │
│                                         ▼                                         │
│              [MANUAL — outside kit] human test team on staging                    │
│              → go/no-go → promote production (RUNBOOK §8)                         │
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
| 5 | `/build` | Frontend/Backend Dev | Implement tasks incrementally using TDD and vertical slices | `src/`, `web/`, `tests/` | ❌ Not required |
| 6 | `/test` | Test Engineer | QA verification with real dependencies — the quality gate before review | `tests/` | ✅ Required |
| 7 | `/review` | Code Reviewer | Review a pull request or branch changes using the Five-Axis Framework | `reports/CODE_REVIEW` | — |

> **Testing Strategy:** `/build` uses Unit Tests (Mock) + Integration Tests (In-Memory) — Docker not required. `/test` uses TestContainers + E2E Tests — Docker required. See details in [`.claude/rules/testing.md`](rules/testing.md).

### Phase 3: Security & Deployment

| # | Command | Agent | Purpose | Output |
|---|---------|-------|---------|--------|
| 8 | `/scan` | Security Auditor | Post-development security scanning and vulnerability assessment | `security/SCAN_REPORT` |
| 9 | `/infra` | Backend Developer | Setup Docker infrastructure for local development | `docker/` |
| 10 | `/docs` | Technical Writer | Generate comprehensive project documentation | `docs/` |
| 11 | `/verify`\* | Test Engineer | Post-deploy verification — exercise every feature (acceptance criteria) against the real deployed artifact. **Step optional · BLOCKING if run.** Strongly recommended before `/deploy` stages; required inside `/hotfix` orchestrator | `reports/VERIFY_REPORT` |
| 12 | `/deploy` | Release Manager | Deploy the verified artifact to **STAGING** (Status: `STAGED`) — the kit's last automated step. **Promoting to production = MANUAL**: the human test team checks on staging (script = `VERIFY_MATRIX`) → go/no-go → promote per `DEPLOY_RUNBOOK §8` (keep the digest, no rebuild) | Staging (`STAGED`) |

> **Why `/verify` is strongly recommended (but optional) before `/deploy`:** `/test` runs in a test environment over an in-process transport — it cannot exercise the production-config × real-network × real-client intersection where CORS, security headers, env-gating middleware, TLS, and container-networking bugs live. `/verify` runs the acceptance-criteria suite against the **exact artifact that will ship**. Step is **optional** in the standard pipeline, but **BLOCKING if run** — when `/verify` is executed, `/deploy` may only promote a digest with a passing report. `/verify` remains **required** inside the `/hotfix` orchestrator (Step 4 re-verify on patched digest). See [`.claude/commands/verify.md`](commands/verify.md).

### Supporting Commands

| Command | Purpose |
|---------|---------|
| `/discover` | **Brownfield Phase A** — onboard a legacy repo: survey stack/structure, verify build/run, snapshot health, generate the Project Profile (read-only) |
| `/discover-system` | **Multi-repo** — aggregate per-repo discovery across a workspace into a system-wide map (service catalog, call-graph, cross-service journeys). Read-only, one-way documentation. See [`references/microservices-multirepo.md`](references/microservices-multirepo.md) |
| `/inspect` | **Query current state** — answer a question about a software feature/state via 3 evidence tiers (records → code → live) + mismatch detection. Read-only, no gate. The live tier (`--live`) and saving a report (`--report`) are both opt-in. Free-text current-state questions are also answered per this command's output contract |
| `/debug` | Systematic debugging and error recovery — find root cause, not symptoms |
| `/simplify` | Reduce complexity without changing behavior — code simplification |
| `/fix-issue` | Analyze and fix a reported bug or issue systematically (dev-time → `/review`; if the bug was found by `/verify`/`/hotfix`, the caller re-verifies the patched digest instead) |
| `/hotfix` | Restore a live/released system — triage rollback vs fix-forward, patch, re-verify, redeploy with audit trail (incident-time) |
| `/export-docs` | **Company-doc export** — compile kit artifacts (SPEC / ARCHITECTURE / security / reports) into company-standard documents (e.g. PRD/SDD) via fill-only templates + a mapping manifest in `.claude/local/doc-templates/` (EXTENSION layer). Read-only on sources; outputs `exports/` + a bidirectional ID trace map |

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
│  ✓ (UI) ASCII wireframe + visual sign-off (prototype opt-in)    │
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
│  ✓ Assumptions log reviewed & dispositioned (if any)           │
│                                                                 │
│  GATE 6: /test → /review                                        │
│  ✓ Coverage: line ≥ 80% · branch ≥ 75%                         │
│  ✓ Every 0%-coverage method listed w/ a test or a reason       │
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
│  AFTER /deploy (STAGED) — OUTSIDE THE KIT, MANUAL:              │
│  ✓ Human test team checks on staging (VERIFY_MATRIX = script)   │
│  ✓ QA/UAT lead signs go/no-go (RELEASE_NOTES §5)                │
│  ✓ Promote production per RUNBOOK §8 — KEEP DIGEST, don't       │
│    rebuild; prod smoke; fill in RELEASE_NOTES §6                │
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
| `output-style.md` | **Output clarity (artifacts)** — every artifact reads clearly for its audience: plain-language summary first, jargon defined, decisions & numbers justified, register matched to reader (stakeholder / engineer / operator). Complements § Output Language; applies to all commands/agents. |

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
│   ├── EVIDENCE.md                 # brownfield REVERSE only — engineer-facing US-ID → file:line evidence map
│   ├── user-stories/               # split layout only (> 20 stories / multi-epic)
│   └── wireframes/                 # UI products: README + screens/ + flows/ (+ prototype/ opt-in)
│
├── architecture/                   # /arch output
│   ├── ARCHITECTURE.md
│   ├── adr/
│   ├── diagrams/
│   └── api/
│
├── plans/                          # /plan output
│   ├── sprint-*.md                 # optional — on-request PM aid (PM agent §Delivery tracking), not a /plan gate output
│   ├── plan.md
│   ├── todo.md
│   └── BACKLOG.md                  # out-of-scope findings (§2.5 routing) — NOT a /plan projection; /simplify's inbox
│
├── security/                       # /secure + /scan output
│   ├── THREAT_MODEL.md
│   ├── SECURITY_REQUIREMENTS.md
│   ├── PRE_DEV_REVIEW.md
│   └── SCAN_REPORT.md
│
├── src/                            # /build output — backend (ASP.NET Core / Node)
│
├── web/                            # /build output — frontend (Next.js/React), if any — canonical FE folder
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
│   ├── verify-artifact.lock        # /verify — digest tested == digest promoted
│   ├── incidents/                  # /hotfix — incident notes (INC-<id>.md: timeline, MTTR, prevention)
│   └── inspect/                    # /inspect --report (opt-in) — INSPECT-<slug>.md
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
├── exports/                        # /export-docs output — company-standard renderings (e.g. PRD.md, SDD.md) + TRACE_MAP.md
│
└── .claude/                        # AI Agent Configuration
    ├── agents/
    ├── commands/
    ├── rules/
    ├── skills/
    ├── references/
    ├── templates/                  # fill-only boilerplates: STRIDE/OWASP (/secure,/scan) · TEST_REPORT (/test) · VERIFY_REPORT (/verify) · CODE_REVIEW (/review) · RUNBOOK_RELEASE (/deploy) · wireframes (/spec) · system (/discover-system) · export-docs (/export-docs mapping-manifest schema)
    ├── scripts/                    # scan-all.sh + scanners/ + scan-summarize.py for /scan · export-db-schema.sh for /discover Phase 1b (guided DB-schema export)
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
| `performance-checklist.md` | Core Web Vitals, optimization |
| `accessibility-checklist.md` | WCAG 2.1 AA compliance |
| `ascii-diagram-guide.md` | ASCII diagram standards for architecture docs |
| `code-review-checklist.md` | Five-axis code review framework |
| `deployment-checklist.md` | Pre-deployment verification gates |
| `docker-patterns.md` | Dockerfile and docker-compose best practices |
| `scenario-traceability.md` | Scenario-level traceability rule (`@US-XXX-Snn` → task/test mapping across all gates) |
| `brownfield-pipeline.md` | Brownfield quick lookup — Phase A discovery order + Phase B flows (B1–B5) |
| `microservices-multirepo.md` | Multi-repo quick lookup — per-repo pipeline + one-way system layer (`/discover-system`), backward-compat as cross-service safety |

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
12. **Route ambiguity by type (phase-aware)** — In `/spec`/`/arch`, eliciting and resolving ambiguity IS the job: ask freely, present interpretations. In `/build`/`/fix-issue`: implementation details → decide via rules, never ask; non-blocking behavior gaps → most conservative interpretation + Assumptions log, reviewed as a batch at the gate; blocking behavior gaps → stop and escalate. Approved behavior-changing assumptions flow back into `specs/` (canonical: `rules/principles-and-practices.md` §2.5).
13. **Surgical changes** — every changed line traces to the current request; don't refactor what isn't broken; orphans your change created → remove, pre-existing dead code → report, don't delete; **record every out-of-scope finding where §2.5's routing table says it lands — a finding stated only in chat is not recorded** (canonical: §2.5).
14. **Declare the commit state** — every command either commits the artifacts it produced, or names in its closing summary exactly what it left uncommitted; silence about a dirty working tree is not allowed. Never fold another flow's uncommitted work into your own commit — commit that separately first (titled for *that* flow), or stop and ask when you cannot tell which flow it belongs to. Why: a dirty tree makes `/deploy`'s git tag stop matching the code inside the image, and it lures the next command into merging two logical changes into one commit (canonical: `rules/git-workflow.md` §Commit ownership).

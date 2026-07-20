---
name: discover
description: Onboard a legacy codebase — survey stack/structure, verify build/run, snapshot health, generate the Project Profile
---

# /discover — Legacy Codebase Onboarding

> "Map the territory before you change it."

## Purpose

The first step when taking over a **legacy repo** (brownfield). Survey the system **read-only** to: understand stack & structure, confirm it builds/runs, take a health snapshot, and **generate the `Project Profile`** — the foundation every subsequent command uses to know which mode and which peripheral stack it is operating in.

This is **Phase A** of the brownfield pipeline: `/discover` → `/spec` (reverse) → `/arch` (reverse) → `/infra` (reverse-bootstrap).

> **Multi-repo microservices:** `/discover` is **repo-scoped** — run it (+ the rest of Phase A) **per service repo**. To then understand how the services fit together, run [`/discover-system`](discover-system.md) once over a workspace of all repos (it aggregates each repo's Phase A output, one-way). See [`../references/microservices-multirepo.md`](../references/microservices-multirepo.md).

## When to Use

- Taking over an existing codebase for the first time, with missing docs/spec/tests.
- Before reverse-engineering the spec & architecture.

| Situation | Command |
|-----------|---------|
| Unfamiliar legacy repo, need to understand + establish baseline | **`/discover`** |
| Baseline already exists, continue development | `/spec` (delta) → … |
| Greenfield (building from scratch) | `/spec` (design) — DO NOT use `/discover` |

## Boundary — READ-ONLY

`/discover` **does not modify source code, does not add/upgrade dependencies or install new global tooling, and does not run migrations that write to the DB**. Restoring the project's *already-declared* dependencies to build/test for observation is fine. It only reads, builds/tests to observe, and produces documentation. All code changes belong to flow B.

> Also does NOT do work that belongs to other commands: does not run a full `/scan` (independent, recommended separately), does not run a full `/review` Five-Axis (per-change). `/discover` only takes a **light health snapshot** sufficient to assess initial risk.

---

## Workflow

### Phase 0 — Workspace scope check (multi-repo)

Runs once, BEFORE Phase 1: decide whether this session root is ONE repo (default) or a workspace parent of several repos — never guess silently.

1. **Detect** — trigger when the root Profile already declares `Mode: workspace`, OR the root has no business code of its own AND ≥ 2 direct subfolders are git repos (`.git` present). Signal-based and one-time — later commands read the declaration instead of re-detecting (declare-once, step 3).
2. **Confirm with the user** (never proceed on detection alone): list the candidate repos → ask (a) is this a workspace? (b) which repo(s) to discover now — one, several, or all sequentially? Propose a kebab-case `Service id` per repo (from the folder name) for approval.
3. **Declare** — write/update the root `.claude/PROJECT_PROFILE.md`: `Mode: workspace` + the `Repos:` registry. Adding a repo later → re-run `/discover` to update the registry.
4. **Run per repo** — for each selected repo, run Phases 1–4 below **unchanged**, with ALL outputs written inside that repo (`<repo>/.claude/PROJECT_PROFILE.md`, `<repo>/docs/CODEBASE_MAP.md`). The per-repo Profile carries the approved `Service id`.

Single repo detected (or the user says "not a workspace") → skip; Phases 1–4 run at the session root exactly as before.

### Phase 1 — Stack & structure inventory

- List languages, frameworks, runtime versions (read `*.csproj`, `global.json`, `package.json`, lockfiles).
- Map the structure: number of projects/modules, layering (Clean Architecture? N-tier? monolith?), entry points, main folders.
- Identify peripheral technologies: database engine, cache, message broker, logging/observability backend, auth.
- **Detect DB-resident logic** — scan the tree for database DDL by TWO signals: (a) file type — `*.sql`, `*.sqlproj`, migration/DDL folders; (b) **content** — any file (C#/TS migration, embedded resource, XML…) containing DDL statements (`CREATE|ALTER TABLE`, `CREATE PROCEDURE|PROC`, `CREATE TRIGGER`, `CREATE INDEX`, `CREATE FUNCTION|VIEW`, e.g. `migrationBuilder.Sql("CREATE PROCEDURE …")`). The location is **not fixed** (`db/`, `src/db/`, `backend/db/`, inside migrations…) — detect by signal, not by path. If the app calls stored procedures / triggers / DB functions, these in-repo scripts are the only readable source of that logic. **Never connect to a live database** (not even via a connection string found in config) — the in-repo snapshot is the only evidence source; see the DB-object inventory in Output.

### Phase 2 — Build & run verification

- Run the build (`dotnet build` / `npm run build` …) — record the result, warnings/errors.
- Run the existing test suite if present (`dotnet test` …) — **measure, do not verify**: does the suite pass? how many tests?
- Confirm the app can start (or explicitly record blockers if it cannot).
- **Sanitized startup (brownfield caution):** a legacy app may auto-connect — or auto-migrate (`context.Database.Migrate()`) — against the real DB / Kafka / Redis the moment it boots with its shipped config. Start it with a **sanitized environment** (env-var overrides pointing at throwaway containers, or placeholder connection strings) — never against the real shared infrastructure just to "see it run". Overrides are runtime-only (env vars / an uncommitted local file, removed afterwards) — the repo's config files are NOT edited (read-only guarantee). "Cannot start without real infra" is itself a finding to record, not a reason to point at production.

### Phase 3 — Health snapshot (light — measure, not verify)

Only signals **independent of the spec** (per `rules/brownfield.md` §Measure-vs-Verify):
- Existing coverage (if measurable) — baseline number, no judgment.
- Coarse complexity / hotspots (abnormally large files, high churn if git history exists).
- Obvious security red-flags: hardcoded secrets, clearly outdated dependencies, dangerous patterns (string-concat SQL, no-auth endpoint). **Does not replace `/scan`** — just flag them for `/scan` to dig into later.

### Phase 4 — Generate Project Profile

Generate / update **`.claude/PROJECT_PROFILE.md`** (the CONFIG layer, user-owned — see `CLAUDE.md` §Kit Layering; an old repo layout that does not yet have this file → update the `## Project Profile` block in `CLAUDE.md` as before):

```markdown
## Project Profile
- Mode: brownfield
- Core: <core language/framework from inventory — C#/ASP.NET Core (base), or Node.js → rules/overrides/lang-nodejs.md + framework-nodejs-web.md + test-nodejs.md>
- Database: <engine> → <rules/overrides/* if different from default, or "base database.md">
- Observability: <Serilog/ELK/Grafana…> → <override if needed>
- Structure: <Clean Architecture | N-tier | monolith | …>
- Frontend: <if any>
- Service id: <kebab-case, unique across the workspace — REQUIRED only for multi-repo products (consumed by /discover-system as the canonical key); single-repo → omit>
- Notes: <red-flags, blockers, risk areas>
```

---

## Output

- `.claude/PROJECT_PROFILE.md` (fully filled in) — the **most important artifact**.
- `docs/CODEBASE_MAP.md` — **REQUIRED** (consumed as the navigation index by `/spec` REVERSE and `/arch` reverse, so they do not re-survey the tree). Must contain at minimum:
  - Module / layering summary + entry points.
  - **Endpoint inventory** — a table `route + method → controller/handler → service` covering every externally reachable entry point. This is the skeleton `/spec` REVERSE turns into as-is user stories.
  - **Red-flag list** — the Phase 3 findings with `file:line` locations, so `/spec` REVERSE carries them over as `⚠️ suspicious behavior` instead of re-detecting.
  - **DB-object inventory** (conditional — REQUIRED when Phase 1 detected DDL in the repo OR the code calls DB-resident logic via `EXEC` / `FromSqlRaw` / raw SQL): a table `object (table / proc / trigger / index / function / view) → defining file (actual path — locations vary per repo) → called from (file:line)`. This table is the index `/spec` REVERSE and characterization tests use to reach DB-resident behavior. Any object the code **calls** whose defining DDL is **not** in the repo → add to the red-flag list as `DB-resident logic not in repo` (blind spot; remedy = the user/DBA exports the CREATE script into the repo — the kit never auto-connects to a database to fetch it).
- Health snapshot (build/test status, coverage baseline, red-flags) — input for deciding whether `/scan` is urgently needed.

## Quality Gate — Phase A Kickoff

Run the §Orchestrator disk-check (below) first, then review.

- [ ] `Project Profile` fully filled in: Mode, Core, Database, Observability, Structure
- [ ] `docs/CODEBASE_MAP.md` written, containing the **endpoint inventory** + **red-flag list** (the index `/spec` REVERSE / `/arch` reverse consume)
- [ ] Build status confirmed (pass / fail + reason)
- [ ] Test suite status measured (pass count / coverage or "no tests")
- [ ] Obvious security/technical red-flags listed (for `/scan` to dig into)
- [ ] DDL detected in repo (by file type or content) → **DB-object inventory** present in `CODEBASE_MAP.md`; every code-called DB object missing its defining DDL → listed as `DB-resident logic not in repo` red-flag
- [ ] No code modifications (read-only guarantee)
- [ ] (workspace) Registry in the root Profile matches the actual folders — no unregistered git subfolder, no registry row without a folder
- [ ] (workspace) Every artifact written inside its repo — nothing new at the workspace root except `.claude/` and `architecture/system/`
- [ ] (workspace) `git status` per member repo shows only the expected new files (Profile, CODEBASE_MAP, health snapshot)

### Orchestrator disk-check (run BEFORE presenting the Phase A kickoff)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level:

- [ ] **Read-only guarantee, verified** — `git status`: no tracked file modified; the only additions are `docs/CODEBASE_MAP.md`, `.claude/PROJECT_PROFILE.md`, and the health-snapshot doc (build/test byproducts like `bin/`/`coverage/` are gitignored, not committed). A modified source/config file = the read-only boundary was broken — revert and surface it.
- [ ] **Profile complete** — every field filled (Mode / Core / Database / Observability / Structure — no `<…>` placeholder left).
- [ ] **CODEBASE_MAP sections present** — module summary, the endpoint inventory table, the red-flag list (with `file:line`); DB-object inventory present when Phase 1 detected DDL or `EXEC`/raw-SQL calls.
- [ ] **Build/test status recorded as observed** — the snapshot quotes real command output (exit code, test counts), not a summary adjective.
- [ ] **(workspace) Placement verified** — diff each member repo's `git status` yourself; any artifact at the workspace root that belongs to a repo = placement bug — move it before presenting.

Any mismatch → fix on disk first.

---

## Agent

Invoke: **Systems Architect** (leads the stack & structure survey), preparing to hand off to **Business Analyst** (reverse `/spec`) and back to **Systems Architect** (reverse `/arch`).

**Phase ownership** — the Systems Architect sub-agent cannot converse with the user: when an **existing, user-edited** `PROJECT_PROFILE.md` contradicts what Phase 1 detected (a declared override vs the actual engine, stale Mode, a hand-written Note) → **return early** with the diff instead of overwriting a user-owned CONFIG file (same reconcile discipline as `/spec` Phase 0). The orchestrator confirms with the user, then runs the disk-check and presents the Phase A kickoff in the main loop.

```text
"As Systems Architect, run /discover on this legacy repo and produce the Project Profile.
Output language: Vietnamese for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

- `/spec` (reverse mode) — extract as-is User Stories from code.
- `/arch` (reverse mode) — draw the actual architecture + ADR for decisions already embedded.
- `/infra` (reverse-bootstrap) — document/bootstrap the existing Docker artifacts (or CONFORMANCE-CHECK if they already exist — see `infra.md` §Brownfield Mode).
- `/scan` — recommended (independent) before the first deploy, especially if Phase 3 surfaced red-flags.

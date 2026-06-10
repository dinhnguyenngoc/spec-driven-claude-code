---
name: discover
description: Onboard a legacy codebase — survey stack/structure, verify build/run, snapshot health, generate the Project Profile
---

# /discover — Legacy Codebase Onboarding

> "Map the territory before you change it."

## Purpose

The first step when taking over a **legacy repo** (brownfield). Survey the system **read-only** to: understand stack & structure, confirm it builds/runs, take a health snapshot, and **generate the `Project Profile`** — the foundation every subsequent command uses to know which mode and which peripheral stack it is operating in.

This is **Phase A** of the brownfield pipeline: `/discover` → `/spec` (reverse) → `/arch` (reverse) → `/infra` (reverse-bootstrap).

## When to Use

- Taking over an existing codebase for the first time, with missing docs/spec/tests.
- Before reverse-engineering the spec & architecture.

| Situation | Command |
|-----------|---------|
| Unfamiliar legacy repo, need to understand + establish baseline | **`/discover`** |
| Baseline already exists, continue development | `/spec` (delta) → … |
| Greenfield (building from scratch) | `/spec` (design) — DO NOT use `/discover` |

## Boundary — READ-ONLY

`/discover` **does not modify code, does not install anything, does not run migrations that write to the DB**. It only reads, builds/tests to observe, and produces documentation. All code changes belong to flow B.

> Also does NOT do work that belongs to other commands: does not run a full `/scan` (independent, recommended separately), does not run a full `/review` Five-Axis (per-change). `/discover` only takes a **light health snapshot** sufficient to assess initial risk.

---

## Workflow

### Phase 1 — Stack & structure inventory

- List languages, frameworks, runtime versions (read `*.csproj`, `global.json`, `package.json`, lockfiles).
- Map the structure: number of projects/modules, layering (Clean Architecture? N-tier? monolith?), entry points, main folders.
- Identify peripheral technologies: database engine, cache, message broker, logging/observability backend, auth.

### Phase 2 — Build & run verification

- Run the build (`dotnet build` / `npm run build` …) — record the result, warnings/errors.
- Run the existing test suite if present (`dotnet test` …) — **measure, do not verify**: does the suite pass? how many tests?
- Confirm the app can start (or explicitly record blockers if it cannot).

### Phase 3 — Health snapshot (light — measure, not verify)

Only signals **independent of the spec** (per `rules/brownfield.md` §Measure-vs-Verify):
- Existing coverage (if measurable) — baseline number, no judgment.
- Coarse complexity / hotspots (abnormally large files, high churn if git history exists).
- Obvious security red-flags: hardcoded secrets, clearly outdated dependencies, dangerous patterns (string-concat SQL, no-auth endpoint). **Does not replace `/scan`** — just flag them for `/scan` to dig into later.

### Phase 4 — Generate Project Profile

Generate / update the `## Project Profile` section in `CLAUDE.md`:

```markdown
## Project Profile
- Mode: brownfield
- Core: <core language/framework from inventory — C#/ASP.NET Core (base), or Node.js → rules/overrides/lang-nodejs.md + framework-nodejs-web.md + test-nodejs.md>
- Database: <engine> → <rules/overrides/* if different from default, or "base database.md">
- Observability: <Serilog/ELK/Grafana…> → <override if needed>
- Structure: <Clean Architecture | N-tier | monolith | …>
- Frontend: <if any>
- Notes: <red-flags, blockers, risk areas>
```

---

## Output

- `## Project Profile` in `CLAUDE.md` (fully filled in) — the **most important artifact**.
- Codebase map (structure summary + entry points) — may be written to `docs/CODEBASE_MAP.md` or included in the report.
- Health snapshot (build/test status, coverage baseline, red-flags) — input for deciding whether `/scan` is urgently needed.

## Quality Gate — Phase A Kickoff

- [ ] `Project Profile` fully filled in: Mode, Core, Database, Observability, Structure
- [ ] Build status confirmed (pass / fail + reason)
- [ ] Test suite status measured (pass count / coverage or "no tests")
- [ ] Obvious security/technical red-flags listed (for `/scan` to dig into)
- [ ] No code modifications (read-only guarantee)

---

## Agent

Invoke: **Systems Architect** (leads the stack & structure survey), preparing to hand off to **Business Analyst** (reverse `/spec`) and back to **Systems Architect** (reverse `/arch`).

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

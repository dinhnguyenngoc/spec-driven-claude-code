# Brownfield Pipeline — Quick Reference

> **Summary:** This is a **quick-lookup table for "which command to run for this task, and in what order"** when working on a project that already has code (*brownfield*). There is **one onboarding pass** (Phase A) and **5 recurring work flows** (Phase B). Intended for pipeline operators — just find your situation in the [Decision Tree](#decision-tree) and follow the command checklist for the corresponding flow.
>
> Detailed discipline (why it must be done this way): [`../rules/brownfield.md`](../rules/brownfield.md) · Mode/Profile declaration: [`../PROJECT_PROFILE.md`](../PROJECT_PROFILE.md) (schema: [`../CLAUDE.md`](../CLAUDE.md) §Project Mode & Profile).

---

## Quick glossary (read once to understand the whole file)

| Term | Short definition |
|-----------|-----------|
| **Brownfield** | Working on a codebase that **already exists / is running in production** (as opposed to *greenfield* = building from scratch). |
| **Legacy code** | Code that is running but **lacks tests / spec / documentation** describing its intent → the biggest risk is "accidentally breaking something that is running". |
| **Phase A (discovery)** | The stage that **onboards a legacy repo — done ONCE**, read-only on the code, to build the baseline documentation. A **kit-built project after its first release** skips it: `/discover` runs the inventory-only §Graduation run instead (the forward pipeline already produced the baseline — never reverse over it). |
| **Phase B** | The **recurring work flows** after onboarding (add/modify features, fix bugs, hotfix, upgrade). |
| **delta** | **Only the changed part** (a new feature or the modified portion) — not the whole system. |
| **reverse** (mode of `/spec`, `/arch`) | Runs "in reverse": generates spec/architecture **from existing code**, instead of generating code from a spec. |
| **conformance-gate** (mode of `/arch`) | `/arch` only **checks whether the change conforms to the current architecture** — by default it does not change the architecture. |
| **characterization test** | A test that **captures the behavior of the code *as it currently runs*** (PASS right away) — a regression net set up *before* making changes. |
| **backward-compat** | **Do not break** the API / contract / data / schema that current clients and data rely on. |
| **strangler-fig** | Replace **gradually**: stand up the new implementation in parallel behind an abstraction layer, migrate over progressively — **do not rewrite in one shot** (big-bang). |
| **ADR** | *Architecture Decision Record* — a record of an architectural decision (context, options, consequences). |

---

## Memory aid — 1 spine + 5 entries

The three development flows (B1/B2/B5) **share a common "spine"** at the end — they differ only in the *entry point*:

```
/build → /test → /review → /verify → /deploy
```

→ Memorize the spine once, then you only need to remember the **entry point** of each flow.

---

## Decision Tree

| Situation | Flow |
|-----------|-------|
| Receiving a legacy repo for the first time | **Phase A** |
| Adding a NEW feature | **B1** |
| Modifying an EXISTING feature | **B2** |
| Bug found during dev (not yet released) | **B3** |
| Error on LIVE production | **B4** |
| Changing / upgrading architecture / technology | **B5** |
| Upgrading a dependency/runtime (.NET bump, CVE patch) — behavior unchanged | **B5-lite** — lightweight ADR, no strangler-fig needed; **full regression mandatory** (blast radius = the whole app) |
| Paying down technical debt / refactoring without changing behavior | **`/simplify`** (separate channel — characterization test as the "behavior unchanged" net) |
| Removing / deprecating a feature | **B2 + ADR** (breaking by design — deprecation window + migration path, per backward-compat rule) |

---

## Phase A — Discovery (ONCE when receiving the repo, READ-ONLY on source)

> **Purpose:** onboard an unfamiliar repo — survey the stack/structure, confirm it builds/runs, and build the baseline documentation (spec + architecture + infra) that matches the actual code. Done **once**, **without modifying business code**.

```
/discover  →  /spec (reverse)  →  /arch (reverse)  →  /infra (reverse-bootstrap)
              [/scan recommended, independent — before the first deploy]
```

**Output:**
- `Project Profile` (mode + DB + observability + structure) in [`.claude/PROJECT_PROFILE.md`](../PROJECT_PROFILE.md)
- `docs/CODEBASE_MAP.md` (endpoint inventory + red-flag list) — `/spec` reverse and `/arch` reverse **consume it as a table of contents**, without re-scanning the tree
- `specs/SPEC.md` baseline (as-is user stories)
- `architecture/` baseline (real architecture + inferred ADRs)
- `docker/Dockerfile` + `docker-compose.yml` + `.dockerignore` + `.env.example` (infra matching the actual code, runnable locally)

**Boundary:** read-only on `src/`/`web/` source code. Phase A may create new files in `docker/`, `specs/`, `architecture/`, `docs/` (documentation/setup artifacts, not business logic code). Any change to **business code** belongs to Phase B.

**Why `/verify` and `/deploy` are NOT part of Phase A:**
- `/verify` and `/deploy` are **execution commands** — they touch runtime state (test the real artifact, promote to production), they do not produce baseline documentation.
- A brownfield project by definition **already has a running production** — it does not need a "first deploy" like greenfield. A new production deploy = touching production state → belongs to Phase B per-change.
- `/infra` REVERSE-BOOTSTRAP is **enough** to spin up a local dev environment (`docker compose up -d`); no `/deploy` is needed to "see the app run".

---

## Phase B — 5 flows

### B1 — NEW feature on legacy

```
/spec(delta) → /arch(conformance) → /plan → [/secure] → /build → /test → /review → [/scan] → /verify → /deploy
```

**Must remember:**
- `/spec(delta)`: specify only the new feature, reference existing stories — do NOT rewrite.
- `/arch(conformance)`: by default a **no-op** (no architecture change); a lightweight ADR only if there is a small new decision.
- `/build`: normal TDD (new code); characterization test **only when** touching untested legacy areas.
- A new feature that opens an **external surface** (payment, SSO, webhook, URL-fetch) → **should run `/secure`** — the new surface is exactly a candidate for the "Highest-Risk Active Surface" (Phase 3.5). `/secure` runs **delta-scoped**: model only the new/changed surface, cite the existing control baseline, assert it does not regress the prior posture (see `commands/secure.md` §Brownfield Mode).

### B2 — Modify an EXISTING feature

```
[characterization test FIRST]  →  /spec(delta) → /arch(conformance) → /plan → /build → /test(backward-compat) → /review → /verify → /deploy
```

**Must remember (different from B1):**
- **Mandatory**: before touching the code, write a **characterization test** capturing the current behavior of the area about to be modified, and make it **PASS** — this is the net that distinguishes intentional changes from unintentional regressions. (This step lives *inside* `/build`, done by the agent — it is not a separate command you type.)
- `/test`: add backward-compat tests — the existing contract / data / API do not change.

### B3 — Fix bug (dev-time, not yet released)

```
/fix-issue → /test → /review → /verify → /deploy
```

**Must remember:**
- Skip `/spec`/`/arch`/`/plan` — there is no new business requirement.
- `/fix-issue`: reproduce → regression test (fails before the fix) → root cause → fix.

### B4 — Hotfix (LIVE production)

```
/hotfix  →  [Triage: rollback?]
         →  /fix-issue (root cause + regression test + fix)
         →  patch version + CHANGELOG + RELEASE_NOTES
         →  /verify (new digest — proves the patch on the real artifact)
         →  /deploy (rollback-ready)
         →  post-incident (runbook + permanent prevention test)
```

**Must remember:**
- `/hotfix` is a **thin orchestrator** — first question: rollback or fix-forward.
- The patch must have its own version + audit trail; re-verify on the new digest before redeploy.

### B5 — Architecture / technology upgrade

```
/arch(REDESIGN: proposal + ADR + migration + v2-trigger)
   → /plan(strangler-fig)
   → [/secure]
   → /build(incremental, feature-flag, backward-compat)
   → /test → /review → /scan → /verify → /deploy
```

**Must remember:**
- **The only time `/arch` may proactively change the architecture** — an ADR is mandatory (supersede the old ADR if needed) + a migration plan.
- Strangler-fig: no big-bang rewrite — stand up in parallel behind an abstraction, feature-flag, expand gradually.
- Backward-compat throughout the migration.
- Examples: adding a Redis cache, migrating Oracle→PostgreSQL, switching Serilog-file → ELK (update the Project Profile + active override).

---

## `/arch` role by flow — quick lookup

| Flow | Mode | Default |
|-------|------|----------|
| Phase A | **reverse** | describe as-is + inferred ADRs |
| B1 (new), B2 (modify) | **conformance-gate** | keep the architecture unchanged; ADR only when there is a small new decision |
| B5 (upgrade) | **redesign** | controlled change + ADR (supersede) + migration |

---

## 2 brownfield disciplines across ALL B flows

1. **Characterization test before modifying** untested legacy code (especially B2) — capture the current behavior as a regression net.
2. **Backward-compat by default** — do not break the running API/contract/data/schema (breaking it → an ADR + migration is mandatory).

---

## Scope per-change — WRITE per delta, RUN everything

> **Answers the question:** *"Do `/test`, `/review`, `/verify` run on the whole source or only the changed part?"* — The key distinction: **WRITING new (expensive) is done only for the changed part; while RUNNING (cheap) runs everything** to prove the unchanged part remains intact. Underlying principle: [`../rules/brownfield.md`](../rules/brownfield.md) §Upfront-vs-Per-change.

| Command | WRITE new — ONLY the changed part | RUN — ALL of what is already automated |
|------|------------------------------|----------------------------------------|
| `/test` | Tests for the delta + characterization of the touched area + backward-compat tests for the adjacent contract | **The entire existing suite** — the existing suite staying green is what proves "the unchanged part is unaffected" |
| `/review` | — | **Only the diff/slice of the change** (Five-Axis on the modified part; the Architecture axis checks conformance against the baseline — do NOT re-review the whole repo) |
| `/verify` | Verify tests for the changed/added scenarios (update the delta part of VERIFY_MATRIX) | **The entire verify suite** (including the zero-seed golden journey — the cheapest system-level net). The only exception: **B4 hotfix** = scoped minimum (liveness + contract of the bug area + scenarios of the related story + a test reproducing the incident) |

> The net grows with each B iteration: the first iteration after Phase A builds the suite (prioritizing the golden journey + the areas about to be touched), later iterations only add the delta. Do NOT retrofit all tests upfront.

---

## Command → command-file mapping

| Command | File |
|------|------|
| `/discover` | [`../commands/discover.md`](../commands/discover.md) |
| `/spec` (reverse + delta) | [`../commands/spec.md`](../commands/spec.md) §Brownfield Mode |
| `/arch` (reverse + conformance + redesign) | [`../commands/arch.md`](../commands/arch.md) §Brownfield Mode |
| `/infra` (reverse-bootstrap + conformance-check) | [`../commands/infra.md`](../commands/infra.md) §Brownfield Mode |
| `/plan` (migration-aware) | [`../commands/plan.md`](../commands/plan.md) §Brownfield Mode |
| `/fix-issue` | [`../commands/fix-issue.md`](../commands/fix-issue.md) |
| `/hotfix` | [`../commands/hotfix.md`](../commands/hotfix.md) |
| `/verify` | [`../commands/verify.md`](../commands/verify.md) — Gate 11 **step optional · BLOCKING if run** (REQUIRED inside `/hotfix`) |
| Spine: `/build`, `/test`, `/review`, `/scan`, `/deploy` | shared across greenfield + brownfield |

# Scenario Traceability — Single Source of Truth

> Canonical rule for **scenario-level traceability** across the SDLC pipeline. Referenced by `/spec`, `/plan`, `/build`, `/test`, `/review`, `/verify`. When this rule changes, change it **here** — the commands only link to it; they must not restate it in full.

## The Rule (5 clauses)

### 1. Stable IDs

Every Gherkin scenario in the spec carries a stable tag — `@US-[ID]-S01` (happy path), `-S02…` (each edge/failure case). IDs never change once assigned; new scenarios get new IDs. IDs are identical across monolithic (`specs/SPEC.md`) and split (`specs/user-stories/US-*.md`) layouts.

### 2. Canonical acceptance checklist

The full set of `@US-XXX-Snn` IDs **is** the acceptance checklist of the feature. Every downstream gate reconciles against it:

| Command | Reconciliation duty |
|---------|---------------------|
| `/spec` | Assigns the IDs; every scenario has a concrete, assertable observable outcome (*Then*) |
| `/plan` | Every ID appears under some task's **Scenarios covered** — or in the Deferred/Waived table |
| `/build` | Implements per task; a task is done only when its scenarios' tests exist and pass |
| `/test` | Every ID has ≥ 1 test asserting that scenario's observable *Then* |
| `/review` | Audits the mapping: every ID → a **wired** path + an effect-asserting test (anti-vacuous) |
| `/verify` | Black-box gate: any ID without a mapped verify test → gate **FAIL** |

### 3. Effect, not presence

A scenario's test must assert the **observable *Then*** — the effect / state change, surviving a round-trip (reload / re-fetch) — not merely that an endpoint/class exists or returns `200 OK`. A test that would still pass if the feature were silently removed does **NOT** satisfy the scenario. **One scenario : its own test** — never conflate two scenarios into one test (e.g. a "favorite filter" test does not cover the "click-favorite-to-mark" action).

### 4. UI-observable needs UI-layer proof

A scenario whose *Then* is user-observable in the UI requires a **UI / E2E-layer** test; an API-layer test alone proves the endpoint, not that the user can reach the behaviour. If deep UI E2E is deferred to `/verify`, record the gap explicitly (TEST_REPORT §9) — never count it as covered.

### 5. No silent drops

Every ID maps to a task/test **or** sits in a **Deferred/Waived table with reason + owner**. A scenario that simply disappears between two phases is a gate failure — at whichever gate first fails to account for it.

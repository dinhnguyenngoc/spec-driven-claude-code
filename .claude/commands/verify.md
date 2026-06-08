---
name: verify
description: Post-deploy verification — exercise every feature against the real deployed artifact before promotion
---

# /verify — Post-Deploy Real-Environment Verification

> "Test what you ship, not a proxy of it."

## Purpose

> **Status: step optional · BLOCKING if run.** Strongly recommended before `/deploy` to production, especially for brownfield (missing legacy test suite) or releases with infra/config changes. **Required** when called from the `/hotfix` orchestrator (Step 4 re-verify on the patched digest).

Verifies **every user-observable feature** works correctly on **the exact artifact about to be promoted** (correct image/build, production config, over real network) — before `/deploy` declares `SUCCEEDED`.

`/verify` closes the **fidelity gap** that earlier test layers cannot touch: `/build` (in-memory) and `/test` (TestContainers + in-process host) both run in a test-environment via in-process transport. A class of bugs only surfaces at **(production environment) × (real network) × (real client)**: CORS, security headers, env-gating middleware, TLS, reverse-proxy headers, container networking, env-var injection, build-time config baking. `/verify` is the only layer that exercises that intersection.

## Scope Clarification

| Command | Responsibility |
|---------|----------------|
| `/test` | **Pre-deploy QA** — unit, integration (real deps via TestContainers), contract tests in-process |
| `/infra` | **Setup** — Dockerfile, compose, env config |
| `/verify` | **Prove on real artifact** — run feature suite against the deployed stack; gate promotion. **Step optional · BLOCKING if run** (REQUIRED inside `/hotfix`) |
| `/deploy` | **Promote** — if `/verify` was run, ship only a build with a passing report for that exact digest |

## Core Principle — Completeness = covering acceptance criteria, NOT covering unit tests

`/verify` does NOT re-run the full unit/integration suite (wrong layer, slow, pointless). It runs a **black-box test set anchored to the spec's acceptance criteria**:

> The Gherkin scenarios (happy + edge) in `specs/SPEC.md` / `specs/user-stories/*` **are** the definition of "every feature must work in production". 100% scenario coverage = full feature coverage.

Completeness is **machine-enforced** in Phase 5: any scenario without a mapped verify test → gate FAIL.

## Prerequisites

**Required:**
- Infrastructure ready (`/infra` done — Dockerfile/compose, app starts up `healthy`)
- A spec with acceptance criteria (`specs/SPEC.md`) — the source of truth for completeness
- The candidate artifact buildable & taggable (image digest or build hash uniquely identifying it)

**Optional (if available):**
- API/contract spec (`architecture/api/openapi.yaml` or equivalent) — to generate contract checks
- Test report (`reports/TEST_REPORT.md`) — to know which debt is still open from `/test`

---

## Workflow — 6 Phases

### Phase 0 — Pre-flight: artifact lock

Ensure we are testing **exactly what will ship**, not a different rebuild.

```bash
# 1. Stack runs the correct candidate tag/digest and all services are healthy
#    (specific commands depend on the orchestrator: docker compose / k8s / nomad / bare process)
<bring up the EXACT candidate build>

# 2. Record the digest/hash of the artifact under test → lock its identity
<record image digest / build hash> > reports/verify-artifact.lock

# 3. Assert production config (NOT dev/test)
<assert APP_ENV / ASPNETCORE_ENVIRONMENT / NODE_ENV == production>
```

> **Invariant rule:** `/deploy` may only promote a digest **with a PASSing verify report matching that digest**. `/verify` and `/deploy` must use the **same digest** — if `/deploy` rebuilds after verify, the lock is broken and the verdict is void.

### Phase 1 — Liveness smoke (fail-fast)

If this phase fails → stop immediately, do not proceed (avoid wasting time running the suite against a dead stack).

- Health endpoint returns OK status over the real network.
- Every frontend/entrypoint returns 2xx at root.
- A call that touches the real datastore (e.g., create an entity and read it back) — proves migration/schema is ready, not just that the process is alive.

### Phase 2 — API / Contract suite (black-box, over real transport)

Run the contract test set against the **real base URL** of the artifact (not an in-process host). Cover **every endpoint × every status code** the API contract promises:

- Happy path: every resource × {create, read, update, delete, list}.
- Error contract: 400 / 401 / 403 / 404 / 409 / 422 / 429 in the correct standard format (e.g., RFC 7807 ProblemDetails) + correlation id.
- **Cross-origin preflight** (`OPTIONS` + `Origin` header) for every state-writing route — covers the CORS bug class.
- **Response headers** on every response (including 4xx/5xx): security headers, cache-control, correlation id.
- **Env-gating**: dev-only resources (API docs UI, debug/diagnostics endpoint, verbose stack trace) are **not** exposed in production.
- Rate limiting / throttling actually triggers at the correct thresholds.

> **"Dual-mode contract test" pattern (strongly recommended):** Write the contract test once, parameterize the base URL via env var. Unset → in-process host (runs in `/test`, fast). Set `VERIFY_BASE_URL=<real>` → calls the real artifact over the network (runs in `/verify`, high fidelity). **Same assertions, two transports, one source — no duplication.** Constraint that comes with it: tests must seed/teardown data **only through the public API** (black-box), because against a real artifact you cannot touch internal state.

### Phase 3 — End-to-end suite (real client, real artifact)

Run E2E via a **real client** (browser for web, real SDK/HTTP client for service/API-only) against the deployed artifact. Each **user story** → one complete journey:

- Cover integration across tiers (frontend ↔ backend ↔ datastore) as the end user experiences it.
- Cover behavior only a real client exposes: cross-origin enforcement, auth token storage/refresh, redirect, optimistic update + rollback, modal/focus, responsive breakpoints.
- Mandatory for products with a UI; for API-only products, Phase 2 is already E2E.

**E2E assertion contract (mandatory per journey).** A journey is PASS only when all four hold — this is what separates "the page rendered" from "the feature works":
1. **`Given` may be seeded via API; `When` must always go through the UI.** Build *preconditions* (the scenario's `Given` — accounts, existing records, bulk data, states the UI cannot produce such as another user's data / expired token / soft-deleted row) via API for speed and reachability. But the **action under test** (the scenario's `When`) MUST traverse the real control → client → transport → server path — **never** simulate it with an API/DB call (e.g. setting `favorite` via `PATCH` instead of clicking the star). Simulating the `When` = verifying nothing.
2. **No conditional interaction.** If the control is absent, the test FAILS — never `if (control.exists) act()`. Use exact, unambiguous selectors (role / accessible-name), not broad patterns that can match a sibling.
3. **Assert the effect, then prove persistence with a round-trip.** After acting, reload (or re-fetch via a fresh client) and assert the new state survived. The round-trip wipes optimistic / in-memory state, so only server-persisted state passes — this catches silent write-failures (wrong method/status, dropped input, unwired handler).
4. **Network tripwire.** Fail the journey if any same-origin API call returns ≥ 400 during a happy path.

**One zero-seed golden journey (mandatory for products with a UI).** Beyond the focused (seeded-precondition) journeys above, include **at least one end-to-end journey that uses NO API seeding** — every step performed through the real UI, chaining the product's core lifecycle (e.g. sign-up → create → tag → favorite → search → edit → delete), asserting persistence after each state change and surviving a final reload. This is the highest-fidelity guard: it drives **every write through its real control in sequence**, so it catches unwired handlers and client↔API method drift that per-feature seeded tests can hide. Keep it to **one happy lifecycle** (breadth + edge cases stay in the seeded journeys). If an external limit genuinely blocks a pure-UI chain (e.g. an auth rate-limit), document the minimal seed used and why — the *actions* still go through the UI.

Capture artifacts on failure: screenshot / video / trace / request log → `reports/` so debugging does not require reproduction.

### Phase 4 — NFR verification (measured on the real artifact)

Verify the measurable NFRs in `specs/SPEC.md`:

- **Performance**: P95/P99 latency below the spec threshold, measured over the real network (e.g., k6, autocannon, wrk).
- **Accessibility** (if UI exists): automated scan (e.g., axe-core) reaches the spec-required level (WCAG A/AA…), 0 critical violations.
- **Resilience**: graceful degradation when a dependency is slow/fails (if the spec requires it).
- Other NFRs in the spec that can be measured at runtime.

> NFRs that require truly high load (soak, stress, spike) can be split into a separate sub-phase if infrastructure permits; at minimum, verify the P95 threshold under normal load.

### Phase 5 — Traceability gate (mechanism that guarantees "full feature coverage")

This is the **heart** of `/verify`. Automatically cross-checks:

```
For EVERY scenario ID in specs/SPEC.md (the @US-XXX-Snn tags; and specs/user-stories/*):
  there must exist ≥ 1 verify test mapped to that scenario ID, at the REQUIRED LAYER:
    - a UI-observable scenario  → an E2E-UI test (Phase 3) meeting the E2E assertion contract
    - an API-only / headless one → a Phase-2 contract test
Any missing scenario, OR a UI scenario satisfied only by an API-layer test → print it → GATE FAIL (exit non-zero).
```

Recommendation: tag each verify test with the **scenario ID** (`@US-001-S01`, `[Trait("Scenario","US-001-S01")]`, `test.describe("US-001-S01 ...")` …) so the coverage script can parse it. Output to `reports/VERIFY_MATRIX.md` — note the **Layer** column, which is what stops an API test from masquerading as UI coverage:

| Scenario ID | Acceptance scenario | Verify test id | Layer | Phase | Result |
|-------------|---------------------|----------------|-------|-------|--------|
| US-001-S01 | happy path | `@US-001-S01` | E2E-UI | 3 | PASS |
| US-001-S02 | edge/failure | `@US-001-S02` | API | 2 | PASS |
| … | … | … | … | … | … |

> **Layer rule:** for a product with a UI, a **user-observable** scenario is satisfied only by an **E2E-UI** test (Phase 3) meeting the E2E assertion contract above — a Phase-2 API test alone does NOT satisfy it (it proves the endpoint, not that the user can reach the behaviour). API-only / headless products: Phase-2 contract tests satisfy.

**0 missing rows AND no UI scenario covered only at the API layer = no feature left unverified.** This gate is independent of whether optional gates (`/secure`, `/scan`, `/review`) are skipped — the feature-behavior net stays intact.

### Phase 6 — Report + artifacts

Generate `reports/VERIFY_REPORT.md` (see structure below) + attach the run output using the **canonical artifact layout** below. The three top-level deliverables live **directly under `reports/`** and never move:
- `reports/VERIFY_REPORT.md` — human-readable gate report (tracked).
- `reports/VERIFY_MATRIX.md` — the scenario → test traceability table (tracked).
- `reports/verify-artifact.lock` — the tested digest/hash (tracked).

Everything the test runner generates goes under **one fixed directory** so the structure is reproducible across runs, agents, and machines — never an agent-chosen ad-hoc path:

```
reports/
├── VERIFY_REPORT.md            # tracked — gate verdict (Phase 6)
├── VERIFY_MATRIX.md            # tracked — scenario→test traceability (Phase 5)
├── verify-artifact.lock        # tracked — tested digest == promoted digest (Phase 0)
└── verify-artifacts/           # ALL run-generated output (one fixed root)
    ├── report/                 # machine-readable results: results.json (tracked) + html report (ignored)
    ├── runner/                 # per-test trace / video / screenshot — retain-on-failure (ignored, heavy)
    └── evidence/               # hand-authored failure evidence + Phase-3 summary (tracked, text only)
```

#### Determinism rules (the layout is reproducible, NOT agent-dependent)

1. **Commit the path in the runner config — never pass it ad-hoc on the CLI.** Set the runner's output directory + reporters to the fixed paths above in the project's committed test config (e.g. Playwright `outputDir: ".../reports/verify-artifacts/runner"` + `reporter: [["list"], ["html", {outputFolder: ".../verify-artifacts/report", open: "never"}], ["json", {outputFile: ".../verify-artifacts/report/results.json"}]]`; xUnit/pytest: the equivalent results-dir setting). A `--output` / `--results-dir` flag typed by an agent at runtime is **not** reproducible and is disallowed as the source of truth.
2. **Let the runner clean its output dir each run.** Playwright clears `outputDir` on start by default → stale artifacts from a previous (e.g. FAILED) run never bleed into the next verdict. If the runner does not auto-clean, the agent MUST `rm -rf reports/verify-artifacts/runner reports/verify-artifacts/report` before the run.
3. **Capture policy = `retain-on-failure`** (default): `trace` / `video` / `screenshot` kept **only for failing tests**. A fully-passing run leaves `runner/` empty and produces only `report/` + a Phase-3 summary in `evidence/`. A project needing always-on audit evidence may override to `trace: "on"` / `video: "on"` and MUST record that choice in `VERIFY_REPORT §3`.
4. **Gitignore the heavy binaries, track the text.** `.gitignore` ignores `reports/verify-artifacts/**` with negations for the durable text: `!reports/verify-artifacts/report/results.json`, `!.../evidence/**` (and `!.../evidence/`, `!.../report/` for the parent dirs). The three top-level deliverables stay tracked regardless.

> **API-only / headless product** (no browser E2E): `runner/` is absent; `report/` (contract-test results) + `evidence/` still apply. The layout degrades cleanly — never invent a browser-artifact dir for a product without a UI.

---

## Output — `reports/VERIFY_REPORT.md` (MANDATORY)

```markdown
# Verify Report — <product> <candidate-tag>

- **Artifact digest(s)**: <locked from Phase 0 — must match the digest /deploy will promote>
- **Environment**: production-config, real network
- **Date**: YYYY-MM-DD

## 1. Summary
| Phase | Suite | Pass / Total | Verdict |
|-------|-------|--------------|---------|
| 1 | Liveness | … | … |
| 2 | API contract | … | … |
| 3 | E2E | … | … |
| 4 | NFR | … | … |

**Gate verdict**: SUCCEEDED / PASS WITH CONDITIONS / FAILED.

## 2. Traceability matrix
Link to `reports/VERIFY_MATRIX.md`. Assert coverage = 100% acceptance scenarios, or list waived scenarios (with reason + approver).

## 3. Failures & evidence
Each failure: test id → US-XXX → symptom → artifact path → suspected root cause.
(`/verify` is read-only on production code — fixes belong to `/fix-issue` or `/hotfix`.)

## 4. NFR results
Actual measurements vs spec thresholds (latency, a11y, …).

## 5. Gate decision
SUCCEEDED ⟺ Phase 1-5 PASS + 100% coverage. Otherwise, name the blocker + recommendation (rollback / hotfix / waiver).
```

---

## Quality Gate 11 — step optional · BLOCKING if run (gate before `/deploy`)

> When the pipeline **does not** run `/verify`, Gate 11 does not apply and `/deploy` proceeds with its own precondition. When `/verify` is run (recommended for production promote, **required for `/hotfix`**), every checklist below becomes BLOCKING — fail = Gate 11 not passed.

`/deploy` may only promote when:

- [ ] **Artifact lock**: tested digest matches the digest to promote (no rebuild between verify and deploy)
- [ ] **Phase 1 liveness** PASS
- [ ] **Phase 2 API contract** PASS — including cross-origin preflight + security headers + env-gating + error contract
- [ ] **Phase 3 E2E** PASS — every user story journey (mandatory if a UI exists), each meeting the **E2E assertion contract** (`When` via real control, never simulated · no conditional skip · effect asserted after a reload round-trip · network tripwire)
- [ ] **≥ 1 zero-seed golden journey** PASS (UI-only, no API seeding, core lifecycle chained with persistence asserted per step) — if a UI exists
- [ ] **Phase 4 NFR** meets measurable spec thresholds
- [ ] **Phase 5 traceability** — 100% scenario IDs have a verify test **at the required Layer** (UI-observable → E2E-UI, not an API test alone); missing/wrong-layer → signed-off waiver, or FAIL
- [ ] `reports/VERIFY_REPORT.md` + `VERIFY_MATRIX.md` + `verify-artifact.lock` produced
- [ ] Failure artifacts captured for every failing test

**Verdict:**
- `SUCCEEDED` ⟺ all items above ✓.
- `PASS WITH CONDITIONS` ⟺ only non-critical failures with explicitly documented waivers → block promotion until closed.
- `FAILED` ⟺ critical failure or uncovered scenario → do NOT promote; rollback (if a previous version is running) + re-verify after fix.

---

## Boundary rule

`/verify` is **read-only on production code** (same as `/test`). Bugs found are filed with evidence in §3; the fix belongs to `/fix-issue` (or `/hotfix` for post-release defects). This keeps the verify suite a trustworthy regression net — it is written against an unchanged artifact.

---

## Honest limits — what `/verify` guarantees

**Guarantees** (≈ "no remaining feature/integration/deployment defect at promotion"): every user-observable feature, every cross-tier integration, CORS/headers/error-contract/env-gating, every acceptance criterion — on the exact artifact that will ship.

**Does NOT guarantee** (other layers needed): rare concurrency races & high load (→ soak/stress test), deep security vulnerabilities (→ `/scan` DAST/pentest), time-based defects & data drift (→ observability + alerting + canary in production). `/verify` eliminates nearly all escaped feature/deployment defects; the remainder is covered by monitoring + fast-rollback, not by testing.

---

## Agent

Invoke: **Test Engineer** (owns verification suite design + execution + gate), collaborating with **Release Manager** (owns artifact identity / tag / promotion decision).

```
"As Test Engineer, run /verify against the deployed candidate and gate promotion on full acceptance-criteria coverage."
```

## Next Step

- `SUCCEEDED` → `/deploy` promotes the verified digest.
- `FAILED` / `PASS WITH CONDITIONS` → `/fix-issue` (or `/hotfix`) the root cause, rebuild, re-run `/verify` from Phase 0.

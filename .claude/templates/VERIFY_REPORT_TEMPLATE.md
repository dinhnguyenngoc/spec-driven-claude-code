# VERIFY_REPORT + VERIFY_MATRIX Template — `/verify` Output Boilerplate

> **Purpose:** Fixed framework for the 2 tracked `/verify` artifacts. The agent **only fills** placeholders — does NOT re-author the structure.
>
> Detailed rules (artifact lock, traceability gate, Layer rule): [`../commands/verify.md`](../commands/verify.md).

---

## §A. `reports/VERIFY_REPORT.md` skeleton

````markdown
# Verify Report — <product> <candidate-tag>

- **Artifact digest(s)**: <locked from Phase 0 — must match the digest /deploy will promote>
- **Environment**: staging config (the env `/deploy` stages — per Phase 0), real network
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
Each failure: test id → US-XXX → input/data that triggered it → expected → actual → symptom → artifact path (screenshot/trace) → suspected root cause.
(`/verify` is read-only on production code — fixes belong to `/fix-issue` or `/hotfix`.)

## 4. NFR results
One row per NFR in `specs/SPEC.md §NFR`, keyed by its `NFR-xx` id — none omitted (the id is the join key the Gate-11 set-check diffs on).

| NFR | Target (spec) | Measured | Status |
|-----|---------------|----------|--------|
| NFR-01 · <P95 latency> | <threshold> | <value> | measured · not-runtime-measurable (verified at <gate>) · waived (<owner> — <reason>) |

## 5. Gate decision
SUCCEEDED ⟺ Phase 1-5 PASS + 100% coverage. Otherwise, name the blocker + recommendation (rollback / hotfix / waiver).
````

## §B. `reports/VERIFY_MATRIX.md` skeleton

> The **Layer** column is the safeguard against "an API test masquerading as UI coverage" — Layer rule: a UI-observable scenario can only be satisfied by an E2E-UI test (Phase 3) that meets the E2E assertion contract.

````markdown
# Verify Matrix — <product> <candidate-tag>

| Scenario ID | Acceptance scenario | Verify test id | Layer | Phase | Result |
|-------------|---------------------|----------------|-------|-------|--------|
| US-001-S01 | [happy path] | `@US-001-S01` | E2E-UI | 3 | PASS |
| US-001-S02 | [edge/failure] | `@US-001-S02` | API | 2 | PASS |
| … | … | … | … | … | … |

**Coverage**: NN/NN scenarios mapped (100%) — [or list waived scenarios with reason + approver]. [Brownfield per-change: NN/NN of the **change-set's** scenarios = the gate; baseline rows accumulate across releases — list any never-covered baseline scenario as a backlog row, not a waiver.]
````

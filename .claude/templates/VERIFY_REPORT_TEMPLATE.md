# VERIFY_REPORT + VERIFY_MATRIX Template — `/verify` Output Boilerplate

> **Mục đích:** Khung cố định cho 2 artifact tracked của `/verify`. Agent **chỉ fill** placeholder — KHÔNG re-author structure.
>
> Quy tắc chi tiết (artifact lock, traceability gate, Layer rule): [`../commands/verify.md`](../commands/verify.md).

---

## §A. `reports/VERIFY_REPORT.md` skeleton

````markdown
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
````

## §B. `reports/VERIFY_MATRIX.md` skeleton

> Cột **Layer** là chốt chống "API test giả danh coverage UI" — Layer rule: UI-observable scenario chỉ được thỏa bởi test E2E-UI (Phase 3) đạt E2E assertion contract.

````markdown
# Verify Matrix — <product> <candidate-tag>

| Scenario ID | Acceptance scenario | Verify test id | Layer | Phase | Result |
|-------------|---------------------|----------------|-------|-------|--------|
| US-001-S01 | [happy path] | `@US-001-S01` | E2E-UI | 3 | PASS |
| US-001-S02 | [edge/failure] | `@US-001-S02` | API | 2 | PASS |
| … | … | … | … | … | … |

**Coverage**: NN/NN scenarios mapped (100%) — [hoặc liệt kê scenario waived kèm reason + approver]
````

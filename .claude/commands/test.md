---
name: test
description: QA verification with real dependencies — the quality gate before review
---

# /test — Quality Gate Testing

> "Tests are proof, not afterthought."

## Purpose

Verify code works correctly in **production-like environment** with real dependencies (database, cache). This is the quality gate before `/review`.

> **Stack Profile note:** TestContainers image follows the `Project Profile`. Default = SQL Server; if Oracle is declared → Oracle XE/Free, MySQL → `mysql:8.0` (see `rules/overrides/database-*.md`). Observability ELK → `rules/overrides/monitoring-elk.md`. Core test stack (xUnit/Moq/FluentAssertions) does not change.

## Prerequisites

- Code implemented via `/build`
- **Docker Desktop installed and running** (REQUIRED)

---

## Test Engineer Responsibilities

`/test` differs from `/build`:

| Aspect | /build (Developer) | /test (Test Engineer) |
|--------|-------------------|------------------------|
| **Focus** | Write tests while implementing | Verify, supplement, and re-run with real engines |
| **Tests ADDED** | Unit (Mock) + Integration (In-Memory) | TestContainers + E2E |
| **Tests EXECUTED** | Unit (Mock) + Integration (In-Memory) | **Everything** — re-runs `/build`'s suite (Unit + In-Memory + frontend Vitest) **AND** adds TestContainers + Playwright E2E |
| **Docker** | ❌ Not required | ✅ Required |
| **Goal** | Feature works | Feature works **in production-like env**, with no regressions |

### Test Engineer Tasks in /test

1. **Run All Tests with Real Dependencies**
   - TestContainers: Real SQL Server, Redis
   - E2E: Full stack with Docker Compose

2. **Coverage Gap Analysis**
   - Run coverage report
   - Identify untested code paths
   - Add missing edge case tests

3. **Boundary Testing**
   - Input validation edge cases
   - Null/empty/max values
   - Concurrent access scenarios

4. **Regression Testing**
   - Verify bug fixes have tests
   - Ensure no regressions from changes

5. **Scenario reconciliation (spec ↔ test)**
   - Every `@US-XXX-Snn` in the spec has ≥ 1 test asserting that scenario's observable *Then* — not just "the endpoint/class works". A **UI-observable** scenario needs a UI/E2E-layer test (deep UI E2E may be deferred to `/verify`, but record the gap, do not count it as covered here).
   - Any scenario with no asserting test → file it (TEST_REPORT §9) for `/verify` / `/review`, never silently treat as covered.

6. **Consumer-contract conformance (cross-layer drift)**
   - Wherever a first-party client / SDK / BFF calls the API, assert its **method + path + success-status** match the API contract (`architecture/api/openapi.yaml` or the controllers). Catches client↔API drift (e.g. client sends `PUT` while the route is `PATCH`) that per-side tests miss because each side passes in isolation.

## Testing Strategy for /test

> **IMPORTANT:** `/test` uses tests that REQUIRE Docker.

```
┌─────────────────────────────────────────────────────────────────┐
│                    /test TESTING APPROACH                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ✅ USED IN /test:                                             │
│   ├── Integration Tests (TestContainers) ─ Real SQL Server      │
│   └── E2E Tests (Docker Compose) ──────────── Full Stack        │
│                                                                  │
│   ✅ ALSO RUN (from /build):                                    │
│   ├── Unit Tests (Mock)                                         │
│   └── Integration Tests (In-Memory)                             │
│                                                                  │
│   Required:  .NET SDK 8.0 + Docker Desktop                      │
│   Docker:    ✅ REQUIRED                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Docker is Required

`/test` re-runs the full `/build` suite (unit + in-memory integration + frontend Vitest) **and additionally** runs **TestContainers** (real SQL Server / Redis instances spun up per test fixture) and **Docker-Compose E2E** (full stack). The latter two depend on a running Docker daemon — they exist to catch issues In-Memory cannot surface (collation, indexes, transactions, network timing, real HTTP).

### Running Tests in /test

```bash
docker info                                                # verify Docker daemon
dotnet test                                                # run full suite
dotnet test --filter "Category=RequiresDocker"             # TestContainers only
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
docker-compose -f docker-compose.test.yml down -v
```

### Test Categories

Tag tests with `[Trait("Category", "RequiresDocker")]` or `[Trait("Category", "E2E")]` so `/test` can filter them. Untagged tests are the `/build` baseline that also re-runs here.

> Implementation patterns (fixture code, `CustomWebApplicationFactory`, container image selection) live in [`rules/testing.md`](../rules/testing.md).

---

## Bug Reproduction: Prove-It Pattern (write-only)

> `/test` is read-only on production code. Inside `/test` we PROVE the bug exists; the fix happens in `/review` (or `/fix-issue` for prod hotfixes).

### Step 1 — Write a failing reproduction test

```csharp
[Fact]
public async Task AddItemAsync_WhenAddingSameProductTwice_ShouldIncrementQuantity()
{
    // This test should FAIL against the current (buggy) production code.
    var cart = new Cart();

    await cart.AddItemAsync("product-1", 1);
    await cart.AddItemAsync("product-1", 1);

    cart.Items.Should().HaveCount(1);
    cart.Items[0].Quantity.Should().Be(2);
}
```

### Step 2 — Verify it fails

Run the test — confirm it fails against unchanged production code. Capture the failure output into TEST_REPORT §8 (Bug Reports → Evidence).

### Step 3 — File BUG-### in §8

Use the Bug Report Template (Severity / Steps / Expected / Actual / Root cause `file:line` / Proposed fix / Regression test = the test you just wrote).

> "Fix the code" + "verify green" are explicitly out of scope here — they belong to `/review` / `/fix-issue`, which will run the same regression test you authored.

---

## Test Pyramid

| Level | Percentage | Speed | Scope |
|-------|------------|-------|-------|
| **Unit** | 80% | ms | Single class, no I/O |
| **Integration** | 15% | seconds | API + DB, component interactions |
| **E2E** | 5% | minutes | Full user flows |

---

## Writing Good Tests

> Patterns (AAA, DAMP, naming `Method_Scenario_ExpectedResult`), test doubles, `CustomWebApplicationFactory`/TestContainers fixture code, and anti-patterns are defined in:
> - [`rules/testing.md`](../rules/testing.md) — mandatory standards + fixture templates
> - [`references/testing-patterns.md`](../references/testing-patterns.md) — quick-lookup checklist

In `/test`, the rule is simple: **prefer real implementations over fakes**. `/build` uses In-Memory providers; `/test` swaps them for TestContainers-backed real engines and re-runs the full suite.

**Assert the effect, not the absence of error.** A test must assert the **resulting state/outcome** the scenario's *Then* describes — not merely that no exception was thrown or that an element rendered. A test that would still pass if the feature were silently removed does not count. Cover the **failure-prone input variant** (e.g. the path a user hits *without* the convenient keystroke), not only the happy path.

---

## Coverage Analysis

Test Engineer must verify coverage meets the threshold before passing the quality gate.

### Coverage Scope Policy (`coverlet.runsettings`)

**MANDATORY.** Create `coverlet.runsettings` at the repo root before generating coverage. Without an explicit scope, auto-generated and host-glue code (which has no meaningful tests by design) inflates the uncovered-line count and produces a misleading low number.

Minimum exclusions:

- `**/Migrations/**/*.cs` — EF Core scaffolded code.
- `**/Program.cs` — host-builder glue; tested implicitly via integration tests.
- `[Obsolete]`, `[GeneratedCode]`, `[CompilerGenerated]`, `[ExcludeFromCodeCoverage]` attributes.
- Scaffolded API clients / DTOs with only auto-properties (case-by-case).

Document any additional exclusions in `TEST_REPORT.md §Coverage` with a one-line rationale per entry.

### Generate Coverage Report

```bash
# Run tests with coverage (honors coverlet.runsettings)
dotnet test --collect:"XPlat Code Coverage" \
  --settings coverlet.runsettings \
  --results-directory ./coverage

# Generate HTML report
reportgenerator \
  -reports:./coverage/**/coverage.cobertura.xml \
  -targetdir:./coverage/report \
  -reporttypes:Html

# Open report
open ./coverage/report/index.html
```

### Coverage Thresholds (Quality Gate 6)

| Metric | Minimum | Target |
|--------|---------|--------|
| Line coverage | 80% | 90% |
| Branch coverage | 75% | 85% |
| Method coverage | 80% | 90% |

### Identify Coverage Gaps

```bash
# Find uncovered lines in report
# Focus on:
# - Error handling paths
# - Edge cases
# - Validation logic
```

---

## Test Commands & Assertion Cheatsheet

> Full `dotnet test` flags, FluentAssertions cheatsheet, and the anti-pattern table live in [`rules/testing.md`](../rules/testing.md). `/test` only needs the four-command core shown in "Running Tests in /test" above.

---

## Output — `reports/TEST_REPORT.md` (MANDATORY)

`/test` produces ONE primary artifact: `reports/TEST_REPORT.md`. It is the handoff document to `/review` and `/scan`. Follow the structure below — every section must be present even if the answer is "n/a, see §X".

```markdown
# Test Report — [Project] (`/test` phase)

**Date**: YYYY-MM-DD
**Test Engineer Agent**: Quality Gate 6 verification
**Inputs**: `/build` deliverables (X backend tests, Y frontend tests, Z E2E specs)

## 1. Summary
| Deliverable | Suite | Pass / Total | Verdict |
|---|---|---|---|
| ... | ... | ... | PASS / FAIL |

**Verdict for Quality Gate 6**: PASS / PASS WITH CONDITIONS / FAIL — one paragraph stating why.

> "PASS WITH CONDITIONS" = baseline green + ≥1 BUG-### filed + no Critical-severity blocker. Conditions must be closed by `/review` before Gate 7 opens.

## 2. Backend in-memory suite (re-run baseline)
Command + per-project pass/fail/skip/duration table. Note any delta vs `/build`-reported counts.

## 3. Backend TestContainers suite (NEW)
- What was built (fixtures, container image choice incl. arm64 / x86 note)
- Curated test set (TC-RD-## table mapping each test to the contract it verifies)
- Execution result + failure analysis (if any)

## 4. Frontend Vitest suite (re-run)
Command + result. If coverage tooling is missing, say so and defer to `/review`.

## 5. E2E (Playwright) — LIVE execution
Setup steps + result + artifact paths (screenshot/video/trace) on failure.

## 6. Coverage report
- `coverlet.runsettings` scope policy (link to file + list of exclusions with rationale)
- Top-level metrics: line / branch / critical-path vs gates
- Per-assembly breakdown
- Top 5 uncovered files with **rationale** ("acceptable" / "gap-closing test added")
- New tests added to close gaps (file → test count → rationale)

## 7. Verification checklist
Every Quality Gate 6 item with PASS/FAIL/n-a.

## 8. Bug reports
One BUG-### subsection per defect using the Test Engineer Bug Report Template
(Severity / Environment / Hidden-by / Found-by / Reproducible / Summary /
Steps / Expected / Actual / Root cause `file:line` / Impact / Evidence /
Proposed fix / Regression test).

## 9. Gaps identified, not closed
Things acknowledged but deferred — frontend coverage, CI verification on other archs, E2E expansion, etc. Each line names the next owner.

## 10. Files added during `/test`
List every new/modified file. Repeat the boundary rule: "No production code under `src/` was modified."

## 11. Quality Gate 6 verdict
PASS / PASS WITH CONDITIONS / FAIL with one-paragraph justification. If PWC or FAIL: name the blocker(s), reference BUG-### in §8.

## 12. Open items for `/review`
Numbered, actionable list — what `/review` must do (fix BUG-001) + optional items (add `@vitest/coverage-v8`, expand E2E suite, …).
```

> **Boundary rule:** `/test` MUST NOT modify production code under `src/` or `client/src/`. Bugs found during `/test` are filed as reports in §8 with a proposed fix; the fix happens in `/review` (or `/fix-issue` for production hotfixes). This is what makes the regression net in §3 trustworthy — the TestContainers tests are written against unchanged production code.

## Exit Criteria (Quality Gate 6)

Before proceeding to `/review`:

- [ ] All tests pass (including Docker-required tests)
- [ ] **Every `@US-XXX-Snn` has a test asserting its observable *Then*** (effect, not presence); scenarios needing UI-layer proof and deferred to `/verify` are listed in §9, not counted as covered
- [ ] **Consumer↔API contract conformance checked** — first-party client/SDK/BFF calls match the contract's method/path/status (no `PUT`-vs-`PATCH`-style drift)
- [ ] Code coverage ≥ 80% (with `coverlet.runsettings` scope applied — exemptions documented)
- [ ] No skipped or disabled tests
- [ ] Bug fixes have reproduction tests
- [ ] Edge cases covered
- [ ] E2E tests for critical paths
- [ ] `reports/TEST_REPORT.md` produced with all 12 sections populated
- [ ] No production code under `src/` or `client/src/` modified during `/test`

## Verification Checklist (Test Engineer)

| Check | Command |
|-------|---------|
| All tests pass | `dotnet test` |
| Docker tests pass | `dotnet test --filter "Category=RequiresDocker"` |
| Coverage ≥ 80% | `dotnet test --collect:"XPlat Code Coverage"` |
| E2E tests pass | `docker-compose -f docker-compose.test.yml up` |

## Agent

Invoke: **Test Engineer** (owns strategy, execution, and verification)

| Agent | Responsibility |
|-------|----------------|
| Test Engineer | Test strategy + TDD coaching + coverage policy + test plans + TestContainers/E2E execution + bug triage |

## Next Step

After all tests pass with coverage ≥ 80%, run `/review` for code review.

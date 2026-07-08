---
name: test
description: QA verification with real dependencies — the quality gate before review
---

# /test — Quality Gate Testing

> "Tests are proof, not afterthought."

## Purpose

Verify code works correctly in **production-like environment** with real dependencies (database, cache). This is the quality gate before `/review`.

> **Stack Profile note:** TestContainers image follows the `Project Profile`. Default = SQL Server; if Oracle is declared → Oracle XE/Free, MySQL → `mysql:8.0` (see `rules/overrides/database-*.md`). Observability ELK → `rules/overrides/monitoring-elk.md`. Core test stack (xUnit/Moq/FluentAssertions) does not change. **On Apple Silicon (arm64):** swap the SQL Server image to `azure-sql-edge` + a TCP/port-wait — the default `mssql/server:2022` image segfaults under qemu; see `rules/testing.md` Template B arm64 note.

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

5. **Scenario reconciliation (spec ↔ test)** — per [`references/scenario-traceability.md`](../references/scenario-traceability.md)
   - Every `@US-XXX-Snn` has ≥ 1 test asserting that scenario's observable *Then* (effect, not presence). A **UI-observable** scenario needs a UI/E2E-layer test (deep UI E2E may be deferred to `/verify` — record the gap, do not count it as covered here).
   - Any scenario with no asserting test → file it (TEST_REPORT §9) for `/verify` / `/review`, never silently treat as covered.

6. **Consumer-contract conformance (cross-layer drift)**
   - Wherever a first-party client / SDK / BFF calls the API, assert its **method + path + success-status** match the API contract (`architecture/api/openapi.yaml` or the controllers). Catches client↔API drift (e.g. client sends `PUT` while the route is `PATCH`) that per-side tests miss because each side passes in isolation.

## Testing Strategy for /test

> **IMPORTANT:** `/test` uses tests that REQUIRE Docker.

```text
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

# ONE full run — covers unit + in-memory + TestContainers AND collects coverage.
# Do NOT also run a plain `dotnet test` or `dotnet test --filter "Category=RequiresDocker"`:
# the full suite already includes them, and re-running spins the TestContainers SQL Server/Redis up redundantly.
dotnet test --collect:"XPlat Code Coverage" --settings coverlet.runsettings --results-directory ./coverage

# Stack-level E2E (separate from dotnet test — cannot be folded into the run above)
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

`/test` produces ONE primary artifact: `reports/TEST_REPORT.md`. It is the handoff document to `/review` and `/scan`.

> **Boilerplate template (fill-only — saves time):** copy [`templates/TEST_REPORT_TEMPLATE.md`](../templates/TEST_REPORT_TEMPLATE.md) and fill in the placeholders — do NOT re-author the 12-section structure on every run. Every section must be present even when it is "n/a, see §X".

**12 sections:** 1 Summary (verdict PASS / PASS-WITH-CONDITIONS / FAIL — PWC = baseline green + ≥1 BUG-### + no Critical blocker) · 2 Backend in-memory re-run · 3 TestContainers (NEW) · 4 Frontend Vitest re-run · 5 E2E live · 6 Coverage (scope policy + metrics + top-5 uncovered with rationale) · 7 Gate-6 checklist · 8 Bug reports (BUG-###, Prove-It) · 9 Gaps deferred (each line names the next owner) · 10 Files added (+ boundary statement) · 11 Gate 6 verdict · 12 Open items for `/review`.

> **Boundary rule:** `/test` MUST NOT modify production code under `src/` or `web/src/`. Bugs found during `/test` are filed as reports in §8 with a proposed fix; the fix happens in `/review` (or `/fix-issue` for production hotfixes). This is what makes the regression net in §3 trustworthy — the TestContainers tests are written against unchanged production code.

## Quality Gate 6 — Exit Criteria

Before proceeding to `/review`:

- [ ] All tests pass — **confirmed by the canonical commands exiting 0** (`dotnet test` AND `npm test`), not merely asserted in `TEST_REPORT.md`. A green report with a red command = gate FAIL.
- [ ] **Adding a new test runner did NOT break the unit-test command** — when scaffolding Playwright/visual/E2E tooling, `npm test` (vitest) MUST still exit 0 (runner isolation: exclude `e2e/`/Playwright specs from the unit runner's glob). The unit command staying green is part of this gate.
- [ ] **No production config mutated for test isolation** — `git diff` shows no changes to `appsettings*.json` / `Program.cs` / `docker-compose*.yml` originating from test setup; isolation was achieved runtime-only (fixture DI swap / env vars / `appsettings.Testing.json`), so the artifact deploys with its **original** connections
- [ ] **Every `@US-XXX-Snn` has a test asserting its observable *Then*** (effect, not presence); scenarios needing UI-layer proof and deferred to `/verify` are listed in §9, not counted as covered
- [ ] **Consumer↔API contract conformance checked** — first-party client/SDK/BFF calls match the contract's method/path/status (no `PUT`-vs-`PATCH`-style drift)
- [ ] Code coverage meets the threshold **per Mode** (`rules/testing.md §Coverage Thresholds`): greenfield = whole-repo ≥ 80% · brownfield per-change = **delta-coverage ≥ 80%** (files changed) + whole-repo **does not drop** (ratchet) — TEST_REPORT §Coverage records BOTH numbers + states clearly which one is the gate (with `coverlet.runsettings` scope applied — exemptions documented)
- [ ] No skipped or disabled tests
- [ ] Bug fixes have reproduction tests
- [ ] Edge cases covered
- [ ] E2E tests for critical paths
- [ ] `reports/TEST_REPORT.md` produced with all 12 sections populated
- [ ] No production code under `src/` or `web/src/` modified during `/test`

## Verification Checklist (Test Engineer)

> The first three checks are all satisfied by the **single** coverage run in "Running Tests in /test" — do not run the suite three times (it would spin up the TestContainers engines redundantly).

| Check | Satisfied by |
|-------|--------------|
| All tests pass (unit + in-memory + TestContainers) | `dotnet test --collect:"XPlat Code Coverage" --settings coverlet.runsettings` (the one run) |
| Coverage ≥ 80% | same run (`--collect` output) |
| E2E tests pass | `docker-compose -f docker-compose.test.yml up` (separate) |

## Agent

Invoke: **Test Engineer** (owns strategy, execution, and verification)

| Agent | Responsibility |
|-------|----------------|
| Test Engineer | Test strategy + TDD coaching + coverage policy + test plans + TestContainers/E2E execution + bug triage |

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After all tests pass with coverage ≥ 80%, run `/review` for code review.

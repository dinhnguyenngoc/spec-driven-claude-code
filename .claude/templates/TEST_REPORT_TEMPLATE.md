# TEST_REPORT Template — `/test` Output Boilerplate

> **Purpose:** Fixed 12-section framework for `reports/TEST_REPORT.md`. The `/test` agent **only fills** the `[…]`/`<…>` placeholders — does NOT re-author the structure on each run.
>
> **Rule:** Every section must be present, even when the answer is "n/a, see §X". Detailed requirements per section: [`../commands/test.md`](../commands/test.md) §Output.

---

````markdown
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

**Failed cases** (omit the table when everything passes):

| Test | @US-Snn | Input/data | Expected → Actual | Evidence | BUG-### |
|------|---------|------------|--------------------|----------|---------|
| ... | ... | payload/arrange values that triggered it | ... → ... | `reports/test-artifacts/runner/<path>` or log excerpt | §8 link or `—` |

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
- **Coverage by Mode** (`rules/testing.md §Coverage Thresholds`) — fill all 3 rows, clearly stating which row is the gate:

  | Metric | Result | Role |
  |-------|---------|---------|
  | Delta coverage (files changed in the change-set) | line \_\_% / branch \_\_% | **GATE** when Mode=brownfield per-change (≥80/≥75) |
  | Whole-repo coverage | line \_\_% / branch \_\_% | **GATE** when greenfield; informational + ratchet when brownfield |
  | Ratchet vs previous measurement | prev \_\_% → now \_\_% (±\_\_) | brownfield: **a decrease = GATE FAIL**; first run = establishes the baseline |

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
Things acknowledged but deferred — frontend coverage, CI verification on other archs, E2E expansion, etc. Each line names the next owner. *(A gap whose next owner is `/review` also gets an `OPEN-###` row in §12 — §12 is the single list `/review` reconciles.)*

## 10. Files added during `/test`
List every new/modified file. Repeat the boundary rule: "No production code under `src/` was modified."

## 11. Quality Gate 6 verdict
PASS / PASS WITH CONDITIONS / FAIL with one-paragraph justification. If PWC or FAIL: name the blocker(s), reference BUG-### in §8.

## 12. Open items for `/review`
Numbered list with **stable `OPEN-###` ids** (sequential): what `/review` must do (OPEN-001: fix BUG-001) + optional items (OPEN-002: add `@vitest/coverage-v8`, …). `/review` dispositions **each id** as CLOSED / DEFERRED-to-Pn / ESCALATED — an id that disappears between the two reports is a gate failure.
````

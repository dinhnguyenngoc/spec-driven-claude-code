---
name: review
description: Review a pull request or branch changes using the Five-Axis Framework
---

# /review — Code Review

> "Quality is non-negotiable."

## Purpose

Perform a thorough code review of specified files, branch changes, or a pull request using the **Five-Axis Framework** (Correctness, Readability, Architecture, Security, Performance).

## Prerequisites

- Code implementation complete (`/build` done)
- Tests passing (`/test` done)
- Code compiles without errors (`dotnet build`)

## Inputs

The reviewer MUST ingest these artifacts before scoring. A finding without traceability back to one of them cannot satisfy the `Relates-to` requirement and will fail Gate 7. *(Brownfield: ingest only what the diff relates-to — see §Brownfield Mode.)*

| Artifact | Used to verify |
|----------|----------------|
| `specs/SPEC.md` + `specs/user-stories/*` | **Correctness** — does the implementation match each `US-XXX` acceptance criterion? |
| `architecture/adr/*.md` + `architecture/api/*` | **Architecture** — are ADR decisions honored? Do API contracts match the implemented routes/DTOs? |
| `plans/todo.md` | **Scope** — did `/build` close exactly the tasks it claimed (`T-XX`)? Flag orphan changes or unticked tasks. |
| `security/PRE_DEV_REVIEW.md` | **Security** — are the Required Controls (`RC-X.Y`) and threat mitigations (`S1..E10` from STRIDE) present in code? |
| `reports/TEST_REPORT.md` | **Gate-6 PASS verdict** (Step 2 trusts this instead of re-running the suite) + **Coverage numbers** + every `OPEN-XXX` debt from `/test` must be tagged **CLOSED / DEFERRED-to-Pn / ESCALATED** in this review — none may be silently dropped. |
| `.claude/rules/*.md` | **Compliance Check** table (see Output File §6). |

## Usage
```text
/review                    # Review current branch changes
/review <file>             # Review specific file
/review <PR#>              # Review pull request
```

---

## Workflow

1. **Identify Scope** — Determine files/PR/branch to review
2. **Confirm the build & trust the test gate** — run `dotnet build` (cheap compile sanity). Do **NOT** re-run the full `dotnet test` suite (especially TestContainers) up front: `/test` already certified it green on this unchanged code in `reports/TEST_REPORT.md` (Gate 6 PASS). **Re-run the affected tests only after a fix** made during this review (the §Resolution verification numbers come from that re-run). **Fallback:** if `TEST_REPORT.md` is absent (review run standalone, no `/test`), run the full suite once.
3. **Apply Five-Axis Review** — Correctness, Readability, Architecture, Security, Performance
4. **Document Findings** — Create `reports/CODE_REVIEW.md`
5. **Decision** — APPROVE / REQUEST CHANGES / NEEDS DISCUSSION

---

## Review Checklist

### Code Quality
- [ ] Code follows style guide (`.claude/rules/code-style.md`)
- [ ] No unnecessary complexity or duplication
- [ ] Functions are small and focused (single responsibility)
- [ ] Variable and function names are descriptive

### Security
- [ ] No hardcoded secrets or credentials
- [ ] Input validation is present
- [ ] Authentication/authorization checks in place
- [ ] See `.claude/rules/security.md` for full checklist

### Error Handling
- [ ] Errors are properly caught and handled
- [ ] Meaningful error messages
- [ ] No swallowed exceptions
- [ ] See `.claude/rules/error-handling.md`

### Testing
- [ ] Unit tests cover new logic
- [ ] Edge cases are tested
- [ ] Tests are readable and maintainable
- [ ] See `.claude/rules/testing.md`

### Database
- [ ] Queries are optimized (no N+1)
- [ ] Transactions used where appropriate
- [ ] See `.claude/rules/database.md`

### API
- [ ] Endpoints follow REST conventions
- [ ] Request/response schemas are documented
- [ ] See `.claude/rules/api-conventions.md`

### Cross-layer conformance (spec ↔ contract ↔ consumer ↔ wiring)
> Feeds the **Correctness** + **Architecture** axes; each finding carries `Relates-to`.
- [ ] **Consumer matches contract** — consumer code (FE client / SDK / BFF) uses the **same HTTP method / path / success-status** as the API contract & controllers. No drift (e.g. client `PUT` vs route `PATCH`).
- [ ] **No orphan / everything wired** — every acceptance behavior is **reachable from the app entry point**; flag any component / handler / endpoint that exists but is never mounted, passed, or routed. "Exists in code" ≠ "wired".
- [ ] **Scenario coverage** — every `@US-XXX-Snn` from the spec maps to a **wired** path **and** to a test that asserts that scenario's observable *Then* (not just an isolated unit / endpoint) — rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md).
- [ ] **Anti-vacuous audit** — for each scenario, open its mapped test and confirm it asserts the observable outcome (effect/state, persisted across a round-trip) — **a test that would still pass if the feature were silently removed does NOT satisfy the scenario**.

## Output Format
Provide feedback as:
- 🔴 **Critical** — Must fix before merge
- 🟡 **Warning** — Should fix, potential issue
- 🟢 **Suggestion** — Nice to have improvement
- ✅ **Good** — Highlight what's done well

> **MANDATORY — `Relates-to` traceability.** Every finding (Critical / Warning / Suggestion) MUST end with a `Relates-to: <ID(s)>` line citing the source artifacts it touches: User Stories (`US-XXX`), Required Controls (`RC-X.Y`), ADRs (`ADR-NNN`), plan tasks (`T-XX`), or threat IDs (`S1..E10`). This is the bridge that lets `/scan` and `/deploy` close the loop back to spec and threat model. A finding without `Relates-to` is half-done.

## Output File

**IMPORTANT:** After completing the review, you MUST create a report file:

```text
reports/CODE_REVIEW.md
```

> **Boilerplate template (fill-only — tối ưu thời gian):** copy [`templates/CODE_REVIEW_TEMPLATE.md`](../templates/CODE_REVIEW_TEMPLATE.md) và fill — KHÔNG re-author structure 7 mục mỗi lần review.

The report MUST include:
1. **Executive Summary** with severity counts
2. **Five-Axis Scores** table — numerical 1-5 per axis with one-line justification (skeleton: template §2). **Score honesty (evidence-anchored):** an axis with an open 🔴 Critical scores **≤ 2**; an axis with an unresolved 🟡 Warning (incl. accept-with-tracking / an open Action Item) scores **≤ 4** — **5 only when that axis has no outstanding finding**. Each justification must cite the finding(s) / Evidence anchoring the number, not a subjective impression. If `REQUEST CHANGES → APPROVED` after a fix, re-score and show the updated number.
3. **All findings** organized by severity (Critical → Warning → Suggestion → Good), each with `Where` (file:line), `Description`, `Recommendation`, and `Relates-to`.
4. **Action Items** checklist (P0, P1, P2) — tick `[x]` for items resolved during the review cycle.
5. **Test Coverage** summary (cite numbers from `reports/TEST_REPORT.md`).
6. **Compliance Check** table — every `.claude/rules/*.md` mapped to PASS / WARNING / FAIL with a one-line note **and an `Evidence` citation** (skeleton: template §6). This frees `/scan` from re-checking rule compliance.
   > **Evidence-based, not asserted (mandatory).** A `PASS` is invalid without an `Evidence` citation — a `file:line`, a wired-pipeline reference, or a test name proving the control is actually present. "Code looks compliant" is not evidence. **Cross-cutting controls especially** (security headers, CORS, HTTPS-redirect, rate-limiting, auth middleware, global exception handler): confirm they are **registered in the request pipeline** (cite where) **and** backed by a test — a control that is *defined but never wired* is a 🔴/🟡 finding, not a PASS. (This closes the gap that let a missing security-headers middleware pass review with a 5/5 security score.)
7. **Approval Status** table with decision (APPROVE / REQUEST CHANGES / NEEDS DISCUSSION). If the verdict flipped (REQUEST CHANGES → APPROVED after fix), include a §Resolution sub-section listing: (a) what changed, (b) verification numbers from re-run, (c) re-scored axes.

Create the `reports/` folder if it doesn't exist.

---

## Quality Gate 7 — Five-Axis Review (Optional)

> Per CLAUDE.md §Quality Gates, `/review` is an **optional** pipeline step (Legend: `*`). **If run**, the checklist below must fully pass before `/scan` — no partial pass.

Before proceeding to `/scan`:

- [ ] Five-axis review completed **with numerical scores (1-5) per axis**
- [ ] **Cross-layer conformance checked** — consumer↔contract method/path match · no orphan (every behavior wired) · each `@US-XXX-Snn` maps to a wired path + an effect-asserting test (anti-vacuous)
- [ ] No outstanding 🔴 Critical findings
- [ ] All 🟡 Warnings have been addressed or explicitly accepted
- [ ] `reports/CODE_REVIEW.md` created with approval decision
- [ ] All critical feedback addressed before merge
- [ ] **Compliance Check table** present — every `.claude/rules/*.md` → PASS / WARNING / FAIL **with an `Evidence` citation per PASS** (no PASS without `file:line` / wired-pipeline ref / test name); cross-cutting controls verified as wired, not just defined
- [ ] **Every finding has `Relates-to: <US-XXX | RC-X.Y | ADR-NNN | T-XX>`** for downstream traceability
- [ ] If verdict flipped post-fix, §Resolution section documents what changed + verification numbers + re-scored axes

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

`/review` is **per-change** on legacy — review the **diff/slice**, not the whole repo:

- **Scope the review to the diff** — the Five-Axis applies to the changed lines **+ their blast radius** (callers/callees the change can affect), not the entire reverse-engineered codebase. Run `/review` on the branch diff / changed files.
- **Ingest relates-to only** — pull in only the spec stories, ADRs, and `RC-X.Y` controls the diff *relates to* (via the plan's task → scenario map), not the full baseline `SPEC.md` / `ARCHITECTURE.md` (which describe the whole as-is system).
- **Backward-compat is a Critical axis** — for a B2 (modify) change, verify the diff does NOT break an existing contract / response shape / behavior; a regression here is a 🔴 Critical. This is the review counterpart of `/plan`'s backward-compat AC and `/secure`'s regression-security check.
- **Characterization tests present** — confirm any touched legacy area without prior tests got a characterization test (per `rules/brownfield.md`) before modification; flag its absence as a finding.
- **Trust the regression net** — the full-suite regression run is `/test`'s job (Gate 6); `/review` trusts `TEST_REPORT.md` (Step 2). Do not re-review unchanged modules.

> **B5 (architecture upgrade) exception:** review the redesign against its ADR + migration plan (strangler-fig), not just a diff.

## Agent

Invoke: **Code Reviewer** (Senior Staff Engineer perspective) for deep review.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After review approved, run `/scan` for post-development security scanning.

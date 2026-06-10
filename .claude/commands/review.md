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

The reviewer MUST ingest these artifacts before scoring. A finding without traceability back to one of them cannot satisfy the `Relates-to` requirement and will fail Gate 7.

| Artifact | Used to verify |
|----------|----------------|
| `specs/SPEC.md` + `specs/user-stories/*` | **Correctness** — does the implementation match each `US-XXX` acceptance criterion? |
| `architecture/adr/*.md` + `architecture/api/*` | **Architecture** — are ADR decisions honored? Do API contracts match the implemented routes/DTOs? |
| `plans/todo.md` | **Scope** — did `/build` close exactly the tasks it claimed (`T-XX`)? Flag orphan changes or unticked tasks. |
| `security/PRE_DEV_REVIEW.md` | **Security** — are the Required Controls (`RC-X.Y`) and threat mitigations (`S1..E10` from STRIDE) present in code? |
| `reports/TEST_REPORT.md` | **Coverage numbers** + every `OPEN-XXX` debt from `/test` must be tagged **CLOSED / DEFERRED-to-Pn / ESCALATED** in this review — none may be silently dropped. |
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
2. **Run Static Analysis** — `dotnet build`, `dotnet test` to verify code compiles
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
2. **Five-Axis Scores** table — numerical 1-5 per axis with one-line justification (skeleton: template §2). If `REQUEST CHANGES → APPROVED` after a fix, re-score and show the updated number.
3. **All findings** organized by severity (Critical → Warning → Suggestion → Good), each with `Where` (file:line), `Description`, `Recommendation`, and `Relates-to`.
4. **Action Items** checklist (P0, P1, P2) — tick `[x]` for items resolved during the review cycle.
5. **Test Coverage** summary (cite numbers from `reports/TEST_REPORT.md`).
6. **Compliance Check** table — every `.claude/rules/*.md` mapped to PASS / WARNING / FAIL with a one-line note (skeleton: template §6). This frees `/scan` from re-checking rule compliance.
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
- [ ] **Compliance Check table** present (every `.claude/rules/*.md` → PASS / WARNING / FAIL)
- [ ] **Every finding has `Relates-to: <US-XXX | RC-X.Y | ADR-NNN | T-XX>`** for downstream traceability
- [ ] If verdict flipped post-fix, §Resolution section documents what changed + verification numbers + re-scored axes

## Agent

Invoke: **Code Reviewer** (Senior Staff Engineer perspective) for deep review.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After review approved, run `/scan` for post-development security scanning.

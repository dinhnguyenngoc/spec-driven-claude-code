# CODE_REVIEW Template — `/review` Output Boilerplate

> **Purpose:** Fixed 7-section framework for `reports/CODE_REVIEW.md`. The `/review` agent **only fills** — does NOT re-author the structure.
>
> Detailed rules (Five-Axis, `Relates-to` mandatory, OPEN-XXX closure): [`../commands/review.md`](../commands/review.md) §Output File. Canonical labels: 🔴 Critical · 🟡 Warning · 🟢 Suggestion · ✅ Good.

---

````markdown
# Code Review — [PR / branch / scope] (`/review` phase)

**Date**: YYYY-MM-DD
**Reviewer**: Code Reviewer agent (Five-Axis Framework)
**Inputs**: specs/SPEC.md · architecture/adr/* · plans/todo.md · security/PRE_DEV_REVIEW.md · reports/TEST_REPORT.md

## 1. Executive Summary
[Overall verdict 1-2 sentences] — 🔴 N · 🟡 N · 🟢 N · ✅ N

## 2. Five-Axis Scores

| # | Axis | Score (1–5) | One-line justification |
|---|------|-------------|------------------------|
| 1 | Correctness | … | … |
| 2 | Readability | … | … |
| 3 | Architecture | … | … |
| 4 | Security | … | … |
| 5 | Performance | … | … |

[If REQUEST CHANGES → APPROVED after fix: re-score and record the new numbers]

## 3. Findings (by severity: 🔴 → 🟡 → 🟢 → ✅)

### 🔴 Critical
- **[file:line]** [Description] — [Recommendation] — *Relates-to: <US-XXX | NFR-xx | RC-N | ADR-NNN | Task N.N | S1..E10>*

### 🟡 Warning
- …— *Relates-to: …*

### 🟢 Suggestion
- …— *Relates-to: …*

### ✅ Good
- **[file:line]** [What's done well]

## 4. Action Items
- [ ] **P0**: [item]
- [ ] **P1**: [item]
- [ ] **P2**: [item]

## 5. Test Coverage
[Cite numbers from reports/TEST_REPORT.md]. Every `OPEN-XXX` debt from `/test`:

| OPEN-XXX | Disposition |
|----------|-------------|
| OPEN-001 | CLOSED / DEFERRED-to-Pn / ESCALATED — [reason] |

## 6. Compliance Check

> `PASS` **must have `Evidence`** (file:line / wired-pipeline ref / test name). PASS with empty Evidence = invalid. Cross-cutting controls (security headers, CORS, rate-limit, auth, exception handler) must cite **where they are wired in the pipeline**, not just "defined".

| Rule | Status | Evidence (file:line / test) | Notes |
|------|--------|-----------------------------|-------|
| clean-code.md | PASS / WARNING / FAIL | `<file:line>` / `<test>` | … |
| code-style.md | … | … | … |
| error-handling.md | … | … | … |
| security.md | … | `Program.cs:NN` (headers/CORS/auth wired) + `<test>` | … |
| database.md | … | … | … |
| api-conventions.md | … | … | … |
| testing.md | … | … | … |
| [every remaining rule in .claude/rules/] | … | … | … |

## 7. Approval Status

| Decision | APPROVE / REQUEST CHANGES / NEEDS DISCUSSION |
|----------|----------------------------------------------|
| Conditions (if any) | … |

[If the verdict flipped after fix → §Resolution: (a) what changed, (b) verification numbers from the re-run, (c) re-scored axes]
````

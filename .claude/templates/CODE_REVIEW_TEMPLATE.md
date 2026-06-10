# CODE_REVIEW Template — `/review` Output Boilerplate

> **Mục đích:** Khung cố định 7 section cho `reports/CODE_REVIEW.md`. Agent `/review` **chỉ fill** — KHÔNG re-author structure.
>
> Quy tắc chi tiết (Five-Axis, `Relates-to` mandatory, OPEN-XXX closure): [`../commands/review.md`](../commands/review.md) §Output File. Nhãn canonical: 🔴 Critical · 🟡 Warning · 🟢 Suggestion · ✅ Good.

---

````markdown
# Code Review — [PR / branch / scope] (`/review` phase)

**Date**: YYYY-MM-DD
**Reviewer**: Code Reviewer agent (Five-Axis Framework)
**Inputs**: specs/SPEC.md · architecture/adr/* · plans/todo.md · security/PRE_DEV_REVIEW.md · reports/TEST_REPORT.md

## 1. Executive Summary
[Overall verdict 1-2 câu] — 🔴 N · 🟡 N · 🟢 N · ✅ N

## 2. Five-Axis Scores

| # | Axis | Score (1–5) | One-line justification |
|---|------|-------------|------------------------|
| 1 | Correctness | … | … |
| 2 | Readability | … | … |
| 3 | Architecture | … | … |
| 4 | Security | … | … |
| 5 | Performance | … | … |

[Nếu REQUEST CHANGES → APPROVED sau fix: re-score và ghi số mới]

## 3. Findings (by severity: 🔴 → 🟡 → 🟢 → ✅)

### 🔴 Critical
- **[file:line]** [Description] — [Recommendation] — *Relates-to: <US-XXX | RC-X.Y | ADR-NNN | T-XX | S1..E10>*

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
[Cite numbers từ reports/TEST_REPORT.md]. Mọi `OPEN-XXX` debt từ `/test`:

| OPEN-XXX | Disposition |
|----------|-------------|
| OPEN-001 | CLOSED / DEFERRED-to-Pn / ESCALATED — [lý do] |

## 6. Compliance Check

| Rule | Status | Notes |
|------|--------|-------|
| clean-code.md | PASS / WARNING / FAIL | … |
| code-style.md | … | … |
| error-handling.md | … | … |
| security.md | … | … |
| database.md | … | … |
| api-conventions.md | … | … |
| testing.md | … | … |
| [mọi rule còn lại trong .claude/rules/] | … | … |

## 7. Approval Status

| Decision | APPROVE / REQUEST CHANGES / NEEDS DISCUSSION |
|----------|----------------------------------------------|
| Conditions (if any) | … |

[Nếu verdict flipped sau fix → §Resolution: (a) what changed, (b) verification numbers từ re-run, (c) re-scored axes]
````

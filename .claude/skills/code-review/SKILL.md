---
name: code-review
description: Five-axis code review for comprehensive quality assessment
---

# Code Review & Quality Skill

## Philosophy

> "Approve a change when it definitely improves overall code health, even if it isn't perfect."

Progress over perfection. Continuous incremental improvement.

---

## Five-Axis Review Framework

### Axis 1: Correctness

**Questions to ask:**
- Does the implementation match the specification?
- Are edge cases handled?
- Are error paths covered?
- Are there potential runtime issues?
  - Off-by-one errors
  - Race conditions
  - Null/undefined access
  - Resource leaks

**Test adequacy:**
- Do tests verify the claimed behavior?
- Are negative cases tested?
- Would a bug slip through?

---

### Axis 2: Readability & Simplicity

**Questions to ask:**
- Can another engineer understand this without explanation?
- Are names clear and descriptive?
- Is control flow straightforward?
- Is the code organized logically?

**Complexity checks:**
- Deep nesting (> 3 levels)?
- Long functions (> 30 lines)?
- Clever tricks that obscure intent?
- Unnecessary abstractions?

---

### Axis 3: Architecture

**Questions to ask:**
- Does this follow existing patterns in the codebase?
- Are module boundaries respected?
- Is there code duplication that should be extracted?
- Is the abstraction level appropriate?
- Do dependencies flow in the right direction?

**Over-engineering checks:**
- Is this simpler than it needs to be?
- Are there abstractions "for future use"?
- Would a simpler approach work?

---

### Axis 4: Security

**Input validation:**
- Is user input validated and sanitized?
- Are queries parameterized?
- Is output properly encoded?

**Authentication & Authorization:**
- Are auth checks in place?
- Is ownership verified for resources?
- Are permissions enforced?

**Secrets management:**
- No hardcoded secrets?
- Sensitive data excluded from logs?
- External data treated as untrusted?

---

### Axis 5: Performance

**Common issues:**
- N+1 query patterns?
- Unbounded operations (loops, queries)?
- Missing pagination?
- Unnecessary re-renders (React)?
- Objects created in hot paths?
- Missing indexes for queries?

**Async handling:**
- Are async operations properly awaited?
- Could operations be parallelized?

---

## Change Sizing Guidelines

| Size | Lines | Guidance |
|------|-------|----------|
| **Ideal** | ~100 | Easy to review thoroughly |
| **Acceptable** | ~300 | Requires focused review |
| **Too Large** | 1000+ | Split into smaller PRs |

Each PR should be **one logical change**, not an entire feature.

---

## Comment Severity Labels

> **Canonical vocabulary — must match `commands/review.md` and `references/code-review-checklist.md`.** Findings in `reports/CODE_REVIEW.md` use these four labels only.

| Label | Meaning | Action Required |
|-------|---------|-----------------|
| 🔴 **Critical** | Merge blocker — correctness, security, data loss | Must fix before merge |
| 🟡 **Warning** | Significant issue — should fix, potential bug or rule violation | Address or explicitly accept before merge |
| 🟢 **Suggestion** | Improvement — readability, style, micro-optimization | Optional, author's choice |
| ✅ **Good** | Praise — highlight what's done well | None (positive signal) |

> Free-form `FYI:` / `Question:` comments are allowed inline in the PR but do not constitute a tracked finding and do not appear in `reports/CODE_REVIEW.md`.

**Examples:**
```
🔴 Critical: This allows SQL injection via the `name` parameter (UsersController.cs:42).

🟡 Warning: `OnChallenge` throws across an await boundary, causing 401s to log at Error severity.

🟢 Suggestion: Consider renaming `data` to `userData` for clarity.

✅ Good: Nice use of the Result pattern here — error handling is much cleaner.
```

---

## Review Process

### Step 1: Understand Context

- What is this PR trying to achieve?
- Is there a linked issue or spec?
- What's the scope of changes?

### Step 2: Review Tests First

Tests reveal:
- What behavior is expected
- What edge cases are considered
- Whether coverage is adequate

### Step 3: Examine Implementation

Walk through changes with the 5 axes in mind.

### Step 4: Categorize Findings

Use the canonical four labels (see *Comment Severity Labels* above):

- 🔴 **Critical** — Correctness, security, data-loss, merge blocker
- 🟡 **Warning** — Significant issue (architecture violation, rule non-compliance, latent bug)
- 🟢 **Suggestion** — Readability, style, micro-optimization
- ✅ **Good** — Praise-worthy patterns to highlight

### Step 5: Provide Actionable Feedback

```
❌ "This is confusing"

✅ "This nested conditional is hard to follow. Consider extracting 
    the inner logic to a named function like `isEligibleForDiscount()`"
```

---

## Review Output Format

```markdown
## Review: [PR Title]

### Summary
[1-2 sentences on overall assessment]

### 🔴 Critical
- **[file:line]** [Issue description] — *Relates-to: US-XXX | RC-X.Y | ADR-NNN*

### 🟡 Warning
- **[file:line]** [Issue description] — *Relates-to: …*

### 🟢 Suggestion
- **[file:line]** [Suggestion] — *Relates-to: …*

### ✅ Good
- **[file:line]** [What's done well]

### Verdict
- [ ] Approve
- [ ] Request changes
- [ ] Needs discussion
```

---

## Rules

- **Don't accept "I'll clean it up later"** — It won't happen
- **Remove dead code** — Don't comment it out
- **Review within 1 business day** — Faster is better
- **Be kind, not nice** — Honest feedback helps everyone
- **One approval minimum** — Before any merge

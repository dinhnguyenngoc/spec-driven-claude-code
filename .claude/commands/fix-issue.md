---
name: fix-issue
description: Analyze and fix a reported bug or issue systematically
---

# /fix-issue — Bug Fix

> "Fix root causes, not symptoms."

## Purpose

Analyze and fix a **reported** bug or issue systematically. This command handles issues from external sources (QA, production, users, issue trackers).

## When to Use

| Situation | Command |
|-----------|---------|
| Bug report from QA/Production/Users | → `/fix-issue` |
| Jira/Linear ticket or issue tracker | → `/fix-issue` |
| `BUG-###` filed in `reports/TEST_REPORT.md` §8, or a failure in `reports/VERIFY_REPORT.md` §3 | → `/fix-issue` |
| `/build` or `/test` fails unexpectedly | → `/debug` |
| Error occurs during development | → `/debug` |

## Usage

```text
/fix-issue JIRA-456               # Fix Jira ticket
/fix-issue LIN-123                # Fix Linear ticket
/fix-issue "Users cannot login"   # Fix bug from description
```

## Process

### 1. Understand the Issue

- Read the error message or bug description carefully
- Identify the affected component(s)
- Reproduce the issue locally if possible

### 2. Issue Source Analysis

**Identify the source and context of the issue:**

```bash
# Check related commits referencing the ticket
git log --grep="JIRA-456" --oneline
git log --grep="LIN-123" --oneline

# Check production logs (if applicable)
# Review Grafana dashboards, Serilog logs
```

| Source | Action |
|--------|--------|
| Jira/Linear ticket | Link ticket, check acceptance criteria, extract reproduction steps |
| `BUG-###` (TEST_REPORT §8) / VERIFY_REPORT §3 | **Reuse the already-written failing regression test + root cause `file:line` + proposed fix from the report** — do not re-author from scratch |
| Production logs | Identify stack trace, affected users |
| User report | Clarify steps to reproduce |

> **Brownfield (Mode: brownfield — flow B3):** if the area being fixed has no tests, write a **characterization test first** (capture current behavior, PASS) before touching the code — per `rules/brownfield.md`. The bug's regression test then documents the *intended* behavior change.

### 3. Root Cause Analysis

```bash
# Check recent git changes
git log --oneline -20

# Check changes to affected files
git log -p --follow -- src/Services/OrderService.cs

# Search for related code
grep -rn "MethodName" src/
```

- Review affected files
- Look for related tests that may reveal expected behavior
- Check logs for stack traces

### 4. Plan the Fix

- Identify the minimal change needed
- Consider side effects on other components
- Update or add tests to cover the fix

### 5. Implement

- Make the targeted fix
- Ensure code follows `.claude/rules/code-style.md`
- Handle errors per `.claude/rules/error-handling.md`

### 6. Verify

```bash
# Run relevant tests
dotnet test --filter "FullyQualifiedName~OrderServiceTests"

# Run full test suite
dotnet test

# Check build
dotnet build --no-restore

# Run analyzers
dotnet format --verify-no-changes
```

### 7. Commit

Follow `.claude/rules/git-workflow.md`:

```text
fix(orders): correct total calculation with percentage discounts

- Fixed rounding issue when applying percentage discounts
- Added unit test for edge case with 0.5% discount

Refs: JIRA-456
```

**Issue linking conventions:**

| Platform | Syntax |
|----------|--------|
| Jira | `Refs: JIRA-456`, `JIRA-456` |
| Linear | `Fixes LIN-123` |

---

## Debugging Tools

> See the `/debug` command for full details.

**Quick reference:**

```bash
# .NET diagnostic tools
dotnet-trace collect --process-id <PID>
dotnet-dump analyze <dump-file>
dotnet-counters monitor --process-id <PID>

# Git bisect for regressions
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>
```

---

## Bug Fix Checklist

- [ ] Issue reproduced locally
- [ ] Root cause identified (`file:line`)
- [ ] Regression test written (fails before fix)
- [ ] If the bug is a **handoff** (producer→consumer: nav-state key / context / event name / shared prop) → the regression test exercises **both ends together** (`references/scenario-traceability.md` §3) — two sides passing in isolation does not cover the join
- [ ] Fix implemented
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No new warnings
- [ ] Commit message references issue

---

## Common Issue Patterns

### Null Reference

```csharp
// Before
var name = user.Profile.DisplayName;

// After
var name = user?.Profile?.DisplayName ?? "Unknown";
```

### N+1 Query

```csharp
// Before
var orders = await _context.Orders.ToListAsync();
foreach (var order in orders)
{
    order.Items = await _context.OrderItems
        .Where(i => i.OrderId == order.Id)
        .ToListAsync();
}

// After
var orders = await _context.Orders
    .Include(o => o.Items)
    .ToListAsync();
```

### Async Deadlock

```csharp
// Before (deadlock risk)
var result = _service.GetDataAsync().Result;

// After
var result = await _service.GetDataAsync();
```

### Missing Validation

```csharp
// Before
public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
{
    var order = new Order { /* map from request */ };
    // No validation!
}

// After
public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
{
    var validationResult = await _validator.ValidateAsync(request);
    if (!validationResult.IsValid)
    {
        var errors = validationResult.Errors
            .GroupBy(e => e.PropertyName)
            .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
        throw new ValidationException(errors);
    }
    
    var order = new Order { /* map from request */ };
}
```

---

## Agent

Invoke: **Backend Developer** or **Frontend Developer** depending on the issue location.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

The exit depends on **where the bug was found**:
- **Dev-time** (during the build cycle, no candidate artifact yet) → after the fix is verified, run `/review`.
- **Found by `/verify` or `/hotfix`** (a candidate artifact already exists) → the **caller owns the continuation**: rebuild the artifact and **re-run `/verify` from Phase 0** on the new digest (per `verify.md`) — do **not** stop at `/review` (`/review` already passed for the prior digest; the fix needs proof on the artifact that will ship).

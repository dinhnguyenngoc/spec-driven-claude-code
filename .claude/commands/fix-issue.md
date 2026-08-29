---
name: fix-issue
description: Analyze and fix a reported bug or issue systematically
---

# /fix-issue — Bug Fix

> "Fix root causes, not symptoms."

## Purpose

Analyze and fix a **reported** bug or issue systematically. This command handles issues from external sources (QA, production, users, issue trackers).

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

> **Stack Profile note:** the `dotnet` commands and C# examples below use the **default profile**. **Core = Node.js** → map to the npm equivalents (`npm test`, `tsc --noEmit`, `npm run build`; debug tooling per the declared stack) — the Common Issue Patterns are default-stack illustration only (`rules/overrides/lang-nodejs.md` idioms apply). **Core = PHP** → `php artisan test` / `vendor/bin/pest` for the suite, `vendor/bin/pint --test` + `vendor/bin/phpstan analyse` for the format/analyzer steps (`rules/overrides/lang-php.md` + `test-php.md` idioms apply).

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

> **Expected behavior must have a source — ambiguity in a fix is a spec question.** If the *expected* behavior cannot be derived from `specs/`, existing tests, or the bug report — i.e. there is no *test oracle*: no authoritative answer to "what is correct here?" — treat it as **blocking**: stop and ask before writing the fix (per `principles-and-practices.md` §2.5); a wrong guess here ships fast. Implementation details follow the standard ladder; any non-blocking behavior assumption you do make is recorded as `A-xx` in the commit body + completion summary for review.

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

> **Fix requires a schema change?** The migration follows [`rules/database.md`](../rules/database.md) §Expand-contract — incident pressure is exactly when a one-step `RENAME`/`DROP COLUMN`/`NOT NULL` is most tempting and most dangerous (it voids image-tag rollback — `deploy.md` Step 5 note). And refresh **`db/schema-snapshot/` in the SAME change-set** (re-export from the test container once the migration has applied there — `rules/brownfield.md` checklist): the dev-time exit of this command goes to `/review` **without passing `/test` Task 7**, so nobody downstream will refresh it for you.

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

Per `CLAUDE.md` §Verification After Delegation, the **orchestrator re-runs the gate-deciding checks itself** (`dotnet test` full suite + Release build + `dotnet format --verify-no-changes` — or their npm equivalents) and confirms the regression test exists and passes on disk — the sub-agent's report is not ground truth.

- [ ] Issue reproduced locally
- [ ] Root cause identified (`file:line`)
- [ ] Expected behavior sourced from spec/tests/report — any assumption made is recorded (`A-xx`)
- [ ] **Every `A-xx` dispositioned by the user before closing** (same mechanism as `/build` Gate 5): approved → one-line AC amendment on the affected story in `specs/` (marked `amended @ fix, A-xx`) + an `Amended` Revision History row (BA agent §semantics); rejected → the fix returns to rework. No behavior decision may live only in the commit body (`principles-and-practices.md` §2.5) — this applies on BOTH exits (dev-time → `/review`, and verify/hotfix → before the re-verify)
- [ ] Regression test written (fails before fix)
- [ ] **New-call precondition check** — the fix replaces an expression with a library/framework
      call on request-derived input? Then: (1) name the new call's preconditions (type, format,
      nullability); (2) enforce them at the boundary per the stack's validation rule
      (`lang-nodejs.md` §Schema validation at the boundary · `api-conventions.md` FluentValidation ·
      `framework-php-laravel.md` §D) — **this enforcement is part of the fix, not out of scope**:
      swapping a total operation (`!==` never throws) for a partial one (`bcrypt.compare` throws on
      non-string) changes the endpoint's input contract, and the fix owns that change; (3) add one
      test sending a type-violating value (object where a string is expected) through the real route.
- [ ] If the bug is a **handoff** (producer→consumer: nav-state key / context / event name / shared prop) → the regression test exercises **both ends together** (`references/scenario-traceability.md` §3) — two sides passing in isolation does not cover the join
- [ ] Fix implemented
- [ ] **(schema-touching fix)** migration classified **non-destructive / destructive** per `database.md` §Expand-contract — destructive ⇒ expand-contract phases or ADR + downtime window, never one step under incident pressure; and `db/schema-snapshot/` refreshed **in the same change-set**
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No new warnings
- [ ] **Out-of-scope findings recorded, not just narrated** — anything noticed outside this fix's
      scope (dead code, a sibling gap, a stale report) is written where `principles-and-practices.md`
      §2.5's routing table sends it (AC ambiguity → SPEC Open Questions · tech debt → `plans/BACKLOG.md`
      · security → carry-forward row), and the closing summary cites that location. This is
      the **out-of-scope** channel — distinct from in-scope assumptions, which follow the `A-xx` log
      above. A finding stated only in chat is not recorded.
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

> Sub-agent prompt MUST include: "Output language: \<declared language — resolve from Project Profile → Output Language\> for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

> Sub-agent prompt MUST also include: "Ambiguity policy: implementation details → decide per rules, never ask; non-blocking behavior/contract gaps → implement the most conservative interpretation and add an Assumptions-log entry (`A-xx`); blocking or expensive-if-wrong gaps → stop and return early with the question (see `rules/principles-and-practices.md` §2.5). Return every `A-xx` entry (or 'Assumptions: none') in your completion report — the orchestrator owns the disposition checklist item (both exits) and the `amended @ fix, A-xx` spec flow-back."

## Next Step

The exit depends on **where the bug was found**:
- **Dev-time** (during the build cycle, no candidate artifact yet) → after the fix is verified, run `/review`.
- **Found by `/verify` or `/hotfix`** (a candidate artifact already exists) → the **caller owns the continuation**: rebuild the artifact and **re-run `/verify` from Phase 0** on the new digest (per `verify.md`) — do **not** stop at `/review` (`/review` already passed for the prior digest; the fix needs proof on the artifact that will ship).

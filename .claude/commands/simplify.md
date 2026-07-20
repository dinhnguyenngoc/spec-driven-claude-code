---
name: simplify
description: Reduce complexity without changing behavior — code simplification
---

# /simplify — Code Simplification

> "Complexity is the enemy of execution."

## Purpose

Simplify code for clarity and maintainability. Reduce complexity **without changing behavior**.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

> **Stack Profile note:** the `dotnet` commands and C# catalog below use the **default profile**. **Core = Node.js** → map to the npm equivalents (`npm test`, `npm run build`); the Common Simplifications are default-stack illustration — apply the equivalent TS idioms per `rules/overrides/lang-nodejs.md` (early returns, discriminated unions + `switch`, arrow shorthand).

## When to Use

- After `/review` identifies complexity issues
- When code is hard to understand
- Before adding new features to tangled code
- During tech debt cleanup sprints

## Principles

### Chesterton's Fence

> Before removing something, understand why it exists.

Don't delete code just because it looks unnecessary. Investigate:
- Git history: `git log -p -- path/to/file`
- Related tests
- Comments or documentation
- Ask team members if unsure

### Rule of 500

If a **file or class** exceeds ~500 lines, it likely needs splitting. (Methods have a much tighter bar: **~30 lines** per `rules/code-style.md` — see the Step 3 table.)

### Brownfield (Mode: brownfield)

`/simplify` is where the tech-debt backlog lands (per `rules/brownfield.md` §No Gratuitous Refactor). Two extra disciplines apply:
- **Characterization-test-first** for any untested area is now the general Step 0 (applies to every mode) — brownfield just hits it most often.
- Stay **within the assigned area** — do not "tidy up" unrelated code in the same pass.

---

## Workflow

### Step 0: Establish a green baseline (before touching any line)

`/simplify`'s entire promise is **behavior unchanged** — provable only if the test net is GREEN **before** and **after**. So first:

1. **Run the suite covering the target area — confirm GREEN.** If RED/flaky → fix or quarantine first; **never simplify on a red base** (you cannot tell "I preserved behavior" from "the test never caught it").
2. **If the target area has no tests → write a characterization test first** (capture current behavior, runs GREEN) — **regardless of mode** (greenfield or brownfield). That net is what makes "behavior unchanged" a checkable claim, not a hope.

### Step 1: Identify Target

```bash
# Recently modified complex code
git diff --stat HEAD~10

# Or specify scope
# "Simplify the OrderService class"
```

### Step 2: Understand Before Changing

1. **Read the code** — What does it do?
2. **Check tests** — What behaviors are verified?
3. **Trace callers** — Who uses this code?
4. **Note edge cases** — Any special handling?

### Step 3: Identify Opportunities

| Pattern | Simplification |
|---------|---------------|
| Deep nesting (> 3 levels) | Guard clauses, extract helpers |
| Long methods (> 30 lines) | Split by responsibility |
| Nested ternaries | `if/else` or `switch` expression |
| Unclear names | Rename for clarity |
| Duplicated code | Extract shared method |
| Dead code | Remove entirely |
| Complex conditionals | Extract to named method |
| Magic numbers | Named constants |

### Step 4: Apply Incrementally

**One change at a time:**

```csharp
// Before: Deep nesting
public async Task ProcessOrderAsync(Order order)
{
    if (order != null)
    {
        if (order.Items.Count > 0)
        {
            if (order.Status == OrderStatus.Pending)
            {
                // ... actual logic buried here
            }
        }
    }
}

// After: Guard clauses
public async Task ProcessOrderAsync(Order order)
{
    if (order is null) return;
    if (order.Items.Count == 0) return;
    if (order.Status != OrderStatus.Pending) return;

    // ... actual logic at top level
}
```

**Run tests after each change.**

### Step 5: Validate

```bash
# All tests pass
dotnet test

# Build succeeds
dotnet build

# Behavior unchanged (manual check if needed)
```

### Step 6: If Tests Fail

**Revert immediately.** Don't debug while mid-simplification.

```bash
git checkout -- .
```

Then:
1. Reassess the change
2. Make a smaller change
3. Or add missing tests first

---

## Common Simplifications

### Extract Guard Clauses

```csharp
// Before
public decimal GetDiscount(User user)
{
    if (user != null)
    {
        if (user.Membership == MembershipType.Premium)
        {
            return 0.2m;
        }
        else
        {
            return 0.1m;
        }
    }
    return 0m;
}

// After
public decimal GetDiscount(User user)
{
    if (user is null) return 0m;
    if (user.Membership == MembershipType.Premium) return 0.2m;
    return 0.1m;
}
```

### Extract Named Methods

```csharp
// Before
var eligibleUsers = users.Where(u => 
    u.Age >= 18 && u.IsVerified && !u.IsBanned && u.SubscriptionType != SubscriptionType.Free
);

// After
private static bool IsEligible(User user) =>
    user.Age >= 18 && 
    user.IsVerified && 
    !user.IsBanned && 
    user.SubscriptionType != SubscriptionType.Free;

var eligibleUsers = users.Where(IsEligible);
```

### Use Switch Expressions

```csharp
// Before
public string GetOrderStatus(bool isPaid, bool isShipped)
{
    if (!isPaid)
        return "pending";
    else if (!isShipped)
        return "processing";
    else
        return "complete";
}

// After
public string GetOrderStatus(bool isPaid, bool isShipped) => (isPaid, isShipped) switch
{
    (false, _) => "pending",
    (true, false) => "processing",
    (true, true) => "complete"
};
```

### Use Pattern Matching

```csharp
// Before
public decimal CalculateShipping(object item)
{
    if (item is Book)
        return 2.99m;
    else if (item is Electronics electronics)
        return electronics.Weight * 0.5m;
    else if (item is null)
        return 0m;
    else
        return 5.99m;
}

// After
public decimal CalculateShipping(object item) => item switch
{
    null => 0m,
    Book => 2.99m,
    Electronics e => e.Weight * 0.5m,
    _ => 5.99m
};
```

### Remove Dead Code

```csharp
// Before
public decimal Calculate(decimal a, decimal b)
{
    // var oldResult = LegacyCalculate(a, b);  // Commented out
    var result = a + b;
    // Debug.WriteLine($"Debug: {result}");  // Debug log
    return result;
}

// After
public decimal Calculate(decimal a, decimal b) => a + b;
```

### Use Expression-Bodied Members

```csharp
// Before
public string FullName
{
    get
    {
        return $"{FirstName} {LastName}";
    }
}

// After
public string FullName => $"{FirstName} {LastName}";
```

---

## Red Flags

Stop if you find yourself:

- Changing behavior while "simplifying"
- Unable to explain why code exists
- Simplifying without tests
- Making changes across unrelated files
- Creating new abstractions

---

## Output

- Simpler, clearer code
- All tests still passing
- Atomic commits with clear messages

## Orchestrator verification (run BEFORE accepting the result)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied to a command that modifies production code:

- [ ] **Green-after, verified** — re-run the full suite + build yourself (`dotnet test` + `dotnet build -c Release`, or the npm equivalents); compare against the Step-0 green baseline. Any new red → apply Step 6 (revert), don't debug mid-simplification.
- [ ] **Scope, verified** — `git diff --stat` touches ONLY the assigned area's files; an unrelated file in the diff = the no-gratuitous-refactor rule was broken — revert that file and surface it.
- [ ] **No new abstractions / no behavior-bearing diff** — spot-check the diff for added public surface or changed conditionals beyond the catalogued simplification patterns (Red Flags list).

Any mismatch → fix on disk first.

## Agent

Invoke: **Code Reviewer** (simplification mode)

The Code Reviewer agent applies the same quality lens used in `/review`, but focuses specifically on reducing complexity while preserving behavior.

**Phase ownership** — the sub-agent cannot converse with the user: a Chesterton's-Fence case it cannot resolve ("ask team members if unsure" — attach the git-history evidence already checked), or the need to **quarantine a flaky test** in Step 0 (disabling part of the safety net is a user-visible decision) → **return early** with the item instead of deciding alone. The orchestrator confirms, runs the verification block above, and presents the result in the main loop.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

Run `/review` to verify improvements.

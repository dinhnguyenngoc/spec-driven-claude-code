---
name: tdd
description: Write tests before code using RED-GREEN-REFACTOR cycle
---

# Test-Driven Development Skill

## Overview

TDD transforms testing from an afterthought into the foundation of development. Tests are proof that code works correctly.

## When to Invoke

- Writing new features
- Fixing bugs (Prove-It pattern)
- When asked to write tests
- Before any implementation work

---

## Core Cycle: RED-GREEN-REFACTOR

### RED Phase

Write a test that describes expected behavior. **It must fail.**

```csharp
public class DiscountCalculatorTests
{
    private readonly DiscountCalculator _sut;

    public DiscountCalculatorTests()
    {
        _sut = new DiscountCalculator();
    }

    [Fact]
    public void Calculate_WhenOrderOverThreshold_AppliesTenPercentDiscount()
    {
        // Arrange
        var orderAmount = 150m;

        // Act
        var discount = _sut.Calculate(orderAmount);

        // Assert
        discount.Should().Be(15m);
    }
}
```

Run: `dotnet test` → Should **FAIL**

### GREEN Phase

Write **minimal** code to pass the test. No extras.

```csharp
public class DiscountCalculator
{
    public decimal Calculate(decimal amount)
    {
        if (amount > 100)
            return amount * 0.1m;
        return 0;
    }
}
```

Run: `dotnet test` → Should **PASS**

### REFACTOR Phase

Improve code while keeping tests green.

```csharp
public class DiscountCalculator
{
    private const decimal DiscountThreshold = 100m;
    private const decimal DiscountRate = 0.1m;

    public decimal Calculate(decimal amount)
    {
        if (amount <= DiscountThreshold)
            return 0;
        
        return amount * DiscountRate;
    }
}
```

Run: `dotnet test` → Should still **PASS**

---

## Prove-It Pattern (Bug Fixes)

### Step 1: Write Failing Test

```csharp
[Fact]
public void GetTotal_WhenCartIsEmpty_ReturnsZeroWithoutError()
{
    // Arrange — This test should FAIL with buggy code
    var cart = new Cart(items: Array.Empty<CartItem>());

    // Act
    var act = () => cart.GetTotal();

    // Assert
    act.Should().NotThrow();
    cart.GetTotal().Should().Be(0);
}
```

### Step 2: Verify Failure

Run test → Confirms bug exists

### Step 3: Fix Bug

```csharp
public decimal GetTotal()
{
    if (Items.Count == 0)
        return 0;  // Fix: handle empty cart
    
    return Items.Sum(item => item.Price * item.Quantity);
}
```

### Step 4: Verify Pass

Run test → Confirms fix works

### Step 5: Run Full Suite

```bash
dotnet test  # No regressions
```

---

## Test patterns & assertions — canonical in `testing.md`

> The pattern catalog — **Test Pyramid, AAA structure, Test Doubles preference order, naming convention, `WebApplicationFactory` integration templates, FluentAssertions, coverage thresholds, and the full `dotnet test` command list** — lives in [`../../rules/testing.md`](../../rules/testing.md). This skill owns the **RED-GREEN-REFACTOR cycle + Prove-It bug-fix pattern** above; do not re-document the catalog here.

---

## DAMP > DRY in Tests

Tests should be **Descriptive And Meaningful Phrases**.

```csharp
// ✅ DAMP — Self-contained and clear
[Fact]
public void ValidatePassword_WhenMissingUppercase_ReturnsInvalidWithError()
{
    // Arrange
    var validator = new PasswordValidator();
    
    // Act
    var result = validator.Validate("lowercase123!");
    
    // Assert
    result.IsValid.Should().BeFalse();
    result.Errors.Should().Contain("Must contain uppercase letter");
}

// ❌ Too DRY — Requires reading shared context
[Fact]
public void RejectsInvalidPassword()
{
    Validate(InvalidPasswordNoUpper).Should().BeFalse();
}
```

---

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Testing internals | Breaks on refactor | Test behavior, not implementation |
| Flaky tests | Erodes trust | Use deterministic data |
| Over-mocking | False confidence | Prefer real implementations |
| Snapshot abuse | Large diffs ignored | Use sparingly |
| Shared mutable state | Tests affect each other | Use fresh instances or IClassFixture |
| Testing frameworks | Wasted effort | Only test your code |

---

## Verification Checklist

- [ ] All new code has tests
- [ ] Bug fixes have reproduction tests
- [ ] Tests describe behavior (readable names)
- [ ] No skipped tests
- [ ] Coverage maintained/improved (≥ 80%)
- [ ] Full suite passes

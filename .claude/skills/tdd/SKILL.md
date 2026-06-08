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

## Test Pyramid

```
         ┌─────────┐
         │   E2E   │  5%  — Critical user flows
         │  Tests  │       Full system, minutes
         ├─────────┤
         │ Integr. │  15% — API + DB interactions
         │  Tests  │       Seconds
         ├─────────┤
         │  Unit   │  80% — Pure logic
         │  Tests  │       Milliseconds
         └─────────┘
```

---

## Test Structure: AAA Pattern

```csharp
[Fact]
public void CalculateTax_ForCaliforniaOrder_ReturnsCorrectRate()
{
    // Arrange — Setup
    var order = new Order { State = "CA", Subtotal = 100m };
    var taxService = new TaxService();
    
    // Act — Execute
    var tax = taxService.Calculate(order);
    
    // Assert — Verify
    tax.Should().Be(7.25m);
}
```

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

## Test Doubles (Preference Order)

1. **Real implementations** — Best, but may be slow
2. **Fakes** — In-memory DB, simplified implementations
3. **Stubs** — Return canned responses
4. **Mocks** — Verify interactions (use sparingly)

```csharp
// ✅ Prefer: Real or fake (In-Memory EF Core)
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseInMemoryDatabase(Guid.NewGuid().ToString())
    .Options;
await using var context = new AppDbContext(options);
var user = await userService.CreateAsync(context, userData);

// ⚠️ Use sparingly: Mocks
var mockRepo = new Mock<IUserRepository>();
mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>()))
    .ReturnsAsync(expectedUser);
```

---

## Naming Conventions

```csharp
// Pattern: Method_Scenario_ExpectedResult

// ✅ Good
"GetByIdAsync_WhenUserExists_ReturnsUser"
"CreateAsync_WithInvalidEmail_ThrowsValidationException"
"SendWelcomeEmailAsync_AfterRegistration_SendsEmail"

// ❌ Bad
"WorksCorrectly"
"TestUserCreation"
"HandlesError"
```

---

## Integration Tests with WebApplicationFactory

```csharp
public class UsersControllerTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public UsersControllerTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetById_WhenUserExists_Returns200WithUser()
    {
        // Arrange
        var userId = Guid.Parse("...");

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{userId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
    }
}
```

---

## FluentAssertions Cheatsheet

```csharp
// Basic
result.Should().NotBeNull();
result.Should().Be(expected);
result.Should().BeEquivalentTo(expected);

// Collections
items.Should().HaveCount(3);
items.Should().Contain(x => x.IsActive);
items.Should().BeInAscendingOrder(x => x.Name);

// Exceptions
var act = () => _sut.Process(null);
act.Should().Throw<ArgumentNullException>();

// Async exceptions
var act = async () => await _sut.ProcessAsync(null);
await act.Should().ThrowAsync<ValidationException>();
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

## Test Commands

```bash
# Run all tests
dotnet test

# Run with verbosity
dotnet test --logger "console;verbosity=detailed"

# Run specific project
dotnet test tests/MyApp.UnitTests

# Run with filter
dotnet test --filter "FullyQualifiedName~DiscountCalculator"

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Watch mode
dotnet watch test --project tests/MyApp.UnitTests
```

---

## Verification Checklist

- [ ] All new code has tests
- [ ] Bug fixes have reproduction tests
- [ ] Tests describe behavior (readable names)
- [ ] No skipped tests
- [ ] Coverage maintained/improved (≥ 80%)
- [ ] Full suite passes

# Testing Patterns Reference

> Quick reference for test patterns. See [`.claude/rules/testing.md`](../rules/testing.md) for full rules.

## When this is used: `/build` vs `/test`

Per [CLAUDE.md](../CLAUDE.md), the testing strategy splits across two SDLC phases:

| Phase | Test types | Dependencies | Docker? |
|-------|-----------|--------------|---------|
| `/build` | Unit (Moq) + Integration (EF Core In-Memory / `WebApplicationFactory`) | Fakes / in-memory | ❌ Not required |
| `/test`  | Integration (TestContainers — real SQL Server / Redis / Kafka) + E2E (Playwright) | Real services in containers | ✅ Required |

→ Use the **Unit / In-Memory** patterns below during `/build` for fast feedback. Promote to **TestContainers / E2E** patterns during `/test` before the `/review` gate.

---

## Test Pyramid

```
         ┌─────────┐
         │   E2E   │  5%   Critical user flows
         ├─────────┤
         │  Integ  │  15%  API + DB interactions
         ├─────────┤
         │  Unit   │  80%  Pure logic, fast
         └─────────┘
```

## Test Structure (AAA)

```csharp
[Fact]
public void CheckPermission_WhenUserIsAdmin_ReturnsTrue()
{
    // Arrange — Setup
    var user = CreateTestUser(role: UserRole.Admin);
    var service = new PermissionService();
    
    // Act — Execute
    var result = service.CheckPermission(user, "delete");
    
    // Assert — Verify
    result.Should().BeTrue();
}
```

## Unit Test Example

```csharp
public class DiscountCalculatorTests
{
    private readonly DiscountCalculator _sut;

    public DiscountCalculatorTests()
    {
        _sut = new DiscountCalculator();
    }

    [Fact]
    public void Calculate_WhenOrderOver100_Returns10Percent()
    {
        _sut.Calculate(150m).Should().Be(15m);
    }

    [Fact]
    public void Calculate_WhenOrderUnder100_ReturnsZero()
    {
        _sut.Calculate(50m).Should().Be(0m);
    }

    [Theory]
    [InlineData(100, 0)]
    [InlineData(101, 10.1)]
    [InlineData(200, 20)]
    public void Calculate_EdgeCases(decimal amount, decimal expected)
    {
        _sut.Calculate(amount).Should().Be(expected);
    }
}
```

## Integration Test Example

```csharp
public class UsersControllerTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;
    private readonly CustomWebApplicationFactory _factory;

    public UsersControllerTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CreateUser_WithValidData_Returns201()
    {
        // Arrange
        var request = new CreateUserRequest
        {
            Email = $"test-{Guid.NewGuid()}@example.com",
            Name = "Test User"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/users", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        
        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
        user!.Email.Should().Be(request.Email);

        // Verify in database
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var dbUser = await context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
        dbUser.Should().NotBeNull();
    }
}
```

## E2E Test Example (Playwright)

```csharp
[Fact]
public async Task UserCanCompleteCheckoutFlow()
{
    await using var playwright = await Playwright.CreateAsync();
    var browser = await playwright.Chromium.LaunchAsync();
    var page = await browser.NewPageAsync();

    // Login
    await page.GotoAsync("https://localhost:5001/login");
    await page.FillAsync("[name='email']", "user@example.com");
    await page.FillAsync("[name='password']", "password");
    await page.ClickAsync("button[type='submit']");

    // Add to cart
    await page.GotoAsync("https://localhost:5001/products/1");
    await page.ClickAsync("button:has-text('Add to Cart')");

    // Checkout
    await page.GotoAsync("https://localhost:5001/checkout");
    await page.FillAsync("[name='card']", "4242424242424242");
    await page.ClickAsync("button:has-text('Pay')");

    // Verify
    await Expect(page.Locator(".success-message")).ToBeVisibleAsync();
}
```

## Test Doubles

```csharp
// 1. Real (preferred) - In-Memory EF Core
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseInMemoryDatabase(Guid.NewGuid().ToString())
    .Options;
using var context = new AppDbContext(options);

// 2. Fake (in-memory implementation)
public class FakeUserRepository : IUserRepository
{
    private readonly List<User> _users = new();
    
    public Task<User?> GetByIdAsync(Guid id)
        => Task.FromResult(_users.FirstOrDefault(u => u.Id == id));
    
    public Task AddAsync(User user)
    {
        _users.Add(user);
        return Task.CompletedTask;
    }
}

// 3. Stub (canned response with Moq)
var mockRepo = new Mock<IUserRepository>();
mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>()))
    .ReturnsAsync(new User { Id = Guid.NewGuid(), Name = "Test" });

// 4. Mock (verify interactions — use sparingly)
_mockEmailService.Verify(
    e => e.SendAsync(It.Is<Email>(m => m.To == user.Email)),
    Times.Once);
```

## Naming Convention

```csharp
// Pattern: Method_Scenario_ExpectedResult

// ✅ Good
"GetByIdAsync_WhenUserNotFound_ReturnsNull"
"CreateAsync_WithInvalidEmail_ThrowsValidationException"
"PlaceOrderAsync_WithValidData_EmitsOrderPlacedEvent"

// ❌ Bad
"Works"
"TestUser"
"ErrorHandling"
```

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
items.Should().OnlyHaveUniqueItems();

// Strings
email.Should().Contain("@");
name.Should().StartWith("John");
message.Should().MatchRegex(@"User \d+ created");

// Exceptions
var act = () => _sut.Process(null);
act.Should().Throw<ArgumentNullException>();

await act.Should().ThrowAsync<ValidationException>()
    .WithMessage("*email*");

// Object comparison
actual.Should().BeEquivalentTo(expected, 
    options => options.Excluding(x => x.CreatedAt));
```

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Testing internals | Breaks on refactor | Test behavior |
| Shared state | Tests affect each other | Use fresh instances |
| Flaky tests | Random failures | Deterministic data |
| Over-mocking | False confidence | Real implementations |
| No assertions | Test always passes | Assert outcomes |
| Magic numbers | Hard to understand | Named constants |

## Coverage Configuration

```xml
<!-- tests/MyApp.UnitTests/MyApp.UnitTests.csproj -->
<PropertyGroup>
    <CollectCoverage>true</CollectCoverage>
    <CoverletOutputFormat>cobertura</CoverletOutputFormat>
    <Threshold>80</Threshold>
    <ThresholdType>line,branch</ThresholdType>
</PropertyGroup>
```

## Commands

```bash
# Run all tests
dotnet test

# Watch mode
dotnet watch test --project tests/MyApp.UnitTests

# Coverage report
dotnet test --collect:"XPlat Code Coverage"

# Run specific tests
dotnet test --filter "FullyQualifiedName~UserServiceTests"

# Run by trait
dotnet test --filter "Category=Unit"
```

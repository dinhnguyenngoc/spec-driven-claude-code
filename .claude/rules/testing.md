# Testing Standards — C# / xUnit

## Testing Pyramid

```
         [E2E Tests]         ← Few, slow, catch integration issues
       [Integration Tests]   ← Some, test component interaction
     [Unit Tests]            ← Many, fast, test isolated logic
```

## Requirements

- Unit test coverage: **minimum 80%**
- All new features must have tests
- All bug fixes must have a regression test
- Tests run in CI before any merge
- Use **xUnit** for testing framework
- Use **FluentAssertions** for readable assertions
- Use **Moq** for mocking dependencies

---

## Test File Organization

```
tests/
├── MyApp.UnitTests/
│   ├── Services/
│   │   ├── UserServiceTests.cs
│   │   └── OrderServiceTests.cs
│   ├── Validators/
│   │   └── CreateUserRequestValidatorTests.cs
│   └── Helpers/
│       └── DateHelperTests.cs
├── MyApp.IntegrationTests/
│   ├── Controllers/
│   │   ├── UsersControllerTests.cs
│   │   └── OrdersControllerTests.cs
│   ├── Repositories/
│   │   └── UserRepositoryTests.cs
│   └── CustomWebApplicationFactory.cs
└── MyApp.E2ETests/
    └── Scenarios/
        └── UserRegistrationTests.cs
```

---

## Unit Test Example (xUnit + FluentAssertions + Moq)

```csharp
// tests/MyApp.UnitTests/Services/UserServiceTests.cs
using FluentAssertions;
using Moq;
using Xunit;

namespace MyApp.UnitTests.Services;

public class UserServiceTests
{
    private readonly Mock<IUserRepository> _mockRepository;
    private readonly Mock<ILogger<UserService>> _mockLogger;
    private readonly UserService _sut; // System Under Test

    public UserServiceTests()
    {
        _mockRepository = new Mock<IUserRepository>();
        _mockLogger = new Mock<ILogger<UserService>>();
        _sut = new UserService(_mockRepository.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task GetByIdAsync_WhenUserExists_ReturnsUser()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var expectedUser = new User { Id = userId, Email = "test@example.com", Name = "Test" };
        _mockRepository.Setup(r => r.GetByIdAsync(userId))
            .ReturnsAsync(expectedUser);

        // Act
        var result = await _sut.GetByIdAsync(userId);

        // Assert
        result.Should().NotBeNull();
        result.Id.Should().Be(userId);
        result.Email.Should().Be("test@example.com");
        _mockRepository.Verify(r => r.GetByIdAsync(userId), Times.Once);
    }

    [Fact]
    public async Task GetByIdAsync_WhenUserNotFound_ThrowsNotFoundException()
    {
        // Arrange
        var userId = Guid.NewGuid();
        _mockRepository.Setup(r => r.GetByIdAsync(userId))
            .ReturnsAsync((User?)null);

        // Act
        var act = () => _sut.GetByIdAsync(userId);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage($"*{userId}*");
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public async Task CreateAsync_WhenEmailIsInvalid_ThrowsValidationException(string? email)
    {
        // Arrange
        var request = new CreateUserRequest { Email = email!, Name = "Test" };

        // Act
        var act = () => _sut.CreateAsync(request);

        // Assert
        await act.Should().ThrowAsync<ValidationException>();
    }
}
```

---

## Integration Test Templates — pick by phase

There are **two templates** for `CustomWebApplicationFactory`. Pick by which phase the test runs in. Both replace the production `DbContextOptions<AppDbContext>` registration so production connection strings are **never** touched during testing.

| Phase | Provider | Docker | Speed | Catches |
|-------|----------|--------|-------|---------|
| `/build` | `UseInMemoryDatabase` | ❌ No | ms | Logic, mapping, validation |
| `/test` | `MsSqlContainer` (TestContainers) | ✅ Yes | seconds | Collation, indexes, transactions, SQL-specific bugs |

> **Host-isolation contract:** Both templates spin up their own isolated dependency (RAM-backed or container-backed). **Neither template should ever connect to `localhost` SQL Server / Redis on the host machine.** If you see `UseSqlServer("Server=localhost;…")` in a test setup, that's a bug.

### Template A — InMemory (for `/build`)

```csharp
// tests/MyApp.IntegrationTests/InMemoryWebApplicationFactory.cs
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace MyApp.IntegrationTests;

public class InMemoryWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase($"TestDb-{Guid.NewGuid()}"));

            // Replace Redis with in-memory distributed cache
            services.AddDistributedMemoryCache();
        });
    }
}
```

> Use this in `/build` integration tests. Untagged — runs under plain `dotnet test`. No `[Trait("Category", "RequiresDocker")]`.

### Template B — TestContainers (for `/test`)

```csharp
// tests/MyApp.IntegrationTests/CustomWebApplicationFactory.cs
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Testcontainers.MsSql;

namespace MyApp.IntegrationTests;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _sqlContainer = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove existing DbContext
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null)
                services.Remove(descriptor);

            // Add test database
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(_sqlContainer.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _sqlContainer.StartAsync();
    }

    public new async Task DisposeAsync()
    {
        await _sqlContainer.DisposeAsync();
    }
}

// tests/MyApp.IntegrationTests/Controllers/UsersControllerTests.cs
namespace MyApp.IntegrationTests.Controllers;

[Trait("Category", "RequiresDocker")]
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
    public async Task GetById_WhenUserExists_Returns200WithUser()
    {
        // Arrange
        var userId = await CreateTestUserAsync();

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{userId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
        user!.Id.Should().Be(userId);
    }

    [Fact]
    public async Task GetById_WhenUserNotFound_Returns404()
    {
        // Arrange
        var nonExistentId = Guid.NewGuid();

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{nonExistentId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Create_WithValidData_Returns201WithUser()
    {
        // Arrange
        var request = new CreateUserRequest
        {
            Email = $"test-{Guid.NewGuid()}@example.com",
            Name = "Test User",
            Password = "Password123!"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/users", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();

        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
        user!.Email.Should().Be(request.Email);
    }

    [Fact]
    public async Task Create_WithInvalidEmail_Returns400()
    {
        // Arrange
        var request = new CreateUserRequest
        {
            Email = "invalid-email",
            Name = "Test User",
            Password = "Password123!"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/users", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    private async Task<Guid> CreateTestUserAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        
        var user = User.Create($"test-{Guid.NewGuid()}@example.com", "Test", "hash");
        context.Users.Add(user);
        await context.SaveChangesAsync();
        
        return user.Id;
    }
}
```

---

## Test Commands

```bash
# Run all tests
dotnet test

# Run specific project
dotnet test tests/MyApp.UnitTests

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run with coverage report
dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage
reportgenerator -reports:./coverage/**/coverage.cobertura.xml -targetdir:./coverage/report

# Run specific test
dotnet test --filter "FullyQualifiedName~UserServiceTests"

# Run tests with specific category
dotnet test --filter "Category=Unit"

# Watch mode
dotnet watch test --project tests/MyApp.UnitTests
```

---

## Naming Conventions

### Test Class Names

```csharp
// Pattern: {ClassUnderTest}Tests
public class UserServiceTests { }
public class CreateUserRequestValidatorTests { }
public class UsersControllerTests { }
```

### Test Method Names

```csharp
// Pattern: {Method}_{Scenario}_{ExpectedResult}
[Fact]
public async Task GetByIdAsync_WhenUserExists_ReturnsUser() { }

[Fact]
public async Task GetByIdAsync_WhenUserNotFound_ThrowsNotFoundException() { }

[Fact]
public async Task CreateAsync_WithDuplicateEmail_ThrowsConflictException() { }
```

---

## Test Structure (Arrange-Act-Assert)

```csharp
[Fact]
public async Task CalculateTotal_WithDiscount_ReturnsDiscountedAmount()
{
    // Arrange - setup test data and dependencies
    var cart = new Cart();
    cart.AddItem(new CartItem { Price = 100, Quantity = 2 });
    cart.ApplyDiscount(10); // 10% discount

    // Act - execute the method under test
    var total = cart.CalculateTotal();

    // Assert - verify the result
    total.Should().Be(180); // 200 - 10% = 180
}
```

---

## Test Doubles

### Preference Order

1. **Real implementations** (in-memory database, actual dependencies)
2. **Fakes** (in-memory implementations)
3. **Stubs** (canned responses)
4. **Mocks** (verify interactions — use sparingly)

### Examples

```csharp
// 1. Real - EF Core In-Memory
var options = new DbContextOptionsBuilder<AppDbContext>()
    .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
    .Options;
using var context = new AppDbContext(options);

// 2. Fake - custom implementation
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

// 3. Stub - canned response with Moq
var mockRepo = new Mock<IUserRepository>();
mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>()))
    .ReturnsAsync(new User { Id = Guid.NewGuid(), Name = "Test" });

// 4. Mock - verify interactions (use sparingly)
var mockLogger = new Mock<ILogger<UserService>>();
// ... run test ...
mockLogger.Verify(
    l => l.Log(
        LogLevel.Information,
        It.IsAny<EventId>(),
        It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("created")),
        null,
        It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
    Times.Once);
```

---

## FluentAssertions Examples

```csharp
// Basic assertions
result.Should().NotBeNull();
result.Should().Be(expected);
result.Should().BeEquivalentTo(expected);

// Collections
users.Should().HaveCount(3);
users.Should().Contain(u => u.Email == "test@example.com");
users.Should().BeInAscendingOrder(u => u.Name);
users.Should().OnlyContain(u => u.IsActive);

// Strings
email.Should().Contain("@");
name.Should().StartWith("John");
message.Should().MatchRegex(@"User \d+ created");

// Numbers
total.Should().BeGreaterThan(0);
percentage.Should().BeInRange(0, 100);
result.Should().BeApproximately(3.14, 0.01);

// Exceptions
var act = () => _sut.GetByIdAsync(invalidId);
await act.Should().ThrowAsync<NotFoundException>()
    .WithMessage("*not found*");

// Object comparison
actual.Should().BeEquivalentTo(expected, options => 
    options.Excluding(u => u.CreatedAt));
```

---

## Coverage Configuration

```xml
<!-- tests/MyApp.UnitTests/MyApp.UnitTests.csproj -->
<PropertyGroup>
    <CollectCoverage>true</CollectCoverage>
    <CoverletOutputFormat>cobertura</CoverletOutputFormat>
    <Threshold>80</Threshold>
    <ThresholdType>line,branch</ThresholdType>
    <ThresholdStat>total</ThresholdStat>
</PropertyGroup>
```

### Coverage Thresholds

| Metric | Minimum |
|--------|---------|
| Line coverage | 80% |
| Branch coverage | 75% |
| Method coverage | 80% |

---

## Coverage Command (Local)

```bash
# Run tests with coverage locally
dotnet test \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage \
  -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura

# Generate HTML report
reportgenerator \
  -reports:./coverage/**/coverage.cobertura.xml \
  -targetdir:./coverage/report \
  -reporttypes:Html
```

---

## Test Categories

```csharp
// Use Trait for categorization
[Fact]
[Trait("Category", "Unit")]
public async Task UnitTest() { }

[Fact]
[Trait("Category", "Integration")]
public async Task IntegrationTest() { }

[Fact]
[Trait("Category", "E2E")]
public async Task E2ETest() { }

// Run by category
// dotnet test --filter "Category=Unit"
```

---

## Checklist

- [ ] All public methods have unit tests
- [ ] Edge cases are covered (null, empty, boundary values)
- [ ] Error paths are tested (exceptions, validation failures)
- [ ] Integration tests cover API endpoints
- [ ] Tests are independent (no shared state)
- [ ] Test names clearly describe what is being tested
- [ ] Coverage meets minimum threshold (80%)
- [ ] Tests run fast (< 10 seconds for unit tests)

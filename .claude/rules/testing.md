# Testing Standards — C# / xUnit

## Testing Pyramid

```
         [E2E Tests]         ← Few, slow, catch integration issues
       [Integration Tests]   ← Some, test component interaction
     [Unit Tests]            ← Many, fast, test isolated logic
```

## Test Phases — `/build` vs `/test`

The testing strategy splits across two SDLC phases (per [CLAUDE.md](../CLAUDE.md) §Development Workflow):

| Phase | Test types added & run | Dependencies | Docker? |
|-------|------------------------|--------------|---------|
| `/build` | Unit (Moq) + Integration (EF Core In-Memory / `WebApplicationFactory`) | Fakes / in-memory | ❌ Not required |
| `/test`  | Integration (TestContainers — real SQL Server / Redis / Kafka) + E2E (Playwright); also re-runs the `/build` suite | Real services in containers | ✅ Required |

→ Use **Unit / In-Memory** during `/build` for fast feedback; promote to **TestContainers / E2E** during `/test` before the `/review` gate. The integration-layer detail (InMemory vs TestContainers templates) is in §Integration Test Templates below.

## Requirements

- Unit test coverage: **minimum 80%** (scope theo Mode — xem §Coverage Thresholds: greenfield = whole-repo; brownfield per-change = delta-coverage + ratchet)
- All new features must have tests
- All bug fixes must have a regression test
- Tests run in CI before any merge
- Use **xUnit** for testing framework
- Use **FluentAssertions** for readable assertions
- Use **Moq** for mocking dependencies

---

## Dual-Implementation Parity (MANDATORY when a rule has ≥ 2 representations)

> **Why this rule exists:** when the same rule is written in two places, they **drift independently** — and per-side tests (each side green on its own) **never** catch the drift. This bug class has escaped both `/build` and `/test` in practice (a T-SQL backfill diverged from the C# `UrlCanonicalizer` at the default-port case — only caught at `/review`). This rule turns "caught by luck" into "caught systematically".

**When it applies** — the same rule/formula exists in two representations that can drift independently:

- SQL migration **backfill** ≈ computed logic in app code (e.g. the `*Canonical` / `*Normalized` column)
- Client-side validation **mirror** ≈ server validation (Zod FE ↔ FluentValidation BE)
- **Cache-key / partition-key** computed in ≥ 2 services
- **Serialize/format** on the producer ↔ parse on the consumer

**Priority order (pick 1, record the choice in the ADR/plan):**

1. **Eliminate the second representation (preferred):** the backfill CALLS the app code itself (a data-migration console / `IDesignTimeDbContextFactory` running C#) instead of reimplementing it in SQL — there is nothing left to drift.
2. **If you must reimplement → differential test is MANDATORY:** ONE test runs BOTH representations over the SAME input table and asserts each output pair is equal. The input table MUST enumerate every variant class of the rule — **each clause in the rule's definition ≥ 1 input** (e.g. URL-canonical: host-case · default-port `:80`/`:443` · non-default port · trailing slash · slash-before-query · fragment · empty path · query-case).

> **Per-side tests DO NOT replace the differential test** — two sides green on their own can still drift. For a reimplementation, "edge cases covered" means: each clause of the rule has an input pair in the parity table.

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

> **Host-isolation contract (all external I/O):** Both templates spin up their own isolated dependencies (RAM-backed or container-backed). **No test may ever connect to pre-existing infrastructure** — not `localhost` SQL Server / Redis on the host machine, and not any shared DB / Redis / **Kafka broker** / email / storage / outbound endpoint referenced by connection strings in `appsettings.json`. If you see `UseSqlServer("Server=localhost;…")` — or a hosted Kafka consumer booting with the real bootstrap servers — in a test run, that's a bug. The contract is **proven, not trusted**: Gate 6 runs a whitelist connection tripwire over the captured runner output (`test.md` §Quality Gate 6) — any non-whitelisted host in the logs fails the gate. Brownfield additions:
>
> - **Hosted services:** `WebApplicationFactory` boots the real `Program.cs`, so every `IHostedService` (Kafka consumer/producer, queue worker, scheduler) starts too. The fixture MUST disable them or point them at a TestContainers-backed broker — never let them read the real `appsettings.json` values. A green suite that silently published test events to a real topic is the worst failure mode: invisible until a downstream consumer acts on garbage.
> - **Test environment config:** run the test host with `ASPNETCORE_ENVIRONMENT=Testing` + a dedicated `appsettings.Testing.json` (a NEW test-only file) containing **no real connection string** — failing fast on missing config beats silently reaching real infrastructure.
> - **Auto-migrate on startup:** legacy `Program.cs` often calls `context.Database.Migrate()` at boot — in the test host this must target the container DB (or be disabled for tests), never the configured real DB.
> - **Runtime-only override — nothing to "restore":** all replacement happens **in-memory** (`ConfigureWebHost` DI swap, env vars, the new test-only config file). NEVER edit existing production config (`appsettings.json` / `appsettings.Production.json` / `Program.cs` / `docker-compose.yml`) to make tests pass — the deployed artifact must keep its original connections exactly as-is. Proof is checkable: `git status` after the suite shows production config files unchanged (cross-checked at the gate per `CLAUDE.md` §Verification After Delegation).

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

> **Time optimization — collection fixture (default):** register the factory via `ICollectionFixture` so that **ONE container serves the ENTIRE integration suite**. Per-class `IClassFixture` = N test classes × (~30–60s SQL Server startup) wasted. Reset state between tests with Respawn / transaction rollback / unique keys per test. Fall back to per-class only when a test corrupts the container state unrecoverably.

> **arm64 (Apple Silicon):** `mcr.microsoft.com/mssql/server:2022-latest` (used in the fixture below) **has no arm64 image → segfaults under qemu**. On an arm64 machine, switch to `.WithImage("mcr.microsoft.com/azure-sql-edge:1.0.7")` + wait strategy `Wait.ForUnixContainer().UntilPortIsAvailable(1433)` (azure-sql-edge lacks `sqlcmd`, so the default `MsSqlBuilder` readiness check cannot be used). EF Core migrations apply fine on Edge for ordinary schemas; if the schema uses SQL Server-specific features missing from Edge → gate after an ADR.

> **Schema/procs defined by raw DDL (no ORM migration):** when tables / stored procedures / triggers live as DDL scripts in the repo (brownfield snapshot — locations vary, see `CODEBASE_MAP.md` §DB-object inventory), the fixture MUST execute those scripts into the container after startup, in dependency order (tables → indexes → functions/procs/triggers) — `dotnet ef database update` / `prisma migrate deploy` alone will NOT create them, and the suite would silently run against a database missing the very logic under test.

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

// tests/MyApp.IntegrationTests/IntegrationCollection.cs
// ONE container for the whole suite — every test class marked [Collection("Integration")]
[CollectionDefinition("Integration")]
public class IntegrationCollection : ICollectionFixture<CustomWebApplicationFactory> { }

// tests/MyApp.IntegrationTests/Controllers/UsersControllerTests.cs
namespace MyApp.IntegrationTests.Controllers;

[Collection("Integration")]
[Trait("Category", "RequiresDocker")]
public class UsersControllerTests
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

### Coverage Thresholds (Quality Gate 6)

The gate reads `Project Profile → Mode` to choose the **scope** — the 80/75 numbers stay the same, the scope changes:

| Mode | GATE (blocking) | Informational (non-blocking, MUST be reported) |
|------|-------------|-------------------------------------------|
| **greenfield** | whole-repo: line ≥ 80% · branch ≥ 75% | **method %** — reported, not gating (see the zero-coverage rule below) |
| **brownfield per-change** | **delta-coverage** — computed only over the files changed/added in the change-set: line ≥ 80% · branch ≥ 75% | **whole-repo** = baseline debt, plus a **ratchet**: must not DECREASE from the previous measurement |

- **delta-coverage** = coverage filtered by `git diff --name-only <base>..HEAD` (base = merge-base with main / the previous release tag). Filter on the cobertura report or scope coverlet `Include` to the changed files.
- **Whole-repo ratchet:** record the previous run's whole-repo number in `TEST_REPORT.md §Coverage`; if the next run is **lower** than the previous one → GATE FAIL (prevents new untested code from hiding behind legacy debt). Baseline debt (e.g. R1 from `/discover`) is paid down gradually through the characterization backlog — it is **NOT** the obligation of a single PR (per `brownfield.md` §Upfront-vs-Per-change: no mass retrofit).
- `TEST_REPORT.md §Coverage` MUST record **both numbers** + the ratchet result, stating clearly which number is the gate.
- **Prerequisite:** delta needs a base commit for `git diff` → the source must be git-tracked. A repo not yet committed (e.g. a just-onboarded brownfield) → measure delta manually against the file list in `plans/plan.md` and note the measurement method in the TEST_REPORT.
- Per-file waiver (diff too small / hard to test) → record the reason in TEST_REPORT §Coverage, using the same mechanism as the exclusion-rationale in `coverlet.runsettings`.
- **Zero-coverage methods (replaces a method-percentage gate):** `TEST_REPORT.md §Coverage` MUST list **every method measured at 0%**, each with either a test added or a one-line reason. A **business-logic** method (Service / Handler / Action / domain method) at 0% with no reason → **GATE FAIL**. Structural members — auto-property, record constructor, compiler-generated equality, design-time factory (`IDesignTimeDbContextFactory`, called only by `dotnet ef`) — need only their kind named as the reason.
  **Already-shipping test:** a business-logic method at 0% that shipping code already calls, registers, or wires (e.g. a redaction transform registered into the logging pipeline) needs **a test, not a reason** — it is reachable today, so "its caller does not exist yet" does not apply. The reason form is for a method **no shipping code references yet** (a factory for an unbuilt feature, an exception type nothing throws). The two cases are separated by a reference search, so the distinction is checkable.
  *Why not a method percentage:* in .NET the method count is dominated by structural members, so a percentage produces false red (entities awaiting a later phase, a factory no test can ever call) while simultaneously hiding the real thing — a handful of untested business methods behind a crowd of covered auto-properties. The list-and-justify form catches what the percentage was meant to catch, with no structural noise.

> **Why the split by Mode:** demanding 80% whole-repo on a brownfield with a 0% test baseline forces every per-change PR to retrofit legacy — a direct conflict with `brownfield.md` (WRITE by delta). The gate is meaningful as "is the code I changed covered?"; whole-repo is a debt/trend metric, and the ratchet keeps the direction upward.

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
- [ ] Edge cases are covered (null, empty, boundary, **wrong-type** values)

> **Wrong-type input is its own test class.** "Edge case" read as *boundary values* misses the
> input that is the wrong **shape** entirely — an object/array/number where a string is expected.
> Every externally-reachable path (HTTP body/query, message payload) MUST have at least one test
> sending a type-violating value through the real route, asserting the documented 4xx — not a
> crash. This is the test-side twin of the boundary-validation rule (`lang-nodejs.md` §Schema
> validation at the boundary · FluentValidation · Laravel FormRequest).
- [ ] Error paths are tested (exceptions, validation failures)
- [ ] Integration tests cover API endpoints
- [ ] Tests are independent (no shared state)
- [ ] Test names clearly describe what is being tested
- [ ] Coverage meets minimum threshold (80%)
- [ ] Tests run fast (< 10 seconds for unit tests)

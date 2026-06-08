---
name: debug
description: Systematic debugging and error recovery — find root cause, not symptoms
---

# /debug — Debugging & Error Recovery

> "Fix root causes, not symptoms."

## Purpose

Systematically diagnose and fix errors. Stop feature work, preserve evidence, find root cause, add guards, then resume.

## Agent

Invoke based on the layer where the error occurs:

| Error Layer | Agent |
|-------------|-------|
| API, service, DB, background job | 🔧 **Backend Developer** |
| Component, page, routing, UI | 🖥️ **Frontend Developer** |
| Test failure (flaky, intermittent) | 🧪 **Test Engineer** |
| Security-related error | 🔒 **Security Auditor** |

---

## When to Invoke

| Situation | Action |
|-----------|--------|
| `/build` fails with unclear error | → Invoke `/debug` |
| `/test` fails with flaky or intermittent test | → Invoke `/debug` |
| Runtime error hard to trace in dev/staging | → Invoke `/debug` |
| Simple error with obvious cause | → Fix directly |
| CI/CD pipeline fails unexpectedly | → Invoke `/debug` |

---

## The Stop-the-Line Rule

When unexpected failures occur:

1. **STOP** — Halt feature work immediately
2. **PRESERVE** — Save error messages, logs, stack traces
3. **DIAGNOSE** — Follow the 6-step triage process
4. **FIX** — Address root cause, not symptoms
5. **GUARD** — Add tests to prevent recurrence
6. **RESUME** — Only continue after verification

---

## 6-Step Triage Process

### Step 1: Reproduce

Make the failure happen reliably.

```bash
# Run the failing test
dotnet test --filter "FullyQualifiedName~FailingTestName"

# Run with detailed output
dotnet test --logger "console;verbosity=detailed"

# Or reproduce manually with specific steps
```

**If not reproducible**, investigate:
- Timing/race conditions
- Environment differences (dev vs CI)
- State leakage between tests
- Random/flaky behavior

### Step 2: Localize

Identify which layer fails:

| Layer | Symptoms |
|-------|----------|
| **UI/Frontend** | Render errors, missing elements, wrong display |
| **API/Backend** | HTTP errors, wrong responses, timeout |
| **Database** | Query errors, constraint violations, missing data |
| **Build** | Compilation errors, missing dependencies |
| **External** | Third-party API failures, network issues |
| **Test itself** | Flaky assertion, wrong expectations |

**Use `git bisect` for regressions:**

```bash
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>
# Git will guide you to the breaking commit
```

### Step 3: Reduce

Strip away unrelated elements:

```csharp
// Original complex failing code
var result = await ProcessOrderAsync(
    await GetConfigAsync(),
    await FetchDataAsync(),
    BuildOptions(opts)
);

// Reduced to find the problem
var config = await GetConfigAsync();
_logger.LogDebug("Config: {@Config}", config);  // Check each step

var data = await FetchDataAsync();
_logger.LogDebug("Data: {@Data}", data);

var result = await ProcessOrderAsync(config, data, opts);
```

### Step 4: Fix Root Cause

**Fix the actual problem, not the symptom:**

| Symptom | Bad Fix | Good Fix |
|---------|---------|----------|
| Duplicate list items | Dedupe in UI | Fix query returning duplicates |
| Null reference error | Add `?.` everywhere | Ensure data is loaded before access |
| Slow API response | Increase timeout | Optimize the query |
| Flaky test | Add retry logic | Fix the race condition |

### Step 5: Guard Against Recurrence

Write a test that catches this specific failure:

```csharp
[Fact]
public async Task GetOrderItems_ShouldNotReturnDuplicates_Regression123()
{
    // Setup that caused the original bug
    await CreateOrderAsync(new Order { Items = new[] { item, item } });
    
    // The query that was returning duplicates
    var result = await _sut.GetOrderItemsAsync();
    
    // Guard: ensure no duplicates
    var ids = result.Select(r => r.Id).ToList();
    ids.Should().OnlyHaveUniqueItems();
}
```

### Step 6: Verify End-to-End

```bash
# Run the specific test
dotnet test --filter "Regression123"

# Run full test suite
dotnet test

# Run build
dotnet build --configuration Release

# Manual verification if needed
```

---

## Error-Specific Triage Trees

### Test Failure

```
Test fails
├── Assertion error
│   ├── Expected value wrong → Check test expectation
│   └── Actual value wrong → Debug implementation
├── Runtime error
│   ├── NullReferenceException → Check null checks, initialization
│   ├── InvalidOperationException → Check state, sequence
│   └── HttpRequestException → Check test setup, mocks
└── Timeout
    ├── Async not awaited → Add missing await
    └── Deadlock → Check async patterns, ConfigureAwait
```

### Build Error

```
Build fails
├── CS error (Compilation)
│   ├── Type mismatch → Fix types or add cast
│   ├── Missing member → Add import or implement
│   └── Nullable warning → Add null check or !
├── Package error
│   ├── Package not found → dotnet restore
│   └── Version conflict → Check Directory.Packages.props
└── Project error
    └── Invalid reference → Check .csproj references
```

### Runtime Error

```
Runtime error
├── API returns error
│   ├── 4xx → Client issue, check request
│   │   ├── 400 → Validation failed
│   │   ├── 401 → Authentication failed
│   │   ├── 403 → Authorization failed
│   │   └── 404 → Resource not found
│   └── 5xx → Server issue, check logs
├── Database error
│   ├── SqlException → Check query, connection
│   ├── DbUpdateException → Check constraints, data
│   └── Timeout → Check query performance, indexes
└── Dependency injection
    └── InvalidOperationException → Check service registration
```

---

## Debugging Tools

### Serilog Diagnostic Logging

```csharp
// Add diagnostic logs at strategic points
_logger.LogDebug("Processing order {OrderId} with {ItemCount} items", 
    order.Id, order.Items.Count);

// Use destructuring for complex objects
_logger.LogDebug("Order details: {@Order}", order);

// Measure duration
var sw = Stopwatch.StartNew();
await ProcessAsync();
_logger.LogDebug("Processing completed in {ElapsedMs}ms", sw.ElapsedMilliseconds);
```

### Visual Studio / VS Code Debugging

```bash
# Launch with debugger attached
dotnet run --launch-profile Development

# Debug tests
# In VS Code: Run and Debug > .NET Core Attach
# In Visual Studio: Debug > Attach to Process
```

### .NET Diagnostic Tools

```bash
# Install global tools
dotnet tool install --global dotnet-trace
dotnet tool install --global dotnet-dump
dotnet tool install --global dotnet-counters

# Collect trace
dotnet trace collect --process-id <PID>

# Live counters (CPU, GC, exceptions)
dotnet counters monitor --process-id <PID>

# Collect dump for analysis
dotnet dump collect --process-id <PID>
```

### EF Core Query Logging

```csharp
// In development, enable sensitive data logging
services.AddDbContext<AppDbContext>(options =>
{
    options.UseSqlServer(connectionString)
           .EnableSensitiveDataLogging()
           .EnableDetailedErrors()
           .LogTo(Console.WriteLine, LogLevel.Information);
});
```

### Git Bisect

```bash
git bisect start
git bisect bad                    # Current commit is broken
git bisect good abc123            # This commit was working
# Test each commit git suggests
git bisect good  # or  git bisect bad
git bisect reset                  # When done
```

---

## Common .NET Errors

### NullReferenceException

```csharp
// ❌ Problem: accessing potentially null reference
var name = user.Profile.DisplayName;

// ✅ Fix: null-conditional operator or validation
var name = user?.Profile?.DisplayName ?? "Unknown";

// ✅ Better: ensure data is loaded
if (user?.Profile is null)
    throw new InvalidOperationException("User profile not loaded");
```

### InvalidOperationException in DI

```csharp
// ❌ Problem: service not registered
InvalidOperationException: Unable to resolve service for type 'IUserService'

// ✅ Fix: register in Program.cs
builder.Services.AddScoped<IUserService, UserService>();
```

### DbUpdateException

```csharp
// ❌ Problem: constraint violation
try
{
    await _context.SaveChangesAsync();
}
catch (DbUpdateException ex) when (ex.InnerException is SqlException sqlEx)
{
    // Check constraint type
    if (sqlEx.Number == 2627) // Unique constraint
        throw new ConflictException("Duplicate entry");
    if (sqlEx.Number == 547)  // FK constraint
        throw new BadRequestException("Referenced entity not found");
    throw;
}
```

---

## Common Rationalizations (Avoid These)

| Excuse | Reality |
|--------|---------|
| "It works on my machine" | Environment differences are bugs |
| "It's just flaky" | Flaky tests have root causes |
| "Let's just retry" | Retries hide real problems |
| "It's a third-party issue" | Still need to handle gracefully |
| "We'll fix it later" | Tech debt compounds |

---

## Output

| Artifact | Description |
|----------|-------------|
| **Root cause fix** | Code fixed at the source |
| **Regression test** | New test in `tests/` to guard against recurrence |
| **Commit** | Format: `fix(<scope>): <description>` |
| **DEBUG_REPORT.md** | (Optional) For complex bugs, record root cause analysis |

**Verification checklist:**
- [ ] Root cause identified (not a workaround)
- [ ] Regression test added and passing
- [ ] All existing tests passing
- [ ] No new warnings introduced

---

## Next Step

| Context | Next |
|---------|------|
| Debug during `/build` phase | → Resume `/build` |
| Debug during `/test` phase | → Re-run `/test` |
| Debug critical/security bug | → `/review` to verify fix |
| Debug production issue | → `/scan` after fix |

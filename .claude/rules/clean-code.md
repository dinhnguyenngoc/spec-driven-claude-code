# Clean Code — C# Rules

> Adapted from Clean Code principles for C# and .NET development.
>
> **Scope:** principles (naming meaning, single-purpose methods, SOLID, async correctness).
> **For formatting / syntax conventions** (braces, `var` usage, file-scoped namespaces, expression-bodied members, file organization, XML docs syntax), see [`code-style.md`](code-style.md).
> **For naming patterns** (cache keys, DB, env vars, routes), see [`naming-conventions.md`](naming-conventions.md).

## Variables

### Use meaningful, pronounceable names

```csharp
// Bad
var yyyymmdstr = DateTime.Now.ToString("yyyy/MM/dd");

// Good
var currentDate = DateTime.Now.ToString("yyyy/MM/dd");
```

### Same vocabulary for same type

```csharp
// Bad: GetUserInfo(), GetClientData(), GetCustomerRecord()
// Good: GetUser(), GetUserAsync()
```

### Use searchable names (no magic numbers)

```csharp
// Bad
await Task.Delay(86400000);

// Good
private const int MillisecondsPerDay = 24 * 60 * 60 * 1000;
await Task.Delay(MillisecondsPerDay);

// Better - use TimeSpan
await Task.Delay(TimeSpan.FromDays(1));
```

### Use explanatory variables

```csharp
// Bad
SaveAddress(address.Split(',')[0], address.Split(',')[1]);

// Good
var parts = address.Split(',');
var (city, zipCode) = (parts[0].Trim(), parts[1].Trim());
SaveAddress(city, zipCode);
```

### Avoid mental mapping — be explicit

```csharp
// Bad
locations.ForEach(l => Dispatch(l));

// Good
locations.ForEach(location => Dispatch(location));

// Better - use foreach for clarity
foreach (var location in locations)
{
    Dispatch(location);
}
```

### Don't add redundant context

```csharp
// Bad
public class Car
{
    public string CarMake { get; set; }
    public string CarModel { get; set; }
    public string CarColor { get; set; }
}

// Good
public class Car
{
    public string Make { get; set; }
    public string Model { get; set; }
    public string Color { get; set; }
}
```

### Use default parameter values and null coalescing

```csharp
// Bad
public void Create(string name)
{
    var actualName = name ?? "Default";
}

// Good
public void Create(string name = "Default") { }

// Use null coalescing
var displayName = user.Name ?? "Anonymous";
var config = options ?? new ConfigOptions();
```

---

## Methods

### 3 parameters or fewer — use objects for more

```csharp
// Bad
public void CreateMenu(string title, string body, string buttonText, bool cancellable) { }

// Good
public void CreateMenu(MenuOptions options) { }

// Or use C# record
public record MenuOptions(string Title, string Body, string ButtonText, bool Cancellable);
```

### Methods should do ONE thing

```csharp
// Bad - does multiple things
public async Task EmailClients()
{
    var clients = await _db.Clients.ToListAsync();
    var activeClients = clients.Where(c => c.IsActive);
    foreach (var client in activeClients)
    {
        await _emailService.SendAsync(client.Email, "...");
    }
}

// Good - separated responsibilities
public async Task EmailActiveClientsAsync()
{
    var activeClients = await GetActiveClientsAsync();
    foreach (var client in activeClients)
    {
        await SendEmailAsync(client);
    }
}

private async Task<IEnumerable<Client>> GetActiveClientsAsync()
{
    return await _db.Clients.Where(c => c.IsActive).ToListAsync();
}
```

### Method names should say what they do

```csharp
// Bad - unclear what is added
public DateTime AddToDate(DateTime date, int value) { }

// Good - crystal clear
public DateTime AddMonthsToDate(DateTime date, int months) { }
public DateTime AddDaysToDate(DateTime date, int days) { }
```

### No flag parameters — split into separate methods

```csharp
// Bad
public void CreateFile(string name, bool isTemp)
{
    if (isTemp) { /* temp logic */ }
    else { /* regular logic */ }
}

// Good
public void CreateFile(string name) { }
public void CreateTempFile(string name) { }
```

### Avoid side effects

```csharp
// Bad - mutates input
public void AddItemToCart(List<CartItem> cart, CartItem item)
{
    cart.Add(item);
}

// Good - returns new collection (immutable approach)
public IReadOnlyList<CartItem> AddItemToCart(IReadOnlyList<CartItem> cart, CartItem item)
{
    return cart.Append(item with { AddedAt = DateTime.UtcNow }).ToList();
}
```

### Favor LINQ over loops

```csharp
// Bad - imperative with mutation
var totalOutput = 0;
foreach (var programmer in programmers)
{
    if (programmer.LinesOfCode > 0)
    {
        totalOutput += programmer.LinesOfCode;
    }
}

// Good - declarative with LINQ
var totalOutput = programmers
    .Where(p => p.LinesOfCode > 0)
    .Sum(p => p.LinesOfCode);
```

### Encapsulate conditionals

```csharp
// Bad
if (fsm.State == "fetching" && listNode.Count == 0) { }

// Good
if (ShouldShowSpinner(fsm, listNode)) { }

private bool ShouldShowSpinner(StateMachine fsm, List<Node> nodes)
    => fsm.State == "fetching" && nodes.Count == 0;
```

### Avoid negative conditionals

```csharp
// Bad
if (!IsNotDomNodePresent(node)) { }

// Good
if (IsDomNodePresent(node)) { }
```

### Remove dead code — yours immediately, pre-existing only on request

Don't comment out code — delete it. Git has history.

- **Orphans created by YOUR change** (imports, variables, functions that just became unused) → delete them in the same change.
- **Pre-existing dead code you happen to notice** → record it per [`principles-and-practices.md`](principles-and-practices.md) §2.5 *Where an out-of-scope finding is recorded* (→ `plans/BACKLOG.md`), then handle it via `/simplify`; do **not** delete it inside an unrelated change — deleting code you don't fully understand is how regressions ship. (Canonical: `principles-and-practices.md` §2.5.)

---

## Classes

### Use records for immutable data

```csharp
// Good - immutable data transfer
public record UserDto(Guid Id, string Email, string Name);

// Good - with non-destructive mutation
var updated = original with { Name = "New Name" };
```

### Use primary constructors (C# 12)

```csharp
// Traditional
public class UserService
{
    private readonly IUserRepository _repository;
    
    public UserService(IUserRepository repository)
    {
        _repository = repository;
    }
}

// C# 12 - Primary constructor
public class UserService(IUserRepository repository)
{
    public async Task<User?> GetByIdAsync(Guid id)
        => await repository.GetByIdAsync(id);
}
```

### Use method chaining (fluent interfaces)

```csharp
public class QueryBuilder
{
    private string _fields = "*";
    private string _table = "";
    private string _where = "";

    public QueryBuilder Select(string fields)
    {
        _fields = fields;
        return this;
    }

    public QueryBuilder From(string table)
    {
        _table = table;
        return this;
    }

    public QueryBuilder Where(string condition)
    {
        _where = condition;
        return this;
    }

    public string Build()
        => $"SELECT {_fields} FROM {_table}" +
           (string.IsNullOrEmpty(_where) ? "" : $" WHERE {_where}");
}

// Usage
var query = new QueryBuilder()
    .Select("Id, Name")
    .From("Users")
    .Where("IsActive = 1")
    .Build();
```

### Prefer composition over inheritance

```csharp
// Bad - inheritance for code reuse
public class Employee : Person { }
public class Customer : Person { }

// Good - composition
public class Employee
{
    public PersonInfo PersonInfo { get; init; }
    public EmploymentInfo Employment { get; init; }
}
```

---

## SOLID Principles

| Principle | Rule |
|-----------|------|
| **S** — Single Responsibility | One class = one reason to change |
| **O** — Open/Closed | Open for extension, closed for modification |
| **L** — Liskov Substitution | Derived classes must be substitutable for base |
| **I** — Interface Segregation | Many specific interfaces > one general interface |
| **D** — Dependency Inversion | Depend on abstractions, not concretions |

### Dependency Inversion Example

```csharp
// Bad - depends on concrete implementation
public class OrderService
{
    private readonly SqlOrderRepository _repository = new();
}

// Good - depends on abstraction (injected)
public class OrderService
{
    private readonly IOrderRepository _repository;

    public OrderService(IOrderRepository repository)
    {
        _repository = repository;
    }
}

// Registration in DI container
services.AddScoped<IOrderRepository, SqlOrderRepository>();
services.AddScoped<IOrderService, OrderService>();
```

---

## Async/Await

### Always use async/await for I/O operations

```csharp
// Good
public async Task<User?> GetUserAsync(Guid id)
{
    try
    {
        var user = await _repository.GetByIdAsync(id);
        return user;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to get user {UserId}", id);
        throw;
    }
}
```

### Never use .Result or .Wait()

```csharp
// Bad - can cause deadlocks
var user = _repository.GetByIdAsync(id).Result;
_repository.GetByIdAsync(id).Wait();

// Good - async all the way
var user = await _repository.GetByIdAsync(id);
```

### Use ConfigureAwait(false) in libraries

```csharp
// In library code (not ASP.NET Core)
public async Task<Data> GetDataAsync()
{
    var result = await _httpClient.GetAsync(url).ConfigureAwait(false);
    return await result.Content.ReadFromJsonAsync<Data>().ConfigureAwait(false);
}
```

### Suffix async methods with Async

```csharp
// Good naming
public async Task<User> GetUserByIdAsync(Guid id);
public async Task SaveChangesAsync();
public async Task<bool> ExistsAsync(string email);
```

---

## See also

- **Formatting, braces, `var`, expression-bodied members, file organization, XML doc syntax** → [`code-style.md`](code-style.md)
- **Naming conventions** (C# code, files, cache keys, DB, env vars) → [`naming-conventions.md`](naming-conventions.md)
- **Error-handling principles** (custom exceptions, ProblemDetails, Result pattern) → [`error-handling.md`](error-handling.md)

# Code Style Guide — C#

> **Scope:** formatting, syntax conventions, file organization.
> **For clean-code principles** (single-purpose methods, SOLID, async correctness, no flag params), see [`clean-code.md`](clean-code.md).
> **For naming patterns** (cache keys, DB, env vars, routes), see [`naming-conventions.md`](naming-conventions.md).

## General Principles

- **Clarity over cleverness** — Write code that is easy to read and understand
- **Consistency** — Follow existing patterns in the codebase
- **DRY** — Don't Repeat Yourself, but don't over-abstract

---

## Formatting

### Indentation and Spacing

- Indentation: **4 spaces** (no tabs)
- Max line length: **120 characters**
- One statement per line
- One declaration per line
- Blank line between method definitions
- Blank line between logical sections within methods

### Braces

```csharp
// Always use braces, even for single-line statements
if (condition)
{
    DoSomething();
}

// Exception: simple null checks / guards can be single line
if (user == null) throw new ArgumentNullException(nameof(user));
if (string.IsNullOrEmpty(email)) return null;
```

### File-Scoped Namespaces (C# 10+)

```csharp
// Good - file-scoped namespace
namespace MyApp.Core.Services;

public class UserService { }

// Avoid - block-scoped namespace (adds unnecessary indentation)
namespace MyApp.Core.Services
{
    public class UserService { }
}
```

---

## Naming Conventions

> **See [`naming-conventions.md`](naming-conventions.md)** for complete naming rules including C# code, files, cache keys, database, Kafka topics, and environment variables.

---

## var vs Explicit Types

### Use var when the type is obvious

```csharp
// Good - type is obvious from the right side
var user = new User();
var users = new List<User>();
var name = user.Name; // string is obvious
var count = users.Count; // int is obvious
var stream = new MemoryStream();

// Good - type is clear from method name
var user = await GetUserByIdAsync(id);
var orders = await GetOrdersAsync();
```

### Use explicit type when clarity is needed

```csharp
// Good - clarifies the type
IReadOnlyList<User> users = GetUsers();
decimal total = CalculateTotal();
IDictionary<string, object> metadata = GetMetadata();

// Good - interface type preferred over concrete
IEnumerable<User> users = GetUsers();
IUserService userService = new UserService();
```

---

## Nullable Reference Types

### Enable nullable globally

```xml
<!-- .csproj -->
<PropertyGroup>
    <Nullable>enable</Nullable>
</PropertyGroup>
```

### Handle nullability explicitly

```csharp
// Nullable parameter
public async Task<User?> GetByIdAsync(Guid id)
{
    return await _context.Users.FindAsync(id);
}

// Non-nullable with null check
public async Task UpdateAsync(User user)
{
    ArgumentNullException.ThrowIfNull(user);
    // ...
}

// Null-forgiving operator (use sparingly, only when you're certain)
var name = user!.Name;

// Null-coalescing
var displayName = user?.Name ?? "Anonymous";

// Null-conditional
var length = user?.Name?.Length ?? 0;
```

---

## Properties

### Auto-properties

```csharp
// Simple auto-property
public string Name { get; set; }

// Init-only property (immutable after construction)
public Guid Id { get; init; }

// Required property (C# 11+)
public required string Email { get; set; }

// Computed property
public string FullName => $"{FirstName} {LastName}";

// Property with backing field (when needed)
private string _email = string.Empty;
public string Email
{
    get => _email;
    set => _email = value?.ToLowerInvariant() ?? string.Empty;
}
```

### Records for DTOs

```csharp
// Positional record (immutable, value equality)
public record UserDto(Guid Id, string Email, string Name);

// Record with optional properties
public record CreateUserRequest
{
    public required string Email { get; init; }
    public required string Name { get; init; }
    public string? Phone { get; init; }
}

// Non-destructive mutation
var updated = user with { Name = "New Name" };
```

---

## Methods

### Async Methods

```csharp
// Suffix with Async
public async Task<User?> GetUserByIdAsync(Guid id)
{
    return await _repository.GetByIdAsync(id);
}

// Accept CancellationToken
public async Task<IEnumerable<User>> GetAllAsync(CancellationToken cancellationToken = default)
{
    return await _context.Users.ToListAsync(cancellationToken);
}

// Return Task for void async
public async Task DeleteAsync(Guid id)
{
    var user = await GetByIdAsync(id);
    if (user != null)
    {
        _context.Users.Remove(user);
        await _context.SaveChangesAsync();
    }
}
```

### Expression-Bodied Members

```csharp
// Single expression methods
public User? GetById(Guid id) => _users.FirstOrDefault(u => u.Id == id);

// Single expression properties
public bool IsActive => Status == UserStatus.Active;
public string FullName => $"{FirstName} {LastName}";

// Single expression constructors (simple cases)
public UserService(IUserRepository repository) => _repository = repository;
```

### Method Length

- Prefer methods **under 30 lines**
- Extract helper methods for complex logic
- One level of abstraction per method

---

## LINQ

### Method syntax preferred

```csharp
// Good - method syntax
var activeUsers = users
    .Where(u => u.IsActive)
    .OrderBy(u => u.Name)
    .Select(u => new UserDto(u.Id, u.Email, u.Name))
    .ToList();

// Use query syntax for complex joins
var result = from order in orders
             join user in users on order.UserId equals user.Id
             where order.Status == OrderStatus.Completed
             select new { order, user };
```

### Format long LINQ chains

```csharp
// Good - one operation per line
var report = orders
    .Where(o => o.CreatedAt >= startDate)
    .Where(o => o.Status == OrderStatus.Completed)
    .GroupBy(o => o.UserId)
    .Select(g => new UserOrderSummary
    {
        UserId = g.Key,
        TotalOrders = g.Count(),
        TotalAmount = g.Sum(o => o.Total)
    })
    .OrderByDescending(s => s.TotalAmount)
    .Take(10)
    .ToList();
```

---

## Comments

### Only comment WHY, not WHAT

```csharp
// Good - explains business reason
// OAuth2 tokens can have clock skew up to 5 minutes
private const int TokenExpirationBufferMinutes = 5;

// Bad - obvious from code
// Get user by ID
var user = await GetUserByIdAsync(id);
```

### Use XML docs for public APIs

```csharp
/// <summary>
/// Retrieves a user by their unique identifier.
/// </summary>
/// <param name="id">The user's unique identifier.</param>
/// <param name="cancellationToken">Cancellation token.</param>
/// <returns>The user if found; otherwise, null.</returns>
public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
```

---

## Imports (using statements)

### Order and grouping

```csharp
// 1. System namespaces
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

// 2. Microsoft namespaces
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

// 3. Third-party namespaces
using FluentValidation;
using Serilog;

// 4. Project namespaces
using MyApp.Core.Entities;
using MyApp.Core.Interfaces;
using MyApp.Infrastructure.Data;
```

### Global usings (C# 10+)

```csharp
// GlobalUsings.cs
global using System;
global using System.Collections.Generic;
global using System.Linq;
global using System.Threading.Tasks;
global using Microsoft.EntityFrameworkCore;
```

---

## File Organization

### Class file structure

```csharp
namespace MyApp.Core.Services;

public class UserService : IUserService
{
    #region Constants
    private const int MaxRetryCount = 3;
    #endregion

    #region Fields
    private readonly IUserRepository _repository;
    private readonly ILogger<UserService> _logger;
    #endregion

    #region Constructor
    public UserService(IUserRepository repository, ILogger<UserService> logger)
    {
        _repository = repository;
        _logger = logger;
    }
    #endregion

    #region Public Methods
    public async Task<UserDto?> GetByIdAsync(Guid id) { }
    public async Task<UserDto> CreateAsync(CreateUserRequest request) { }
    #endregion

    #region Private Methods
    private void ValidateRequest(CreateUserRequest request) { }
    #endregion
}
```

> Note: Regions are optional. Prefer small, focused classes over heavy use of regions.

### Project structure

```
src/
├── MyApp.Api/
│   ├── Controllers/
│   ├── Middleware/
│   ├── Extensions/
│   └── Program.cs
├── MyApp.Core/
│   ├── Entities/
│   ├── Interfaces/
│   ├── Services/
│   ├── DTOs/
│   └── Exceptions/
└── MyApp.Infrastructure/
    ├── Data/
    ├── Repositories/
    └── Services/
```

---

## EditorConfig

Place `.editorconfig` in solution root:

```ini
root = true

[*.cs]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
max_line_length = 120

# Naming rules
dotnet_naming_rule.private_fields_should_be_camel_case.severity = warning
dotnet_naming_rule.private_fields_should_be_camel_case.symbols = private_fields
dotnet_naming_rule.private_fields_should_be_camel_case.style = camel_case_underscore

dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private

dotnet_naming_style.camel_case_underscore.required_prefix = _
dotnet_naming_style.camel_case_underscore.capitalization = camel_case

# Code style
csharp_style_var_for_built_in_types = true:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = true:suggestion
csharp_style_expression_bodied_methods = when_on_single_line:suggestion
csharp_style_expression_bodied_properties = true:suggestion
csharp_prefer_braces = true:warning
csharp_using_directive_placement = outside_namespace:warning
csharp_style_namespace_declarations = file_scoped:warning
```

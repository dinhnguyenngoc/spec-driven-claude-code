# Naming Conventions — .NET / C#

> Standard naming rules for C# code, cache keys, database identifiers, Kafka topics, environment variables, and more.

---

## C# Code Naming

### General Rules

| Element | Convention | Example |
|---------|------------|---------|
| Namespaces | PascalCase | `MyApp.Core.Services` |
| Classes | PascalCase | `UserService` |
| Records | PascalCase | `UserDto`, `CreateUserRequest` |
| Interfaces | IPascalCase | `IUserRepository`, `IEmailService` |
| Methods | PascalCase | `GetUserAsync`, `CalculateTotal` |
| Async Methods | PascalCase + Async | `GetByIdAsync`, `SaveChangesAsync` |
| Properties | PascalCase | `FirstName`, `IsActive` |
| Public Fields | PascalCase | `MaxRetryCount` |
| Private Fields | _camelCase | `_repository`, `_logger` |
| Local Variables | camelCase | `userId`, `orderTotal` |
| Parameters | camelCase | `userId`, `cancellationToken` |
| Constants | PascalCase | `DefaultTimeout`, `MaxPageSize` |
| Enum Types | PascalCase singular | `UserRole`, `OrderStatus` |
| Enum Values | PascalCase | `UserRole.Admin`, `OrderStatus.Pending` |
| Type Parameters | TPascalCase | `TEntity`, `TKey`, `TResult` |

### Examples

```csharp
namespace MyApp.Core.Services;

public interface IUserService
{
    Task<UserDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
}

public class UserService : IUserService
{
    private const int MaxRetryCount = 3;
    
    private readonly IUserRepository _repository;
    private readonly ILogger<UserService> _logger;

    public UserService(IUserRepository repository, ILogger<UserService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<UserDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var user = await _repository.GetByIdAsync(id, cancellationToken);
        return user?.ToDto();
    }
}

public enum UserRole
{
    User,
    Admin,
    SuperAdmin
}

public record UserDto(Guid Id, string Email, string Name, UserRole Role);
```

---

## File & Folder Naming

### Files

```
# C# files: PascalCase, match class name
UserService.cs
IUserRepository.cs
CreateUserRequest.cs
UserConfiguration.cs

# Test files: {ClassName}Tests.cs
UserServiceTests.cs
UsersControllerTests.cs

# Configuration files
appsettings.json
appsettings.Development.json
appsettings.Production.json
```

### Folders

```
# Solution structure
src/
├── MyApp.Api/
│   ├── Controllers/
│   ├── Middleware/
│   ├── Filters/
│   └── Extensions/
├── MyApp.Core/
│   ├── Entities/
│   ├── Interfaces/
│   ├── Services/
│   ├── DTOs/
│   └── Exceptions/
└── MyApp.Infrastructure/
    ├── Data/
    │   ├── Configurations/
    │   └── Migrations/
    ├── Repositories/
    └── Services/

tests/
├── MyApp.UnitTests/
└── MyApp.IntegrationTests/

docker/
├── Dockerfile
└── docker-compose.yml
```

---

## Cache Key Naming

### Format

```
{app}:{version}:{entity}:{identifier}:{variant}
```

### Rules

- Use **colons** (`:`) as separators
- Use **lowercase** for each segment
- Always prefix with app/service name to avoid collision
- Include version for easy cache invalidation

### Examples

```
# User data
myapp:v1:user:12345
myapp:v1:user:12345:profile
myapp:v1:user:12345:permissions

# Lists / collections
myapp:v1:users:active:list
myapp:v1:products:category:electronics:page:1

# Sessions
myapp:v1:session:abc123xyz

# Rate limiting
myapp:v1:ratelimit:user:12345:api
myapp:v1:ratelimit:ip:192.168.1.1

# Feature flags
myapp:v1:feature:new_checkout:enabled

# Temporary locks (mutex)
myapp:v1:lock:payment:order:99999

# Aggregates / computed
myapp:v1:dashboard:user:12345:stats:daily
```

### Cache Keys in C#

```csharp
// Infrastructure/Caching/CacheKeys.cs
public static class CacheKeys
{
    private const string Prefix = "myapp:v1";

    public static string User(Guid id) => $"{Prefix}:user:{id}";
    public static string UserProfile(Guid id) => $"{Prefix}:user:{id}:profile";
    public static string UserPermissions(Guid id) => $"{Prefix}:user:{id}:permissions";
    public static string Session(string sessionId) => $"{Prefix}:session:{sessionId}";
    public static string RateLimit(string key) => $"{Prefix}:ratelimit:{key}";
}
```

### TTL Conventions

| Data Type | Recommended TTL |
|-----------|----------------|
| User session | 7 days |
| Auth tokens | 15 minutes |
| User profile | 1 hour |
| Product catalog | 6 hours |
| Config/settings | 24 hours |
| Rate limit windows | 15 minutes |
| Temporary locks | 30 seconds |

---

## Database Naming (SQL Server)

### Tables

```sql
-- PascalCase, plural nouns (EF Core default)
Users
Orders
OrderItems
ProductCategories
UserRoleMappings    -- junction tables: Entity1Entity2s
```

### Columns

```sql
-- PascalCase (EF Core default for SQL Server)
Id                  -- primary key
UserId              -- foreign key: {ReferencedTable}Id
CreatedAt           -- timestamps: {Event}At
UpdatedAt
DeletedAt           -- soft delete
IsActive            -- booleans: Is{Adjective}
HasVerifiedEmail
Email               -- data fields: descriptive name
FullName
```

### Indexes

```sql
-- Pattern: IX_{Table}_{Columns}
IX_Users_Email
IX_Orders_UserId_CreatedAt
IX_Products_CategoryId_IsActive

-- Unique indexes
UQ_Users_Email

-- Filtered indexes
IX_Users_Active WHERE DeletedAt IS NULL
```

### Foreign Keys

```sql
-- Pattern: FK_{ChildTable}_{ParentTable}_{Column}
FK_Orders_Users_UserId
FK_OrderItems_Orders_OrderId
FK_OrderItems_Products_ProductId
```

---

## Kafka Topics & Events

### Topic Names

```
# Pattern: {domain}.{entity}.{action}
# Use dots as separators, lowercase

user.events
order.events
payment.events
notification.events
audit.events
```

### Event Names (Domain Events)

```
# Pattern: {Entity}{PastTenseVerb}
# Events describe things that HAPPENED

UserCreated
UserUpdated
UserDeleted
UserEmailVerified

OrderPlaced
OrderPaymentReceived
OrderFulfilled
OrderCancelled

PaymentProcessed
PaymentFailed
PaymentRefunded
```

### Event Classes

```csharp
// Core/Events/UserEvents.cs
public record UserCreatedEvent(
    Guid UserId,
    string Email,
    DateTime OccurredAt);

public record UserUpdatedEvent(
    Guid UserId,
    string[] ChangedProperties,
    DateTime OccurredAt);

// Publishing
await _eventPublisher.PublishAsync(
    topic: "user.events",
    key: userId.ToString(),
    message: new UserCreatedEvent(user.Id, user.Email, DateTime.UtcNow));
```

### Consumer Group Names

```
# Pattern: {service-name}-{topic}-consumer
order-service-user-events-consumer
notification-service-order-events-consumer
```

---

## Environment Variables & Configuration

### Rules

- **UPPER_SNAKE_CASE** for environment variables
- Use `__` (double underscore) for nested configuration in env vars
- **PascalCase** for appsettings.json keys

### Environment Variables

```bash
# App
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://+:8080
APP_NAME=myapp

# Database (connection string components)
ConnectionStrings__DefaultConnection="Server=...;Database=...;..."

# Or individual settings
DB_HOST=localhost
DB_PORT=1433
DB_NAME=myapp_production
DB_USER=myapp_user
DB_PASSWORD=...

# Cache
ConnectionStrings__Redis=localhost:6379

# Kafka
Kafka__BootstrapServers=localhost:9092

# Auth
Jwt__Secret=...
Jwt__ExpiresInMinutes=15
Jwt__RefreshExpiresInDays=7
Keycloak__Authority=https://auth.example.com/realms/myapp
Keycloak__Audience=myapp-api

# External Services
Email__ApiKey=...
Storage__ConnectionString=...

# Monitoring
Serilog__MinimumLevel__Default=Information
Jaeger__Endpoint=http://localhost:14268/api/traces
```

### Configuration Files

```json
// appsettings.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=MyApp;...",
    "Redis": "localhost:6379"
  },
  "Jwt": {
    "Secret": "your-secret-key-here",
    "ExpiresInMinutes": 15,
    "RefreshExpiresInDays": 7
  },
  "Kafka": {
    "BootstrapServers": "localhost:9092"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft.AspNetCore": "Warning"
      }
    }
  }
}
```

### Configuration Classes

```csharp
// Core/Configuration/JwtOptions.cs
public class JwtOptions
{
    public const string SectionName = "Jwt";
    
    public string Secret { get; init; } = string.Empty;
    public int ExpiresInMinutes { get; init; } = 15;
    public int RefreshExpiresInDays { get; init; } = 7;
}

// Registration
builder.Services.Configure<JwtOptions>(
    builder.Configuration.GetSection(JwtOptions.SectionName));

// Usage
public class AuthService
{
    private readonly JwtOptions _jwtOptions;
    
    public AuthService(IOptions<JwtOptions> jwtOptions)
    {
        _jwtOptions = jwtOptions.Value;
    }
}
```

---

## URL / Route Naming

### REST API Routes

```
# Plural nouns, kebab-case for multi-word, versioned
GET    /api/v1/users
GET    /api/v1/users/{id}
POST   /api/v1/users
PUT    /api/v1/users/{id}
PATCH  /api/v1/users/{id}
DELETE /api/v1/users/{id}

# Nested resources
GET    /api/v1/users/{id}/orders
POST   /api/v1/users/{id}/orders
GET    /api/v1/users/{id}/orders/{orderId}

# Multi-word resources
GET    /api/v1/order-items
GET    /api/v1/user-profiles/{id}

# Actions (use verbs sparingly)
POST   /api/v1/auth/login
POST   /api/v1/auth/logout
POST   /api/v1/auth/refresh
POST   /api/v1/payments/{id}/refund
POST   /api/v1/orders/{id}/cancel
```

### Controller Routes in C#

```csharp
[ApiController]
[Route("api/v1/[controller]")]  // Uses controller name (UsersController → users)
public class UsersController : ControllerBase
{
    [HttpGet]                    // GET /api/v1/users
    [HttpGet("{id:guid}")]       // GET /api/v1/users/{id}
    [HttpPost]                   // POST /api/v1/users
    [HttpPut("{id:guid}")]       // PUT /api/v1/users/{id}
    [HttpDelete("{id:guid}")]    // DELETE /api/v1/users/{id}
    
    [HttpGet("{id:guid}/orders")] // GET /api/v1/users/{id}/orders
}

[ApiController]
[Route("api/v1/order-items")]    // Explicit kebab-case route
public class OrderItemsController : ControllerBase { }
```

---

## Solution & Project Naming

### Solution

```
# Pattern: {Company}.{Product} or {Product}
MyApp.sln
Acme.ECommerce.sln
```

### Projects

```
# Pattern: {SolutionName}.{Layer}
MyApp.Api
MyApp.Core
MyApp.Infrastructure
MyApp.UnitTests
MyApp.IntegrationTests

# For microservices
MyApp.UserService.Api
MyApp.OrderService.Api
MyApp.Shared
```

### Namespaces

```csharp
// Follow project structure
namespace MyApp.Core.Services;
namespace MyApp.Core.Entities;
namespace MyApp.Core.Interfaces.Repositories;
namespace MyApp.Infrastructure.Data;
namespace MyApp.Api.Controllers;
```

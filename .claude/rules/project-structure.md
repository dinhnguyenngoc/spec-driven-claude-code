# Project Structure — ASP.NET Core Clean Architecture

## Solution Layout

```
MyApp.sln
│
├── src/
│   ├── MyApp.Api/                          # Presentation Layer
│   │   ├── Controllers/
│   │   │   ├── AuthController.cs
│   │   │   ├── UsersController.cs
│   │   │   └── OrdersController.cs
│   │   ├── Middleware/
│   │   │   ├── ExceptionHandlingMiddleware.cs
│   │   │   ├── CorrelationIdMiddleware.cs
│   │   │   └── RequestLoggingMiddleware.cs
│   │   ├── Filters/
│   │   │   └── ValidationFilter.cs
│   │   ├── Extensions/
│   │   │   ├── ServiceCollectionExtensions.cs
│   │   │   └── ApplicationBuilderExtensions.cs
│   │   ├── Properties/
│   │   │   └── launchSettings.json
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   ├── appsettings.Production.json
│   │   ├── Program.cs
│   │   └── MyApp.Api.csproj
│   │
│   ├── MyApp.Core/                         # Domain + Application Layer
│   │   ├── Entities/
│   │   │   ├── User.cs
│   │   │   ├── Order.cs
│   │   │   ├── OrderItem.cs
│   │   │   └── BaseEntity.cs
│   │   ├── Enums/
│   │   │   ├── UserRole.cs
│   │   │   └── OrderStatus.cs
│   │   ├── Interfaces/
│   │   │   ├── Repositories/
│   │   │   │   ├── IUserRepository.cs
│   │   │   │   ├── IOrderRepository.cs
│   │   │   │   └── IRepository.cs
│   │   │   └── Services/
│   │   │       ├── IUserService.cs
│   │   │       ├── IOrderService.cs
│   │   │       ├── ICacheService.cs
│   │   │       └── IEventPublisher.cs
│   │   ├── Services/
│   │   │   ├── UserService.cs
│   │   │   └── OrderService.cs
│   │   ├── DTOs/
│   │   │   ├── Requests/
│   │   │   │   ├── CreateUserRequest.cs
│   │   │   │   ├── UpdateUserRequest.cs
│   │   │   │   └── CreateOrderRequest.cs
│   │   │   ├── Responses/
│   │   │   │   ├── UserDto.cs
│   │   │   │   ├── OrderDto.cs
│   │   │   │   └── PagedResult.cs
│   │   │   └── Filters/
│   │   │       └── UserFilterRequest.cs
│   │   ├── Validators/
│   │   │   ├── CreateUserRequestValidator.cs
│   │   │   └── CreateOrderRequestValidator.cs
│   │   ├── Exceptions/
│   │   │   ├── AppException.cs
│   │   │   ├── NotFoundException.cs
│   │   │   ├── ConflictException.cs
│   │   │   └── ValidationException.cs
│   │   ├── Events/
│   │   │   ├── UserCreatedEvent.cs
│   │   │   └── OrderPlacedEvent.cs
│   │   ├── Configuration/
│   │   │   ├── JwtOptions.cs
│   │   │   └── KafkaOptions.cs
│   │   └── MyApp.Core.csproj
│   │
│   └── MyApp.Infrastructure/               # Infrastructure Layer
│       ├── Data/
│       │   ├── AppDbContext.cs
│       │   ├── Configurations/
│       │   │   ├── UserConfiguration.cs
│       │   │   └── OrderConfiguration.cs
│       │   ├── Migrations/
│       │   └── Seeds/
│       │       └── DataSeeder.cs
│       ├── Repositories/
│       │   ├── Repository.cs
│       │   ├── UserRepository.cs
│       │   └── OrderRepository.cs
│       ├── Caching/
│       │   ├── RedisCacheService.cs
│       │   └── CacheKeys.cs
│       ├── Messaging/
│       │   ├── KafkaProducer.cs
│       │   └── Consumers/
│       │       └── OrderEventConsumer.cs
│       ├── ExternalServices/
│       │   ├── EmailService.cs
│       │   └── StorageService.cs
│       ├── DependencyInjection.cs
│       └── MyApp.Infrastructure.csproj
│
├── tests/
│   ├── MyApp.UnitTests/
│   │   ├── Services/
│   │   │   ├── UserServiceTests.cs
│   │   │   └── OrderServiceTests.cs
│   │   ├── Validators/
│   │   │   └── CreateUserRequestValidatorTests.cs
│   │   └── MyApp.UnitTests.csproj
│   │
│   ├── MyApp.IntegrationTests/
│   │   ├── Controllers/
│   │   │   ├── UsersControllerTests.cs
│   │   │   └── OrdersControllerTests.cs
│   │   ├── Repositories/
│   │   │   └── UserRepositoryTests.cs
│   │   ├── CustomWebApplicationFactory.cs
│   │   └── MyApp.IntegrationTests.csproj
│   │
│   └── MyApp.E2ETests/
│       ├── Scenarios/
│       │   └── UserRegistrationTests.cs
│       └── MyApp.E2ETests.csproj
│
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   └── docker-compose.prod.yml
│
├── docs/
│   ├── api/
│   │   └── openapi.yaml
│   ├── architecture/
│   │   ├── ARCHITECTURE.md
│   │   └── diagrams/
│   └── getting-started.md
│
├── scripts/
│   ├── setup.sh
│   └── migration.sh
│
├── .editorconfig
├── .gitignore
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── README.md
└── CLAUDE.md
```

---

## Clean Architecture Layers

```
┌───────────────────────────────────────────────────────────────┐
│                        MyApp.Api                              │
│                    (Presentation Layer)                       │
│         Controllers, Middleware, Filters, Extensions          │
├───────────────────────────────────────────────────────────────┤
│                        MyApp.Core                             │
│                   (Domain + Application)                      │
│    Entities, Interfaces, Services, DTOs, Validators, Events  │
├───────────────────────────────────────────────────────────────┤
│                    MyApp.Infrastructure                       │
│                   (Infrastructure Layer)                      │
│     EF Core, Repositories, Redis, Kafka, External Services   │
└───────────────────────────────────────────────────────────────┘
```

### Dependency Rules

```csharp
// Api → Core, Infrastructure
// Infrastructure → Core
// Core → (nothing external, only .NET BCL)

// Api can reference:
using MyApp.Core.Services;
using MyApp.Core.DTOs;
using MyApp.Core.Interfaces;
using MyApp.Infrastructure;

// Infrastructure can reference:
using MyApp.Core.Entities;
using MyApp.Core.Interfaces;

// Core NEVER references Api or Infrastructure
```

---

## Layer Responsibilities

| Layer | Project | Responsibility |
|-------|---------|----------------|
| **Presentation** | `MyApp.Api` | HTTP handling, routing, middleware, filters |
| **Application** | `MyApp.Core` | Business logic, use cases, DTOs, validation |
| **Domain** | `MyApp.Core` | Entities, domain events, business rules |
| **Infrastructure** | `MyApp.Infrastructure` | EF Core, external services, caching, messaging |

### Request Flow

```
HTTP Request
    ↓
[Middleware] ← Correlation ID, Logging, Exception Handling
    ↓
[Controller] ← Route handling, model binding
    ↓
[Validation] ← FluentValidation
    ↓
[Service] ← Business logic
    ↓
[Repository] ← Data access
    ↓
[Database/Cache/Queue]
```

---

## File Naming Conventions

### C# Files

```
# Classes: PascalCase, match filename
UserService.cs
IUserRepository.cs
CreateUserRequest.cs
UserConfiguration.cs

# Tests: {ClassName}Tests.cs
UserServiceTests.cs
UsersControllerTests.cs
```

### Folders

```
# PascalCase, plural for collections
Controllers/
Services/
Repositories/
DTOs/
Entities/
Middleware/
Exceptions/
```

---

## Configuration Files

### appsettings.json

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "",
    "Redis": ""
  },
  "Jwt": {
    "Secret": "",
    "Issuer": "MyApp",
    "Audience": "MyApp",
    "ExpiresInMinutes": 15
  },
  "Kafka": {
    "BootstrapServers": ""
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

### Directory.Build.props (Shared settings)

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

### global.json

```json
{
  "sdk": {
    "version": "8.0.100",
    "rollForward": "latestMinor"
  }
}
```

---

## Project References

### MyApp.Api.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\MyApp.Core\MyApp.Core.csproj" />
    <ProjectReference Include="..\MyApp.Infrastructure\MyApp.Infrastructure.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Serilog.AspNetCore" Version="8.*" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.*" />
  </ItemGroup>
</Project>
```

### MyApp.Core.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="FluentValidation" Version="11.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="8.*" />
  </ItemGroup>
</Project>
```

### MyApp.Infrastructure.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\MyApp.Core\MyApp.Core.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.*" />
    <PackageReference Include="Dapper" Version="2.*" />
    <PackageReference Include="StackExchange.Redis" Version="2.*" />
    <PackageReference Include="Confluent.Kafka" Version="2.*" />
  </ItemGroup>
</Project>
```

---

## Dependency Injection Registration

### Infrastructure/DependencyInjection.cs

```csharp
namespace MyApp.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Database
        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("DefaultConnection"),
                b => b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName)));

        // Repositories
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IOrderRepository, OrderRepository>();

        // Caching
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = configuration.GetConnectionString("Redis");
        });
        services.AddScoped<ICacheService, RedisCacheService>();

        // Messaging
        services.AddSingleton<IEventPublisher, KafkaProducer>();

        return services;
    }
}
```

### Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add application services
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IOrderService, OrderService>();

// Add validators
builder.Services.AddValidatorsFromAssemblyContaining<CreateUserRequestValidator>();

// Add infrastructure
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

// Configure pipeline
app.UseExceptionHandling();
app.UseCorrelationId();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
```

---

## Folder Decision Guide

| Question | Folder |
|----------|--------|
| Handles HTTP request/response? | `Api/Controllers/` |
| Cross-cutting HTTP concern? | `Api/Middleware/` |
| Contains business rules? | `Core/Services/` |
| Defines data shape? | `Core/Entities/` or `Core/DTOs/` |
| Defines contracts? | `Core/Interfaces/` |
| Validates requests? | `Core/Validators/` |
| Talks to database? | `Infrastructure/Repositories/` |
| Connects to external service? | `Infrastructure/ExternalServices/` |
| Caches data? | `Infrastructure/Caching/` |
| Publishes/consumes messages? | `Infrastructure/Messaging/` |

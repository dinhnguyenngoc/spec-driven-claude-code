# API Conventions — ASP.NET Core

## REST API Design Standards

### URL Structure

- Use **kebab-case** for URL paths: `/api/user-profiles`
- Use **plural nouns** for resource collections: `/api/users`, `/api/products`
- Nest related resources: `/api/users/{id}/orders`
- API version prefix: `/api/v1/...`

### HTTP Methods

| Method | Usage | Success Code |
|--------|-------|--------------|
| GET | Read resources (idempotent) | 200 OK |
| POST | Create new resource | 201 Created |
| PUT | Replace entire resource | 200 OK |
| PATCH | Partial update | 200 OK |
| DELETE | Remove resource | 204 No Content |

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | OK — Successful GET/PUT/PATCH |
| 201 | Created — Successful POST |
| 204 | No Content — Successful DELETE |
| 400 | Bad Request — Invalid input **and validation failures** |
| 401 | Unauthorized — Not authenticated |
| 403 | Forbidden — No permission |
| 404 | Not Found |
| 409 | Conflict |
| 500 | Internal Server Error |

> **Validation errors use `400 Bad Request`** (not 422). This matches the `ValidationException` defined in [`error-handling.md`](error-handling.md#custom-exception-classes), which is the single source of truth for the API's error contract. Field-level details are returned via the `errors` extension on `ProblemDetails`.

---

## Controller Conventions

### Basic Controller Structure

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(IUserService userService, ILogger<UsersController> logger)
    {
        _userService = userService;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<UserDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? sortBy = "createdAt",
        [FromQuery] string? order = "desc")
    {
        var result = await _userService.GetPagedAsync(page, pageSize, sortBy, order);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var user = await _userService.GetByIdAsync(id);
        return Ok(user);
    }

    [HttpPost]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        var user = await _userService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = user.Id }, user);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateUserRequest request)
    {
        var user = await _userService.UpdateAsync(id, request);
        return Ok(user);
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _userService.DeleteAsync(id);
        return NoContent();
    }
}
```

### Route Constraints

```csharp
[HttpGet("{id:guid}")]              // GUID only
[HttpGet("{id:int}")]               // Integer only
[HttpGet("{id:int:min(1)}")]        // Integer >= 1
[HttpGet("{slug:regex(^[a-z-]+$)}")] // Regex pattern
[HttpGet("{name:alpha}")]           // Alphabetic only
[HttpGet("{*path}")]                // Catch-all
```

### Action Return Types

```csharp
// Return specific type (200 OK assumed)
[HttpGet("{id:guid}")]
public async Task<UserDto> GetById(Guid id)
{
    return await _userService.GetByIdAsync(id);
}

// Return ActionResult<T> for multiple status codes
[HttpGet("{id:guid}")]
public async Task<ActionResult<UserDto>> GetById(Guid id)
{
    var user = await _userService.GetByIdAsync(id);
    if (user == null)
        return NotFound();
    return user;
}

// Return IActionResult for full control
[HttpPost]
public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
{
    var user = await _userService.CreateAsync(request);
    return CreatedAtAction(nameof(GetById), new { id = user.Id }, user);
}
```

---

## Request/Response Format

### Using ProblemDetails (RFC 7807)

```csharp
// Configure in Program.cs
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
    };
});
```

### Success Response (Simple)

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "email": "user@example.com",
  "name": "John Doe",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### Paginated List Response

```csharp
// Core/DTOs/PagedResult.cs
public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalCount { get; init; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasPrevious => Page > 1;
    public bool HasNext => Page < TotalPages;
}
```

```json
{
  "items": [
    { "id": "...", "email": "...", "name": "..." }
  ],
  "page": 1,
  "pageSize": 20,
  "totalCount": 100,
  "totalPages": 5,
  "hasPrevious": false,
  "hasNext": true
}
```

### Error Response (ProblemDetails)

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "Bad Request",
  "status": 400,
  "detail": "Validation failed",
  "instance": "/api/v1/users",
  "traceId": "00-abc123-def456-00",
  "errors": {
    "email": ["Email is required", "Invalid email format"],
    "password": ["Password must be at least 8 characters"]
  }
}
```

---

## FluentValidation Integration

### Validator Definition

```csharp
// Core/Validators/CreateUserRequestValidator.cs
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required")
            .EmailAddress().WithMessage("Invalid email format")
            .MaximumLength(255);

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MinimumLength(2).WithMessage("Name must be at least 2 characters")
            .MaximumLength(100);

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required")
            .MinimumLength(8).WithMessage("Password must be at least 8 characters")
            .MaximumLength(128)
            .Matches("[A-Z]").WithMessage("Password must contain uppercase letter")
            .Matches("[a-z]").WithMessage("Password must contain lowercase letter")
            .Matches("[0-9]").WithMessage("Password must contain digit")
            .Matches("[^a-zA-Z0-9]").WithMessage("Password must contain special character");
    }
}
```

### Register Validators

```csharp
// Program.cs
builder.Services.AddValidatorsFromAssemblyContaining<CreateUserRequestValidator>();
builder.Services.AddFluentValidationAutoValidation();
```

---

## Filtering & Pagination

### Query Parameters

```
GET /api/v1/users?page=1&pageSize=20&sortBy=createdAt&order=desc
GET /api/v1/products?categoryId=123&minPrice=100&maxPrice=500&inStock=true
GET /api/v1/orders?status=pending,processing&from=2024-01-01&to=2024-12-31
```

### Filter DTO

```csharp
// Core/DTOs/UserFilterRequest.cs
public record UserFilterRequest
{
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 20;
    public string? SortBy { get; init; } = "createdAt";
    public string? Order { get; init; } = "desc";
    public string? Search { get; init; }
    public bool? IsActive { get; init; }
    public UserRole? Role { get; init; }
}

// Controller usage
[HttpGet]
public async Task<ActionResult<PagedResult<UserDto>>> GetAll([FromQuery] UserFilterRequest filter)
{
    return await _userService.GetPagedAsync(filter);
}
```

---

## API Versioning

### URL Path Versioning (Recommended)

```csharp
// Program.cs
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
});

// Controller
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0")]
public class UsersController : ControllerBase { }

// Multiple versions
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
public class UsersController : ControllerBase
{
    [HttpGet]
    [MapToApiVersion("1.0")]
    public async Task<IActionResult> GetAllV1() { }

    [HttpGet]
    [MapToApiVersion("2.0")]
    public async Task<IActionResult> GetAllV2() { }
}
```

---

## Swagger/OpenAPI Documentation

### Setup

```csharp
// Program.cs
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "MyApp API",
        Version = "v1",
        Description = "API for MyApp application"
    });

    // JWT Bearer auth
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });

    // Include XML comments
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
        options.IncludeXmlComments(xmlPath);
});

// Enable in development
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "MyApp API v1"));
}
```

### XML Documentation

```csharp
/// <summary>
/// Retrieves a user by their unique identifier.
/// </summary>
/// <param name="id">The user's unique identifier.</param>
/// <returns>The user details.</returns>
/// <response code="200">Returns the user.</response>
/// <response code="404">User not found.</response>
[HttpGet("{id:guid}")]
[ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
public async Task<IActionResult> GetById(Guid id)
{
    var user = await _userService.GetByIdAsync(id);
    return Ok(user);
}
```

---

## Naming Conventions

### Request/Response Fields

- Use **camelCase** for JSON properties (default in System.Text.Json)
- Use **PascalCase** for C# properties (serializer converts automatically)

```csharp
// C# DTO (PascalCase)
public record UserDto
{
    public Guid Id { get; init; }
    public string Email { get; init; }
    public string FullName { get; init; }
    public DateTime CreatedAt { get; init; }
}

// Serialized JSON (camelCase)
// { "id": "...", "email": "...", "fullName": "...", "createdAt": "..." }
```

### Configure JSON Options

```csharp
// Program.cs
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
        options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });
```

---

## Security

### Authentication & Authorization

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]  // Require authentication for all actions
public class UsersController : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]  // Override: allow without auth
    public async Task<IActionResult> GetAll() { }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id) { }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]  // Require admin role
    public async Task<IActionResult> Delete(Guid id) { }

    [HttpPost("admin-action")]
    [Authorize(Policy = "AdminOnly")]  // Require policy
    public async Task<IActionResult> AdminAction() { }
}
```

### Rate Limiting

```csharp
// Program.cs
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.User.Identity?.Name ?? context.Request.Headers.Host.ToString(),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1)
            }));

    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15)
            }));
});

// Controller
[HttpPost("login")]
[EnableRateLimiting("auth")]
public async Task<IActionResult> Login([FromBody] LoginRequest request) { }
```

---

## Checklist

- [ ] All controllers use `[ApiController]` attribute
- [ ] Routes use plural nouns and kebab-case
- [ ] API versioning is implemented
- [ ] All actions have `[ProducesResponseType]` attributes
- [ ] Swagger/OpenAPI documentation is complete
- [ ] Input validation uses FluentValidation
- [ ] Authentication/Authorization properly configured
- [ ] Rate limiting on sensitive endpoints
- [ ] Error responses use ProblemDetails format

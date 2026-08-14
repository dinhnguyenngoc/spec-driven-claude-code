# Security Rules — ASP.NET Core

## CRITICAL — Never Violate These

- **Never** hardcode secrets, API keys, passwords, or tokens in source code
- **Never** commit `appsettings.*.json` with real secrets to version control
- **Never** log sensitive data (passwords, tokens, PII, credit cards)
- **Never** use string concatenation for SQL queries
- **Always** validate and sanitize all user inputs
- **Always** use parameterized queries (EF Core / Dapper)

---

## Secrets Management

```csharp
// Use configuration/secrets manager
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var jwtSecret = builder.Configuration["Jwt:Secret"];

// NEVER hardcode secrets
var jwtSecret = "my-secret-key-123"; // NEVER DO THIS

// Use User Secrets in development
// dotnet user-secrets set "Jwt:Secret" "your-secret"

// Use environment variables in production
// ConnectionStrings__DefaultConnection="Server=..."
```

### Secret Storage Options

| Environment | Method |
|-------------|--------|
| Development | User Secrets (`dotnet user-secrets`) |
| Production | Azure Key Vault, AWS Secrets Manager, HashiCorp Vault |

---

## Input Validation

### FluentValidation — Security-Sensitive Rules

> **General FluentValidation setup & registration:** see [`api-conventions.md`](api-conventions.md#fluentvalidation-integration).
>
> The rules below focus on **security-hardening** validation (password complexity, character whitelisting). **The password-complexity policy below is canonical** — `api-conventions.md`'s validator example and agent illustrations point here instead of restating it.

```csharp
// Core/Validators/CreateUserRequestValidator.cs — security additions
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        // Password complexity (NIST SP 800-63B style)
        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required")
            .MinimumLength(8).WithMessage("Password must be at least 8 characters")
            .MaximumLength(128)
            .Matches("[A-Z]").WithMessage("Password must contain uppercase letter")
            .Matches("[a-z]").WithMessage("Password must contain lowercase letter")
            .Matches("[0-9]").WithMessage("Password must contain digit")
            .Matches("[^a-zA-Z0-9]").WithMessage("Password must contain special character");

        // Whitelist allowed characters to mitigate injection / homoglyph attacks
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100)
            .Matches(@"^[\p{L}\s\-']+$").WithMessage("Name contains invalid characters");
    }
}
```

### HTML Sanitization (for rich text)

```csharp
// Use HtmlSanitizer for user-generated HTML
using Ganss.Xss;

var sanitizer = new HtmlSanitizer();
var cleanHtml = sanitizer.Sanitize(userInput);
```

---

## Authentication

### JWT Configuration

```csharp
// Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Secret"]!)),
            ClockSkew = TimeSpan.Zero // No tolerance for expired tokens
        };
    });
```

### Password Hashing

```csharp
// Use BCrypt or ASP.NET Identity
using BCrypt.Net;

// Hash password
var hashedPassword = BCrypt.HashPassword(password, workFactor: 12);

// Verify password
var isValid = BCrypt.Verify(password, hashedPassword);

// Or use ASP.NET Identity's IPasswordHasher
public class UserService
{
    private readonly IPasswordHasher<User> _passwordHasher;

    public string HashPassword(User user, string password)
        => _passwordHasher.HashPassword(user, password);

    public bool VerifyPassword(User user, string password, string hash)
        => _passwordHasher.VerifyHashedPassword(user, hash, password) 
           != PasswordVerificationResult.Failed;
}
```

### Token Expiry Guidelines

| Token Type | Expiry |
|------------|--------|
| Access Token | 15 minutes |
| Refresh Token | 7 days |
| Email Verification | 24 hours |
| Password Reset | 1 hour |

---

## Authorization

### Policy-Based Authorization

```csharp
// Program.cs
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("Admin"));
    
    options.AddPolicy("CanManageUsers", policy =>
        policy.RequireClaim("permissions", "users:manage"));
    
    options.AddPolicy("ResourceOwner", policy =>
        policy.Requirements.Add(new ResourceOwnerRequirement()));
});

// Controller usage
[Authorize(Policy = "AdminOnly")]
[HttpDelete("{id:guid}")]
public async Task<IActionResult> Delete(Guid id) { }

// Resource ownership check
public async Task<IActionResult> Update(Guid id, UpdateRequest request)
{
    var resource = await _service.GetByIdAsync(id);
    
    var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
    if (resource.OwnerId.ToString() != userId && !User.IsInRole("Admin"))
    {
        return Forbid();
    }
    
    // ... update
}
```

---

## HTTP Security Headers

```csharp
// Program.cs - Using custom middleware or package
// Install: NetEscapades.AspNetCore.SecurityHeaders

app.UseSecurityHeaders(policies =>
    policies
        .AddDefaultSecurityHeaders()
        .AddStrictTransportSecurityMaxAgeIncludeSubDomains(maxAgeInSeconds: 31536000)
        .AddXContentTypeOptionsNoSniff()
        .AddXFrameOptionsDeny()
        .AddContentSecurityPolicy(builder =>
        {
            builder.AddDefaultSrc().Self();
            builder.AddScriptSrc().Self();
            builder.AddStyleSrc().Self().UnsafeInline();
            builder.AddImgSrc().Self().Data();
        })
        .RemoveServerHeader()
);

// Or manual middleware
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    context.Response.Headers.Append("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
    await next();
});
```

---

## CORS Configuration

```csharp
// Program.cs
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
    {
        policy
            .WithOrigins(
                "https://myapp.com",
                "https://admin.myapp.com")
            .WithMethods("GET", "POST", "PUT", "PATCH", "DELETE")
            .WithHeaders("Authorization", "Content-Type")
            .AllowCredentials();
    });
    
    options.AddPolicy("Development", policy =>
    {
        policy
            .WithOrigins("http://localhost:3000")
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

// Apply based on environment
if (app.Environment.IsDevelopment())
    app.UseCors("Development");
else
    app.UseCors("Production");
```

---

## Rate Limiting

```csharp
// Program.cs (.NET 7+)
builder.Services.AddRateLimiter(options =>
{
    // Global rate limit
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.User.Identity?.Name 
                ?? context.Request.Headers.Host.ToString(),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1)
            }));

    // Auth endpoints - stricter limit
    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15)
            }));
    
    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        await context.HttpContext.Response.WriteAsJsonAsync(new
        {
            error = "Too many requests. Please try again later."
        }, token);
    };
});

app.UseRateLimiter();

// Controller usage
[HttpPost("login")]
[EnableRateLimiting("auth")]
public async Task<IActionResult> Login([FromBody] LoginRequest request) { }
```

---

## SQL Injection Prevention

```csharp
// ALWAYS use parameterized queries

// EF Core - automatically parameterized
var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);

// Dapper - use parameters
var user = await _connection.QueryFirstOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Email = @Email",
    new { Email = email });

// NEVER concatenate user input
// BAD - SQL Injection vulnerability
var sql = $"SELECT * FROM Users WHERE Email = '{email}'"; // NEVER!
```

---

## Dependency Security

```bash
# Check for vulnerable packages
dotnet list package --vulnerable --include-transitive

# Update packages
dotnet outdated
dotnet add package <PackageName> --version <LatestSafeVersion>
```

### Local Vulnerability Check Script

```bash
# Check vulnerable packages
dotnet list package --vulnerable --include-transitive --format json > vulnerabilities.json

# Fail if Critical/High vulnerabilities found
if grep -q '"severity": "High"\|"severity": "Critical"' vulnerabilities.json; then
    echo "Critical/High vulnerabilities found!"
    exit 1
fi
```

---

## Data Protection

### Never Log Sensitive Data

```csharp
// Configure Serilog to mask sensitive data
Log.Logger = new LoggerConfiguration()
    .Destructure.ByTransforming<User>(u => new
    {
        u.Id,
        u.Email,
        Password = "***REDACTED***"
    })
    .CreateLogger();

// Or use [NotLogged] attribute with custom handling
_logger.LogInformation("User logged in: {UserId}", userId);
// NOT: _logger.LogInformation("User logged in with password: {Password}", password);
```

### Encryption at Rest

```csharp
// Use Data Protection API for encrypting sensitive data
public class EncryptionService
{
    private readonly IDataProtector _protector;

    public EncryptionService(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector("MyApp.SensitiveData");
    }

    public string Encrypt(string plainText) => _protector.Protect(plainText);
    public string Decrypt(string cipherText) => _protector.Unprotect(cipherText);
}
```

---

## Security Checklist

### Pre-Commit

- [ ] No hardcoded secrets in code
- [ ] `.gitignore` excludes `appsettings.*.json` with real secrets
- [ ] `appsettings.example.json` committed (no real values)
- [ ] No sensitive data in logs

### Authentication

- [ ] Passwords hashed with BCrypt (work factor >= 12)
- [ ] JWT tokens have short expiry (15 min)
- [ ] Refresh tokens stored securely
- [ ] Rate limiting on auth endpoints

### Authorization

- [ ] `[Authorize]` on all protected endpoints
- [ ] Resource ownership verified
- [ ] Role/policy checks implemented

### Input Validation

- [ ] All inputs validated with FluentValidation
- [ ] File uploads validated (type, size)
- [ ] HTML sanitized if rich text allowed

### Headers & CORS

- [ ] Security headers configured
- [ ] CORS restricted to known origins
- [ ] HTTPS enforced (`UseHttpsRedirection`)

### Dependencies

- [ ] `dotnet list package --vulnerable` shows no critical issues
- [ ] Dependabot or similar enabled

### Error Handling

- [ ] Stack traces not exposed in production
- [ ] Generic error messages for 500 errors
- [ ] Sensitive data not in error responses

# Security Checklist

> Quick reference for security review. See `.claude/rules/security.md` for full rules.

## Pre-Commit Checks

- [ ] No secrets in code (API keys, passwords, connection strings)
- [ ] `.gitignore` excludes `appsettings.*.json` with real secrets
- [ ] `appsettings.example.json` contains only placeholder values
- [ ] No hardcoded connection strings with credentials
- [ ] User Secrets used for development (`dotnet user-secrets`)

## Authentication

- [ ] Passwords hashed with BCrypt (work factor >= 12) or ASP.NET Identity
- [ ] Cookie options: `HttpOnly`, `Secure`, `SameSite.Lax`
- [ ] JWT tokens have reasonable expiry (15min access, 7d refresh)
- [ ] Rate limiting on auth endpoints (max 5-10 attempts/15min)
- [ ] Refresh tokens stored securely and rotated
- [ ] Logout invalidates session/refresh token

```csharp
// JWT Configuration
services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.Zero  // No tolerance
        };
    });
```

## Authorization

- [ ] `[Authorize]` on all protected controllers/endpoints
- [ ] Resource ownership verified (no IDOR vulnerabilities)
- [ ] Policy-based authorization for roles/permissions
- [ ] JWT signature, expiration, and issuer validated
- [ ] Admin functions protected with `[Authorize(Policy = "AdminOnly")]`

```csharp
// Resource ownership check
if (resource.OwnerId != currentUserId && !User.IsInRole("Admin"))
    return Forbid();
```

## Input Validation

- [ ] FluentValidation on all request DTOs
- [ ] String lengths constrained (MaxLength)
- [ ] Numeric ranges validated
- [ ] File uploads restricted by type and size
- [ ] SQL queries parameterized (EF Core / Dapper)

```csharp
// FluentValidation example
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(255);
        
        RuleFor(x => x.Password)
            .MinimumLength(8)
            .MaximumLength(128);
    }
}
```

## Security Headers

```csharp
// Required headers (use NetEscapades.AspNetCore.SecurityHeaders)
app.UseSecurityHeaders(policies =>
    policies
        .AddContentSecurityPolicy(builder =>
            builder.AddDefaultSrc().Self())
        .AddStrictTransportSecurityMaxAgeIncludeSubDomains(31536000)
        .AddXContentTypeOptionsNoSniff()
        .AddXFrameOptionsDeny()
        .RemoveServerHeader());
```

Required headers:
- [ ] `Content-Security-Policy: default-src 'self'`
- [ ] `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY`
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] Server header removed

## CORS

- [ ] Specific origins configured (no `AllowAnyOrigin` in production)
- [ ] Methods restricted to needed ones
- [ ] Headers restricted
- [ ] Credentials mode appropriate

```csharp
// ✅ Good: Restrictive CORS
services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
        policy.WithOrigins("https://myapp.com", "https://admin.myapp.com")
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type")
              .AllowCredentials());
});
```

## Data Protection

- [ ] Sensitive fields excluded from API responses
- [ ] No secrets/PII in logs (Serilog destructuring)
- [ ] HTTPS enforced (`app.UseHttpsRedirection()`)
- [ ] Data Protection API for encryption at rest
- [ ] Database backups encrypted

## Dependencies

```bash
# Run regularly
dotnet list package --vulnerable --include-transitive
```

- [ ] No critical/high vulnerabilities
- [ ] Dependencies up to date
- [ ] Lock file committed (packages.lock.json if used)
- [ ] Dependabot enabled

## Error Handling

- [ ] Generic error messages in production
- [ ] No stack traces exposed (`app.UseExceptionHandler("/error")`)
- [ ] No database details in errors
- [ ] No internal paths revealed
- [ ] ProblemDetails used for error responses

## Rate Limiting

```csharp
// Configure rate limiting (.NET 7+)
services.AddRateLimiter(options =>
{
    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString(),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15)
            }));
});
```

## OWASP Top 10 Quick Check

| # | Vulnerability | Check |
|---|--------------|-------|
| 1 | Broken Access Control | `[Authorize]` on all endpoints? Ownership verified? |
| 2 | Cryptographic Failures | Secrets in Key Vault? HTTPS enforced? BCrypt for passwords? |
| 3 | Injection | EF Core parameterized? FluentValidation? |
| 4 | Insecure Design | Threat modeling done? |
| 5 | Security Misconfiguration | Headers set? Development page disabled? |
| 6 | Vulnerable Components | `dotnet list package --vulnerable` clean? |
| 7 | Auth Failures | Rate limiting? Strong password policy? |
| 8 | Data Integrity | JWT signatures verified? CI/CD secure? |
| 9 | Logging Failures | Security events logged? No PII in logs? |
| 10 | SSRF | External URLs validated? Allowlist? |

## Commands

```bash
# Check vulnerable packages
dotnet list package --vulnerable --include-transitive

# Check for secrets in code
gitleaks detect --source . --verbose

# Run security analyzers
dotnet build /p:RunAnalyzers=true /warnaserror

# Semgrep security scan
semgrep --config=p/csharp --config=p/security-audit .
```

---
name: security-review
description: Skill to perform a thorough security audit of the codebase
---

# Security Review Skill

## Purpose
Systematically scan the codebase for security vulnerabilities and produce a prioritized report.

## Checklist

### 🔴 Critical (Check First)
- [ ] Hardcoded secrets, API keys, passwords in source files
  ```bash
  grep -rn --include="*.cs" --include="*.json" \
    -E "(password|secret|apikey|api_key|connectionstring)\s*[:=]\s*['\"][^'\"]{8,}" src/
  ```
- [ ] `appsettings.json` with real secrets committed
  ```bash
  git log --all --full-history -- "**/appsettings*.json"
  grep -rn "Password=" src/
  ```
- [ ] SQL injection via string concatenation (Dapper raw queries)
  ```bash
  grep -rn --include="*.cs" "ExecuteAsync\|QueryAsync" src/ | grep -v "@"
  grep -rn --include="*.cs" '\$".*SELECT\|INSERT\|UPDATE\|DELETE' src/
  ```
- [ ] Insecure deserialization
  ```bash
  grep -rn --include="*.cs" "JsonSerializer.Deserialize\|BinaryFormatter" src/
  ```

### 🟡 High Priority
- [ ] Missing `[Authorize]` on protected endpoints
  ```bash
  grep -rn --include="*.cs" "\[HttpGet\]\|\[HttpPost\]\|\[HttpPut\]\|\[HttpDelete\]" src/ | \
    grep -v "\[Authorize\]"
  ```
- [ ] Missing authorization checks (privilege escalation)
- [ ] Passwords stored without hashing
  ```bash
  grep -rn --include="*.cs" "Password\s*=" src/ | grep -v "PasswordHash\|HashPassword"
  ```
- [ ] JWT secrets too short or hardcoded
  ```bash
  grep -rn --include="*.cs" --include="*.json" "Jwt.*Secret" src/
  ```
- [ ] No rate limiting on auth endpoints
  ```bash
  grep -rn --include="*.cs" "\[HttpPost\].*login\|signin\|register" src/
  ```
- [ ] Missing FluentValidation on request DTOs
  ```bash
  # Check if validators exist for Request classes
  find src/ -name "*Request.cs" -exec basename {} \; | \
    while read f; do grep -l "${f%.*}Validator" src/ || echo "Missing: $f"; done
  ```

### 🟢 Medium Priority
- [ ] Missing security headers
  ```bash
  grep -rn --include="*.cs" "UseSecurityHeaders\|X-Frame-Options\|X-Content-Type" src/
  ```
- [ ] CORS configured too broadly (`AllowAnyOrigin`)
  ```bash
  grep -rn --include="*.cs" "AllowAnyOrigin\|AllowAnyHeader\|AllowAnyMethod" src/
  ```
- [ ] NuGet packages with known vulnerabilities
  ```bash
  dotnet list package --vulnerable --include-transitive
  ```
- [ ] Sensitive data in logs
  ```bash
  grep -rn --include="*.cs" "Log.*password\|Log.*token\|Log.*secret" src/
  ```
- [ ] Missing HTTPS enforcement
  ```bash
  grep -rn --include="*.cs" "UseHttpsRedirection" src/
  ```

### ℹ️ Low / Informational
- [ ] Error messages revealing stack traces in production
  ```bash
  grep -rn --include="*.cs" "app.UseDeveloperExceptionPage" src/
  ```
- [ ] Missing CSP headers
- [ ] Cookie security flags (HttpOnly, Secure, SameSite)
  ```bash
  grep -rn --include="*.cs" "CookieOptions\|SameSiteMode" src/
  ```
- [ ] Missing request size limits
  ```bash
  grep -rn --include="*.cs" "MaxRequestBodySize\|RequestSizeLimit" src/
  ```

## ASP.NET Core Security Verification

```csharp
// Verify these are configured in Program.cs

// ✅ HTTPS Redirection
app.UseHttpsRedirection();

// ✅ Security Headers
app.UseSecurityHeaders();

// ✅ Authentication before Authorization
app.UseAuthentication();
app.UseAuthorization();

// ✅ Rate limiting
app.UseRateLimiter();

// ✅ CORS (not AllowAnyOrigin in production)
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
        policy.WithOrigins("https://myapp.com")  // Specific origins
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type"));
});

// ✅ Exception handling (no stack traces in production)
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
}
```

## Output Format
```markdown
# Security Review Report — [Date]

## Summary
- **Commit**: [SHA]
- **Files Scanned**: [count]
- **Critical Issues**: [count]
- **High Priority Issues**: [count]

## Critical Issues
| # | Location | Issue | Recommendation |
|---|----------|-------|----------------|
| 1 | `src/MyApp.Api/Controllers/UserController.cs:45` | Missing [Authorize] | Add authorization |

## High Priority Issues
[List with file:line references]

## Medium Priority Issues
[List with file:line references]

## Recommendations
[Prioritized action items]

## Approval
| Role | Name | Date | Decision |
|------|------|------|----------|
| Security Lead | | | APPROVED/REJECTED |
```

## Commands

```bash
# NuGet vulnerability audit
dotnet list package --vulnerable --include-transitive

# Check for secret patterns in C# files
grep -rn --include="*.cs" --include="*.json" \
  -E "(password|secret|api_key|token|connectionstring)\s*[:=]\s*['\"][^'\"]{8,}" src/

# Check for secrets in git history
gitleaks detect --source . --verbose

# Run Semgrep security rules
semgrep --config=p/csharp --config=p/security-audit .

# Find controllers without authorization
grep -rL "\[Authorize\]" src/MyApp.Api/Controllers/*.cs

# Check for raw SQL (potential injection)
grep -rn --include="*.cs" "FromSqlRaw\|ExecuteSqlRaw" src/
```

## Local Verification Commands

```bash
# Check vulnerable packages
dotnet list package --vulnerable --include-transitive 2>&1 | tee vuln.txt
if grep -q "has the following vulnerable packages" vuln.txt; then
    echo "Vulnerable packages detected"
    exit 1
fi

# Run Semgrep locally
semgrep --config=p/csharp --config=p/security-audit --config=p/owasp-top-ten .

# Scan for secrets
gitleaks detect --source . --verbose
```

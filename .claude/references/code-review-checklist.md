# Code Review Checklist (Five-Axis)

> Quick reference for `/review` phase. Evaluate code across 5 axes.

## Five-Axis Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    FIVE-AXIS REVIEW                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. CORRECTNESS     Does it work? Edge cases handled?       │
│  2. READABILITY     Can others understand it easily?        │
│  3. ARCHITECTURE    Does it fit the system design?          │
│  4. SECURITY        Are there vulnerabilities?              │
│  5. PERFORMANCE     Will it scale? Any bottlenecks?         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Correctness

### Logic & Behavior
- [ ] Code does what the spec/ticket requires
- [ ] Edge cases handled (null, empty, boundary values)
- [ ] Error paths handled appropriately
- [ ] No off-by-one errors
- [ ] Async operations handled correctly (await, cancellation)

### Tests
- [ ] Unit tests cover happy path
- [ ] Unit tests cover edge cases
- [ ] Integration tests for API endpoints
- [ ] Tests actually assert behavior (not just run)
- [ ] Coverage meets threshold (≥ 80%)

```csharp
// ✅ Good: Edge case handled
public async Task<User?> GetByIdAsync(Guid id)
{
    if (id == Guid.Empty)
        throw new ArgumentException("Invalid user ID", nameof(id));
    
    return await _repository.GetByIdAsync(id);
}

// ❌ Bad: Missing null check
public string GetDisplayName(User user)
{
    return user.FirstName + " " + user.LastName; // NullReferenceException!
}
```

---

## 2. Readability

### Naming
- [ ] Variables/methods have meaningful names
- [ ] Names follow conventions (PascalCase, camelCase, _privateField)
- [ ] No abbreviations or cryptic names
- [ ] Boolean names are clear (`isActive`, `hasPermission`)

### Structure
- [ ] Methods are short (< 30 lines)
- [ ] Single responsibility per method
- [ ] No deeply nested code (max 3 levels)
- [ ] Consistent formatting
- [ ] Logical grouping of related code

### Comments
- [ ] No obvious comments ("// increment i")
- [ ] Complex logic explained with WHY, not WHAT
- [ ] No commented-out code (delete it)
- [ ] Public APIs have XML docs

```csharp
// ❌ Bad naming
var d = DateTime.Now; // What is d?
var x = users.Where(u => u.a > 0); // What is 'a'?

// ✅ Good naming
var currentDate = DateTime.Now;
var activeUsers = users.Where(u => u.IsActive);
```

---

## 3. Architecture

### Design Principles
- [ ] Follows Clean Architecture layers
- [ ] Dependencies flow inward (not Infrastructure → Core)
- [ ] SOLID principles respected
- [ ] DRY without over-abstraction
- [ ] No feature creep (only what's needed)

### Patterns
- [ ] Correct use of DI (constructor injection)
- [ ] Repository pattern for data access
- [ ] DTOs for API boundaries
- [ ] Domain entities encapsulate logic

### Boundaries
- [ ] API contracts are versioned
- [ ] No business logic in controllers
- [ ] No database concerns in domain layer
- [ ] External services abstracted behind interfaces

```csharp
// ❌ Bad: Controller doing too much
[HttpPost]
public async Task<IActionResult> Create(CreateUserRequest request)
{
    // Validation in controller
    if (string.IsNullOrEmpty(request.Email)) return BadRequest();
    
    // Business logic in controller
    var hashedPassword = BCrypt.HashPassword(request.Password);
    
    // Direct DB access
    _context.Users.Add(new User { ... });
    await _context.SaveChangesAsync();
    
    return Ok();
}

// ✅ Good: Thin controller
[HttpPost]
public async Task<IActionResult> Create(CreateUserRequest request)
{
    var user = await _userService.CreateAsync(request);
    return CreatedAtAction(nameof(GetById), new { id = user.Id }, user);
}
```

---

## 4. Security

### Authentication & Authorization
- [ ] `[Authorize]` on protected endpoints
- [ ] Resource ownership verified (no IDOR)
- [ ] Sensitive actions require re-authentication
- [ ] JWT validation configured correctly

### Input Validation
- [ ] All inputs validated (FluentValidation)
- [ ] SQL queries parameterized
- [ ] File uploads validated (type, size)
- [ ] No user input in logs

### Secrets & Data
- [ ] No hardcoded secrets
- [ ] Sensitive data not in responses
- [ ] PII not logged
- [ ] HTTPS enforced

```csharp
// ❌ Bad: IDOR vulnerability
[HttpGet("{id}")]
public async Task<IActionResult> GetOrder(Guid id)
{
    var order = await _orderService.GetByIdAsync(id);
    return Ok(order); // Anyone can access any order!
}

// ✅ Good: Ownership check
[HttpGet("{id}")]
public async Task<IActionResult> GetOrder(Guid id)
{
    var userId = User.GetUserId();
    var order = await _orderService.GetByIdAsync(id);
    
    if (order.UserId != userId && !User.IsInRole("Admin"))
        return Forbid();
    
    return Ok(order);
}
```

---

## 5. Performance

### Database
- [ ] No N+1 queries (use Include/projection)
- [ ] Indexes on queried columns
- [ ] Pagination for lists
- [ ] `AsNoTracking()` for read-only queries

### Async
- [ ] Async all the way (no `.Result` or `.Wait()`)
- [ ] `CancellationToken` propagated
- [ ] Parallel operations where appropriate

### Caching
- [ ] Hot data cached (Redis)
- [ ] Appropriate TTLs
- [ ] Cache invalidation strategy

```csharp
// ❌ Bad: N+1 query
var users = await _context.Users.ToListAsync();
foreach (var user in users)
{
    user.Orders = await _context.Orders
        .Where(o => o.UserId == user.Id)
        .ToListAsync(); // N extra queries!
}

// ✅ Good: Eager loading
var users = await _context.Users
    .Include(u => u.Orders)
    .AsNoTracking()
    .ToListAsync();
```

---

## Review Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    REVIEW PROCESS                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Understand context (read ticket/spec)                   │
│  2. Run tests locally (do they pass?)                       │
│  3. Review each file systematically                         │
│  4. Check each axis (Correctness → Performance)             │
│  5. Leave actionable comments                               │
│  6. Approve, Request Changes, or Comment                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Comment Guidelines

### Be Specific

```
// ❌ Vague
"This could be better"

// ✅ Specific
"Consider extracting this validation logic to CreateUserRequestValidator 
to follow the single responsibility principle"
```

### Categorize Severity

> **Canonical vocabulary — must match `commands/review.md` and `skills/code-review/SKILL.md`.** Findings recorded in `reports/CODE_REVIEW.md` use these four labels only.

| Label | Meaning |
|-------|---------|
| 🔴 **Critical** | Merge blocker — correctness, security, data-loss |
| 🟡 **Warning** | Significant issue — architecture violation, latent bug, rule non-compliance |
| 🟢 **Suggestion** | Improvement — readability, style, micro-optimization |
| ✅ **Good** | Praise — highlight what's done well |

> Inline `FYI` / `Question` comments are allowed in the PR conversation but do not constitute a tracked finding and do not appear in `reports/CODE_REVIEW.md`.

### Praise Good Code

```
// ✅ Positive feedback
"Nice use of the Result pattern here - makes error handling much cleaner!"
```

---

## Common Code Smells

| Smell | Symptom | Fix |
|-------|---------|-----|
| Long method | > 30 lines | Extract methods |
| God class | Too many responsibilities | Split into focused classes |
| Feature envy | Method uses other class's data | Move method |
| Primitive obsession | Using primitives for domain concepts | Create value objects |
| Dead code | Unused variables/methods | Delete it |
| Magic numbers | `if (status == 3)` | Use constants/enums |
| Copy-paste | Duplicate code | Extract to shared method |

---

## Quick Decision Matrix

| Issue Type | Label |
|------------|-------|
| Security vulnerability | 🔴 Critical |
| Bug / incorrect behavior | 🔴 Critical |
| Missing test coverage | 🟡 Warning |
| Architecture violation | 🟡 Warning |
| Performance concern (hot path) | 🟡 Warning |
| Performance concern (cold path) | 🟢 Suggestion |
| Naming / style issue | 🟢 Suggestion |
| Missing comment | 🟢 Suggestion (usually skip) |
| Praise-worthy pattern | ✅ Good |

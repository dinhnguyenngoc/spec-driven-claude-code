# Error Handling — C# / ASP.NET Core

## Core Principles

- **Never swallow exceptions silently** — always log or rethrow
- Use a centralized exception handling middleware
- Return consistent error responses using ProblemDetails
- Distinguish between:
  - **Expected exceptions** (business rules, validation) — return 4xx
  - **Unexpected exceptions** (bugs, infrastructure) — return 500, log details

---

## Custom Exception Classes

```csharp
// Core/Exceptions/AppException.cs
public abstract class AppException : Exception
{
    public string Code { get; }
    public int StatusCode { get; }

    protected AppException(string message, string code, int statusCode)
        : base(message)
    {
        Code = code;
        StatusCode = statusCode;
    }
}

// Core/Exceptions/NotFoundException.cs
public class NotFoundException : AppException
{
    public NotFoundException(string message)
        : base(message, "NOT_FOUND", StatusCodes.Status404NotFound) { }

    public NotFoundException(string entityName, object id)
        : base($"{entityName} with ID '{id}' was not found", "NOT_FOUND", StatusCodes.Status404NotFound) { }
}

// Core/Exceptions/ConflictException.cs
public class ConflictException : AppException
{
    public ConflictException(string message)
        : base(message, "CONFLICT", StatusCodes.Status409Conflict) { }
}

// Core/Exceptions/ValidationException.cs
public class ValidationException : AppException
{
    public IReadOnlyDictionary<string, string[]> Errors { get; }

    public ValidationException(IDictionary<string, string[]> errors)
        : base("Validation failed", "VALIDATION_ERROR", StatusCodes.Status400BadRequest)
    {
        Errors = new ReadOnlyDictionary<string, string[]>(errors);
    }
}

// Core/Exceptions/ForbiddenException.cs
public class ForbiddenException : AppException
{
    public ForbiddenException(string message = "Access denied")
        : base(message, "FORBIDDEN", StatusCodes.Status403Forbidden) { }
}

// Core/Exceptions/UnauthorizedException.cs
public class UnauthorizedException : AppException
{
    public UnauthorizedException(string message = "Authentication required")
        : base(message, "UNAUTHORIZED", StatusCodes.Status401Unauthorized) { }
}
```

---

## Throwing Exceptions

```csharp
// Use custom exceptions for known error conditions
public async Task<User> GetByIdAsync(Guid id)
{
    var user = await _repository.GetByIdAsync(id);
    
    if (user == null)
        throw new NotFoundException("User", id);

    return user;
}

public async Task<User> CreateAsync(CreateUserRequest request)
{
    var existingUser = await _repository.GetByEmailAsync(request.Email);
    
    if (existingUser != null)
        throw new ConflictException("A user with this email already exists");

    // ... create user
}

public async Task DeleteAsync(Guid id, Guid currentUserId)
{
    var user = await GetByIdAsync(id);
    
    if (user.Id != currentUserId && !await IsAdminAsync(currentUserId))
        throw new ForbiddenException("You can only delete your own account");

    // ... delete user
}
```

---

## Global Exception Handling Middleware

```csharp
// Api/Middleware/ExceptionHandlingMiddleware.cs
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;
    private readonly IHostEnvironment _environment;

    public ExceptionHandlingMiddleware(
        RequestDelegate next,
        ILogger<ExceptionHandlingMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var (statusCode, errorCode, message, errors) = exception switch
        {
            ValidationException validationEx => (
                validationEx.StatusCode,
                validationEx.Code,
                validationEx.Message,
                validationEx.Errors
            ),
            AppException appEx => (
                appEx.StatusCode,
                appEx.Code,
                appEx.Message,
                (IReadOnlyDictionary<string, string[]>?)null
            ),
            _ => (
                StatusCodes.Status500InternalServerError,
                "INTERNAL_ERROR",
                "An unexpected error occurred",
                (IReadOnlyDictionary<string, string[]>?)null
            )
        };

        // Log based on severity
        if (statusCode >= 500)
        {
            _logger.LogError(exception, 
                "Unhandled exception: {Message} | TraceId: {TraceId}",
                exception.Message,
                context.TraceIdentifier);
        }
        else
        {
            _logger.LogWarning(
                "Client error: {ErrorCode} - {Message} | TraceId: {TraceId}",
                errorCode,
                message,
                context.TraceIdentifier);
        }

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/problem+json";

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = GetTitleForStatusCode(statusCode),
            Detail = message,
            Instance = context.Request.Path,
            Extensions =
            {
                ["traceId"] = context.TraceIdentifier,
                ["code"] = errorCode
            }
        };

        if (errors != null)
        {
            problemDetails.Extensions["errors"] = errors;
        }

        // Include stack trace in development
        if (_environment.IsDevelopment() && statusCode >= 500)
        {
            problemDetails.Extensions["exception"] = exception.ToString();
        }

        await context.Response.WriteAsJsonAsync(problemDetails);
    }

    private static string GetTitleForStatusCode(int statusCode) => statusCode switch
    {
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        409 => "Conflict",
        _ => "Internal Server Error"
    };
}

// Extension method for registration
public static class ExceptionHandlingMiddlewareExtensions
{
    public static IApplicationBuilder UseExceptionHandling(this IApplicationBuilder app)
    {
        return app.UseMiddleware<ExceptionHandlingMiddleware>();
    }
}
```

### Register Middleware

```csharp
// Program.cs
var app = builder.Build();

// Must be first in pipeline to catch all exceptions
app.UseExceptionHandling();

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

---

## API Response Format (ProblemDetails)

Using RFC 7807 ProblemDetails format:

```json
// 404 Not Found
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.4",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID '123' was not found",
  "instance": "/api/users/123",
  "traceId": "00-abc123-def456-00",
  "code": "NOT_FOUND"
}

// 400 Validation Error
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "Bad Request",
  "status": 400,
  "detail": "Validation failed",
  "instance": "/api/users",
  "traceId": "00-abc123-def456-00",
  "code": "VALIDATION_ERROR",
  "errors": {
    "Email": ["Email is required", "Invalid email format"],
    "Password": ["Password must be at least 8 characters"]
  }
}

// 500 Internal Error
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.6.1",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred",
  "instance": "/api/orders",
  "traceId": "00-abc123-def456-00",
  "code": "INTERNAL_ERROR"
}
```

---

## FluentValidation → ValidationException

> **Validator definition & registration:** see [`api-conventions.md`](api-conventions.md#fluentvalidation-integration).
>
> This section focuses only on how validation failures are converted into `ValidationException` so the global exception middleware can render a consistent `ProblemDetails` response.

```csharp
// Api/Filters/ValidationFilter.cs
public class ValidationFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        var serviceProvider = context.HttpContext.RequestServices;

        foreach (var argument in context.Arguments)
        {
            if (argument == null) continue;

            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());
            var validator = serviceProvider.GetService(validatorType) as IValidator;

            if (validator == null) continue;

            var validationContext = new ValidationContext<object>(argument);
            var result = await validator.ValidateAsync(validationContext);

            if (!result.IsValid)
            {
                var errors = result.Errors
                    .GroupBy(e => e.PropertyName)
                    .ToDictionary(
                        g => g.Key,
                        g => g.Select(e => e.ErrorMessage).ToArray());

                throw new ValidationException(errors);
            }
        }

        return await next(context);
    }
}
```

---

## Result Pattern (Alternative to Exceptions)

For cases where you prefer to avoid exceptions for control flow:

```csharp
// Core/Common/Result.cs
public class Result<T>
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? Error { get; }
    public string? ErrorCode { get; }

    private Result(bool isSuccess, T? value, string? error, string? errorCode)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
        ErrorCode = errorCode;
    }

    public static Result<T> Success(T value) => new(true, value, null, null);
    public static Result<T> Failure(string error, string errorCode = "ERROR") 
        => new(false, default, error, errorCode);

    public TResult Match<TResult>(
        Func<T, TResult> onSuccess,
        Func<string, string, TResult> onFailure)
    {
        return IsSuccess 
            ? onSuccess(Value!) 
            : onFailure(Error!, ErrorCode!);
    }
}

// Usage in service
public async Task<Result<UserDto>> GetByIdAsync(Guid id)
{
    var user = await _repository.GetByIdAsync(id);
    
    return user == null
        ? Result<UserDto>.Failure($"User with ID '{id}' not found", "NOT_FOUND")
        : Result<UserDto>.Success(user.ToDto());
}

// Usage in controller
[HttpGet("{id:guid}")]
public async Task<IActionResult> GetById(Guid id)
{
    var result = await _userService.GetByIdAsync(id);
    
    return result.Match<IActionResult>(
        onSuccess: user => Ok(user),
        onFailure: (error, code) => code switch
        {
            "NOT_FOUND" => NotFound(new ProblemDetails { Detail = error }),
            _ => BadRequest(new ProblemDetails { Detail = error })
        });
}
```

---

## Logging Best Practices

```csharp
// Use structured logging
_logger.LogError(exception, 
    "Failed to process order {OrderId} for user {UserId}",
    orderId,
    userId);

// Log context, not just message
_logger.LogWarning(
    "Rate limit exceeded for user {UserId}. Requests: {RequestCount} in {WindowMinutes} minutes",
    userId,
    requestCount,
    windowMinutes);

// Never log sensitive data
_logger.LogInformation("User {UserId} logged in", userId);
// NOT: _logger.LogInformation("User logged in with password {Password}", password);
```

---

## Exception Checklist

- [ ] Custom exceptions extend a base `AppException` class
- [ ] All exceptions include error codes for API clients
- [ ] Global middleware catches and formats all exceptions
- [ ] 5xx errors are logged with full stack trace
- [ ] 4xx errors are logged at warning level
- [ ] Sensitive data never appears in error messages
- [ ] TraceId is included in all error responses
- [ ] ProblemDetails format used for consistency
- [ ] Validation errors include field-level details

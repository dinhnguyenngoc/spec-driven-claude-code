# Performance Checklist

> Quick reference for performance optimization in ASP.NET Core applications.

## Core Web Vitals Targets (Frontend)

| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| **LCP** (Largest Contentful Paint) | < 2.5s | 2.5-4s | > 4s |
| **INP** (Interaction to Next Paint) | < 200ms | 200-500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | < 0.1 | 0.1-0.25 | > 0.25 |

## API Performance Targets

| Metric | Target |
|--------|--------|
| P50 Latency | < 50ms |
| P95 Latency | < 200ms |
| P99 Latency | < 500ms |
| Error Rate | < 0.1% |
| Throughput | Depends on workload |

## Frontend Performance (Next.js)

### Critical Render Path
- [ ] Minimize critical CSS (inline above-fold styles)
- [ ] Defer non-critical JavaScript
- [ ] Preload critical resources
- [ ] Optimize font loading (font-display: swap)

### Images
- [ ] Use modern formats (WebP, AVIF)
- [ ] Implement lazy loading (`next/image`)
- [ ] Serve responsive sizes (srcset)
- [ ] Use CDN for static assets
- [ ] Set explicit width/height (prevent CLS)

### JavaScript
- [ ] Code splitting (dynamic imports)
- [ ] Tree shaking enabled
- [ ] Bundle size monitored (< 200KB initial)
- [ ] No unused dependencies

## Backend Performance (ASP.NET Core)

### Database (EF Core / Dapper)
- [ ] Indexes on queried columns
- [ ] No N+1 queries (use Include/ThenInclude)
- [ ] Pagination implemented
- [ ] Connection pooling configured
- [ ] Query timeouts set
- [ ] Use `AsNoTracking()` for read-only queries

```csharp
// ❌ N+1 Problem
var users = await _context.Users.ToListAsync();
foreach (var user in users)
{
    user.Orders = await _context.Orders
        .Where(o => o.UserId == user.Id)
        .ToListAsync(); // N+1 queries!
}

// ✅ Fixed: Eager loading
var users = await _context.Users
    .Include(u => u.Orders)
    .AsNoTracking()
    .ToListAsync();

// ✅ Alternative: Dapper for complex queries
var users = await _connection.QueryAsync<User, Order, User>(
    @"SELECT u.*, o.* FROM Users u 
      LEFT JOIN Orders o ON o.UserId = u.Id",
    (user, order) => { user.Orders.Add(order); return user; },
    splitOn: "Id");
```

### Response Compression
```csharp
// Program.cs
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
    options.Level = CompressionLevel.Fastest);

app.UseResponseCompression();
```

### Caching
- [ ] Output caching for GET endpoints
- [ ] Distributed cache (Redis) for session/data
- [ ] Appropriate TTLs set
- [ ] Cache invalidation strategy
- [ ] CDN for static content

```csharp
// Redis caching pattern
public async Task<UserDto?> GetUserAsync(Guid id)
{
    var cacheKey = $"myapp:v1:user:{id}";
    
    var cached = await _cache.GetStringAsync(cacheKey);
    if (cached is not null)
        return JsonSerializer.Deserialize<UserDto>(cached);
    
    var user = await _repository.GetByIdAsync(id);
    if (user is null) return null;
    
    var dto = user.ToDto();
    await _cache.SetStringAsync(
        cacheKey, 
        JsonSerializer.Serialize(dto),
        new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
        });
    
    return dto;
}
```

### Async Best Practices
```csharp
// ✅ Good: Async all the way
public async Task<IActionResult> GetUsersAsync()
{
    var users = await _userService.GetAllAsync();
    return Ok(users);
}

// ❌ Bad: Blocking async
public IActionResult GetUsers()
{
    var users = _userService.GetAllAsync().Result; // Deadlock risk!
    return Ok(users);
}

// ✅ Good: Parallel independent operations
var userTask = _userService.GetByIdAsync(userId);
var ordersTask = _orderService.GetByUserIdAsync(userId);
await Task.WhenAll(userTask, ordersTask);
```

### API Optimization
- [ ] Pagination for lists (`?page=1&limit=20`)
- [ ] Field selection (`?fields=id,name,email`)
- [ ] Async operations for slow tasks (queue background jobs)
- [ ] Response caching headers

```csharp
// Paginated endpoint
[HttpGet]
public async Task<ActionResult<PagedResult<UserDto>>> GetUsers(
    [FromQuery] int page = 1,
    [FromQuery] int limit = 20)
{
    var result = await _userService.GetPagedAsync(page, limit);
    return Ok(result);
}
```

## Measurement Commands

```bash
# EF Core query logging (development)
# In appsettings.Development.json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
}

# SQL Server query analysis — built-in DMVs (no extra install)
# Missing indexes the optimizer would benefit from:
SELECT  mid.statement AS table_name,
        migs.avg_user_impact,
        migs.user_seeks + migs.user_scans AS demand,
        mid.equality_columns, mid.inequality_columns, mid.included_columns
FROM    sys.dm_db_missing_index_groups       mig
JOIN    sys.dm_db_missing_index_group_stats  migs ON migs.group_handle = mig.index_group_handle
JOIN    sys.dm_db_missing_index_details      mid  ON mig.index_handle  = mid.index_handle
ORDER BY migs.avg_user_impact * demand DESC;

# Top expensive queries:
SELECT TOP 20 qs.total_worker_time/qs.execution_count AS avg_cpu_us,
              qs.execution_count, SUBSTRING(qt.text, qs.statement_start_offset/2, 200) AS query
FROM   sys.dm_exec_query_stats qs
CROSS  APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER  BY avg_cpu_us DESC;

# Optional 3rd-party (Brent Ozar's First Responder Kit): sp_BlitzIndex, sp_BlitzCache

# Redis latency
redis-cli --latency

# API response time
curl -o /dev/null -s -w '%{time_total}\n' https://api.example.com/health

# .NET diagnostics
dotnet-counters monitor --process-id <PID> --counters System.Runtime
dotnet-trace collect --process-id <PID>
```

## BenchmarkDotNet

```csharp
// For micro-benchmarking critical code paths
[MemoryDiagnoser]
public class SerializationBenchmarks
{
    private readonly User _user = new() { Id = Guid.NewGuid(), Name = "Test" };

    [Benchmark(Baseline = true)]
    public string NewtonsoftJson()
        => JsonConvert.SerializeObject(_user);

    [Benchmark]
    public string SystemTextJson()
        => JsonSerializer.Serialize(_user);
}

// Run: dotnet run -c Release
```

## Performance Budget

| Resource | Budget |
|----------|--------|
| Initial JS (Frontend) | < 200KB |
| Initial CSS | < 50KB |
| Total page weight | < 1MB |
| API response (P95) | < 200ms |
| Database query | < 50ms |
| Cache hit ratio | > 80% |

## Monitoring

- [ ] OpenTelemetry tracing enabled
- [ ] Prometheus metrics exposed (`/metrics`)
- [ ] Grafana dashboards (RED method: Rate, Errors, Duration)
- [ ] Alerting on latency/error rate
- [ ] Serilog structured logging

```csharp
// Health check with dependencies
builder.Services.AddHealthChecks()
    .AddSqlServer(connectionString, name: "sqlserver")
    .AddRedis(redisConnectionString, name: "redis")
    .AddKafka(producerConfig, name: "kafka");
```

## Common Performance Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| N+1 queries | Slow list endpoints | Use Include/Dapper |
| Missing indexes | Slow queries | Add appropriate indexes |
| Sync over async | Thread pool exhaustion | Async all the way |
| No caching | Repeated DB calls | Add Redis caching |
| Large payloads | High latency | Pagination, field selection |
| No compression | High bandwidth | Enable Brotli/Gzip |

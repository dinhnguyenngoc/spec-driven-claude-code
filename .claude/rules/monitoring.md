# Monitoring & Observability — ASP.NET Core

> Standards for logging, metrics, tracing, alerting, and Grafana dashboard design.
>
> **Default backend = Serilog + Prometheus + Grafana + Jaeger.** If `Project Profile → Observability` declares **ELK** → read alongside `rules/overrides/monitoring-elk.md` (switch the sink + dashboard to Elasticsearch/Kibana). All agnostic principles (structured logging, correlation id, log levels, no logging of sensitive data, health checks, RED/USE method) **remain unchanged across every backend**.

## The Three Pillars of Observability

| Pillar | Tool | Purpose |
|--------|------|---------|
| **Logs** | Serilog + Grafana Loki | What happened |
| **Metrics** | Prometheus + Grafana | How the system is behaving |
| **Traces** | OpenTelemetry + Jaeger | Why something is slow |

---

## Logging (Serilog)

### Log Levels

| Level | When to Use |
|-------|-------------|
| `Fatal` | Application cannot continue |
| `Error` | Unexpected failure requiring attention |
| `Warning` | Unexpected but recoverable situation |
| `Information` | Normal significant events (startup, request lifecycle) |
| `Debug` | Detailed debugging info (dev only) |
| `Verbose` | Very verbose (never in production) |

### Serilog Setup

```csharp
// Program.cs
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.EntityFrameworkCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithEnvironmentName()
    .Enrich.WithProperty("Application", "MyApp.Api")
    .Enrich.WithProperty("Version", typeof(Program).Assembly.GetName().Version?.ToString())
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.File(
        new JsonFormatter(),
        "logs/log-.json",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 7)
    .CreateLogger();

try
{
    Log.Information("Starting application");
    
    var builder = WebApplication.CreateBuilder(args);
    builder.Host.UseSerilog();
    
    // ... rest of setup
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application failed to start");
    throw;
}
finally
{
    Log.CloseAndFlush();
}
```

### Structured Logging

```csharp
// Use message templates with named properties
_logger.LogInformation(
    "Order {OrderId} placed by user {UserId} for {Amount:C}",
    order.Id,
    userId,
    order.Total);

// Include context with BeginScope
using (_logger.BeginScope(new Dictionary<string, object>
{
    ["OrderId"] = orderId,
    ["UserId"] = userId
}))
{
    _logger.LogInformation("Processing order");
    // All logs within scope include OrderId and UserId
}

// Output (JSON):
// {
//   "Timestamp": "2024-01-15T10:30:00Z",
//   "Level": "Information",
//   "MessageTemplate": "Order {OrderId} placed by user {UserId} for {Amount:C}",
//   "Properties": {
//     "OrderId": "abc-123",
//     "UserId": "user-456",
//     "Amount": 99.99,
//     "Application": "MyApp.Api",
//     "MachineName": "server-1"
//   }
// }
```

### Correlation ID Middleware

```csharp
// Api/Middleware/CorrelationIdMiddleware.cs
public class CorrelationIdMiddleware
{
    private const string CorrelationIdHeader = "X-Correlation-ID";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = context.Request.Headers[CorrelationIdHeader].FirstOrDefault()
            ?? Guid.NewGuid().ToString();

        context.Response.Headers[CorrelationIdHeader] = correlationId;

        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await _next(context);
        }
    }
}
```

### What NOT to Log

```csharp
// NEVER log sensitive data
_logger.LogInformation("User logged in: {Password}", password);     // NEVER
_logger.LogInformation("Token: {Token}", authToken);                 // NEVER
_logger.LogInformation("Credit card: {CardNumber}", cardNumber);     // NEVER

// Use destructuring to exclude sensitive fields
Log.Logger = new LoggerConfiguration()
    .Destructure.ByTransforming<User>(u => new
    {
        u.Id,
        u.Email,
        PasswordHash = "***REDACTED***"
    })
    .CreateLogger();
```

---

## Metrics (OpenTelemetry + Prometheus)

### Setup

```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddProcessInstrumentation()
            .AddMeter("MyApp.Api")
            .AddPrometheusExporter();
    });

// Expose Prometheus endpoint
app.MapPrometheusScrapingEndpoint("/metrics");
```

### Custom Metrics

```csharp
// Core/Metrics/ApplicationMetrics.cs
using System.Diagnostics.Metrics;

public class ApplicationMetrics
{
    private readonly Counter<long> _ordersCreated;
    private readonly Histogram<double> _orderProcessingDuration;
    private readonly ObservableGauge<int> _activeConnections;
    
    private int _connectionCount;

    public ApplicationMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("MyApp.Api");

        _ordersCreated = meter.CreateCounter<long>(
            "orders_created_total",
            description: "Total number of orders created");

        _orderProcessingDuration = meter.CreateHistogram<double>(
            "order_processing_duration_seconds",
            unit: "s",
            description: "Order processing duration");

        _activeConnections = meter.CreateObservableGauge(
            "active_connections",
            () => _connectionCount,
            description: "Number of active connections");
    }

    public void OrderCreated(string status)
    {
        _ordersCreated.Add(1, new KeyValuePair<string, object?>("status", status));
    }

    public void RecordOrderProcessing(double durationSeconds)
    {
        _orderProcessingDuration.Record(durationSeconds);
    }
}

// Usage in service
public class OrderService
{
    private readonly ApplicationMetrics _metrics;

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        var sw = Stopwatch.StartNew();
        
        try
        {
            var order = await ProcessOrderAsync(request);
            _metrics.OrderCreated("success");
            return order;
        }
        catch
        {
            _metrics.OrderCreated("failed");
            throw;
        }
        finally
        {
            _metrics.RecordOrderProcessing(sw.Elapsed.TotalSeconds);
        }
    }
}
```

### Metric Naming Convention

```
# Pattern: {namespace}_{subsystem}_{name}_{unit}
# All lowercase, underscores

http_request_duration_seconds         # histogram
http_requests_total                   # counter
http_requests_in_flight               # gauge
db_query_duration_seconds             # histogram
cache_hits_total                      # counter
cache_misses_total                    # counter
orders_created_total                  # counter
queue_messages_pending                # gauge
```

### Labels (Dimensions)

```csharp
// Use labels for meaningful dimensions
_ordersCreated.Add(1, 
    new KeyValuePair<string, object?>("status", "completed"),
    new KeyValuePair<string, object?>("payment_method", "credit_card"));

// DON'T use high-cardinality labels (userId, orderId)
// This creates millions of time series and crashes Prometheus
```

---

## Distributed Tracing (OpenTelemetry + Jaeger)

### Setup

```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("MyApp.Api")
                .AddTelemetrySdk())
            .AddSource("MyApp.Api")
            .AddAspNetCoreInstrumentation(options =>
            {
                options.RecordException = true;
                options.Filter = context => 
                    !context.Request.Path.StartsWithSegments("/health");
            })
            .AddHttpClientInstrumentation()
            .AddEntityFrameworkCoreInstrumentation(options =>
            {
                options.SetDbStatementForText = true;
            })
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(builder.Configuration["Jaeger:Endpoint"]!);
            });
    });
```

### Custom Spans

```csharp
using System.Diagnostics;

public class OrderService
{
    private static readonly ActivitySource ActivitySource = new("MyApp.Api");

    public async Task<Order> ProcessOrderAsync(CreateOrderRequest request)
    {
        using var activity = ActivitySource.StartActivity("ProcessOrder");
        activity?.SetTag("order.user_id", request.UserId);
        activity?.SetTag("order.items_count", request.Items.Count);

        try
        {
            // Validate
            using (var validateActivity = ActivitySource.StartActivity("ValidateOrder"))
            {
                await ValidateOrderAsync(request);
            }

            // Process payment
            using (var paymentActivity = ActivitySource.StartActivity("ProcessPayment"))
            {
                await ProcessPaymentAsync(request);
            }

            activity?.SetTag("order.status", "completed");
            return order;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);
            throw;
        }
    }
}
```

### Span Naming Convention

```
# HTTP: {method} {route}
GET /api/v1/users/{id}

# DB: {operation} {table}
SELECT Users
INSERT Orders

# Cache: {operation} {key_pattern}
GET user:{id}
SET session:{id}

# Queue: {operation} {topic}
PUBLISH order.events
CONSUME user.events
```

---

## Health Checks

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")!,
        name: "sqlserver",
        tags: new[] { "ready" })
    .AddRedis(
        builder.Configuration.GetConnectionString("Redis")!,
        name: "redis",
        tags: new[] { "ready" })
    .AddKafka(
        new ProducerConfig
        {
            BootstrapServers = builder.Configuration["Kafka:BootstrapServers"]
        },
        name: "kafka",
        tags: new[] { "ready" });

// Health endpoints
app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = _ => false // Basic liveness
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = WriteHealthCheckResponse
});

static Task WriteHealthCheckResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json";
    return context.Response.WriteAsJsonAsync(new
    {
        status = report.Status.ToString(),
        checks = report.Entries.Select(e => new
        {
            name = e.Key,
            status = e.Value.Status.ToString(),
            duration = e.Value.Duration.TotalMilliseconds
        })
    });
}
```

---

## Grafana Dashboard Design

### Dashboard Naming

```
{Service} — {Category}
MyApp API — Overview
MyApp API — Errors & Latency
Order Service — Business Metrics
Infrastructure — SQL Server
Infrastructure — Redis
```

### Panel Naming

```
# Use title case, include units
Request Rate (req/s)
P99 Latency (ms)
Error Rate (%)
Active DB Connections
Cache Hit Rate (%)
Queue Depth
Memory Usage (MB)
```

### The RED Method (for Services)

Every service dashboard MUST have:
- **R** — **Rate**: requests per second
- **E** — **Errors**: error rate (%)
- **D** — **Duration**: P50, P95, P99 latency

```promql
# Rate
rate(http_server_request_duration_seconds_count{service="myapp-api"}[5m])

# Error rate
rate(http_server_request_duration_seconds_count{http_status_code=~"5.."}[5m])
/ rate(http_server_request_duration_seconds_count[5m]) * 100

# P99 latency (ms)
histogram_quantile(0.99,
  rate(http_server_request_duration_seconds_bucket{service="myapp-api"}[5m])
) * 1000
```

### Standard Dashboard Layout

```
Row 1: Summary / Health Overview (traffic lights)
Row 2: RED metrics (Rate, Errors, Duration)
Row 3: Resource usage (CPU, Memory, DB connections)
Row 4: Business metrics (orders/min, signups, payments)
Row 5: Logs panel (Loki integration)
```

---

## Alerting Rules

### Severity Levels

| Level | Response Time | Example |
|-------|--------------|---------|
| `critical` | Immediate (PagerDuty) | Service down, payment failures |
| `warning` | Within 30min (Slack) | High error rate, slow queries |
| `info` | Business hours | Unusual traffic patterns |

### Prometheus Alert Rules

```yaml
groups:
  - name: myapp-api-alerts
    rules:
      # Service is down
      - alert: ServiceDown
        expr: up{job="myapp-api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MyApp API is down"

      # High error rate
      - alert: HighErrorRate
        expr: |
          rate(http_server_request_duration_seconds_count{http_status_code=~"5.."}[5m])
          / rate(http_server_request_duration_seconds_count[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Error rate > 5%"

      # High P99 latency
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            rate(http_server_request_duration_seconds_bucket[5m])
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency > 1s"

      # Low cache hit rate
      - alert: LowCacheHitRate
        expr: |
          rate(cache_hits_total[5m])
          / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.7
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit rate < 70%"
```

---

## Checklist

- [ ] Serilog configured with structured JSON logging
- [ ] Correlation ID middleware added
- [ ] Sensitive data excluded from logs
- [ ] OpenTelemetry metrics configured
- [ ] Prometheus endpoint exposed at `/metrics`
- [ ] Distributed tracing configured with Jaeger
- [ ] Health checks for all dependencies
- [ ] Grafana dashboards with RED metrics
- [ ] Alerts configured for critical issues

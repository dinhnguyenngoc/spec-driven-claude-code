# Override: Observability — ELK Stack

> **Active when** `Project Profile → Observability: ELK`. Read alongside `rules/monitoring.md` (base). This file **only records the differences** from the default stack (Serilog→file + Prometheus + Grafana + Jaeger). All agnostic principles in the base (structured logging, correlation id, log levels, no logging of sensitive data, health checks, RED/USE method) **remain unchanged**.

## Replacement map

| Pillar | Base (default) | ELK (override) |
|--------|----------------|----------------|
| **Logs** | Serilog → Console/File JSON + Loki | Serilog → **Elasticsearch** (via sink), viewed in **Kibana** |
| **Metrics** | Prometheus + Grafana | **Metricbeat** → Elasticsearch, Kibana dashboards (or keep Prometheus in parallel if needed) |
| **Traces** | OpenTelemetry + Jaeger | OpenTelemetry → **APM Server** (Elastic APM) → Kibana APM |
| **Dashboard** | Grafana | **Kibana** |

## Logs — Serilog sink to Elasticsearch

```xml
<PackageReference Include="Serilog.Sinks.Elasticsearch" Version="10.*" />
<!-- or Elastic.Serilog.Sinks (ECS-native, newer recommended) -->
<PackageReference Include="Elastic.Serilog.Sinks" Version="8.*" />
```

```csharp
// replaces .WriteTo.Console(new JsonFormatter()) / .WriteTo.File(...)
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Application", "MyApp.Api")
    // ECS format — standard Elastic schema, fields auto-mapped in Kibana
    .WriteTo.Elasticsearch(new[] { new Uri(cfg["Elastic:Uri"]!) }, opts =>
    {
        opts.DataStream = new DataStreamName("logs", "myapp", "prod");
        opts.BootstrapMethod = BootstrapMethod.Failure;
    })
    .CreateLogger();
```

- **Index/data-stream naming:** `logs-myapp-{environment}` (following Elastic data stream convention).
- **ECS (Elastic Common Schema):** use ECS formatter so fields are standardized (`@timestamp`, `service.name`, `trace.id`, `log.level`) — Kibana displays + correlates traces automatically.
- **Correlation id:** the `CorrelationId` field (from the base `CorrelationIdMiddleware`) must be enriched onto every log event — do not change the middleware, only change the sink.

## Traces — OpenTelemetry → Elastic APM

```csharp
builder.Services.AddOpenTelemetry().WithTracing(t => t
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddEntityFrameworkCoreInstrumentation()
    // replace AddOtlpExporter→Jaeger with OTLP→APM Server
    .AddOtlpExporter(o => o.Endpoint = new Uri(cfg["Elastic:ApmOtlpEndpoint"]!)));
```

## Alerting & dashboards

- **Dashboard:** built in **Kibana** (replaces Grafana). RED method (Rate/Errors/Duration) for services, USE for resources — **same metrics, different visualization tool**.
- **Alerting:** **Kibana Alerting** / ElastAlert (replaces Prometheus Alertmanager). Severity levels (critical/warning/info) + thresholds **remain unchanged** per base `monitoring.md` §Alerting.
- Query: KQL (Kibana Query Language) replaces PromQL — e.g. error rate, P99 latency computed over ECS fields `event.duration` / `http.response.status_code`.

## Health checks

Unchanged — `/health`, `/health/ready`, `/health/live` per base. You may add a health check for Elasticsearch reachability if the app logs synchronously (recommended to use async/buffered sink so a logging outage does not bring down requests).

## Unchanged (still follows base `monitoring.md`)

Structured logging + message templates, log levels, **no logging of sensitive data** (destructure-redact `PasswordHash`/token), correlation id middleware, RED/USE method, severity thresholds, span naming convention.

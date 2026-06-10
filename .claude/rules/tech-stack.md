# Technology Stack — Selection & Standards

> This rule defines the **approved tech stack** and the **decision process** for adopting new technologies. Implementation details for each layer live in the specialized rules (see "Where to look for implementation" at the bottom).

---

## Core vs Peripheral (read `Project Profile` first)

The stack is divided into 2 groups. **Core is fixed** for every project using this kit; **Peripheral is declared per-project** in `## Project Profile` (CLAUDE.md) and may be overridden.

| Group | Components | Rule |
|-------|-----------|------|
| **CORE (fixed per project)** | Language **C# 12**, framework **ASP.NET Core 8**, ORM **EF Core 8** (default) | Do not change mid-project. Default = C#/.NET — all code rules (`code-style`, `clean-code`, `error-handling`, `api-conventions`, `naming-conventions`) apply as-is. If the Profile declares a **Node.js** core → apply the 3 Node overrides (see table below) |
| **PERIPHERAL (per-project)** | Database engine, cache, message broker, **observability backend**, file storage, search | Default = Quick Reference table below. If the Profile declares otherwise → follow `rules/overrides/*` |

**Available overrides:**

| Peripheral | Default | Override when Profile declares otherwise |
|-----------|---------|------------------------------------------|
| Core language | C# 12 + ASP.NET Core 8 + EF Core 8 | Node.js → [`overrides/lang-nodejs.md`](overrides/lang-nodejs.md) + [`overrides/framework-nodejs-web.md`](overrides/framework-nodejs-web.md) + [`overrides/test-nodejs.md`](overrides/test-nodejs.md) |
| Database | SQL Server 2022 | Oracle → [`overrides/database-oracle.md`](overrides/database-oracle.md) · MySQL → [`overrides/database-mysql.md`](overrides/database-mysql.md) · PostgreSQL → [`overrides/database-postgres.md`](overrides/database-postgres.md) · MongoDB (NoSQL) → [`overrides/database-mongodb.md`](overrides/database-mongodb.md) |
| Observability | Grafana + Prometheus + Serilog | ELK → [`overrides/monitoring-elk.md`](overrides/monitoring-elk.md) |

> When an override is active: it **only replaces the dialect/backend-specific parts**; all agnostic principles (parametrized query, AsNoTracking, structured logging, correlation id…) in the base rule still apply. The Quick Reference table below is the **default profile** — read it together with the Project Profile to know which entries have been overridden.

---

## Quick Reference — Approved Stack

| Layer | Primary Choice | Alternative | Avoid |
|-------|---------------|-------------|-------|
| **Frontend — Landing/SEO** | Next.js 14+ (App Router) | — | CRA (deprecated) |
| **Frontend — Admin/Dashboard** | React + Vite (SPA) | — | Next.js (overkill for admin) |
| **UI Components** | shadcn/ui + Radix UI | Chakra UI | MUI (too heavy) |
| **Styling** | Tailwind CSS | CSS Modules | Styled-components (runtime cost) |
| **State Management** | Zustand | Redux Toolkit | MobX, Recoil |
| **Data Fetching** | TanStack Query (React Query) | SWR | Axios alone |
| **Form Validation** | React Hook Form + Zod | — | Formik (heavier) |
| **Backend Framework** | ASP.NET Core 8 (LTS) | — | Node.js/Express |
| **API Style** | REST (Controller-based) | gRPC (internal only) | GraphQL (unless needed) |
| **Language** | C# 12 | — | JavaScript/TypeScript backend |
| **Database** | SQL Server 2022 | PostgreSQL | MySQL |
| **ORM** | Entity Framework Core 8 | — | NHibernate |
| **High-Performance Query** | Dapper | — | Raw ADO.NET |
| **Validation** | FluentValidation | — | Data Annotations alone |
| **Cache** | Redis (StackExchange.Redis) | — | Memcached |
| **Message Broker** | Apache Kafka | — | RabbitMQ (unless simpler needs) |
| **Background Jobs** | Hangfire | Kafka Consumer | Quartz.NET |
| **API Gateway** | YARP | — | Ocelot |
| **Auth** | JWT + Keycloak | ASP.NET Identity | Firebase Auth |
| **File Storage** | Azure Blob / AWS S3 | MinIO | Local disk |
| **Email** | SendGrid | SMTP direct | — |
| **Search** | SQL Server FTS | Elasticsearch | — |
| **Monitoring** | Grafana + Prometheus | Datadog | — |
| **Logging** | Serilog | — | NLog, log4net |
| **Metrics** | OpenTelemetry + Prometheus | — | Custom metrics |
| **Tracing** | OpenTelemetry + Jaeger | — | Zipkin |
| **Testing** | xUnit + FluentAssertions | NUnit | MSTest |
| **Mocking** | Moq | NSubstitute | — |
| **Integration Testing** | WebApplicationFactory | — | — |
| **E2E Testing** | Playwright | Cypress | Selenium |
| **Containerization** | Docker + Docker Compose | — | — |
| **Orchestration (later)** | Kubernetes | — | Docker Swarm |
| **Reverse Proxy** | NGINX | — | IIS (Windows only) |
| **Resilience** | Polly | — | Custom retry logic |
| **API Docs** | Swagger / OpenAPI 3.0 | — | — |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     RECOMMENDED ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Next.js Frontend                                               │
│         ↓                                                        │
│      NGINX (Reverse Proxy)                                       │
│         ↓                                                        │
│   YARP API Gateway                                               │
│         ↓                                                        │
│   ASP.NET Core Services                                          │
│         ↓                                                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  SQL Server    │    Redis    │    Kafka                │   │
│   └─────────────────────────────────────────────────────────┘   │
│         ↓                                                        │
│   Observability Stack                                            │
│   (Serilog + Prometheus + Grafana + OpenTelemetry + Jaeger)     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Frontend — Next.js vs Vite SPA

A project typically ships **both** surfaces. Pick per surface, not per project.

| Criteria | Next.js 14 (App Router) | React + Vite (SPA) |
|----------|------------------------|--------------------|
| **Purpose** | Landing page, marketing, blog | Admin panel, dashboard, internal tool |
| **SEO** | SSR/SSG — Google indexes well | SPA — poor SEO |
| **Hosting** | Vercel (optimal) | Cloudflare Pages, Netlify, S3 |
| **Performance** | Server Components — less JS to client | Client-side rendering |
| **Auth** | NextAuth.js | JWT in cookie/localStorage |
| **API** | Route Handlers or Server Actions | Call backend REST separately |

> Coding standards, component patterns, state management, forms, accessibility, and performance targets → [`frontend.md`](frontend.md).

---

## Backend — Why ASP.NET Core 8

- High performance (consistently top of TechEmpower benchmarks)
- Built-in DI, middleware pipeline, configuration system
- Long-term support (.NET 8 LTS until November 2026)
- Strong typing — failures caught at compile time
- Excellent tooling (Visual Studio, Rider, VS Code)
- Native async/await throughout

> Solution layout & layer boundaries → [`project-structure.md`](project-structure.md). API conventions → [`api-conventions.md`](api-conventions.md). Error handling → [`error-handling.md`](error-handling.md).

---

## Technology Decision Process

When **proposing a new library or technology**, evaluate against these criteria:

| Criterion | Questions to Ask |
|-----------|-----------------|
| **Necessity** | Does an approved alternative already solve this? |
| **Maintenance** | NuGet downloads > 100k? Last commit < 6 months? |
| **Performance** | Any benchmarks available? |
| **License** | Is it MIT/Apache? (No GPL in commercial products) |
| **Security** | `dotnet list package --vulnerable` — zero high/critical |
| **Community** | Active issues/discussions? Stack Overflow answers? |

### Decision Template

```markdown
## Technology Decision: [Library Name]

**Problem**: What problem does this solve?
**Alternative evaluated**: What from the approved stack was considered?
**Why chosen**: Specific reason this is better for the use case
**Risk**: Known downsides or migration cost
**Decision**: Adopt / Reject
```

---

## What NOT to Use Initially

| Technology/Pattern | Reason |
|-------------------|--------|
| Kubernetes | Complexity too high for start |
| Service Mesh (Istio) | Overkill |
| CQRS everywhere | Increases complexity |
| Event Sourcing | Hard to maintain |
| gRPC everywhere | Harder to debug than REST |
| Multi-database polyglot | Operational complexity |
| Distributed transactions | Hard to scale |
| Too-small microservices | Network overhead |

---

## Production Practices (Critical)

| # | Practice | What it means | Reference |
|---|----------|---------------|-----------|
| 1 | **Structured logging** | Every request carries Correlation ID, User ID, Trace ID | [`monitoring.md`](monitoring.md) |
| 2 | **Database indexing** | Most bottlenecks are in the DB, not the framework. Profile queries regularly | [`database.md`](database.md) |
| 3 | **Async processing** | Never block HTTP requests for email, notifications, reports, file exports — push to Kafka/Hangfire | [`system-design.md`](system-design.md) |
| 4 | **Cache correctly** | Redis for hot data, sessions, rate limiting, expensive queries | [`database.md`](database.md) |
| 5 | **Graceful failure** | Retry with backoff, fallback response, timeout — never crash the whole system | [`system-design.md`](system-design.md) |
| 6 | **Secrets management** | No hardcoded secrets; User Secrets in dev, Key Vault / Secrets Manager in prod | [`security.md`](security.md) |

---

## Where to look for implementation

This rule says **what to use** and **why**. Each rule below owns the **how** for its layer — do not duplicate setup code here.

| Concern | Authoritative rule |
|---------|--------------------|
| Solution layout, DI registration, Clean Architecture layers | [`project-structure.md`](project-structure.md) |
| EF Core, Dapper, migrations, transactions, N+1 prevention | [`database.md`](database.md) |
| Cache keys, naming, env vars, Kafka topics | [`naming-conventions.md`](naming-conventions.md) |
| REST routes, versioning, ProblemDetails, Swagger, FluentValidation wiring | [`api-conventions.md`](api-conventions.md) |
| Global exception middleware, `AppException`, error contract | [`error-handling.md`](error-handling.md) |
| Serilog, OpenTelemetry, Prometheus, health checks, alerting | [`monitoring.md`](monitoring.md) |
| JWT, password hashing, security headers, CORS, rate limiting | [`security.md`](security.md) |
| Caching strategies, circuit breaker, retries, sharding | [`system-design.md`](system-design.md) |
| Unit/integration/E2E pyramid, TestContainers fixtures, coverage thresholds | [`testing.md`](testing.md) |
| Next.js/React/Tailwind coding standards | [`frontend.md`](frontend.md) |
| Dockerfile patterns, docker-compose service health checks | [`../references/docker-patterns.md`](../references/docker-patterns.md) |

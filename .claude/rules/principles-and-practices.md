# Engineering Principles & Best Practices

> Single source of truth for design principles, best practices, architecture defaults, container baseline, and NFR-dependent infrastructure. Referenced across the entire kit.

> **Scope:** applies to all projects using this kit. Items marked **[v2 trigger]** are conditional — activated only when the listed trigger is met. Items in §5 are **opt-in**: design the interface from day 1, implement when measurement justifies it.

---

## 1. Design Principles

### 1.1 SOLID
- **S**ingle Responsibility — one class = one reason to change
- **O**pen/Closed — open for extension, closed for modification
- **L**iskov Substitution — derived classes substitute base classes safely
- **I**nterface Segregation — many small, specific interfaces > one large interface
- **D**ependency Inversion — depend on abstractions, not concretions

### 1.2 Pragmatic constraints
- **YAGNI** — You Aren't Gonna Need It; do not add abstractions for hypothetical futures
- **KISS** — Keep It Simple, Stupid; the simplest thing that could work
- **DRY** — Don't Repeat Yourself, **with discipline**: three similar lines is better than a premature abstraction

> Tension: SOLID + DRY can push toward over-engineering. YAGNI + KISS pull back. Lean YAGNI when in doubt.

### 1.3 Code-level habits
- **Composition > Inheritance** — favor object composition over class inheritance hierarchies
- **Tell-Don't-Ask** — tell objects what to do; do not ask for state and then decide outside
- **Law of Demeter** — talk only to immediate friends; avoid `a.b.c.d.e` chains

### 1.4 Separation of Concerns (SoC)
- Each module owns one concern
- Cross-cutting concerns (logging, auth, validation, error handling) live in dedicated layers/middleware
- Foundation of Clean Architecture layering

### 1.5 Module/system level
- **Loosely Coupled** — modules know minimum about each other; depend on interfaces, not concrete types
- **Acyclic Dependency** — no circular dependencies between modules (verify via static analysis)
- **Backward Compatibility (default)** — API contracts, response shape, DB schema, event format: never break without ADR + migration plan. See [`brownfield.md`](brownfield.md).

### 1.6 Quality attributes (-ilities)
- **Scalable** — designed to handle 10× current load without redesign
- **Resilient** — fails gracefully under partial outage; auto-recovers when dependencies come back
- **Observable** — every behavior is visible via logs, metrics, traces, audit log
- **Fault Isolation** — failure in one component does not cascade across the system

### 1.7 Microservices-specific principles [v2 trigger]
> Apply only **after** the architecture decision in §3 has moved to microservices.

- **Independently Deployable** [v2] — each service deploys without coordinating with others
- **Decentralized Data** [v2] — each service owns its data; no shared DB across service boundaries
- **Technology Agnostic** [v2, expensive] — each service can use its own stack
  - ⚠️ **Tradeoff**: this principle is costly. Multi-stack teams pay ongoing tax in tooling, libraries, hiring, and operational complexity. Apply only when justified by domain or team boundary, **not as a default**.

---

## 2. Best Practices

### 2.1 Service design
1. **Keep services small and focused** — one bounded context per service
2. **Design for failure** — every external call can fail; assume it will
3. **Use asynchronous communication** — where decoupling is needed; not as a default
4. **Version your APIs** — URL path versioning (`/api/v1/...`); deprecation policy with sunset header
5. **Secure service-to-service communication** — mTLS or signed tokens; never trust the network

### 2.2 Quality discipline
6. **Test-first / TDD** — write a failing test before implementation. See [`testing.md`](testing.md).
7. **Code review (Five-Axis)** — Correctness, Readability, Architecture, Security, Performance
8. **Pre-commit hooks** — lint, format, unit-test before commit. See [`git-workflow.md`](git-workflow.md).
9. **Idempotency keys** — for non-idempotent operations (POST, PATCH) that may be retried under failure

### 2.3 Operations
10. **Automate everything** — build, test, deploy, infrastructure, security scanning, monitoring
11. **Monitor and observe everything** — logs + metrics + traces + audit log
12. **SLO/SLI + error budget** — quantify "observable"; alerts trigger from SLO breach, not arbitrary thresholds

### 2.4 Continuous learning
13. **ADR — Documentation as code** — every architectural decision recorded with context, options, consequences, v2 trigger
14. **Postmortem (blameless)** — after every incident; document root cause + lessons; update runbook

---

## 3. Architecture Decision

### 3.1 Default — Modular Monolith + Clean Architecture

> Use this as the starting point unless an ADR justifies otherwise. Microservices is **not** the default.

**Structure:**

```
src/
├── App.Api/                       # Presentation
├── App.Core/                      # Domain + Application
│   ├── Modules/
│   │   ├── UserModule/            # Bounded context: User
│   │   ├── BookmarkModule/        # Bounded context: Bookmark
│   │   └── TagModule/             # Bounded context: Tag
│   ├── Shared/                    # Cross-cutting (auth, time, ID generation)
│   └── Interfaces/                # Module contracts
└── App.Infrastructure/            # EF Core, Redis, Kafka, external adapters
```

**Why modular monolith first:**
- Lower operational cost (single deploy, no distributed system tax)
- Bounded contexts identified in code structure, even though they share a process
- Strangler-fig path open: when a module needs independent scaling/team/tech → extract to microservice

**Module discipline:**
- Each module has its own folder + namespace
- Modules communicate only via published interfaces (no direct entity reach across modules)
- Cross-module integration via in-process events or service contracts
- DB tables owned by module (schema-per-module if SQL Server supports it; otherwise table prefix)

### 3.2 When to revisit (move toward microservices)

Trigger ADR + redesign when **any 2 of the following** become true:
- Team size > 15 developers with persistent merge-conflict pain
- One module has dramatically different scaling needs (10× other modules)
- Independent deploy cadence required (one module ships daily, others weekly)
- Compliance requires data isolation (PII, financial — schema/DB-level)
- Tech-stack divergence required (one module needs Python/ML, the rest stay on C#)

### 3.3 Strangler-fig migration path

1. Extract module from monolith into a standalone service behind the same external API
2. Route a subset of traffic via gateway to the new service
3. Decommission the monolith path when the new service is stable
4. **Never** big-bang rewrite (see [`brownfield.md`](brownfield.md))

> **DO NOT** start with microservices. (Martin Fowler — "MonolithFirst")

---

## 4. Docker Baseline (20 must-haves)

> All apply to **every** containerized service. Verified by `/infra` (creation) and `/deploy` (gate). See [`../references/docker-patterns.md`](../references/docker-patterns.md) for templates.

### 4.1 Image construction
1. **Multi-stage build** — separate build stage from runtime; smaller final image (3–10× smaller)
2. **Non-root user** — `USER appuser` (UID ≥ 1000); never run as root in production
3. **HEALTHCHECK self-describing** — defined in Dockerfile, works under any orchestrator
4. **Image pinned** — digest (`@sha256:...`) or semver tag; never `:latest` beyond a dev laptop
5. **`.dockerignore` at repo root** — exclude `.env`, `node_modules`, `bin/obj`, SDLC artifacts
6. **Container image scanning** — Trivy/Grype in CI; block on Critical/High CVE

### 4.2 Runtime safety
7. **Resource limits** — CPU and memory limits in compose/k8s; prevent noisy-neighbor failure modes
8. **Read-only filesystem** where possible — mark only required dirs as writable
9. **Secrets NOT in image** — inject via env/vault; never `COPY .env` or hardcode

### 4.3 Health & observability hooks
10. **Health check endpoints** — `/health/live` (process alive) + `/health/ready` (dependencies OK)
11. **Logging to stdout/stderr** — let orchestrator capture; structured JSON (Serilog). See [`monitoring.md`](monitoring.md).
12. **Metrics endpoint exposed** — `/metrics` for Prometheus scrape (or OTLP push) — **OpenTelemetry**
13. **Distributed tracing** — OpenTelemetry SDK initialized; propagate W3C TraceContext header
14. **Correlation ID middleware** — `X-Correlation-ID` header propagated end-to-end across services

### 4.4 Reliability features (every external call)
15. **Timeout policy** — every HTTP/DB/cache/queue call has an explicit timeout; default-deny on indefinite wait
16. **Retry with exponential backoff + jitter** — Polly for .NET; **not unconditional** (avoid retry storms)
17. **Circuit breaker** — Polly; open after N failures; half-open probe before close
18. **Rate limiting** — protect ingress; per-user + per-IP fixed/sliding window. See [`security.md`](security.md).

### 4.5 Data discipline
19. **Audit columns systematic** — `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy` on every domain table
20. **Optimistic concurrency** — `rowversion` column on mutable aggregates; reject conflicting writes with `409 Conflict`

### 4.6 Additional must-haves (beyond the 20)
- **Soft delete + retention policy** — `DeletedAt` column; cleanup job removes after N days (per data class)
- **Error code + friendly message** — every error has a stable code (e.g. `USER_NOT_FOUND`) + human-readable message; clients pattern-match on the code. See [`error-handling.md`](error-handling.md).
- **Audit log** — every sensitive action (auth event, permission change, data export, admin action) logged with actor, target, timestamp, outcome
- **Connection pooling** — explicit pool size for DB; tune via load test, not guesswork

---

## 5. NFR-Dependent Infrastructure

> Each item below is **opt-in** based on a measured NFR trigger. **Design the interface from day 1** (see ADR-007 `ICacheService` pattern), implement only when the trigger fires.

| Component | Interface to plan day 1 | Trigger to implement |
|-----------|------------------------|----------------------|
| **Redis cache** | `ICacheService` | Hot-path P95 > target SLO **OR** DB CPU > 70% sustained |
| **Kafka / RabbitMQ** | `IEventPublisher`, `IEventConsumer` | Async throughput > Z msg/s **OR** cross-service decoupling required |
| **Read replicas** | `IReadOnlyDbContext` | Read/write ratio > 4:1 **AND** primary DB CPU > 70% |
| **Sharding** | Sharding key picked early (userId, tenantId, regionId) | Single-shard data > 500 GB **OR** IOPS bottleneck |
| **CDN + edge cache** | Static asset URL strategy | Geo distribution required **OR** static asset traffic > X GB/day |
| **Background jobs** (Hangfire / `IHostedService`) | `IBackgroundJobScheduler` | Long-running task > 30s (must not block HTTP) **OR** scheduled work required |
| **Multi-tenancy** | Tenant context middleware | SaaS requirement — pick model (shared / schema / DB-per-tenant) **before first paying tenant** |
| **Search engine** (Elasticsearch / OpenSearch) | `ISearchService` | Search query P95 > target with SQL `LIKE` |
| **Time-series DB** (InfluxDB / TimescaleDB) | `IMetricStore` (or OTel collector) | Metric/event volume > Z points/s |

**Rule:** when a trigger fires → write an ADR documenting:
- Measurement showing the trigger has been met
- Chosen implementation + comparison with alternatives
- Migration plan (strangler-fig)
- Next v2 trigger (e.g. multi-region replica, shard rebalancing)

---

## 6. Enforcement Across the Kit

This rule is referenced and enforced by the following commands:

| Command | Enforcement responsibility |
|---------|----------------------------|
| `/spec` | Surface NFR requirements that may trigger §5 items |
| `/arch` | Verify architecture decision aligns with §3; ADR required for any deviation; verify §1 principles are honored in diagrams |
| `/plan` | Tasks must respect §2.1 service boundaries and §2.2 quality discipline |
| `/secure` | Apply §1.6 (Resilient, Fault Isolation, Observable) + §2.1.5 (secure communication) |
| `/build` | Follow §1 principles + §2 best practices; emit code conforming to §4.5 data discipline |
| `/test` | Verify §2.2 (TDD, coverage ≥ 80%) |
| `/review` | Five-Axis review checks adherence to §1 + §2; flag violations |
| `/scan` | Verify §4.1.6 (image scan); verify §4 baseline before deploy |
| `/infra` | Produce Dockerfile + compose meeting §4 baseline; reject artifacts missing any of the 20 must-haves |
| `/deploy` | Gate on §4 (healthcheck on every service, image pin, non-root) |
| `/verify` | Validate §1.6 attributes against measured behavior (resilience drills, observability evidence) |

---

## 7. Cross-references

| Topic | Detailed rule |
|-------|---------------|
| SOLID + clean-code examples | [`clean-code.md`](clean-code.md) |
| Code style enforcement | [`code-style.md`](code-style.md) |
| Naming conventions | [`naming-conventions.md`](naming-conventions.md) |
| Project structure | [`project-structure.md`](project-structure.md) |
| Tech stack approved list | [`tech-stack.md`](tech-stack.md) |
| API conventions (versioning, ProblemDetails) | [`api-conventions.md`](api-conventions.md) |
| Database patterns (EF Core, Dapper, indexes) | [`database.md`](database.md) |
| Error handling (`AppException`, ProblemDetails) | [`error-handling.md`](error-handling.md) |
| Security (auth, secrets, rate limit, headers) | [`security.md`](security.md) |
| System design (CAP, scaling, caching) | [`system-design.md`](system-design.md) |
| Testing (TDD, coverage, TestContainers) | [`testing.md`](testing.md) |
| Monitoring & observability stack | [`monitoring.md`](monitoring.md) |
| Git workflow & branching | [`git-workflow.md`](git-workflow.md) |
| Brownfield discipline (characterization, ADR-to-change) | [`brownfield.md`](brownfield.md) |
| Frontend standards | [`frontend.md`](frontend.md) |
| Docker patterns & checklist | [`../references/docker-patterns.md`](../references/docker-patterns.md) |
| Deployment checklist | [`../references/deployment-checklist.md`](../references/deployment-checklist.md) |

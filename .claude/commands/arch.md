---
name: arch
description: Design system architecture with diagrams, ADRs, and API contracts
---

# /arch — Architecture Design

> "Good architecture enables agility."

## Purpose

Transform requirements into technical architecture **before** planning implementation tasks. This ensures alignment on system design, technology choices, and integration patterns.

## Prerequisites

- A specification exists (`specs/SPEC.md` from `/spec`)
- Understanding of non-functional requirements (scale, performance, security)

## References to Rules

The following rules provide detailed standards. **The Purpose column is self-sufficient for routine design decisions — do NOT open these files wholesale at the start. Open a specific rule only when a concrete decision genuinely needs its threshold/detail** (e.g., read `system-design.md` only when a scaling/caching choice is actually on the table). This avoids reading several large rule files on every `/arch` run.

| Rule | Purpose |
|------|---------|
| [principles-and-practices.md](../rules/principles-and-practices.md) | **Master reference** — architecture default (§3 Modular Monolith + Clean Architecture; ADR required for any deviation), NFR-dependent infrastructure (§5 opt-in triggers) |
| [tech-stack.md](../rules/tech-stack.md) | Approved technologies & decision criteria |
| [system-design.md](../rules/system-design.md) | CAP theorem, scaling, caching patterns |
| [project-structure.md](../rules/project-structure.md) | Clean Architecture layers |
| [api-conventions.md](../rules/api-conventions.md) | REST standards, versioning |
| [ascii-diagram-guide.md](../references/ascii-diagram-guide.md) | **Diagram format** — Use ASCII art for all diagrams |

## Workflow

### Phase 1: Architecture Analysis

1. **Read the spec** — Understand functional requirements
2. **Carry-forward Open Questions** — Read `specs/SPEC.md` §Open Questions; copy each into `ARCHITECTURE.md` §Open Questions and tag the blocking phase (`/secure`, `/plan`, or stakeholder). Any new OQ surfaced during this phase is added to the same table with `Source: /arch`.
3. **Cross-check NFRs (completeness)** — list every NFR in `specs/SPEC.md §NFR` **plus** every project-mandatory NFR in the rules (`security.md` incl. §HTTP Security Headers, `principles-and-practices.md §4`); ensure each has a NFR-mechanism row, a §Security Considerations line, or a tagged Open Question — no silent drop (see the Completeness rule under the NFR table).
4. **Identify components** — What systems/services are needed?
5. **Map integrations** — How do components communicate?
6. **Choose patterns** — Which architectural patterns apply?

### Phase 2: Design Artifacts

> **Diagram format is delegated.** All diagram art follows the canonical templates in [`../references/ascii-diagram-guide.md`](../references/ascii-diagram-guide.md) — do not re-draw them here. The rules below are `/arch`-specific: which diagrams are **mandatory**, and **when** the optional ones are warranted.

#### 2.1 System Context Diagram — **mandatory**

Show the system boundary, its actors, and external dependencies. Template: [`ascii-diagram-guide.md` §1](../references/ascii-diagram-guide.md#1-system-context-diagram).

#### 2.2 Container Diagram — **mandatory**

Show the deployable units (frontend, gateway, API, worker) and the data stores they depend on. Template: [`ascii-diagram-guide.md` §2](../references/ascii-diagram-guide.md#2-container-diagram).

#### 2.3 Component Diagram — *when a service has > 5 internal components or complex dependencies*

Use for complex service internals, onboarding documentation, or refactoring planning. Template: [`ascii-diagram-guide.md` §3](../references/ascii-diagram-guide.md#3-component-diagram-layered).

#### 2.4 Architecture Decision Records (ADRs)

> **Single source of truth:** [`../agents/systems-architect.md`](../agents/systems-architect.md) § "Architecture Decision Record (ADR)". **Decision ADRs** follow that template **verbatim** (Context → Options Considered → Decision → Consequences → v2 Upgrade Trigger → Implementation Notes). **Rejection ADRs default to the lightweight consolidated table** (ONE ADR, one row per excluded component); `/arch --adr=per-component` switches them to one full ADR each — see the agent § "Rejection ADR pattern". Do not restate either template here.

Every significant decision (and every intentional exclusion) gets an ADR in `architecture/adr/` (filename `ADR-NNN-kebab-title.md`).

> **Bound the ADRs (greenfield + brownfield alike):** write a full Decision-ADR only for a decision that **constrains future change** — persistence engine, auth model, module/service boundary, sync-vs-async integration, public contract. **Routine settings** (timeouts, page sizes, log levels, retry counts) go in an `ARCHITECTURE.md` notes list, **NOT** a per-item ADR.

#### 2.5 Sequence Diagrams — *for any flow involving > 2 components or where timing/ordering matters*

Create for:
- **Authentication/Authorization** — Login, token refresh, permission checks
- **Payment/Transactions** — Multi-step processes with rollback scenarios
- **Multi-service interactions** — When > 2 services coordinate
- **Error handling flows** — Retry logic, circuit breaker behavior

Template: [`ascii-diagram-guide.md` §4](../references/ascii-diagram-guide.md#4-sequence-diagram).

### Phase 3: API Contract Design

```yaml
# architecture/api/openapi.yaml
openapi: 3.0.3
info:
  title: Service API
  version: 1.0.0
paths:
  /api/v1/users:
    get:
      summary: List users
      responses:
        '200':
          description: Success
```

#### 3.1 Error code contract (required)

Every API contract MUST include a centralized error-code table in `ARCHITECTURE.md` (typically §7.x). The table is the **stable, machine-readable contract** clients pattern-match on:

| `code` | HTTP | Exception | Triggered by | Story |
|--------|------|-----------|--------------|-------|
| `VALIDATION_ERROR` | 400 | `ValidationException` | FluentValidation failure on any request DTO. `errors` extension carries per-field messages. | … |
| `UNAUTHORIZED` | 401 | `UnauthorizedException` + auth middleware | Missing / invalid / expired bearer token; auth failures. | … |
| `NOT_FOUND` | 404 | `NotFoundException` | Resource missing OR cross-tenant access (indistinguishable, per project ADR). | … |
| `CONFLICT` | 409 | `ConflictException` | Unique-constraint violation (e.g., duplicate email). | … |
| `INTERNAL_ERROR` | 500 | (fallback) any non-`AppException` | Unhandled exception; stack trace logged, never returned in body outside Dev. | all |

Contract rules:
- The list is **exhaustive** for the version — adding a new `code` requires a new ADR.
- `code` is a **stable contract**; renaming is a breaking change.
- `detail` is human-readable and may evolve; clients must not parse it.
- `errors` extension is present **only** on `VALIDATION_ERROR`.
- `traceId` is always populated (carried from `X-Correlation-ID`).

Honors `.claude/rules/error-handling.md` (`AppException` + ProblemDetails RFC 7807).

#### 3.2 Service Contracts — *multi-repo system-layer input (only when this service is one repo of a multi-repo product)*

When this service is **one repo of a multi-repo microservices product**, `ARCHITECTURE.md` MUST include a **Service Contracts** section so [`/discover-system`](discover-system.md) can stitch the cross-service call-graph. **Single-repo projects skip this.**

```markdown
## Service Contracts (system-layer input)
**Service id:** <service-id>   <!-- canonical key; matches Project Profile → Service id + the system service-catalog -->

### Exposes
| Contract id | Type (REST/Event) | Method/Path or Topic | @US |
|-------------|-------------------|----------------------|-----|
| order.create | REST | `POST /api/v1/orders` | US-012 |
| order.created | Event | `topic order.events / OrderCreated` | US-012 |

### Consumes
| Contract id | Type | Method/Path or Topic | Partner service |
|-------------|------|----------------------|-----------------|
| payment.charge | REST | `POST /api/v1/charges` | payment-service |
```

> **`contract-id` is the join key:** a consumer's `payment.charge` must match the provider's exposed `payment.charge` **exactly** — keep ids stable. Read your own outbound calls (HTTP clients, event consumers) to fill `Consumes`; you do **not** need the system layer to do this. Convention: [`../references/microservices-multirepo.md`](../references/microservices-multirepo.md).

### Phase 4: Output Structure

```text
architecture/
├── ARCHITECTURE.md           # Main architecture document
├── adr/                      # Architecture Decision Records (filename: ADR-NNN-kebab-title.md)
│   ├── ADR-001-database-choice.md
│   ├── ADR-002-auth-strategy.md
│   └── ADR-003-caching-strategy.md
├── diagrams/                 # ASCII art diagrams (see ascii-diagram-guide.md)
│   ├── system-context.md
│   ├── container.md
│   ├── component.md
│   └── sequence/
│       ├── auth-flow.md
│       └── payment-flow.md
└── api/                      # API Contracts
    └── openapi.yaml
```

## Architecture Document Template

```markdown
# Architecture: [Feature/System Name]

## Overview
[1-2 paragraphs describing the system]

## Goals
- [Goal 1]
- [Goal 2]

## Non-Functional Requirements
| Requirement | Target | Architectural answer |
|-------------|--------|----------------------|
| Availability | 99.9% | [Mechanism that delivers it — e.g., active-passive replica + health probes] |
| Latency P99 | < 200ms | [Mechanism — e.g., Redis cache + indexed read path + `AsNoTracking()`] |
| Throughput | 1000 req/s | [Mechanism — e.g., horizontal scaling behind YARP + Kestrel thread pool tuning] |

> **Rule:** every row MUST have a concrete architectural mechanism in the third column. An NFR without a mechanism is an unmet NFR.
> **Completeness rule:** every NFR in `specs/SPEC.md §NFR` **and** every project-mandatory NFR in the rules (`security.md` incl. §HTTP Security Headers, `principles-and-practices.md §4`) MUST appear here as a row, **or** as a line in §Security Considerations, **or** as a tagged Open Question — no NFR is silently dropped. This is the symmetric counterpart of `/plan`'s spec-NFR → task chain.

## System Context
[Diagram showing system boundaries]

## Components
### Component A
- **Responsibility**: [What it does]
- **Technology**: [Stack choices]
- **Interfaces**: [APIs exposed/consumed]

## Data Model
[ER diagram + entities/fields + keys, indexes, precision, relationships as **design decisions** — NOT EF `Configure()` code (that belongs to `/build`)]

## Security Considerations
> List the **required controls** below; each must name its mechanism, or be deferred to `/secure` with a tagged Open Question. A control omitted here is a control that will not be built.
- Authentication: [approach]
- Authorization / data-isolation (IDOR): [approach]
- **HTTP security headers**: X-Content-Type-Options, X-Frame-Options, Referrer-Policy, HSTS, CSP — middleware wired in the request pipeline (or deferred to `/secure` + OQ)
- **CORS**: allowlist of origins for state-writing routes
- Secrets management: [approach]
- Transport (HTTPS) / SSRF / other surface-specific controls: [as applicable]
- Data encryption: [approach]

## Deployment Architecture
[Infrastructure diagram]

## Open Questions
- [Questions to resolve]

## ADR References
- [ADR-001](adr/001-database-choice.md)
```

## Quality Gate 2 — Architecture Review

Before proceeding to `/plan`:
- [ ] Architecture document reviewed
- [ ] Diagrams are clear and complete (System Context + Container **mandatory**; Component & Sequence as needed)
- [ ] ADRs document key decisions
- [ ] **Every NFR row has a concrete architectural mechanism** (no empty third column)
- [ ] **NFR completeness** — every spec NFR + every project-mandatory NFR (rules) maps to a mechanism row / §Security line / tagged OQ (no silent drop)
- [ ] **Every ADR has `Options Considered` and `v2 Upgrade Trigger`** sections populated
- [ ] **Rejection ADR exists** if any approved-stack component is intentionally excluded — consolidated table by default, or one full ADR per component when `--adr=per-component` was requested
- [ ] **Error-code contract table** exists in `ARCHITECTURE.md`
- [ ] **Open Questions table** carried from SPEC + arch-surfaced, each tagged with blocking phase
- [ ] **No "either is acceptable" hedges** — every option is committed; alternatives live in `v2 Upgrade Trigger`
- [ ] API contracts defined (OpenAPI 3.0.3)
- [ ] **Security controls listed** — §Security names HTTP security headers + CORS + auth/authz/secrets/transport, each with a mechanism or deferred to `/secure` with an OQ (not just "addressed")

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

`/arch` switches role per flow — this is the "don't change architecture unless truly needed" mechanism:

| Flow | Mode | Behavior |
|------|------|----------|
| Discovery (no `architecture/ARCHITECTURE.md` yet) | **REVERSE** | **First consume the `/discover` artifacts** (`Project Profile` + `docs/CODEBASE_MAP.md`) as the index — do not re-survey the tree. Draw the **actual** architecture from code: container/component diagrams from project refs, ER from DbContext/migrations, sequence for the main flows. Record **inferred ADRs** for decisions already embedded (e.g., "JWT 15min no-refresh — inferred from JwtTokenService"). Describe as-is, do not propose changes. **Bound the inferred ADRs per the general rule in §2.4** (full ADR only for decisions that constrain future change; routine settings → ARCHITECTURE.md notes list) — applied here to *inferred* decisions. |
| B1 new feature / B2 modify feature (ARCHITECTURE.md exists) | **CONFORMANCE-GATE** | Default is to **keep as-is**. Answer one question: *"does this change REQUIRE an architecture change?"* → NO: proceed with the current ARCHITECTURE.md; lightweight ADR only when a small new decision is made. → YES: stop, switch to the B5 flow. |
| B5 architecture/technology upgrade | **REDESIGN** | The **only** time proactive changes are allowed: propose **minimal** changes + **mandatory ADR** (supersede old ADR if needed, with v2-trigger) + **migration plan** (strangler-fig per `rules/brownfield.md`). |

**CONFORMANCE-GATE output** (B1/B2) — add a table to `ARCHITECTURE.md` or to the report:

| Change | Touches architecture? | ADR needed? | Conclusion |
|--------|:---------------------:|:-----------:|------------|
| [description] | No | No | Honor existing architecture → proceed |

> **Peripheral stack:** read the `Project Profile`. If Database/Observability differs from the default (e.g., Oracle, ELK) → reference `rules/overrides/*` when describing/designing the data + monitoring layers; do not use the default SQL Server/Grafana examples.

## Agent

Invoke: **Systems Architect**

For UI-heavy features, also consult: **UI/UX Designer** (design system, tokens, key user flows). The **state-per-component matrix** (default / hover / focus / active / disabled / loading / error / empty) is owned here — see [`../agents/ui-ux-designer.md`](../agents/ui-ux-designer.md) §States; `/spec` only produces the 5 page-level states.

```text
"As Systems Architect, design the architecture for [feature].
Output language: Vietnamese for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After architecture approved, run `/plan` to decompose into implementation tasks.

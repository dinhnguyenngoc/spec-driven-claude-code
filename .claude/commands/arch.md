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

The following rules provide detailed standards — refer to them during architecture design:

| Rule | Purpose |
|------|---------|
| [tech-stack.md](../rules/tech-stack.md) | Approved technologies & decision criteria |
| [system-design.md](../rules/system-design.md) | CAP theorem, scaling, caching patterns |
| [project-structure.md](../rules/project-structure.md) | Clean Architecture layers |
| [api-conventions.md](../rules/api-conventions.md) | REST standards, versioning |
| [ascii-diagram-guide.md](../references/ascii-diagram-guide.md) | **Diagram format** — Use ASCII art for all diagrams |

## Workflow

### Phase 1: Architecture Analysis

1. **Read the spec** — Understand functional requirements
2. **Carry-forward Open Questions** — Read `specs/SPEC.md` §Open Questions; copy each into `ARCHITECTURE.md` §Open Questions and tag the blocking phase (`/secure`, `/plan`, or stakeholder). Any new OQ surfaced during this phase is added to the same table with `Source: /arch`.
3. **Identify components** — What systems/services are needed?
4. **Map integrations** — How do components communicate?
5. **Choose patterns** — Which architectural patterns apply?

### Phase 2: Design Artifacts

#### 2.1 System Context Diagram

```
                         ┌──────────┐
                         │   User   │
                         └────┬─────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Our Application │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
    ┌────────────┐    ┌────────────┐    ┌────────────┐
    │  Database  │    │   Cache    │    │ External   │
    │            │    │  (Redis)   │    │    API     │
    └────────────┘    └────────────┘    └────────────┘
```

#### 2.2 Container Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        System Boundary                           │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │  Frontend   │  │   Admin     │                               │
│  │  (Next.js)  │  │   (SPA)     │                               │
│  └──────┬──────┘  └──────┬──────┘                               │
│         │                │                                       │
│         └───────┬────────┘                                       │
│                 ▼                                                │
│         ┌─────────────┐                                         │
│         │   Gateway   │                                         │
│         │   (YARP)    │                                         │
│         └──────┬──────┘                                         │
│                │                                                 │
│      ┌─────────┴─────────┐                                      │
│      ▼                   ▼                                      │
│  ┌────────┐        ┌────────────┐                               │
│  │  API   │        │   Worker   │                               │
│  └───┬────┘        └─────┬──────┘                               │
│      │                   │                                       │
│      └─────────┬─────────┘                                       │
│                │                                                 │
│    ┌───────────┼───────────┐                                    │
│    ▼           ▼           ▼                                    │
│ ┌──────┐  ┌────────┐  ┌────────┐                                │
│ │ SQL  │  │ Redis  │  │ Kafka  │                                │
│ └──────┘  └────────┘  └────────┘                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.3 Component Diagram (for complex services)

Create component diagrams when a service has **> 5 internal components** or complex dependencies:

```
┌─────────────────────────────────────────────────────┐
│                    API Service                       │
│                                                      │
│  ┌─────────────┐                                    │
│  │ Controllers │                                    │
│  └──────┬──────┘                                    │
│         │                                           │
│    ┌────┴────┐                                      │
│    ▼         ▼                                      │
│ ┌──────┐ ┌──────────┐                              │
│ │Valid.│ │ Services │                              │
│ └──────┘ └────┬─────┘                              │
│               │                                     │
│          ┌────┴────┐                               │
│          ▼         ▼                               │
│    ┌──────────┐ ┌────────┐                         │
│    │  Repos   │ │ Events │                         │
│    └──────────┘ └────────┘                         │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**When to create**: Complex service internals, onboarding documentation, or refactoring planning.

#### 2.4 Architecture Decision Records (ADRs)

```markdown
# ADR-NNN: [Decision title]

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX

## Context
What problem requires a decision? Cite the SPEC user story, NFR, or rule in `.claude/rules/` that surfaces it.

## Options Considered
| Option | Pros | Cons |
|--------|------|------|
| **A. [Chosen]** | … | … |
| B. [Alternative] | … | … |
| C. [Alternative] | … | … |

## Decision
Adopt **Option A** because [reason tied to NFR / rule / SPEC].

## Consequences
**Positive**: [benefits]
**Negative**: [tradeoffs the team must accept]
**Risks**: [what could go wrong + mitigation]

## v2 Upgrade Trigger
Revisit this decision when **any** of the following becomes true:
- [trigger 1 — e.g., a second concurrent user is supported]
- [trigger 2 — e.g., latency SLO drops below X ms]

## Implementation Notes
Concrete guidance for `/build`: which library, which config knob, which rule in `.claude/rules/` is honored.
```

**Rejection ADR pattern** — if this phase decides **not** to adopt a component listed in `.claude/rules/tech-stack.md` (Redis, Kafka, YARP, Hangfire, Polly, etc.), write a dedicated ADR (e.g., `ADR-NNN-no-redis-kafka-or-gateway-in-v1.md`) that lists each rejected component, the reason, and the v2 trigger. This prevents scope-creep during `/plan` and `/build`.

#### 2.5 Sequence Diagrams (for key flows)

Create sequence diagrams for:
- **Authentication/Authorization** — Login, token refresh, permission checks
- **Payment/Transactions** — Multi-step processes with rollback scenarios
- **Multi-service interactions** — When > 2 services coordinate
- **Error handling flows** — Retry logic, circuit breaker behavior

```
┌────────┐      ┌─────────┐      ┌────────┐      ┌────────┐
│ Client │      │ Gateway │      │  Auth  │      │  User  │
└───┬────┘      └────┬────┘      └───┬────┘      └───┬────┘
    │                │               │               │
    │ POST /login    │               │               │
    │───────────────>│               │               │
    │                │ Validate      │               │
    │                │──────────────>│               │
    │                │               │ Get user      │
    │                │               │──────────────>│
    │                │               │               │
    │                │               │  User data    │
    │                │               │<──────────────│
    │                │  JWT token    │               │
    │                │<──────────────│               │
    │ 200 OK + token │               │               │
    │<───────────────│               │               │
    │                │               │               │
```

**When to create**: Any flow involving > 2 components or where timing/ordering matters.

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

### Phase 4: Output Structure

```
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

## System Context
[Diagram showing system boundaries]

## Components
### Component A
- **Responsibility**: [What it does]
- **Technology**: [Stack choices]
- **Interfaces**: [APIs exposed/consumed]

## Data Model
[ER diagram or schema overview]

## Security Considerations
- Authentication: [approach]
- Authorization: [approach]
- Data encryption: [approach]

## Deployment Architecture
[Infrastructure diagram]

## Open Questions
- [Questions to resolve]

## ADR References
- [ADR-001](adr/001-database-choice.md)
```

## Quality Gate 2

Before proceeding to `/plan`:
- [ ] Architecture document reviewed
- [ ] Diagrams are clear and complete (System Context + Container **mandatory**; Component & Sequence as needed)
- [ ] ADRs document key decisions
- [ ] **Every NFR row has a concrete architectural mechanism** (no empty third column)
- [ ] **Every ADR has `Options Considered` and `v2 Upgrade Trigger`** sections populated
- [ ] **Rejection ADR exists** if any approved-stack component is intentionally excluded
- [ ] **Error-code contract table** exists in `ARCHITECTURE.md`
- [ ] **Open Questions table** carried from SPEC + arch-surfaced, each tagged with blocking phase
- [ ] **No "either is acceptable" hedges** — every option is committed; alternatives live in `v2 Upgrade Trigger`
- [ ] API contracts defined (OpenAPI 3.0.3)
- [ ] Security considerations addressed

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

`/arch` switches role per flow — this is the "don't change architecture unless truly needed" mechanism:

| Flow | Mode | Behavior |
|------|------|----------|
| Discovery (no `architecture/ARCHITECTURE.md` yet) | **REVERSE** | Draw the **actual** architecture from code: container/component diagrams from project refs, ER from DbContext/migrations, sequence for the main flows. Record **inferred ADRs** for decisions already embedded (e.g., "JWT 15min no-refresh — inferred from JwtTokenService"). Describe as-is, do not propose changes. |
| B1 new feature / B2 modify feature (ARCHITECTURE.md exists) | **CONFORMANCE-GATE** | Default is to **keep as-is**. Answer one question: *"does this change REQUIRE an architecture change?"* → NO: proceed with the current ARCHITECTURE.md; lightweight ADR only when a small new decision is made. → YES: stop, switch to the B5 flow. |
| B5 architecture/technology upgrade | **REDESIGN** | The **only** time proactive changes are allowed: propose **minimal** changes + **mandatory ADR** (supersede old ADR if needed, with v2-trigger) + **migration plan** (strangler-fig per `rules/brownfield.md`). |

**CONFORMANCE-GATE output** (B1/B2) — add a table to `ARCHITECTURE.md` or to the report:

| Change | Touches architecture? | ADR needed? | Conclusion |
|--------|:---------------------:|:-----------:|------------|
| [description] | No | No | Honor existing architecture → proceed |

> **Peripheral stack:** read the `Project Profile`. If Database/Observability differs from the default (e.g., Oracle, ELK) → reference `rules/overrides/*` when describing/designing the data + monitoring layers; do not use the default SQL Server/Grafana examples.

## Agent

Invoke: **Systems Architect**

```
"As Systems Architect, design the architecture for [feature]"
```

## Next Step

After architecture approved, run `/plan` to decompose into implementation tasks.

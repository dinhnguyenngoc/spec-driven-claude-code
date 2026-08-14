---
name: arch
description: Design system architecture with diagrams, ADRs, and API contracts
---

# /arch — Architecture Design

> "Good architecture enables agility."

## Purpose

Transform requirements into technical architecture **before** planning implementation tasks. This ensures alignment on system design, technology choices, and integration patterns.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

## Prerequisites

- A specification exists (`specs/SPEC.md` from `/spec`)
- The spec passed Gate 1 — header `Status` is **Approved**, not Draft (stop and finish `/spec` sign-off otherwise)
- The spec's **`Coverage` is `full`** — a SPEC marked `Coverage: partial (scoped)` (produced by `/spec --scope`) → **STOP**: finish the baseline first (further `--scope` slices, or a full REVERSE). Rationale: `/arch`'s completeness gates read the SPEC — NFR completeness cross-checks `specs/SPEC.md §NFR`, and the Flow-Disposition candidate list reads `specs/wireframes/flows/` — so against a partial spec they would **pass while covering only part of the system**. That is worse than not running at all: it yields a signed-off architecture carrying false assurance. *(A SPEC with no `Coverage` field predates the field → treated as `full` — backward-compatible, same convention as `Output Language`.)*
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
2. **Carry-forward Open Questions** — Read `specs/SPEC.md` §Open Questions & Decisions; carry the **Open** items only (Resolved ones stay in the spec as the decision record). Items deferred to `/arch` → **resolve them in this phase**; copy the rest into `ARCHITECTURE.md` §Open Questions tagged with their blocking phase (`/secure`, `/plan`, or stakeholder). Any new OQ surfaced during this phase is added to the same table with `Source: /arch`.
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

**Flow Disposition (mandatory — no silent omission).** Judgment decides *how* a flow is documented, never *whether it was considered*: enumerate every candidate flow mechanically, then disposition each in a **Flow Disposition table** in `ARCHITECTURE.md`:

| Candidate flow | Source | Disposition |
|----------------|--------|-------------|
| <name> | spec-flow / external-dep / code-evidence | `diagrams/sequence/<file>.md` or `Waived — <1-line reason>` |

Candidate sources (building the LIST is mechanical — no judgment):

1. **spec-flow** — every file in `specs/wireframes/flows/*.md` (UI products; headless → skip this source).
2. **external-dep** — every external system crossing the container-diagram boundary (each appears in ≥ 1 sequence diagram or a waiver row).
3. **code-evidence** *(brownfield REVERSE)* — every code path with failure semantics recorded in `docs/CODEBASE_MAP.md` (timeout / retry / fail-open / outbound call).

The §2.5 criteria above decide the Disposition column (draw vs waive); a waiver needs one concrete line (e.g. "linear Controller→Service→Repository path — component diagram + OpenAPI suffice"). A flow that carries failure semantics MUST have its failure branches in the diagram (inline `alt` frames or a companion failure table/diagram). Applies to greenfield and brownfield alike.

#### 2.6 Design System — *UI products only*

The **UI/UX Designer** produces `architecture/design-system.md` — the system-level UI contract that `/spec` Phase 2.5 explicitly defers here. It does **NOT** re-draw screens — screens / layout / flows are already signed off in `specs/wireframes/`; this file defines the shared vocabulary those screens are built with:

- **Design tokens** — the `tailwind.config.ts` block (colors, typography, spacing, radius) per [`ui-ux-designer.md`](../agents/ui-ux-designer.md) §Design Tokens.
- **State-per-component matrix** — default / hover / focus / active / disabled / loading / error / empty for each shared component (owned HERE, not in `/spec` — fidelity boundary in ui-ux-designer.md).
- **Component contracts** — shared components (Button, Input, Card, EmptyState…) with props/variants at design level.
- **Navigation / IA decisions + state-management choice** — cite an ADR when a choice constrains future change.

Consumed by the Frontend Developer at the start of `/build`. Skip for headless / API-only products.

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

> **Schema `example` values (recommended, non-gate):** populate `example` on request/response schema properties — Swagger UI renders them, and `/export-docs` carries API samples **verbatim** instead of constructing illustrative values (see `export-docs.md` §API sample derivation).

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
├── design-system.md          # UI products only — tokens + component contracts (consumed by /build FE)
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
| NFR-01 · Availability | 99.9% | [Mechanism that delivers it — e.g., active-passive replica + health probes] |
| NFR-02 · Latency P99 | < 200ms | [Mechanism — e.g., Redis cache + indexed read path + `AsNoTracking()`] |
| NFR-03 · Throughput | 1000 req/s | [Mechanism — e.g., horizontal scaling behind YARP + Kestrel thread pool tuning] |

> **Rule:** every row MUST have a concrete architectural mechanism in the third column. An NFR without a mechanism is an unmet NFR.
> **Completeness rule:** every NFR in `specs/SPEC.md §NFR` **and** every project-mandatory NFR in the rules (`security.md` incl. §HTTP Security Headers, `principles-and-practices.md §4`) MUST appear here as a row, **or** as a line in §Security Considerations, **or** as a tagged Open Question — no NFR is silently dropped. This is the symmetric counterpart of `/plan`'s spec-NFR → task chain. Every spec-sourced row carries its **`NFR-xx` id** (the join key `/plan`'s reconciliation and `/verify` Phase-4 diff on); a row with **no id** is a rules-mandated NFR the spec missed — route it back to the spec (AC amendment / OQ) rather than leaving it keyless.

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
- [ADR-001](adr/ADR-001-database-choice.md)
```

## Quality Gate 2 — Architecture Review

Run the §Orchestrator disk-check (below) first, then review. Before proceeding to `/plan`:
- [ ] Architecture document reviewed
- [ ] Diagrams are clear and complete (System Context + Container **mandatory**; Component as needed; **Sequence per §2.5 Flow Disposition** — drawn, or waived with a stated reason)
- [ ] **Flow Disposition table complete** — every candidate (spec flows + container external dependencies + REVERSE code-evidence paths) has a row; every row is a sequence file that exists or a waiver with a reason (§2.5)
- [ ] ADRs document key decisions
- [ ] **Every NFR row has a concrete architectural mechanism** (no empty third column)
- [ ] **NFR completeness** — every spec NFR + every project-mandatory NFR (rules) maps to a mechanism row / §Security line / tagged OQ (no silent drop)
- [ ] **Every ADR has `Options Considered` and `v2 Upgrade Trigger`** sections populated
- [ ] **Rejection ADR exists** if any approved-stack component is intentionally excluded — consolidated table by default, or one full ADR per component when `--adr=per-component` was requested
- [ ] **Error-code contract table** exists in `ARCHITECTURE.md`
- [ ] **Data Model present** — §Data Model carries the entity/ER design (keys, indexes, relationships, precision) whenever the Profile declares a database; brownfield: the entities match the evidence (`CODEBASE_MAP.md` §DB-object inventory / `db/schema-snapshot/`), DB-resident objects included
- [ ] **Open Questions table** carried from SPEC + arch-surfaced, each tagged with blocking phase
- [ ] **No "either is acceptable" hedges** — every option is committed; alternatives live in `v2 Upgrade Trigger`
- [ ] API contracts defined (OpenAPI 3.0.3)
- [ ] **Security controls listed** — §Security names HTTP security headers + CORS + auth/authz/secrets/transport, each with a mechanism or deferred to `/secure` with an OQ (not just "addressed")
- [ ] **(UI products) Design system defined** — `architecture/design-system.md` with tokens + state-per-component matrix + component contracts (skip for headless / API-only)

### Orchestrator disk-check (run BEFORE presenting for Gate 2 review)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level. The orchestrator re-checks the **mechanical** invariants on disk itself (design quality — whether patterns/mechanisms are *right* — remains human judgment at review):

- [ ] **Files exist** — `architecture/ARCHITECTURE.md`, `architecture/api/openapi.yaml`, and the two mandatory diagrams (system context + container — in `diagrams/` or embedded).
- [ ] **ADR completeness** — every Decision-ADR in `architecture/adr/` contains the `## Options Considered` and `## v2 Upgrade Trigger` headings; filenames follow `ADR-NNN-kebab-title.md`. *(Exception: the consolidated Rejection ADR follows its own table pattern — check it has the v2-trigger column instead.)*
- [ ] **NFR mechanisms** — the NFR table has no empty third column, **and every spec-sourced row carries its `NFR-xx` id** (an id-less row = a rules-mandated NFR the spec missed → routed back as a spec amendment/OQ, never silently keyless).
- [ ] **Contract tables** — the error-code table and the §Open Questions table exist; every OQ row is tagged a blocking phase.
- [ ] **Data Model non-empty** — when `Project Profile → Database` names an engine, `ARCHITECTURE.md` §Data Model exists and holds at least one entity/table definition (not just the heading). Downstream depends on it: `/export-docs` SDD treats a missing data model as **STOP**, and `/plan` sizes migration work from it.
- [ ] **OpenAPI is more than a stub** — `architecture/api/openapi.yaml` declares `openapi: 3.0` and has a non-empty `paths:` block with at least one operation; a scaffolded-but-empty file passes "file exists" and then fails everything downstream.
- [ ] **Security controls named** — grep §Security Considerations for each required control (security headers · CORS · authentication · authorization/IDOR · secrets · transport): each appears **with a mechanism**, or with an explicit deferral to `/secure` carrying an OQ id — the word "addressed" with no mechanism does not count.
- [ ] **Flow disposition** — diff the Flow Disposition table rows against `specs/wireframes/flows/*.md` filenames and the external systems in the container diagram; every `diagrams/sequence/<file>` cited in the table exists on disk.
- [ ] **(UI products)** `architecture/design-system.md` exists with the tokens block + state matrix.
- [ ] **No template residue** — no `TODO` / unfilled placeholders left in `architecture/`.

Any mismatch → fix on disk first; never present an architecture that fails its own gate mechanics.

> **Warning-only check (surfaced, never blocking):** grep for hedge phrasing — `either is acceptable` · `either would work` · `can be either` · `tùy chọn nào cũng được` — and list the hits. A committed architecture states **one** option; alternatives belong in `v2 Upgrade Trigger`. This stays a warning rather than a gate failure because the same words are legitimate *inside* a v2-trigger sentence ("either option becomes viable at v2"), so the judgment stays human.

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

`/arch` switches role per flow — this is the "don't change architecture unless truly needed" mechanism:

| Flow | Mode | Behavior |
|------|------|----------|
| Discovery (no `architecture/ARCHITECTURE.md` yet) | **REVERSE** | Draw the **actual** architecture from code and describe it **as-is** — never propose changes. Details: §REVERSE — notes below the table. |
| B1 new feature / B2 modify feature (ARCHITECTURE.md exists) | **CONFORMANCE-GATE** | Default is to **keep as-is**. Answer one question: *"does this change REQUIRE an architecture change?"* → NO: proceed with the current ARCHITECTURE.md; lightweight ADR only when a small new decision is made. → YES: stop, switch to the B5 flow. When the change **implements a previously-planned decision** (an ADR/annotation marked "planned / not yet enforced" — e.g., an optimistic-concurrency ADR awaiting `/build`), refresh the as-is annotations citing it across `ARCHITECTURE.md` / `diagrams/` / `api/openapi.yaml` (append an update note; the ADR itself is NOT edited — it is now fulfilled, not stale). |
| B5 architecture/technology upgrade | **REDESIGN** | The **only** time proactive changes are allowed: propose **minimal** changes + **mandatory ADR** (supersede old ADR if needed, with v2-trigger) + **migration plan** (strangler-fig per `rules/brownfield.md`). |

**REVERSE — notes:**

- **Consume, don't re-survey:** the `/discover` artifacts (`Project Profile` + `docs/CODEBASE_MAP.md`) are the index — go straight to what you need. **Fallback guard:** map missing/incomplete → **STOP** and run `/discover` first (or re-scan only the missing area); never fall back to a full-tree survey (same guard as `/spec` REVERSE and `/plan`).
- **Source per artifact:** container/component diagrams ← project references · ER ← DbContext/migrations + the `CODEBASE_MAP.md` DB-object inventory / `db/schema-snapshot/` · sequence diagrams ← §2.5 **Flow Disposition** (candidates: spec flows + container external dependencies + `CODEBASE_MAP.md` failure-semantics paths).
- **Integration Contracts:** a broker/cache client in the repo → record them in `ARCHITECTURE.md` from the `CODEBASE_MAP.md` messaging/cache inventories (topic + message-schema catalog · key patterns + TTL) — the single-repo counterpart of the multi-repo §Service Contracts (§3.2).
- **Inferred ADRs:** record decisions already embedded in code (e.g. *"JWT 15min no-refresh — inferred from `JwtTokenService`"*), **bounded per §2.4** — a full ADR only for decisions that constrain future change; routine settings go to the ARCHITECTURE notes list.
- **Time-bound as-is claims carry a machine-readable marker:** a statement a later pipeline step will invalidate ("no Docker yet", "no `/metrics` yet") MUST name that step — the `` pre-`/<cmd>` `` idiom, or an §Open Questions row owned by that command. The `/infra` + `/deploy` "As-is refresh" gate items sweep for exactly these (backticked command names are language-neutral anchors).
- **Describe, don't fix:** behavior that looks wrong is documented as-is and flagged — never silently corrected in the diagram.

**CONFORMANCE-GATE output** (B1/B2) — add a table to `ARCHITECTURE.md` or to the report:

| Change | Touches architecture? | ADR needed? | Conclusion |
|--------|:---------------------:|:-----------:|------------|
| [description] | No | No | Honor existing architecture → proceed |

> **Peripheral stack:** read the `Project Profile`. If Database/Observability differs from the default (e.g., Oracle, ELK) → reference `rules/overrides/*` when describing/designing the data + monitoring layers; do not use the default SQL Server/Grafana examples.

## Agent

Invoke: **Systems Architect**

For any product with a UI, also consult: **UI/UX Designer** (design system → §2.6, written to `architecture/design-system.md`). The **state-per-component matrix** (default / hover / focus / active / disabled / loading / error / empty) is owned here — see [`../agents/ui-ux-designer.md`](../agents/ui-ux-designer.md) §States; `/spec` only produces the 5 page-level states.

**Phase ownership** — the SA sub-agent cannot converse with the user: an ambiguity that needs stakeholder input → return early with the question, or tag it as an Open Question with its blocking phase. The orchestrator runs the Gate 2 disk-check and presents the architecture for review in the main loop. **(UI products)** The orchestrator spawns the **UI/UX Designer as a separate sub-agent AFTER the SA returns** (a sub-agent cannot spawn sub-agents), passing the settled container/component list so §2.6 tokens + state matrix align with the final design; the SA does **not** author `architecture/design-system.md`.

```text
"As Systems Architect, design the architecture for [feature].
Mode: <greenfield | REVERSE | CONFORMANCE-GATE (B1/B2) | REDESIGN (B5)> — resolved by the orchestrator per §Brownfield Mode; honor that role's behavior table (a CONFORMANCE-GATE run never redesigns).
Output language: <Output Language from Project Profile> for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After architecture approved, run `/plan` to decompose into implementation tasks.

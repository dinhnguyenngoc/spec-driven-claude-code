---
name: spec
description: Spec before code — User Stories & Acceptance Criteria for new features
---

# /spec — Specification-Driven Development

> "Plan the work, then work the plan."

## Purpose

Create a comprehensive specification document **before** writing any code — defining **WHAT** to build and **WHY**, not HOW. This ensures alignment on requirements, constraints, and acceptance criteria.

## Usage

| How to invoke | Result |
|----------|---------|
| `/spec <requirements>` | Generate `SPEC.md` + (if the product has a UI) **ASCII wireframes**. **This is the default** — does NOT generate an HTML prototype. |
| `/spec <requirements> --prototype` | As above, **plus** a clickable HTML prototype. Can also be triggered in plain language: add *"with prototype" / "include prototype"* to the request. |
| `/spec` (no arguments) | See **Phase 0**: repo already has code → brownfield (needs `/discover` first); nothing there → ask the user to provide requirements. |

> **Why the prototype is OFF by default:** it is the heaviest artifact of `/spec`. ASCII wireframes (always generated) are already enough as a source of truth + in most cases enough for sign-off. The prototype is generated when the user requests it, **or** when the stakeholder/PO needs a click-through to feel confident approving at Gate 1. Details: Phase 2.5.

## Phase 0 — Mode Auto-Detection (run BEFORE Phase 1)

`/spec` resolves the mode itself at runtime instead of trusting `Project Profile → Mode` absolutely (it can be stale). Three signals:

- **ARGS** — does `/spec` come with input requirements? (`/spec <requirements>` vs bare `/spec`)
- **CODE** — does the repo have source code? Probe: the existence of any `src/**/*.csproj`, `web/package.json`, or another build manifest outside `.claude/` (the same way `/discover` checks).
- **DISCOVERY** — has it been onboarded via `/discover`? Probe: `docs/CODEBASE_MAP.md` exists (a mandatory deliverable of `/discover` — having it = having a navigation index for REVERSE/DELTA). *The STOP signal is "missing discovery", NOT "missing SPEC" — because REVERSE is itself the step that creates `SPEC.md` from nothing.*

| ARGS | CODE | DISCOVERY | Resolved mode | Action |
|:----:|:----:|:---------:|---------------|-----------|
| ✅ | ❌ | — | **greenfield** | Write a forward spec from args (continue to Phase 1). If the Profile says `brownfield` → treat it as stale, surface + propose a fix. |
| ❌ | ✅ | ❌ | **brownfield (not yet discovered)** | **STOP** — run `/discover` first (REVERSE needs `docs/CODEBASE_MAP.md` as an index), then `/spec` again. |
| ❌ | ✅ | ✅ | **brownfield** | Has `specs/SPEC.md` → **DELTA** · does not → **REVERSE** (establish a baseline) — go down to §Brownfield Mode. |
| ✅ | ✅ | ❌ | **brownfield (not yet discovered)** | **STOP** — `/discover` first; then if there is no baseline SPEC → bare `/spec` (REVERSE) before `/spec <args>` (DELTA). |
| ✅ | ✅ | ✅ | **brownfield (DELTA)** | If there is no `specs/SPEC.md` → do REVERSE first (establish a baseline) then spec the delta; if there is → spec only the delta. Do not rewrite existing stories. |
| ❌ | ❌ | — | **undecidable** | **STOP** — nothing to spec. Ask the user: provide requirements (→ greenfield) or bring in code (→ brownfield). |

**Reconcile:** after resolving, compare against `Project Profile → Mode`. Match → continue. Mismatch → surface it, propose changing `Mode:` to the resolved value (for greenfield, also delete the stale "current codebase" Notes). Do NOT continue while there is a mismatch.

**Persist:** when the resolved mode differs from the Profile, offer to update `Project Profile → Mode` so that `/arch`, `/plan`, and the activation of `rules/brownfield.md` stay in sync downstream.

## Workflow

### Phase 1: Discovery (Ask Questions)

> **Ask, don't assume (mandatory).** When a requirement is missing, ambiguous, or you are about to fill a gap with a default/guess — **ask the user** (`AskUserQuestion`), or log it as an explicit **Assumption** in *Open Questions & Decisions* for confirmation. A "sensible default" the user has not confirmed is an *unconfirmed assumption*, not a decision. See `.claude/agents/business-analyst.md` § Discovery Framework.

Before generating a spec, gather requirements by asking:

**Scope**
- What is the objective of this feature?
- Who are the target users?
- What problem does this solve?

**Features**
- What are the core features (MVP)?
- What are the acceptance criteria for each?
- What is the priority? (Must / Should / Could / Won't)
- What is explicitly out of scope?

**Technical**
- Any tech stack preferences or constraints?
- Integration points with existing systems?
- Performance requirements? (response time, throughput)
- Scale expectations? (concurrent users, data volume)
- Data sensitivity? (PII / financial / public — `/secure` reads the spec for asset inventory & data classification; record in §NFR Security row and/or §Boundaries → Never Do)

**Project-mandatory NFRs (cross-check before closing discovery)**

Before generating the spec, cross-check project-default NFRs against the table below so none are silently omitted. **The table is self-sufficient — surface these items directly; do NOT read the full rule files for this check. Open a specific rule file only when a particular threshold/detail is genuinely unclear.**

| Rule | NFR(s) to surface in the spec |
|------|------------------------------|
| `.claude/rules/security.md` | Rate limiting on auth endpoints, password policy, JWT lifetime, secrets storage, **HTTP security headers** (X-Content-Type-Options / X-Frame-Options / Referrer-Policy / HSTS / CSP — see `security.md §HTTP Security Headers`) |
| `.claude/rules/frontend.md` + `.claude/references/accessibility-checklist.md` | **Accessibility (WCAG 2.1 AA)** as an NFR for every user-facing screen |
| `.claude/rules/frontend.md` + `.claude/agents/ui-ux-designer.md` | **Responsive** — no horizontal overflow at the design-system breakpoints (320 / 768 / 1024 / 1280px); usable on mobile **and** desktop — a *measurable* NFR for every screen |
| `.claude/rules/monitoring.md` | Structured logging, correlation IDs, log redaction of sensitive data |
| `.claude/rules/tech-stack.md` | Approved tech stack alignment statement |
| `.claude/rules/api-conventions.md` | `ProblemDetails` error contract, `PagedResult<T>` envelope |
| `.claude/rules/principles-and-practices.md` §5 | NFR-dependent infra triggers — surface whether Redis / Kafka / read-replica / CDN may be needed, or explicitly confirm "not yet" (design the seam now, implement on measured trigger) |

Treat anything listed in these rules as **default-on NFRs** — the spec must either include them or explicitly justify an exception.

### Phase 2: Generate Specification

After discovery, produce `SPEC.md` using the **authoritative structure** defined in the Business Analyst agent.

> **Single source of truth:** `.claude/agents/business-analyst.md` § "Specification Document Structure" — follow that template verbatim.
>
> It includes (in this order): Header table (Version / Mode / Status / Date) → **Revision History** → Executive Summary → Objective → Target Users → User Stories (with **Gherkin AC**, **Business Rules**, **UI/UX Notes**, **Dependencies** per story) → Non-Functional Requirements → Boundaries (Always/Ask/Never) → Out of Scope → Open Questions & Decisions → Glossary → Appendix.

**Per-story format** — follow the BA agent § "User Story Format (BDD)" template **verbatim** (`#### US-[ID]` → As-a / I-want / So-that → Gherkin AC → Business Rules → UI/UX Notes → Dependencies); that copy is canonical, do not restate it here. The spec-specific rules below augment it:

> Do **not** use single-line checkbox AC (`- [ ] Given… When… Then…`) — always use Gherkin code blocks with named Scenarios covering happy path + at least one edge/failure case.

**Scenario IDs (traceability seed).** Tag every scenario with a stable ID — `@US-[ID]-S01` (happy), `-S02…` (each edge/failure). These IDs are the **canonical acceptance checklist** every downstream gate reconciles against — full rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md).

**User-perspective scenarios (mandatory).** Every **user-facing action** MUST have ≥ 1 scenario written from the **user's observable perspective** — the action as the user performs it (*"When I click Delete on an order"*) and the **observable outcome** (*"Then it disappears from my list"*) — NOT only the transport call (*"When I send `DELETE /…`"*). An API/transport-phrased scenario is allowed **in addition** (it documents the API contract) but, for a product with a UI, does **not** by itself satisfy the user-facing action. The *Then* must be a concrete, assertable observable outcome — per the "effect, not presence / survives a round-trip" rule in [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3.
> *Self-adapting:* for an API-only / headless product the "user" is the API consumer, so the transport scenario **is** the user-perspective — no fake UI required.

### Phase 2.5: Wireframe & Visual Prototype (UI products)

> Skip for headless / API-only products (the API contract is the interface), and for the brownfield REVERSE baseline (wireframes are per-change there — see §Brownfield Mode). For **any** product with a UI — UI-light or UI-heavy — the **UI/UX Designer** produces the wireframes; the HTML prototype is an **opt-in** add-on:

1. **ASCII / Mermaid wireframes** (`specs/wireframes/`) — **ALWAYS produced.** The versioned, diff-able **source of truth**: one file per screen with layout + states (empty / loading / error / no-result) + a11y notes + a **control → `@US-[ID]-Snn` mapping table**, plus a Mermaid sitemap and key user flows. This is what `/arch`, `/build`, and `/verify` cite for traceability.
   > **Page-level state only** (default / empty / loading / error / no-result) for each screen. The per-component state matrix (hover / focus / active / disabled…) is the design-system territory of `/arch` — do **NOT** generate it in `/spec` (fidelity = intent-level).
2. **A clickable HTML prototype** (`specs/wireframes/prototype/index.html`) — **OPT-IN, default OFF** (it is the heaviest artifact of `/spec`). Generate it **only when the user requests it** (e.g. `/spec … --prototype`, or "with prototype" in the request) **or when the stakeholder/PO cannot confidently sign off from the ASCII wireframes alone** and needs to click through the flow. It is a self-contained, **intent-level** sign-off aid (no real backend): disposable after approval (or snapshot per release); NOT pixel-perfect and NOT the design system (tokens / component contracts belong to `/arch`).

**Fidelity stays intent-level** — this phase validates *what the user sees and how the flow works*, not pixels/tokens. **The Gate 1 quality bar is: ASCII wireframes + stakeholder/PO visual sign-off** (both mandatory); the HTML prototype is an optional aid to reaching that sign-off, not a gate item in itself. **Fill-only boilerplate:** copy [`.claude/templates/wireframes/`](../templates/wireframes/) into `specs/wireframes/`. Convention: [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md); ASCII rules: [`.claude/references/ascii-diagram-guide.md`](../references/ascii-diagram-guide.md).

### Phase 3: Review & Confirm

- **Run the §Quality Gate 1 orchestrator disk-check first** — never present a spec whose mechanical invariants fail
- Present the spec to the user (Product Owner / Stakeholder)
- Record the change-set in **Revision History**: the first approved spec = the `v1.0 | Baseline` row; every later spec change (greenfield included — new stories, AC amendments) appends a new row. Semantics: BA agent §Revision History semantics.
- **(UI products) Tell the user the HTML prototype was not generated (opt-in, default OFF) and how to get it** — e.g. *"The ASCII wireframes are ready. The HTML prototype is not generated by default; if you/the stakeholder want a click-through to review, say 'create prototype' (or run `/spec … --prototype`)."* This is how the user discovers the option at point-of-use.
- Confirm before proceeding to `/arch`

## Output

### File Layout Strategy

Decide between **monolithic** and **split** layouts based on size and review workflow:

| Layout | When to use | Files |
|--------|-------------|-------|
| **Monolithic** *(default)* | Single feature, ≤ 20 user stories, reviewed as one PR | `specs/SPEC.md` only — keep `specs/user-stories/` absent or empty |
| **Split** | > 20 stories, multiple epics, or stories reviewed/implemented in separate PRs | `specs/SPEC.md` (overview + index + NFRs + Boundaries + Glossary) **plus** `specs/user-stories/US-001-<slug>.md`, `US-002-<slug>.md`, … (one file per story, full BDD detail) |

**Rules for the split layout:**
- `SPEC.md` keeps an index table with columns: `ID | Title | Epic | Priority | File`.
- Each `US-NNN-<slug>.md` is self-contained: As-a/I-want/So-that, Gherkin AC, Business Rules, Dependencies.
- Story IDs (`US-001`…) are stable across both layouts so `/plan`, `/build`, `/test` can cite them.
- Do **not** duplicate story content between `SPEC.md` and `user-stories/*.md` — link, don't copy.

### Deliverables

- `specs/SPEC.md` — always required
- `specs/user-stories/US-*.md` — only when split layout is chosen
- `specs/wireframes/` — required for UI products (Phase 2.5): `README.md` (Mermaid sitemap + design notes) · `screens/US-*.md` (ASCII layout + states + a11y + control→`@US` mapping) · `flows/*.md` (Mermaid). `prototype/index.html` (self-contained clickable prototype) — **only when requested (opt-in, default OFF)**
- Clear alignment on WHAT to build and WHY

## Quality Gate 1 — Definition of Ready (DoR)

Before moving to `/arch`, verify the **full DoR** in the Business Analyst agent — see [`.claude/agents/business-analyst.md`](../agents/business-analyst.md) § "Definition of Ready (DoR)" for the **authoritative checklist** (that copy is canonical — do not restate it here).

The **blocking essentials** (the gate fails without these):

- [ ] **Stakeholder sign-off obtained** — spec `Status` is `Approved`, not `Draft`
- [ ] **Every scenario has a stable ID (`@US-XXX-Snn`) + a concrete, assertable observable outcome (*Then*)**, and **every user-facing action has a user-perspective scenario** — not only an API-transport one
- [ ] **No unconfirmed assumptions / open questions** — each is `Resolved (date)` or `Open (owner / next command)`
- [ ] **(UI products) Wireframes + states in `specs/wireframes/` (mapped to `@US-XXX-Snn`), and visual UI signed off by stakeholder + PO** (date + name) — blocking before `/arch` *(greenfield & brownfield DELTA — touched screens only; waived for the REVERSE baseline, see §Brownfield Mode)*
- [ ] **Revision History has an append-only row for this change-set** — Type + version bump per the BA agent §Revision History semantics; `Breaking` → ADR cited; extended/superseded stories carry their marker line

> All other DoR items (story format, personas, priority, NFRs, Out-of-Scope, Glossary) → the authoritative checklist in the BA agent.

### Orchestrator disk-check (run BEFORE Phase 3 presents the spec)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level. The orchestrator re-checks the **mechanical** invariants on disk itself (the semantic DoR items — user-perspective scenarios, assertable ACs — remain human/BA judgment at sign-off):

- [ ] **Scenario tags complete** — every `Scenario:` in `specs/` has an `@US-XXX-Snn` tag on the line above; tag count == scenario count, no duplicate IDs (grep + count, don't trust the report's numbers).
- [ ] **Layout integrity** — `specs/SPEC.md` exists; split layout → the index table and `specs/user-stories/US-*.md` files match 1:1 (no orphan file, no dangling index row).
- [ ] **(UI, when Phase 2.5 ran) Wireframe completeness** — every user-facing story's §UI/UX Notes links an existing `specs/wireframes/screens/US-*.md`, and each screen file contains its `control → @US-[ID]-Snn` mapping table.
- [ ] **No template residue** — no unfilled placeholders (`[ … ]`, `TODO`, `[PRODUCT]`…) left in `specs/` (wireframes are copied from fill-only templates — residue means an unfinished fill).
- [ ] **Revision History** — exactly one new append-only row for this change-set; header `Version`/`Status` consistent with §Revision History semantics.

Any mismatch → fix on disk first; never present a spec that fails its own gate mechanics to the stakeholder.

## Brownfield Mode (when Phase 0 resolves = brownfield)

Only enter this section when **Phase 0** has resolved = brownfield **and** `docs/CODEBASE_MAP.md` exists (if missing → Phase 0 has already STOPped and required `/discover`). At that point `/spec` chooses REVERSE vs DELTA based on the presence of `specs/SPEC.md` — not present → REVERSE (establish a baseline); present → DELTA:

| Situation | Mode | Behavior |
|-----------|------|----------|
| `specs/SPEC.md` does not exist (after `/discover`) | **REVERSE** | **First consume the `/discover` artifacts** (`Project Profile` + `docs/CODEBASE_MAP.md` endpoint inventory + red-flag list) as the navigation index. From the inventory, go **directly** to the relevant handlers/`Services`/validators to extract **User Stories as-is** (describe what the system *is currently doing*, not what it should do) — do **NOT** re-survey the whole tree (that was `/discover`'s job). Assign stable US-IDs. This is baseline documentation. |
| `specs/SPEC.md` already exists | **DELTA** | Spec only **changes/new features**; reference existing stories (`Extend US-011…`), do NOT rewrite existing stories. Keep old IDs stable. |

**REVERSE — notes:**
- **Consume, don't re-scan:** the `docs/CODEBASE_MAP.md` endpoint inventory is the skeleton — one story-cluster per entry-point group; read handler bodies only for the behavior detail. Targeted reads, not a full-tree sweep.
- **Reuse red-flags:** carry the red-flag list from `/discover` straight into the spec as `⚠️ suspicious behavior` — do not re-detect from scratch.
- **Fallback guard:** if `docs/CODEBASE_MAP.md` is missing or has no endpoint inventory, **STOP** and re-run `/discover` (or scan only the missing area) — do not silently fall back to a full-tree survey.
- Describe **actual** behavior (even if it looks wrong/incomplete) — flag with `⚠️ suspicious behavior` instead of correcting it in the spec.
- Discovery `/spec` only **measures** (describes), does NOT verify against acceptance criteria (there are none yet) — per `rules/brownfield.md` §Measure-vs-Verify.
- Acceptance criteria are written based on observed behavior; used as a baseline for per-change characterization tests later.
- **DB-resident logic is a behavior source, same rank as a Service:** when the trace reaches `EXEC <proc>` / raw SQL touching a DB object, read the object's body from the defining file listed in the CODEBASE_MAP **DB-object inventory** (paths vary per repo — the inventory holds the actual locations) and extract its behavior into the story like any service code. Defining DDL not in the repo → tag the story `⚠️ DB-resident logic not in repo` and describe only the observable call surface (inputs / outputs / side effects seen from code) — do NOT guess the object's internals.
- The approved baseline is recorded as the `v1.0 | Baseline` row of **Revision History** (semantics: BA agent §Revision History semantics).
- **Phase 2.5 (wireframes) is NOT required for REVERSE** — the running UI is the as-is visual truth, and there is nothing for a stakeholder to visually sign off (it already shipped); baseline approval is the spec sign-off itself (the `v1.0 | Baseline` row). Wireframes + control→`@US-[ID]-Snn` mapping tables are produced **per-change** (DELTA / B1 / B2) for exactly the screens the change touches — per `rules/brownfield.md` §Upfront-vs-Per-change (no mass retrofit). The DoR wireframe + visual sign-off items are therefore **waived for the REVERSE baseline**.

**DELTA — notes:** do not break existing stories; if changes affect backward compatibility → state it clearly in the new story + flag for `/arch` conformance-gate. Each DELTA run appends exactly **one Revision History row** (`Added` / `Changed` / `Deprecated` / `Breaking`, version bump per BA agent §Revision History semantics) and puts the one-line marker (`> Extended by US-0xx (vX.Y)` / `> Superseded by US-0xx (vX.Y) — deprecated`) on every story it extends or supersedes — the old story body is never rewritten. **(UI products)** Phase 2.5 applies to the delta only: produce/update `specs/wireframes/screens/` for exactly the screens the change adds or modifies (untouched legacy screens need no wireframe); the DoR wireframe + visual sign-off items apply to those screens only.

## Agent

Invoke: **Business Analyst**

For **any product with a UI** (UI-light or UI-heavy), the **UI/UX Designer** produces the Phase 2.5 ASCII/Mermaid wireframes (always) plus the clickable HTML prototype (opt-in, default OFF) — see [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md) for the `specs/wireframes/` convention and fidelity rules.

**Phase ownership** — a sub-agent cannot converse with the user (its output does not stream to the chat — `CLAUDE.md` §Progress Visibility), so the interactive phases stay in the orchestrator's main loop:

| Phase | Runs in | Why |
|-------|---------|-----|
| 0 (mode detection) · 1 (discovery Q&A) · 3 (review & sign-off) + the Gate 1 disk-check | **Orchestrator (main loop)** | These steps converse with the user (`AskUserQuestion`, sign-off) or verify on disk — a sub-agent can do neither interactively |
| 2 (generate SPEC) | **Business Analyst sub-agent** | Spawn with ALL Phase 1 answers + logged assumptions; a gap those answers cannot resolve → the sub-agent returns early with the question (never assumes silently) |
| 2.5 (wireframes) | **UI/UX Designer sub-agent** | Spawn AFTER Phase 2 with the drafted stories, so mapping tables cite the final `@US-[ID]-Snn` |

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After spec is approved, run `/arch` to design the architecture.

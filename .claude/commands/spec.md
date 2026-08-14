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
| `/spec --wireframes` (brownfield REVERSE only) | Opt-in **as-is wireframes** for the REVERSE baseline (default: waived) — either during the REVERSE run, or **post-hoc** over an existing baseline (documentation supplement; see §Brownfield Mode → Wireframe supplement). Plain language works too: *"kèm wireframe"*. No-op outside REVERSE — wireframes are already always-produced for UI products. `--prototype` is NOT accepted in REVERSE (the running app is the click-through truth). |
| `/spec --propose-goals` (brownfield REVERSE only) | Opt-in **labeled goal proposals** when the repo has no goals evidence: the BA drafts Business/Product goals + Business Need/Expected Outcomes **inferred from observed product behavior**, each marked `📝P-nn` + provenance + an Open Questions row for the PO to confirm (see §Brownfield Mode → Goals proposal). Numbers (KPI values, baselines, timeframes) are NEVER invented — those cells stay `[NEEDS PO]`. Default without the flag: the orchestrator **asks** at run time (propose vs plain `N/A`); works post-hoc over an approved baseline too. |
| `/spec --scope <selector>` (brownfield REVERSE only) | **Scoped REVERSE** — reverse-engineer only the named feature group / endpoints instead of the whole repo: for a large legacy system onboarded **incrementally**, or when only part of a system is being taken over / ported. Selectors are comma-separated, matched (case-insensitive substring) against the `CODEBASE_MAP.md` **endpoint-inventory** columns — route, handler, or module: `--scope "/api/v1/bookmarks,/api/v1/tags"` · `--scope BookmarksController` · `--scope module:Billing`. **No match, or a match that would select everything → STOP** and print what matched: silently reversing nothing (or the whole repo) is worse than stopping. See §Brownfield Mode → Scoped REVERSE. |
| `/spec` (no arguments) | See **Phase 0**: repo already has code → brownfield (needs `/discover` first); nothing there → ask the user to provide requirements. |

> **Why the prototype is OFF by default:** it is the heaviest artifact of `/spec`. ASCII wireframes (always generated) are already enough as a source of truth + in most cases enough for sign-off. The prototype is generated when the user requests it, **or** when the stakeholder/PO needs a click-through to feel confident approving at Gate 1. Details: Phase 2.5.

## Phase 0 — Mode Auto-Detection (run BEFORE Phase 1)

> **Workspace precondition (BEFORE the signal table):** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode first, then evaluate ALL three signals below **inside the target repo** (CODE probes `<repo>/src/**`, `<repo>/web/package.json`; DISCOVERY probes `<repo>/docs/CODEBASE_MAP.md`). Evaluating them at the workspace root mis-resolves to greenfield — the root owns no build manifest.

`/spec` resolves the mode itself at runtime instead of trusting `Project Profile → Mode` absolutely (it can be stale). Three signals:

- **ARGS** — does `/spec` come with input requirements? (`/spec <requirements>` vs bare `/spec`)
- **CODE** — does the repo have source code? Probe: the existence of any `src/**/*.csproj`, `web/package.json`, `composer.json`, or another build manifest outside `.claude/` (the same way `/discover` checks).
- **DISCOVERY** — has it been onboarded via `/discover`? Probe: `docs/CODEBASE_MAP.md` exists (a mandatory deliverable of `/discover` — having it = having a navigation index for REVERSE/DELTA). *The STOP signal is "missing discovery", NOT "missing SPEC" — because REVERSE is itself the step that creates `SPEC.md` from nothing.*

| ARGS | CODE | DISCOVERY | Resolved mode | Action |
|:----:|:----:|:---------:|---------------|-----------|
| ✅ | ❌ | — | **greenfield** | Write a forward spec from args (continue to Phase 1). If the Profile says `brownfield` → treat it as stale, surface + propose a fix. |
| ❌ | ✅ | ❌ | **brownfield (not yet discovered)** | **STOP** — run `/discover` first (REVERSE needs `docs/CODEBASE_MAP.md` as an index), then `/spec` again. |
| ❌ | ✅ | ✅ | **brownfield** | Has `specs/SPEC.md` with `Coverage: full` → **DELTA** · has one with `Coverage: partial` **and `--scope` given** → **scoped REVERSE that EXTENDS coverage** (never rewrites what is already covered) · has one with `Coverage: partial` and the request touches an **uncovered** area → **STOP**: reverse that area first (`--scope`) — a DELTA against a spec that never described the thing is a guess, not a delta · has none → **REVERSE** (full, or `--scope` for the first slice) — go down to §Brownfield Mode. |
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
- What are the measurable goals? Business vs product goal, KPI, baseline, timeframe — feeds §Goals & Success Metrics

**Features**
- What are the core features (MVP)?
- What are the acceptance criteria for each?
- What is the priority? (Must / Should / Could / Won't)
- What is explicitly out of scope?
- Which roles can perform each core action? Any ownership-scoped access (own records only)? — feeds §Permission Matrix

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
> It includes (in this order): Header table (Version / Mode / Status / Date) → **Revision History** → Executive Summary → Objective → **Goals & Success Metrics** → Target Users → **Permission Matrix** → User Stories (with **Gherkin AC**, **Business Rules**, **UI/UX Notes**, **Dependencies** per story) → Non-Functional Requirements → Boundaries (Always/Ask/Never) → Out of Scope → Open Questions & Decisions → Glossary → Appendix.

**Per-story format** — follow the BA agent § "User Story Format (BDD)" template **verbatim** (`#### US-[ID]` → As-a / I-want / So-that → Gherkin AC → Business Rules → UI/UX Notes → Dependencies); that copy is canonical, do not restate it here. The spec-specific rules below augment it:

> Do **not** use single-line checkbox AC (`- [ ] Given… When… Then…`) — always use Gherkin code blocks with named Scenarios covering happy path + at least one edge/failure case.

**Scenario IDs (traceability seed).** Tag every scenario with a stable ID — `@US-[ID]-S01` (happy), `-S02…` (each edge/failure). These IDs are the **canonical acceptance checklist** every downstream gate reconciles against — full rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md). Each scenario also carries exactly one **class tag** (`@happy` / `@negative` / `@edge`) next to its ID — convention defined in the BA agent §User Story Format; class tags map 1:1 to external doc conventions (✅/❌/⚠️) at export time.

**User-perspective scenarios (mandatory).** Every **user-facing action** MUST have ≥ 1 scenario written from the **user's observable perspective** — the action as the user performs it (*"When I click Delete on an order"*) and the **observable outcome** (*"Then it disappears from my list"*) — NOT only the transport call (*"When I send `DELETE /…`"*). An API/transport-phrased scenario is allowed **in addition** (it documents the API contract) but, for a product with a UI, does **not** by itself satisfy the user-facing action. The *Then* must be a concrete, assertable observable outcome — per the "effect, not presence / survives a round-trip" rule in [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3.
> *Self-adapting:* for an API-only / headless product the "user" is the API consumer, so the transport scenario **is** the user-perspective — no fake UI required.

### Phase 2.5: Wireframe & Visual Prototype (UI products)

> Skip for headless / API-only products (the API contract is the interface), and for the brownfield REVERSE baseline (wireframes are per-change there — **unless the user opts in with `--wireframes` for as-is wireframes**; see §Brownfield Mode → Wireframe supplement). For **any** product with a UI — UI-light or UI-heavy — the **UI/UX Designer** produces the wireframes; the HTML prototype is an **opt-in** add-on:

1. **ASCII / Mermaid wireframes** (`specs/wireframes/`) — **ALWAYS produced.** The versioned, diff-able **source of truth**: one file per screen with layout + states (empty / loading / error / no-result) + a11y notes + a **control → `@US-[ID]-Snn` mapping table**, plus a Mermaid sitemap and key user flows. This is what `/arch`, `/build`, and `/verify` cite for traceability.
   > **Page-level state only** (default / empty / loading / error / no-result) for each screen. The per-component state matrix (hover / focus / active / disabled…) is the design-system territory of `/arch` — do **NOT** generate it in `/spec` (fidelity = intent-level).
2. **A clickable HTML prototype** (`specs/wireframes/prototype/index.html`) — **OPT-IN, default OFF** (it is the heaviest artifact of `/spec`). Generate it **only when the user requests it** (e.g. `/spec … --prototype`, or "with prototype" in the request) **or when the stakeholder/PO cannot confidently sign off from the ASCII wireframes alone** and needs to click through the flow. It is a self-contained, **intent-level** sign-off aid (no real backend): disposable after approval (or snapshot per release); NOT pixel-perfect and NOT the design system (tokens / component contracts belong to `/arch`).

**Fidelity stays intent-level** — this phase validates *what the user sees and how the flow works*, not pixels/tokens. **The Gate 1 quality bar is: ASCII wireframes + stakeholder/PO visual sign-off** (both mandatory); the HTML prototype is an optional aid to reaching that sign-off, not a gate item in itself. **Fill-only boilerplate:** copy [`.claude/templates/wireframes/`](../templates/wireframes/) into `specs/wireframes/`. Convention: [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md); ASCII rules: [`.claude/references/ascii-diagram-guide.md`](../references/ascii-diagram-guide.md).

### Phase 3: Review & Confirm

- **Run the §Quality Gate 1 orchestrator disk-check first** — never present a spec whose mechanical invariants fail
- Present the spec to the user (Product Owner / Stakeholder)
- Record the change-set in **Revision History**: the first approved spec = the `v1.0 | Baseline` row; every later spec change (greenfield included — new stories, AC amendments) appends a new row. Semantics: BA agent §Revision History semantics.
- **(UI products) Tell the user the HTML prototype was not generated (opt-in, default OFF) and how to get it** — e.g. *"The ASCII wireframes are ready. The HTML prototype is not generated by default; if you/the stakeholder want a click-through to review, say 'create prototype' (or run `/spec … --prototype`)."* This is how the user discovers the option at point-of-use.
- **(Workspace)** After sign-off, flag that the system layer is now STALE for this service (`architecture/system/` + `specs/system/` `last-synced` < the new spec version) — recommend re-running `/discover-system`; system-target exports are blocked on freshness anyway (`export-docs.md` Phase 0).
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
- [ ] **(UI products) Wireframes + states in `specs/wireframes/` (mapped to `@US-XXX-Snn`), and visual UI signed off by stakeholder + PO** (date + name) — blocking before `/arch` *(greenfield & brownfield DELTA — touched screens only; waived for the REVERSE baseline — even when as-is wireframes were opted in via `--wireframes`, they document shipped UI and only the mechanical disk-checks apply; see §Brownfield Mode)*
- [ ] **Revision History has an append-only row for this change-set** — Type + version bump per the BA agent §Revision History semantics; `Breaking` → ADR cited; extended/superseded stories carry their marker line
- [ ] **(scoped REVERSE) Coverage declared** — header `Coverage:` present; §Scope & Coverage lists covered AND uncovered entry points with counts; the uncovered list is derived from `CODEBASE_MAP.md`, not hand-written

> All other DoR items (story format, personas, priority, NFRs, Out-of-Scope, Glossary) → the authoritative checklist in the BA agent.

### Orchestrator disk-check (run BEFORE Phase 3 presents the spec)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level. The orchestrator re-checks the **mechanical** invariants on disk itself (the semantic DoR items — user-perspective scenarios, assertable ACs — remain human/BA judgment at sign-off):

- [ ] **Scenario tags complete** — every `Scenario:` in `specs/` has an `@US-XXX-Snn` tag on the line above; tag count == scenario count, no duplicate IDs (grep + count, don't trust the report's numbers).
- [ ] **Class tags complete** — every scenario in stories touched by this change-set has exactly one `@happy`/`@negative`/`@edge` tag, and each touched story has ≥ 1 `@happy` (grep + count; full-spec scope for Baseline/design mode, touched-stories scope for DELTA).
- [ ] **(UI products) No transport-only stories** — grep `(GET|POST|PUT|DELETE) /` inside the gherkin blocks: a story whose scenarios ALL carry transport phrasing (none written from the user's observable perspective) FAILS. Transport wording may appear only *in addition* to a user-perspective scenario. API-only/headless products: N/A — there the transport call IS the user perspective. Same scope rule as the class-tag check.
- [ ] **Proposal pairing** — every `📝P-` label in the spec body has exactly one matching Open Questions row citing the same `P-nn` (and vice versa); no `📝` label carries a concrete KPI number/baseline/timeframe (those cells must read `[NEEDS PO]`). Grep + count; zero labels = check passes trivially.
- [ ] **Goals, NFR & Permission sections present** — `SPEC.md` contains the Goals table (≥ 1 `| G-` row), the NFR table (≥ 1 `| NFR-` row), and the Permission Matrix table (cells carry ✅/🔒/— markers), each either filled or replaced by an explicit `N/A + reason` line. Anchor the grep on these **language-neutral markers** (`G-`/`NFR-` IDs, ✅/🔒/—), NOT on English heading strings — headings render in the artifact's output language. Baseline/design mode only — a DELTA over a legacy baseline adds them delta-scoped without failing on the legacy remainder.
- [ ] **Layout integrity** — `specs/SPEC.md` exists; split layout → the index table and `specs/user-stories/US-*.md` files match 1:1 (no orphan file, no dangling index row).
- [ ] **(REVERSE — any scope) Coverage ledger reconciles** — extract the entry-point set from `docs/CODEBASE_MAP.md` and the set covered by stories. **Full REVERSE ⇒ the uncovered set must be EMPTY**: an entry point with no story is a silently missing slice of the baseline — exactly what a full reverse exists to prevent, and nothing else in the pipeline would ever catch it. **Scoped REVERSE ⇒** `covered ∪ uncovered` must equal the inventory **exactly** (nothing missing from both lists, nothing in both), which is what stops a partial baseline from passing as a full one. Count and diff yourself. *(All the scope-sensitive checks above — scenario tags, class tags, Goals/Permission, wireframes — narrow to the scoped story set, exactly as they do for a DELTA.)*
- [ ] **(UI, when Phase 2.5 ran) Wireframe completeness** — every user-facing story's §UI/UX Notes links an existing `specs/wireframes/screens/US-*.md`, and each screen file contains its `control → @US-[ID]-Snn` mapping table.
- [ ] **No template residue** — no unfilled placeholders (`[ … ]`, `TODO`, `[PRODUCT]`…) left in `specs/` (wireframes are copied from fill-only templates — residue means an unfinished fill).
- [ ] **Revision History** — exactly one new append-only row for this change-set; header `Version`/`Status` consistent with §Revision History semantics.

Any mismatch → fix on disk first; never present a spec that fails its own gate mechanics to the stakeholder.

> **Warning-only check (surfaced, never blocking):** grep the `Then` lines for empty-meaning outcomes — `thành công` · `hoạt động đúng` · `xử lý được` · `works` · `is handled` · `as expected` · `correctly` — and list every hit for the signer to re-read. A *Then* that names no observable effect cannot become a test at `/plan`/`/test`, and that is where the cost lands; but deciding whether a given sentence is vague stays human judgment, so this reports and never fails the gate. Rule it defends: [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3 — *effect, not presence*.

## Brownfield Mode (when Phase 0 resolves = brownfield)

Only enter this section when **Phase 0** has resolved = brownfield **and** `docs/CODEBASE_MAP.md` exists (if missing → Phase 0 has already STOPped and required `/discover`). At that point `/spec` picks the mode from `specs/SPEC.md` **and its `Coverage` field** — Phase 0 already resolved this; the table below is its detail:

| Situation | Mode | Behavior |
|-----------|------|----------|
| `specs/SPEC.md` does not exist (after `/discover`) | **REVERSE** | **First consume the `/discover` artifacts** (`Project Profile` + `docs/CODEBASE_MAP.md` endpoint inventory + red-flag list) as the navigation index. From the inventory, go **directly** to the relevant handlers/`Services`/validators to extract **User Stories as-is** (describe what the system *is currently doing*, not what it should do) — do **NOT** re-survey the whole tree (that was `/discover`'s job). Assign stable US-IDs. This is baseline documentation. |
| `specs/SPEC.md` exists with `Coverage: full` | **DELTA** | Spec only **changes/new features**; reference existing stories (`Extend US-011…`), do NOT rewrite existing stories. Keep old IDs stable. |
| `specs/SPEC.md` exists with `Coverage: partial (scoped)` | **DELTA · scoped REVERSE · or STOP** | Request targets an **already-covered** area → DELTA as usual · targets an **uncovered** area → **STOP**: reverse that area first (`--scope`), because a DELTA against a spec that never described the thing is a guess · `--scope` given → **extend coverage** (append-only — §Scoped REVERSE below). |

**Scoped REVERSE (`--scope`) — building the baseline in slices.** A 500-endpoint legacy system cannot be reversed in one sitting, and a takeover or a feature port often needs only part of it. Rules:

1. **The selector resolves against the endpoint inventory** (HTTP routes · message consumers · scheduled jobs · CLI — the generalized inventory), never against a raw file glob. Print the resolved set and its size **before** writing anything; no match / matches everything → STOP.
2. **The SPEC declares its own coverage** — header `Coverage: partial (scoped)` + a **§Scope & Coverage** section listing the covered entry points **and, explicitly, the uncovered remainder** (derived by diffing the inventory against the stories' entry points — a machine-checkable ledger, not a promise). *A partial SPEC that does not say it is partial is the exact failure mode this feature must avoid:* it looks identical to a complete baseline, so Phase 0 would resolve to DELTA forever and the rest of the repo would never be specced.
3. **Extending is append-only** — a later `--scope` run adds stories with fresh IDs and appends a Revision History row `Added — coverage extended: <selector>`; already-covered stories are never rewritten (same discipline as DELTA).
4. **Red-flags stay whole-repo** — carry every `/discover` red-flag touching the scoped area into the stories as `⚠️ suspicious behavior`; a red-flag **outside** the scope is still listed under §Scope & Coverage as *known, not yet specced*, so it cannot be lost.
5. **Coverage reaches 100% → flip the header to `Coverage: full`** (+ a Revision History row); from then on Phase 0 behaves exactly as before.
6. **Combining flags:** `--scope` works with `--wireframes` (draw only the screens inside the scope). It is **not** combined with `--propose-goals` — product-level goals cannot be inferred from a single slice; propose goals only once the baseline covers the product (`Coverage: full`).

**REVERSE — notes:**
- **Consume, don't re-scan:** the `docs/CODEBASE_MAP.md` endpoint inventory is the skeleton — one story-cluster per entry-point group; read handler bodies only for the behavior detail. Targeted reads, not a full-tree sweep.
- **No schema evidence → surface it, don't spec blind:** a clearly data-centric app whose repo shows no DDL/migration/schema snapshot (and the DB-object inventory is empty while code calls DB objects) → **stop and surface the gap** with the paved road (`/discover` §Phase 1b guided export, or commit the CREATE scripts by hand), and ask whether to continue. Writing as-is stories over an invisible data layer produces a baseline with a hole in exactly the place brownfield changes are most dangerous. A database MCP tool being available in the session changes nothing here: **spec content is written from repo artifacts only** — reading a live schema through MCP and typing stories from it produces evidence nobody can re-verify from a checkout.
- **Non-HTTP entry points are stories too:** a message consumer / scheduled job in the endpoint inventory becomes a story cluster with the **upstream system or scheduler as the actor** (*"When an `OrderCreated` message arrives → the system … (observable effect)"*) — its transport scenario IS the user-perspective (same self-adapting rule as API-only products).
- **Reuse red-flags:** carry the red-flag list from `/discover` straight into the spec as `⚠️ suspicious behavior` — do not re-detect from scratch.
- **Fallback guard:** if `docs/CODEBASE_MAP.md` is missing or has no endpoint inventory, **STOP** and re-run `/discover` (or scan only the missing area) — do not silently fall back to a full-tree survey.
- Describe **actual** behavior (even if it looks wrong/incomplete) — flag with `⚠️ suspicious behavior` instead of correcting it in the spec.
- **User-perspective phrasing holds in REVERSE too (UI products):** extract behavior from code, but PHRASE user-facing scenarios from the user's observable perspective (*"When I submit the register form…"*) — reading code naturally biases toward `POST /…` wording; resist it. Method/path/HTTP-status details belong to the API contract artifacts (`/arch`: `openapi.yaml` + the error-code table), not scenario prose; a **stable error code** may stay as an identifier when it is user-visible behavior. Evidence citations (`file:line`, class/method names) go into HTML comments or the Appendix — never into stakeholder-facing prose (the SPEC is a stakeholder document — `rules/output-style.md` §1).
- **Goals & Success Metrics in REVERSE:** fill only from real evidence (README, docs, stakeholder answers). No evidence → the orchestrator ASKS the user (never decides silently): (a) plain `N/A — legacy baseline; goals not documented in source evidence`, or (b) **labeled proposals** per §Goals proposal below (`--propose-goals` pre-answers this). Never write an inferred goal as if it were fact — unlabeled inference is still forbidden.
- **Permission Matrix in REVERSE:** derive from observed authz evidence — `[Authorize]` attributes, route guards, middleware (the CODEBASE_MAP endpoint inventory lists route → handler). An endpoint with no authz observed → mark `⚠️ no authz observed` (a red-flag for `/scan`), never guess intent.
- Discovery `/spec` only **measures** (describes), does NOT verify against acceptance criteria (there are none yet) — per `rules/brownfield.md` §Measure-vs-Verify.
- Acceptance criteria are written based on observed behavior; used as a baseline for per-change characterization tests later.
- **DB-resident logic is a behavior source, same rank as a Service:** when the trace reaches `EXEC <proc>` / raw SQL touching a DB object, read the object's body from the defining file listed in the CODEBASE_MAP **DB-object inventory** (paths vary per repo — the inventory holds the actual locations) and extract its behavior into the story like any service code. Defining DDL not in the repo → tag the story `⚠️ DB-resident logic not in repo` and describe only the observable call surface (inputs / outputs / side effects seen from code) — do NOT guess the object's internals.
- The approved baseline is recorded as the `v1.0 | Baseline` row of **Revision History** (semantics: BA agent §Revision History semantics).
- **Phase 2.5 (wireframes) is NOT required for REVERSE** — the running UI is the as-is visual truth and there is nothing to sign off before build (it already shipped); baseline approval IS the spec sign-off (`v1.0 | Baseline`). Wireframes are produced **per-change** (DELTA/B1/B2) for the touched screens only — `rules/brownfield.md` §Upfront-vs-Per-change. The DoR wireframe + visual-sign-off items are therefore **waived here**; `--wireframes` is the opt-in exception → §Wireframe supplement below.

**Wireframe supplement — REVERSE opt-in (`--wireframes`):**

- **When:** during the REVERSE run itself, OR **post-hoc** — `/spec --wireframes` when the baseline `specs/SPEC.md` already exists and `specs/wireframes/` does not → documentation-supplement mode: draw wireframes only; do NOT touch stories, AC, or Revision History.
- **Semantics — as-is documentation (measure, not design):** drawn from code evidence per UI/UX Designer §REVERSE Mode (routes, components, states actually implemented). A page-level state with no code path → `⚠️ not observed (as-is gap)` + the file checked — never drawn as if it existed. No beautifying: shipped UI that looks wrong is drawn as-is and flagged, not fixed.
- **Scope confirmation (mandatory):** list the screens found from the route inventory and confirm with the user which to draw (all by default; subset allowed for large apps) — never mass-document beyond what was asked.
- **Artifacts:** same layout + fill-only boilerplate as Phase 2.5 (`README.md` + `screens/US-*.md` + `flows/`), each screen carrying its control → `@US-[ID]-Snn` mapping table (the main traceability value — a control no scenario covers → `⚠️ no scenario covers this control`). `prototype/` is NOT produced in REVERSE.
- **Story pointer update (post-hoc only):** each covered story's §UI/UX Notes line switches from the waiver note to a link to its screen file — a pointer swap only (no AC/BR/body change), **no new Revision History row** (a documentation supplement is not a product decision); record one line in §Appendix with the supplement date.
- **Gate:** the mechanical wireframe checks in §Orchestrator disk-check ("(UI, when Phase 2.5 ran)") apply to the drawn screens; the stakeholder **visual sign-off stays waived** — the artifact documents shipped UI, there is nothing to approve before build.

**Goals proposal — REVERSE opt-in (`--propose-goals`):**

- **What it is:** the BA drafts the business-intent layer that code cannot evidence (Goals, Business Need, Expected Outcomes, Impact if Not Done) as **clearly-labeled proposals** for the PO to confirm. **The content rules are canonical in [`business-analyst.md`](../agents/business-analyst.md) §Proposed Content** — closed field list · `📝P-nn` + inference basis · qualitative only (numbers stay `[NEEDS PO]`) · one paired Open Questions row each. Not restated here.
- **Confirmation path:** at Gate 1 sign-off the stakeholder confirms/edits (labels removed → real content) or leaves the OQ rows Open (labels survive; `/export-docs` carries them through so the company-flow PO decides). A later confirmation lands as one `Amended` Revision History row citing the resolved `P-nn`.
- **Post-hoc mode:** `/spec --propose-goals` over an existing baseline (any Status) → adds the labeled proposals + OQ rows + exactly one Revision History row (`Amended`, pending sign-off); stories/AC untouched.

**DELTA — notes:** do not break existing stories; if changes affect backward compatibility → state it clearly in the new story + flag for `/arch` conformance-gate. Each DELTA run appends exactly **one Revision History row** (`Added` / `Changed` / `Deprecated` / `Breaking`, version bump per BA agent §Revision History semantics) and puts the one-line marker (`> Extended by US-0xx (vX.Y)` / `> Superseded by US-0xx (vX.Y) — deprecated`) on every story it extends or supersedes — the old story body is never rewritten. **(UI products)** Phase 2.5 applies to the delta only: produce/update `specs/wireframes/screens/` for exactly the screens the change adds or modifies (untouched legacy screens need no wireframe); the DoR wireframe + visual sign-off items apply to those screens only. New sections & class tags follow the same delta discipline: a legacy baseline missing `## Goals & Success Metrics` / `## Permission Matrix` gets them added **scoped to the delta** (the change's goals, the touched actions/roles) — no backfill of the legacy remainder; class tags are required only on scenarios this change-set authors or modifies — never retag untouched stories.

## Agent

Invoke: **Business Analyst**

For **any product with a UI** (UI-light or UI-heavy), the **UI/UX Designer** produces the Phase 2.5 ASCII/Mermaid wireframes (always) plus the clickable HTML prototype (opt-in, default OFF) — see [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md) for the `specs/wireframes/` convention and fidelity rules.

**Phase ownership** — a sub-agent cannot converse with the user (its output does not stream to the chat — `CLAUDE.md` §Progress Visibility), so the interactive phases stay in the orchestrator's main loop:

| Phase | Runs in | Why |
|-------|---------|-----|
| 0 (mode detection) · 1 (discovery Q&A) · 3 (review & sign-off) + the Gate 1 disk-check | **Orchestrator (main loop)** | These steps converse with the user (`AskUserQuestion`, sign-off) or verify on disk — a sub-agent can do neither interactively |
| 2 (generate SPEC) | **Business Analyst sub-agent** | Spawn with ALL Phase 1 answers + logged assumptions **+ the resolved project-mandatory NFR list** (the Phase 1 cross-check outcome — each NFR either to include or with its justified exception; the sub-agent must not re-derive or drop any); a gap those answers cannot resolve → the sub-agent returns early with the question (never assumes silently) |
| 2.5 (wireframes) | **UI/UX Designer sub-agent** | Spawn AFTER Phase 2 with the drafted stories, so mapping tables cite the final `@US-[ID]-Snn` |

> Sub-agent prompt MUST include: "Output language: \<declared language — resolve from Project Profile → Output Language\> for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After spec is approved, run `/arch` to design the architecture.

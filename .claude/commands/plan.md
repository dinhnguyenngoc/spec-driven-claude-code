---
name: plan
description: Decompose specs into small, verifiable tasks with dependency ordering
---

# /plan — Planning & Task Breakdown

> "Vertical slices, not horizontal layers."

## Purpose

Transform a specification into an ordered list of small, verifiable tasks. Each task delivers end-to-end functionality.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

## Prerequisites

**Required:**
- A specification exists (`specs/SPEC.md` from `/spec`), passed Gate 1 — header `Status` is **Approved**, not Draft
- Architecture exists (`architecture/` from `/arch`) — greenfield: Gate 2 passed; brownfield B1/B2: the Phase A baseline + this change's CONFORMANCE-GATE verdict (a one-question check — do not skip it for "small" changes; the verdict IS the cheap path). Includes `architecture/api/openapi.yaml` when the feature has an API surface.
- Understanding of the codebase structure

## Workflow

### Phase 1: Analysis (Read-Only)

1. **Spec-readiness pre-check** — confirm the spec passed Gate 1: the header `Status` is **Approved**, every scenario has a stable ID (`@US-XXX-Snn`) and a testable, observable AC. If the Status is still Draft, a scenario is missing an ID, has a vague/untestable AC, or a needed behaviour isn't in the spec at all → **do not start decomposing it.**
2. **Read the spec** — Understand objectives and acceptance criteria
3. **Survey the codebase** — Identify relevant files, patterns, and integration points. *(Brownfield: consume `/discover` artifacts as the index — see §Brownfield Mode — do not re-survey the tree.)*
4. **Review architecture (if exists)** — Check ADRs, API contracts, diagrams
5. **Map dependencies** — Which components depend on which?

> **Do NOT modify code during planning.**

> **Don't invent scope — route gaps back (mandatory).** `/plan` decomposes **what the spec says**; it does not author requirements. When a scenario/AC is missing, ambiguous, or un-plannable, **STOP and route it back to `/spec`** (or ask the user with `AskUserQuestion`; when running as a sub-agent you cannot reach the user — return early with the question to the orchestrator instead) — get it added/clarified there, or record it as a **blocking Open item**. Never fill a spec gap by inventing a task scope or guessing the behaviour — a planner's guess is an unconfirmed requirement, and it bypasses the BA's Gate 1.

### Phase 2: Vertical Slicing

Break work into **vertical slices** — each slice delivers complete functionality through all layers:

```text
❌ Horizontal (anti-pattern):
   Task 1: Create all DB models
   Task 2: Create all API routes
   Task 3: Create all UI components

✅ Vertical (correct):
   Task 1: User can create a task (DB + API + UI)
   Task 2: User can view task list (DB + API + UI)
   Task 3: User can mark task complete (DB + API + UI)
```

### Phase 3: Task Definition

Each task must include:

```markdown
## Task: [Short description]

**User stories**: US-XXX, US-YYY  *(traceability back to specs/SPEC.md — every task must map to at least one story or be flagged as "Foundation" with justification)*

**Scenarios covered**: `@US-XXX-S01`, `@US-XXX-S03`, …  *(list the exact scenario IDs this task delivers — story-level mapping is NOT enough; a sub-behavior cannot hide inside a bundled task. Every `@US-XXX-Snn` must appear under some task or in the Deferred/Waived table — rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md))*

**References**: ADR-NNN (if a decision drives this task), `architecture/api/openapi.yaml#OperationId` (if API task)

**Objective**: [What this achieves]

**Files to modify**:
- `src/models/task.ts`
- `src/routes/tasks.ts`
- `src/components/TaskList.tsx`

**Acceptance Criteria**:
- [ ] User can [action]
- [ ] [Validation] is enforced
- [ ] [Observable behavior]

**Tests to add**:
- `tests/unit/.../XxxTests.YyyScenario_ExpectedResult`
- `tests/integration/.../ZzzControllerTests.Method_Scenario_ExpectedResult`

> AC describes the **observable behavior**; Tests to add lists the **specific test files/names** that prove each AC. Keep them in 1-to-1 (or 1-to-many) correspondence — every AC should be backed by at least one named test.
>
> **One scenario : its own effect-asserting test** — per [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3–4: each scenario ID maps to a test asserting **that scenario's observable *Then*** (never conflate two scenarios into one test); a UI-observable scenario requires a UI/E2E-layer test, not an API test alone.
>
> **Test the handoff** — if a slice has one unit that *produces* a value another *consumes* (navigation-state key, React context, event/message name, shared prop contract), list ≥ 1 test exercising **both ends together** (producer acts → consumer's observable effect asserted), not two isolated per-side tests — per [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3 (handoff clause). A key/name mismatch passes both sides alone yet breaks the feature.

**Dependencies**: [Task IDs this depends on]

**Verification**: Done when every test under "Tests to add" passes, plus manual check: [steps a human/agent runs to confirm done]

**Estimate**: S | M | L  *(S ≤ 2 h, M 2–6 h, L 6–12 h — task-level. Stories > 12 h must be split.)*
```

### Phase 4: Ordering

Order tasks by:
1. **Foundation first** — DB models, types, shared utilities
2. **Risk-first** — Tackle uncertain/complex items early
3. **Dependencies** — Respect the dependency graph
4. **Quick wins** — Early momentum with smaller tasks

### Phase 5: Checkpoints

Insert checkpoints between major phases:

```markdown
---
## Checkpoint: Core CRUD Complete

**Verify before proceeding**:
- [ ] All CRUD operations work
- [ ] Test coverage ≥ 80%
- [ ] No console errors
- [ ] NFR spot-check passes (e.g. P95 latency < spec threshold)

---
```

## Output

Save to `plans/` directory:

- `plans/plan.md` — Full planning document with context
- `plans/todo.md` — Actionable task checklist

> **Single source of truth = the Task blocks (Phase 3)** in `plans/plan.md`. The **Summary table** and **`todo.md`** are **pure projections** — they reuse each task's id + title **verbatim** and add no new scope/detail. When a task changes, edit the Task block, then re-project; never let the three drift.

### `plans/plan.md` — required structure

The plan document MUST include the following sections, in this order:

1. **Header — Inputs consumed**
   Bullet list of every source file the plan was derived from: `specs/SPEC.md` (with user-story IDs), `architecture/ARCHITECTURE.md` sections, ADR files, `architecture/api/openapi.yaml`. Lets downstream agents (`/secure`, `/build`) verify nothing was missed.

2. **Build-time testing scope**
   Declare which test layers belong to `/build` vs deferred to `/test`, per `.claude/rules/testing.md`. Typical:
   - `/build`: Unit tests (xUnit + Moq) + Integration tests using the **InMemory** `WebApplicationFactory` template (no Docker).
   - Deferred to `/test`: TestContainers + Playwright E2E.

3. **Summary table** — every task in one scan (**projection** of the Task blocks; reuse id + title verbatim, no new detail):

   | # | Task | User story | Estimate | Phase |
   |---|------|------------|---------:|-------|
   | 0.1 | Scaffold solution | Foundation | M | 0 |
   | 1.1 | Register endpoint | US-001 | M | 1 |
   | … | … | … | … | … |

   End with `**Total ideal points** (S=1, M=2, L=3): N` for rough capacity sizing.

4. **Phases, Checkpoints, and Tasks** *(per the Task template in Phase 3 above)*

5. **Risk register** — table of `(task, risk, mitigation already in plan)`. Each mitigation MUST reference an existing AC or named test in this plan (not a TBD). Example:

   | Task | Risk | Mitigation already in plan |
   |------|------|----------------------------|
   | 2.2 | SSRF mitigation has many ranges; missing one = vulnerability | One unit test per documented IPv4/IPv6 range in `IpRangeCheckerTests` |

6. **Deferred/Waived scenarios** *(only when not 100% covered by tasks)* — table `@US-XXX-Snn | Deferred to (phase/owner) / Waived | Reason`. The union of this table + all tasks' "Scenarios covered" MUST equal the change-set's full scenario set — rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md) §5 (no silent drops).

7. **Out of scope** — explicit list of what later workflow phases own and will NOT be done here:

   - `/test` — TestContainers + Playwright E2E
   - `/scan` — SCA, full STRIDE walk-through
   - `/infra` — production docker-compose, Dockerfile
   - `/docs` — API reference site, runbooks
   - `/deploy` — staged rollout, release notes

   This protects against scope creep during `/build`.

### `plans/todo.md` — template

> **Projection only:** each line is `- [ ] Task <id>: <same title as its Task block>` — do not re-describe or add scope. Update `plan.md` first, then re-project. *(Status annotations appended by downstream phases — the `- [x]` tick, `[A-xx]` assumption flags — are allowed; new scope text is not.)*

```markdown
# TODO: [Feature Name]

## Phase 1: Foundation
- [ ] Task 1.1: [Description]
- [ ] Task 1.2: [Description]

## Checkpoint: Foundation Complete

## Phase 2: Core Features
- [ ] Task 2.1: [Description]
- [ ] Task 2.2: [Description]

## Checkpoint: Core Complete

## Phase 3: Polish
- [ ] Task 3.1: [Description]
```

> Per CLAUDE.md rule 11: downstream phases (`/build`, `/test`) MUST tick `- [x]` immediately on task completion. When work is delegated to a sub-agent, the orchestrator owns the tick and applies it after the sub-agent's success report.

## Quality Gate 3 — Task Breakdown

Run the §Orchestrator disk-check (below) first, then review. Before proceeding to `/secure`:
- [ ] Tasks broken into vertical slices (no horizontal "all DB → all API → all UI" tasks)
- [ ] Every task traces to a user story (or is flagged "Foundation" with reason)
- [ ] **Scenario coverage 100% — every `@US-XXX-Snn` from the spec is listed under some task's "Scenarios covered", or in a Deferred/Waived table (reason + owner). No scenario hidden inside a bundled task.**
- [ ] **NFR coverage — every NFR from the spec and every mechanism in `/arch`'s NFR-mechanism table (e.g. rate limiter on `/auth/login`, Redis cache + indexed read path for a P95 target) is either a task, folded into a task's AC, or listed in Out of scope / Deferred (reason + owner). No NFR drops silently.** This closes the `spec NFR → arch mechanism → plan task` chain — the symmetric counterpart of the scenario-coverage rule above. **Baseline NFR sweep:** also cross-check a baseline set (security headers / CSP / HSTS, CORS, rate-limiting — `security.md`; accessibility — `accessibility-checklist.md`); a baseline NFR absent from *both* spec and arch is **not** silently passed — route it back to `/spec` / `/arch` or record a blocking Open item. Do **not** invent a task (honor No-invented-scope above) — this sweep *exposes* a gap, it does not *fill* it.
- [ ] Each task has acceptance criteria
- [ ] Each task lists explicit **Tests to add** (file + name per AC)
- [ ] **Each scenario ID → its own test asserting that scenario's *Then* (no conflation); UI-observable scenarios have a UI/E2E-layer test, not an API test alone**
- [ ] **No invented scope** — every task traces to a spec scenario/NFR; any spec gap or ambiguity was routed back to `/spec` (or asked), not filled by guessing. Spec-readiness pre-check passed (every scenario has an ID + testable AC).
- [ ] Dependencies mapped between tasks
- [ ] Checkpoints inserted between phases
- [ ] `plans/plan.md` includes: Inputs consumed · Build-time testing scope · Summary table · Phases/Tasks · Risk register · Deferred/Waived scenarios (if any) · Out of scope
- [ ] `plans/todo.md` is actionable

### Orchestrator disk-check (run BEFORE presenting for Gate 3 review)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level (mechanical invariants only; slicing quality & ordering stay human judgment):

- [ ] **Scenario set reconciliation** — extract the full `@US-XXX-Snn` set from `specs/` and the union of every task's "Scenarios covered" + the Deferred/Waived table: the two sets must be **equal** (no missing, no unknown IDs). Count + diff yourself — don't trust the report's "100%". *(Brownfield per-change: the spec-side set = the scenarios of THIS change-set — the stories in its DELTA Revision History row — not the whole baseline spec.)*
- [ ] **Required sections** — `plans/plan.md` contains every section of the §required structure, in order.
- [ ] **Projection integrity** — every `todo.md` line and Summary-table row reuses a Task block's id + title verbatim; no orphan row, no task missing from the projections.
- [ ] **Tests declared** — no task has an empty "Tests to add"; every Risk-register mitigation names an existing AC/test (no `TBD`).
- [ ] **No template residue** — no `TODO` / unfilled placeholders in `plans/`.

Any mismatch → fix on disk first; never present a plan that fails its own gate mechanics.

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

Planning on legacy differs from greenfield in that it must **protect what is already running**, not just build new things:

- **Consume `/discover` artifacts, don't re-survey (Phase 1):** read `docs/CODEBASE_MAP.md` (endpoint inventory + red-flag list) + baseline `specs/SPEC.md` + `architecture/ARCHITECTURE.md` as the navigation index → go directly to the slice of code the change touches. Do **NOT** re-scan the whole tree (that was `/discover`'s job; `/plan` is per-change). **Fallback:** if `CODEBASE_MAP.md` is missing/incomplete → re-run `/discover` (or scan only the missing area), don't silently full-scan.
- **Characterization-test-first for the area being touched:** every task that touches legacy code without tests must include a sub-step "write a characterization test capturing current behavior (PASS) before modifying" — per `rules/brownfield.md`. Include it in the task's "Tests to add".
- **Backward compatibility is an acceptance criterion:** every task that modifies an existing feature (B2) adds an AC "old behavior/contract unchanged" + a corresponding backward-compat test.
- **Migration plan for B5 (upgrade):** use **strangler-fig** — split the task into: (1) build the new implementation behind an abstraction/seam, (2) route some traffic via feature flag, (3) measure + expand gradually, (4) remove the old version. No big-bang rewrite in a single task.
- **Vertical slice still applies**, but a "slice" may be "add a new path in parallel with the old one" instead of "build from scratch".
- **Risk register** prioritizes regression risk: any task that touches untested / shared / hot-path code → mitigation = a specific characterization test (test name in the plan).

> A brownfield plan does NOT propose architectural changes unless this is a B5 flow approved by `/arch` redesign (with an ADR). B1/B2 plans honor the existing architecture.

## Agent

Invoke: **Project Manager**

**Phase ownership** — the PM sub-agent cannot converse with the user: a spec gap or ambiguity that blocks decomposition → return early with the question (so the orchestrator routes it back to `/spec` / asks the user); a non-blocking gap → record it as a blocking Open item for the gate. The orchestrator runs the Gate 3 disk-check and presents the plan for review in the main loop.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After plan is approved, run `/secure` for pre-development security review, then `/build` to implement tasks.

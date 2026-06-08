---
name: spec
description: Spec before code — User Stories & Acceptance Criteria for new features
---

# /spec — Specification-Driven Development

> "Plan the work, then work the plan."

## Purpose

Create a comprehensive specification document **before** writing any code. This ensures alignment on requirements, constraints, and acceptance criteria.

## Role

**Business Analyst / Product Owner** — Responsible for defining WHAT to build and WHY, not HOW.

## Phase 0 — Mode Auto-Detection (chạy TRƯỚC Phase 1)

`/spec` tự resolve mode tại runtime thay vì tin tuyệt đối vào `Project Profile → Mode` (có thể stale). Hai tín hiệu:

- **ARGS** — `/spec` có kèm requirements đầu vào không? (`/spec <requirements>` vs bare `/spec`)
- **CODE** — repo có source code không? Probe: tồn tại bất kỳ `src/**/*.csproj`, `web/package.json`, hoặc build manifest khác ngoài `.claude/` (cùng cách `/discover` kiểm tra).

| ARGS | CODE | Resolved mode | Hành động |
|:----:|:----:|---------------|-----------|
| ✅ | ❌ | **greenfield** | Viết forward spec từ args (đi tiếp Phase 1). Nếu Profile ghi `brownfield` → coi là stale, surface + đề xuất sửa. |
| ❌ | ✅ | **brownfield** | Cần baseline. Chưa có `specs/SPEC.md` → **STOP**, yêu cầu chạy `/discover` rồi `/spec` lại. Có rồi → xuống §Brownfield Mode (REVERSE/DELTA). |
| ✅ | ✅ | **brownfield (DELTA)** | Args mô tả feature mới/đổi trên code có sẵn. Bắt buộc baseline `/discover` (`specs/SPEC.md`) trước; rồi chỉ spec phần delta. |
| ❌ | ❌ | **undecidable** | **STOP** — không có gì để spec. Hỏi user: cấp requirements (→ greenfield) hay đưa code vào (→ brownfield). |

**Reconcile:** sau khi resolve, so với `Project Profile → Mode`. Khớp → tiếp tục. Lệch → surface, đề xuất đổi `Mode:` về giá trị resolved (greenfield thì xoá kèm các Notes "current codebase" stale). KHÔNG tự đi tiếp khi đang lệch.

**Persist:** khi resolved mode khác Profile, offer cập nhật `Project Profile → Mode` để `/arch`, `/plan`, và việc kích hoạt `rules/brownfield.md` đồng bộ ở downstream.

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

**Project-mandatory NFRs (cross-check before closing discovery)**

Before generating the spec, consult these rule files so project-default NFRs are not silently omitted:

| Rule | NFR(s) to surface in the spec |
|------|------------------------------|
| `.claude/rules/security.md` | Rate limiting on auth endpoints, password policy, JWT lifetime, secrets storage |
| `.claude/rules/frontend.md` + `.claude/references/accessibility-checklist.md` | **Accessibility (WCAG 2.1 AA)** as an NFR for every user-facing screen |
| `.claude/rules/monitoring.md` | Structured logging, correlation IDs, log redaction of sensitive data |
| `.claude/rules/tech-stack.md` | Approved tech stack alignment statement |
| `.claude/rules/api-conventions.md` | `ProblemDetails` error contract, `PagedResult<T>` envelope |

Treat anything listed in these rules as **default-on NFRs** — the spec must either include them or explicitly justify an exception.

### Phase 2: Generate Specification

After discovery, produce `SPEC.md` using the **authoritative structure** defined in the Business Analyst agent.

> **Single source of truth:** `.claude/agents/business-analyst.md` § "Specification Document Structure" — follow that template verbatim.
>
> It includes (in this order): Executive Summary → Objective → Target Users → User Stories (with **Gherkin AC**, **Business Rules**, **UI/UX Notes**, **Dependencies** per story) → Non-Functional Requirements → Boundaries (Always/Ask/Never) → Out of Scope → Open Questions → Glossary → Appendix.

**Per-story format** must match BA agent § "User Story Format (BDD)":

```markdown
#### US-[ID]: [Title] — [Must/Should/Could]

**As a** [persona],
**I want to** [action],
**So that** [benefit].

##### Acceptance Criteria

```gherkin
@US-[ID]-S01
Scenario: [happy path]
  Given …
  When [the user performs the action as they perform it] …
  Then [observable outcome the user can see] …

@US-[ID]-S02
Scenario: [edge case / failure]
  Given …
  When …
  Then …
```

##### Business Rules
- [Validation, normalization, invariants]

##### Dependencies (optional)
- Requires: US-XXX
```

> Do **not** use single-line checkbox AC (`- [ ] Given… When… Then…`) — always use Gherkin code blocks with named Scenarios covering happy path + at least one edge/failure case.

**Scenario IDs (traceability seed).** Tag every scenario with a stable ID — `@US-[ID]-S01` (happy), `-S02…` (each edge/failure). These IDs are the **canonical acceptance checklist** that every downstream gate (`/plan`, `/build`, `/test`, `/review`, `/verify`) reconciles against: each ID maps to a task/test or carries an explicit **waiver (reason + owner)**. No scenario silently dropped.

**User-perspective scenarios (mandatory).** Every **user-facing action** MUST have ≥ 1 scenario written from the **user's observable perspective** — the action as the user performs it (*"When I click Delete on a bookmark"*) and the **observable outcome** (*"Then it disappears from my list"*) — NOT only the transport call (*"When I send `DELETE /…`"*). An API/transport-phrased scenario is allowed **in addition** (it documents the API contract) but, for a product with a UI, does **not** by itself satisfy the user-facing action. The outcome must be concrete enough that a black-box test can assert it **survives a round-trip** (reload / re-fetch), not merely "no error".
> *Self-adapting:* for an API-only / headless product the "user" is the API consumer, so the transport scenario **is** the user-perspective — no fake UI required.

### Phase 3: Review & Confirm

- Present the spec to the user (Product Owner / Stakeholder)
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
- Clear alignment on WHAT to build and WHY

## Quality Gate 1 — Definition of Ready (DoR)

Before moving to `/arch`, verify the **full DoR** maintained by the Business Analyst agent — see [`.claude/agents/business-analyst.md`](../agents/business-analyst.md) § "Definition of Ready (DoR)" for the authoritative checklist.

Summary (must all be ✓):

- [ ] All user stories follow "As a… I want… So that…" format
- [ ] All stories have Given/When/Then acceptance criteria (Gherkin, with happy path + ≥ 1 edge case)
- [ ] **Every user-facing action has a user-perspective (observable) scenario** — not only an API-transport scenario
- [ ] **Every scenario has a stable ID (`@US-XXX-Snn`) and a concrete, assertable observable outcome (*Then*)**
- [ ] Personas defined for all user types
- [ ] Priority assigned (Must / Should / Could / Won't)
- [ ] Non-Functional Requirements identified, including project-mandatory NFRs from `.claude/rules/*`
- [ ] Out of Scope explicitly documented
- [ ] **Open questions resolved or explicitly deferred** (no naked `- [ ]` items at Gate 1 — every question is either in `Resolved` with a decision + date, or in `Open` with a target command/owner)
- [ ] **No unconfirmed assumptions** — every gap is either asked & `Confirmed (date)`, or an `Open` item with owner; no unconfirmed guess embedded as a "default"
- [ ] Glossary includes all domain terms
- [ ] Stakeholder sign-off obtained — spec `Status` is `Approved`, not `Draft`

## Brownfield Mode (khi Phase 0 resolve = brownfield)

Chỉ vào mục này khi **Phase 0** đã resolve = brownfield **và** `specs/SPEC.md` tồn tại (nếu chưa có → Phase 0 đã STOP và yêu cầu `/discover`). Khi đó `/spec` chọn REVERSE vs DELTA theo sự hiện diện của `specs/SPEC.md`:

| Situation | Mode | Behavior |
|-----------|------|----------|
| `specs/SPEC.md` does not exist (after `/discover`) | **REVERSE** | Read `Controllers/`, `Services/`, validators, routes → extract **User Stories as-is** (describe what the system *is currently doing*, not what it should do). Assign stable US-IDs. This is baseline documentation. |
| `specs/SPEC.md` already exists | **DELTA** | Spec only **changes/new features**; reference existing stories (`Extend US-011…`), do NOT rewrite existing stories. Keep old IDs stable. |

**REVERSE — notes:**
- Describe **actual** behavior (even if it looks wrong/incomplete) — flag with `⚠️ suspicious behavior` instead of correcting it in the spec.
- Discovery `/spec` only **measures** (describes), does NOT verify against acceptance criteria (there are none yet) — per `rules/brownfield.md` §Measure-vs-Verify.
- Acceptance criteria are written based on observed behavior; used as a baseline for per-change characterization tests later.

**DELTA — notes:** do not break existing stories; if changes affect backward compatibility → state it clearly in the new story + flag for `/arch` conformance-gate.

## Agent

Invoke: **Business Analyst**

For UI-heavy features, also consult: **UI/UX Designer**

## Next Step

After spec is approved, run `/arch` to design the architecture.

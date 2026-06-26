---
name: spec
description: Spec before code — User Stories & Acceptance Criteria for new features
---

# /spec — Specification-Driven Development

> "Plan the work, then work the plan."

## Purpose

Create a comprehensive specification document **before** writing any code — defining **WHAT** to build and **WHY**, not HOW. This ensures alignment on requirements, constraints, and acceptance criteria.

## Usage

| Cách gọi | Kết quả |
|----------|---------|
| `/spec <requirements>` | Sinh `SPEC.md` + (nếu sản phẩm có UI) **ASCII wireframes**. **Đây là mặc định** — KHÔNG sinh prototype HTML. |
| `/spec <requirements> --prototype` | Như trên, **kèm** clickable HTML prototype. Cũng kích hoạt được bằng ngôn ngữ thường: thêm *"kèm prototype" / "có prototype"* vào yêu cầu. |
| `/spec` (không tham số) | Xem **Phase 0**: repo đã có code → brownfield (cần `/discover` trước); chưa có gì → hỏi user cấp requirements. |

> **Vì sao prototype mặc định OFF:** nó là artifact nặng nhất của `/spec`. ASCII wireframes (luôn sinh) đã đủ làm source of truth + đa số trường hợp đủ để sign-off. Prototype được sinh khi user yêu cầu, **hoặc** khi stakeholder/PO cần click-through mới yên tâm duyệt ở Gate 1. Chi tiết: Phase 2.5.

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
> It includes (in this order): Executive Summary → Objective → Target Users → User Stories (with **Gherkin AC**, **Business Rules**, **UI/UX Notes**, **Dependencies** per story) → Non-Functional Requirements → Boundaries (Always/Ask/Never) → Out of Scope → Open Questions → Glossary → Appendix.

**Per-story format** — follow the BA agent § "User Story Format (BDD)" template **verbatim** (`#### US-[ID]` → As-a / I-want / So-that → Gherkin AC → Business Rules → UI/UX Notes → Dependencies); that copy is canonical, do not restate it here. The spec-specific rules below augment it:

> Do **not** use single-line checkbox AC (`- [ ] Given… When… Then…`) — always use Gherkin code blocks with named Scenarios covering happy path + at least one edge/failure case.

**Scenario IDs (traceability seed).** Tag every scenario with a stable ID — `@US-[ID]-S01` (happy), `-S02…` (each edge/failure). These IDs are the **canonical acceptance checklist** every downstream gate reconciles against — full rule: [`references/scenario-traceability.md`](../references/scenario-traceability.md).

**User-perspective scenarios (mandatory).** Every **user-facing action** MUST have ≥ 1 scenario written from the **user's observable perspective** — the action as the user performs it (*"When I click Delete on an order"*) and the **observable outcome** (*"Then it disappears from my list"*) — NOT only the transport call (*"When I send `DELETE /…`"*). An API/transport-phrased scenario is allowed **in addition** (it documents the API contract) but, for a product with a UI, does **not** by itself satisfy the user-facing action. The *Then* must be a concrete, assertable observable outcome — per the "effect, not presence / survives a round-trip" rule in [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3.
> *Self-adapting:* for an API-only / headless product the "user" is the API consumer, so the transport scenario **is** the user-perspective — no fake UI required.

### Phase 2.5: Wireframe & Visual Prototype (UI products)

> Skip for headless / API-only products (the API contract is the interface). For **any** product with a UI — UI-light or UI-heavy — the **UI/UX Designer** produces the wireframes; the HTML prototype is an **opt-in** add-on:

1. **ASCII / Mermaid wireframes** (`specs/wireframes/`) — **ALWAYS produced.** The versioned, diff-able **source of truth**: one file per screen with layout + states (empty / loading / error / no-result) + a11y notes + a **control → `@US-[ID]-Snn` mapping table**, plus a Mermaid sitemap and key user flows. This is what `/arch`, `/build`, and `/verify` cite for traceability.
   > **Chỉ page-level state** (default / empty / loading / error / no-result) cho mỗi screen. Ma trận state per-component (hover / focus / active / disabled…) là design-system territory của `/arch` — **KHÔNG** sinh ở `/spec` (fidelity = intent-level).
2. **A clickable HTML prototype** (`specs/wireframes/prototype/index.html`) — **OPT-IN, default OFF** (it is the heaviest artifact of `/spec`). Generate it **only when the user requests it** (e.g. `/spec … --prototype`, or "kèm prototype" in the request) **or when the stakeholder/PO cannot confidently sign off from the ASCII wireframes alone** and needs to click through the flow. It is a self-contained, **intent-level** sign-off aid (no real backend): disposable after approval (or snapshot per release); NOT pixel-perfect and NOT the design system (tokens / component contracts belong to `/arch`).

**Fidelity stays intent-level** — this phase validates *what the user sees and how the flow works*, not pixels/tokens. **The Gate 1 quality bar is: ASCII wireframes + stakeholder/PO visual sign-off** (both mandatory); the HTML prototype is an optional aid to reaching that sign-off, not a gate item in itself. **Fill-only boilerplate:** copy [`.claude/templates/wireframes/`](../templates/wireframes/) into `specs/wireframes/`. Convention: [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md); ASCII rules: [`.claude/references/ascii-diagram-guide.md`](../references/ascii-diagram-guide.md).

### Phase 3: Review & Confirm

- Present the spec to the user (Product Owner / Stakeholder)
- **(UI products) Tell the user the HTML prototype was not generated (opt-in, default OFF) and how to get it** — e.g. *"Đã có ASCII wireframes. Prototype HTML không sinh mặc định; nếu bạn/stakeholder muốn click-through để duyệt, nói 'tạo prototype' (hoặc chạy `/spec … --prototype`)."* This is how the user discovers the option at point-of-use.
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
- [ ] **(UI products) Wireframes + states in `specs/wireframes/` (mapped to `@US-XXX-Snn`), and visual UI signed off by stakeholder + PO** (date + name) — blocking before `/arch`

> All other DoR items (story format, personas, priority, NFRs, Out-of-Scope, Glossary) → the authoritative checklist in the BA agent.

## Brownfield Mode (khi Phase 0 resolve = brownfield)

Chỉ vào mục này khi **Phase 0** đã resolve = brownfield **và** `specs/SPEC.md` tồn tại (nếu chưa có → Phase 0 đã STOP và yêu cầu `/discover`). Khi đó `/spec` chọn REVERSE vs DELTA theo sự hiện diện của `specs/SPEC.md`:

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

**DELTA — notes:** do not break existing stories; if changes affect backward compatibility → state it clearly in the new story + flag for `/arch` conformance-gate.

## Agent

Invoke: **Business Analyst**

For **any product with a UI** (UI-light or UI-heavy), the **UI/UX Designer** produces the Phase 2.5 ASCII/Mermaid wireframes (always) plus the clickable HTML prototype (opt-in, default OFF) — see [`.claude/agents/ui-ux-designer.md`](../agents/ui-ux-designer.md) for the `specs/wireframes/` convention and fidelity rules.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

After spec is approved, run `/arch` to design the architecture.

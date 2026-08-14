---
name: discover-system
description: Multi-repo onboarding — aggregate per-repo discovery into a system-wide map (service catalog, call-graph, cross-service journeys)
---

# /discover-system — System-Level Map (Multi-Repo)

> "Understand the whole product before changing one service."

## Purpose

For a microservices product spread across **many repos**, build a **system-wide map** by aggregating the per-repo discovery artifacts. This is the system-scope counterpart of `/discover` (which is repo-scope). **Read-only · run once + incremental.**

> **Workspace Mode:** this is the ONE command that runs AT the workspace root itself — do not scope it to a member repo.

> **One-way by design.** `/discover-system` reads per-repo output → produces `architecture/system/` as **documentation to understand the system**. Individual services keep developing + testing **independently**; they do NOT take a runtime dependency on the system layer. Cross-service safety = backward-compat discipline (`rules/brownfield.md`). Full convention: [`../references/microservices-multirepo.md`](../references/microservices-multirepo.md).

## When to Use

- Onboarding an existing multi-repo microservices product (one-time), or refreshing the map after services were added/changed.
- NOT for a single-repo project — use `/discover`.

## Prerequisites

- A **workspace**: all service repos checked out under one parent folder (clone them side by side if they live in separate repos — Pattern B in the reference).
- **Per-repo Phase A done for each service** — every repo has:
  - `docs/CODEBASE_MAP.md` (from `/discover`)
  - `specs/SPEC.md` with `@US` ids (from reverse-`/spec`)
  - `architecture/ARCHITECTURE.md` + `architecture/api/openapi.yaml` + **§Service Contracts** (from reverse-`/arch` — see [`arch.md`](arch.md) §3.2)
  - a `Service id` declared in its `Project Profile`.

> A repo missing any of the above → list it in the catalog as `⚠️ incomplete`; do NOT fabricate its boundary/contracts.

## Boundary — READ-ONLY

`/discover-system` reads per-repo artifacts and writes only `architecture/system/`. It does NOT modify any service repo's source, spec, or architecture. It reads **compact artifacts** (CODEBASE_MAP rows, §Service Contracts tables, openapi, SPEC `@US`), NOT full service code.

---

## Workflow

### Phase 0 — Change detection (incremental re-sync; bash-first, near-zero tokens)

A prior map exists (`architecture/system/` + `specs/system/`) → detect what actually changed BEFORE reading anything at LLM cost. **One shell pass over all repos** (`head`/`grep` per repo in a single batch): compare each repo's current `SPEC.md` header `Version` (+ a content hash of its `ARCHITECTURE.md §Service Contracts` block) against the views' per-service `last-synced` → classify every repo **`CHANGED` / `UNCHANGED`**.

**Full regenerate is MANDATORY when** — no prior map exists (first run) · the `Repos:` registry changed (repo added/removed/renamed) · the user asked for `--full` · any view file is missing its GENERATED banner or `last-synced` (integrity suspect). Otherwise → **incremental mode**.

**Incremental scoping rule (governs Phases 1–3b):** re-read ONLY the `CHANGED` repos' artifacts. Rows/entries of `UNCHANGED` repos are **carried forward verbatim from the existing views** — projection semantics make this correct (source unchanged ⇒ projection unchanged, provable via `last-synced`). Cross-repo joins (call-graph edges, `⚠️ term conflict` / `⚠️ goal overlap` / `⚠️ NFR inconsistency`) are **recomputed over the merged data** — the views already hold the UNCHANGED repos' terms/goals/thresholds/contracts, so no re-read is needed for the join. The drift summary MUST state: `re-synced: N repos (vX→vY each) · carried forward: M repos`.

### Phase 1 — Aggregate (service catalog)

Read the repo list from the workspace Profile's `Repos:` registry (canonical — Workspace Mode); no registry (Patterns A/B) → enumerate workspace subfolders as before. **Cross-check registry vs actual folders**: a git subfolder missing from the registry → flag `⚠️ unregistered repo` (never silently skip); a registry row without a folder → flag it too. For each repo, read its `Service id`, `CODEBASE_MAP`, `openapi`, `ARCHITECTURE` → one row in `service-catalog.md`: `id · repo · responsibility · stack · owner · last-synced`. Mark missing-artifact repos `⚠️ incomplete`. The `owner` column is **user-supplied** (ask once at the first aggregation, carry it forward on later runs) — no per-repo artifact contains it, so **never infer it** (not from git history, not from folder names); unknown → `—`.

### Phase 2 — Synthesize (call-graph + diagrams + journeys)

1. From each service's **§Service Contracts**, collect `Exposes` and `Consumes` rows.
2. **Match** every `Consumes.contract-id` to the `Exposes.contract-id` of another service → one **edge** (`consumer → provider`) in the call-graph. `contract-id` is the join key.
   - Unmatched consume, no plausible provider → `⚠️ dangling consumer` (missing dependency — a provider service may be absent / not yet onboarded).
   - Unmatched consume that **near-matches** an `Exposes.contract-id` (differs only by a typo / version suffix — e.g. `order.craete` vs `order.create`, `payment.charge` vs `payment.charge.v2`) → `⚠️ contract-id near-miss (typo / version drift)` — flag it and **recommend which side to fix** (route the fix to that repo's own `/arch` conformance/DELTA — this command is read-only on service repos and never edits their contracts); do NOT add a service. (`contract-id` must match **exactly** — see `arch.md §3.2`.)
   - Unmatched expose → note `no first-party consumer` (may be an external client).
   - **Write the collected rows into `contracts/event-catalog.md`** — §Events (contract-id · topic/schema · producer · consumers) + §REST cross-service (contract-id · method/path · provider · consumers), per the fill-only template: this is the cross-service contract index every call-graph edge cites. Dangling/near-miss rows carry their ⚠️ flag into the catalog too — the catalog states what IS, including what is broken.
3. Draw `system-context.md` (C4 L1) + `container.md` (C4 L2 — services + edges + shared infra: gateway, message bus, shared stores).
4. Reconstruct **cross-service journeys** (`journeys/*.md`) by following edges for the main flows; tag each with a system scenario id `@SYS-US-NNN`.
   - **Flag REST-derived vs event-derived.** Event (pub/sub) journeys are **inferred** — mark `inferred: true` and require human review (async coupling cannot be proven from contracts alone).

### Phase 3 — Map (cross-repo traceability)

Build `traceability.md`: each `@SYS-US-NNN` → the set of `{service: @US}` that participate (from each service's SPEC). Flag:
- a `@SYS-US` with a participating service but no mapped `@US` → `⚠️ orphan step`.
- a service `@US` that no `@SYS-US` covers → fine (service-local feature); list it under "service-local".

**Phase 3b — Requirements views (`specs/system/`).** The same per-repo SPEC pass also builds four PROJECTION files (**reference-first**: IDs + titles + class tags + spec version/status + links back to each repo's SPEC anchor; full quoted text ONLY inside ⚠️ conflict excerpts, where side-by-side comparison IS the value):

1. `requirements-map.md` — per `@SYS-US`: the journey's steps → `{service: @US, title, class tags, spec version/status}` + links (the deep view over `traceability.md`, which keeps the bare id map).
2. `goals-catalog.md` — every service's `G-xx` rows side by side, labeled by source; overlapping/contradicting goals → `⚠️ goal overlap`.
3. `glossary-system.md` — merged + deduped; the same term defined differently in ≥ 2 repos → `⚠️ term conflict` (quote both definitions — the one place full text is allowed).
4. `nfr-catalog.md` — every service's `NFR-xx` rows side by side, **labeled by source** (ids collide across repos — same discipline as `G-xx` above); a caller promising a tighter budget than its provider (e.g. A p95 200ms calling B p95 500ms) → `⚠️ NFR inconsistency`.

Every file opens with a generated banner (`> GENERATED by /discover-system — do not edit; re-run to refresh`) + per-service `last-synced` (the SPEC version read). These are **VIEWS, not a third source of truth**: regenerate-only, the per-repo SPEC always wins, no separate sign-off.

### Phase 4 — Output + drift check

Write `architecture/system/` (structure below). If a prior map exists, **conformance-check**: compare each service's current contracts vs the map → list drift (`new / changed / removed contract`) with `last-synced` per service — and each service's current SPEC version vs the views' `last-synced` → **requirements drift listed alongside contract drift** (in incremental mode this IS the Phase-0 classification, carried through to the report). Do NOT silently overwrite — surface what changed.

```text
architecture/system/            # commit to the platform repo (shared documentation)
├── service-catalog.md
├── system-context.md
├── container.md
├── journeys/
│   └── <flow>.md               # @SYS-US + inferred flag
├── contracts/
│   └── event-catalog.md
└── traceability.md

specs/system/                   # PROJECTION — generated requirements views (Phase 3b)
├── requirements-map.md
├── goals-catalog.md
├── glossary-system.md
└── nfr-catalog.md
```

> **Boilerplate (fill-only):** copy [`../templates/system/`](../templates/system/) and fill the `[ … ]` placeholders — do not re-author the structure.

---

## Quality Gate — System Map

Run the §Orchestrator disk-check (below) first, then review.

- [ ] `service-catalog.md` lists **every** workspace repo (or marks it `⚠️ incomplete`)
- [ ] Registry cross-checked against the workspace directory listing — unregistered repos / dangling registry rows flagged
- [ ] Each repo's `Service id` is **unique** across the workspace and **matches** between its Project Profile and its §Service Contracts; collisions / mismatches flagged `⚠️ service-id collision/mismatch` (a wrong canonical key merges catalog rows / mis-targets call-graph edges)
- [ ] Every call-graph edge has **both** ends (consumer + provider matched by `contract-id`); dangling consumers flagged — and `contract-id` **near-misses** (typo / version drift) flagged **separately** from true missing-dependency dangling
- [ ] `contracts/event-catalog.md` present, and its rows cover **every** matched edge + every flagged dangling/near-miss (the union of Phase-2 step-2 output — no contract row silently dropped between the call-graph and the catalog)
- [ ] Every cross-service journey tagged `@SYS-US`; event-derived journeys marked `inferred` and human-reviewed
- [ ] `traceability.md` maps every `@SYS-US` → participating `{service:@US}`; orphan steps flagged
- [ ] Drift vs previous map surfaced (not silently overwritten)
- [ ] `specs/system/` views present (4 files) when participating repos have SPECs; each opens with the GENERATED banner + per-service `last-synced`
- [ ] Conflict checks ran — `⚠️ term conflict` / `⚠️ goal overlap` / `⚠️ NFR inconsistency` sections exist (findings listed, or explicitly "none")
- [ ] Reference-first holds — no full Gherkin block in the views outside ⚠️ conflict excerpts (grep the ``` fences)
- [ ] Staleness recomputed — every view's `last-synced` == the SPEC version read this run; services whose SPEC moved since the prior map → in the drift summary
- [ ] (incremental run) **Change detection recorded** — the `CHANGED` list with old→new versions + the carried-forward list; the full-regenerate triggers (first run · registry change · `--full` · integrity suspect) were honored, not skipped for convenience
- [ ] Output committed to the platform repo (documentation, one-way — no per-repo runtime dependency)

### Orchestrator disk-check (run BEFORE presenting the system map)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level:

- [ ] **Catalog completeness** — diff the workspace directory listing against `service-catalog.md` rows: every repo present (or `⚠️ incomplete`), no fabricated row without a repo.
- [ ] **Read-only across repos, verified** — `git status` in EVERY service repo is clean; only the platform repo gains `architecture/system/` + `specs/system/`.
- [ ] **Service-id uniqueness** — collect each repo's `Project Profile → Service id` and dedupe yourself (a collision merges catalog rows).
- [ ] **Edge integrity** — every `Consumes` row across all §Service Contracts appears as a matched edge OR is flagged (`dangling` / `near-miss`) — none silently dropped.
- [ ] **Inferred flags present** — every event-derived journey carries `inferred: true`.
- [ ] **(incremental) Carry-forward verified** — for every `UNCHANGED` repo, grep its current SPEC `Version` yourself and confirm it equals the view's `last-synced` (do NOT trust the Phase-0 report); any mismatch → escalate that repo to re-read, or the whole run to full regenerate.
- [ ] **No template residue** — no `[ … ]` placeholders left in `architecture/system/` or `specs/system/`.

Any mismatch → fix on disk first.

## Agent

Invoke: **Systems Architect** (leads system-scope discovery, as it leads per-repo `/discover` + `/arch`).

**Phase ownership** — the Systems Architect sub-agent cannot converse with the user: the **human review** of event-derived (`inferred`) journeys, and the **which-side-fixes-it** decision on a contract-id near-miss (it touches another team's contract) → **return early** with the flagged list instead of deciding alone. The orchestrator obtains the review/decision, runs the disk-check, and presents the system map in the main loop.

```text
"As Systems Architect, run /discover-system across the workspace: aggregate each repo's
CODEBASE_MAP + SPEC + ARCHITECTURE §Service Contracts into architecture/system/.
Mode: <full | incremental — CHANGED: [repo vX→vY, …] · carried forward: [repos]> — the Phase-0 classification computed by the orchestrator; scope your reads to CHANGED repos only. Owner column values: <user-supplied rows, or —> (never infer).
Read-only; flag incomplete repos and inferred (event-derived) journeys.
Output language: <Output Language from Project Profile> for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

- Commit `architecture/system/` to the platform repo (shared documentation).
- Continue per-service work via the normal per-repo pipeline (Phase B); keep services **independent**. Refresh this map incrementally when services/contracts change.

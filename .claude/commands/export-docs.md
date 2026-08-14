---
name: export-docs
description: Compile kit artifacts into company-standard documents (PRD/SDD…) via fill-only templates + a mapping manifest
---

# /export-docs — Company-Standard Document Export

> "The artifacts are the source of truth; the company doc is a rendering."

## Purpose

Render the kit's SDLC artifacts (`specs/`, `architecture/`, `security/`, `reports/`, `docs/`…) into **company-standard documents** (e.g. a corporate PRD/SDD template) without duplicating authorship. The export is **fill-only**: every filled section traces to a kit artifact; anything the artifacts cannot answer becomes an explicit `N/A — <reason>` or a `[NEEDS <role/command>]` handoff marker — never invented content.

**Content changes never happen here.** A gap discovered during export (missing goals, missing threat model…) routes back to `/spec` / `/arch` / `/secure` as a new change-set, then re-export. Gate 1/2 stay the only places where requirements/design change; this command only re-renders.

## Usage

| How to invoke | Result |
|---------------|--------|
| `/export-docs prd` | Compile the `PRD` target per the manifest → `exports/PRD.md` + `exports/TRACE_MAP.md` |
| `/export-docs sdd` | Compile the `SDD` target → `exports/SDD.md` (+ `TRACE_MAP` refresh) |
| `/export-docs prd --draft` | Export although `specs/SPEC.md` is still `Draft` — line 1 of the output carries a `**DRAFT — not yet Gate-1 signed-off**` watermark (phrased per the artifact's Output Language) |
| Re-run any target | **Refresh**: regenerate + print a per-section diff summary vs the previous export; every previously issued ID stays stable (§ID stability) |

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate. A target declaring **`Scope: system`** instead runs at the **workspace ROOT**: sources = `specs/system/` + `architecture/system/` (+ per-repo artifacts via the registry when a row cites them); output = the root `exports/`; the workspace disk-check exception covers it.

## Configuration — where templates live

| File | Layer | Role |
|------|-------|------|
| `.claude/local/doc-templates/mapping.md` | EXTENSION (user-owned) | The **mapping manifest**: per target — template path, output path, agent, required inputs, placeholder patterns, and the section → source rows |
| `.claude/local/doc-templates/<TEMPLATE>.md` | EXTENSION (user-owned) | The company template(s) in markdown form (fill target) |
| `.claude/templates/export-docs/MAPPING_MANIFEST.md` | CORE | Manifest schema + a compact example to copy from |

Company templates are **company assets** → they live in `.claude/local/` (the EXTENSION layer — never shipped with, or touched by, a kit upgrade; keep them out of any public remote). The kit ships only this engine + the manifest schema. Targets are not limited to PRD/SDD — any document the manifest declares works the same way.

**Reuse across projects:** one company = one `doc-templates/` pack. Copy the whole `.claude/local/doc-templates/` folder (templates + manifest) into each project's repo — or keep it in an internal template repo and copy from there — so every project renders the same company documents identically; project-specific tweaks go into that project's copy of `mapping.md`, not into the shared templates.

---

## Workflow

### Phase 0 — Preconditions (orchestrator; STOP style)

1. Read the Project Profile (Mode, Output Language). Read `.claude/local/doc-templates/mapping.md`. Manifest missing, or a referenced template file missing → **STOP**: point the user to `.claude/templates/export-docs/MAPPING_MANIFEST.md` and ask them to set up `.claude/local/doc-templates/` first.
2. Target = the argument (`prd` | `sdd` | any target the manifest declares). Unknown target → **STOP**, list the declared targets.
3. **Required inputs** (the manifest's `Required inputs:` line) must all exist:
   - PRD default: `specs/SPEC.md` with header `Status: Approved`. Still `Draft` → **STOP** unless `--draft` (then apply the watermark). Rationale: an unapproved spec rendered into a company form reads as an approved requirement — the watermark keeps the distinction visible.
   - SDD default: `architecture/ARCHITECTURE.md` (Gate 2 baseline).
   - Missing required input → **STOP + name the exact command(s) to run first** (e.g. "run `/spec` → Gate 1 sign-off, then re-run `/export-docs prd`").
4. **Enrichment inputs** missing (`security/THREAT_MODEL.md`, `reports/TEST_REPORT.md`, `reports/VERIFY_REPORT.md`, `DEPLOY_RUNBOOK`, `docker/`…) → do **NOT** stop; the mapped sections receive their manifest-declared `On missing` treatment (`[NEEDS /secure]`, `N/A — …`).
5. **(`Scope: system` targets) The system layer must be FRESH** — run the `/discover-system` conformance pass first; contract or requirements drift ≠ clean → **STOP** (re-sync, or the user explicitly acknowledges exporting from a stale map — recorded in the export-provenance comment). Rendering a company document from a stale view is a wrong document with a stamp on it.

### Phase 1 — Collect (orchestrator)

- Read the manifest rows for the target; read each cited source **targeted** (the named file/section) — never a whole-tree sweep.
- Load the previous `exports/TRACE_MAP.md` (if any): the **stability memory** for scenario-ID and FR-number assignments.
- **Pre-compute deterministic tables** — the scenario-ID transform table and the FR catalogue (numbering + status) per §Transform rules. The orchestrator computes these (not the sub-agent) so the gate can independently re-derive and compare.

### Phase 2 — Fill (sub-agent)

Spawn the manifest-declared agent (PRD → **Business Analyst** · SDD → **Systems Architect**) with: the template, the manifest rows, the collected source excerpts, and the pre-computed ID/FR tables.

Fill-only discipline (hard rules):

- **Template structure is inviolable** — no section added, removed, renamed, or reordered. Repeat-block markers in the template (`repeat:per-AC`, `repeat:per-FR`…) are instantiated once per item, structure unchanged.
- **No invented content** — every claim traces to a provided source. No source → the row's `On missing` treatment: `N/A — <one-line reason>` or `[NEEDS <role/command>]`.
- **Source comments** — every filled section starts with `<!-- source: <artifact path> §<section> -->` (invisible after docx conversion; makes every fill auditable).
- **Sign-off cells are never filled** — approval names/dates/checkmarks belong to humans; emit `[NEEDS <role>]`. Self-filling a sign-off is fabricated approval.
- **Strip the template's own authoring-meta comment** — a company template's leading HTML comment (documenting *its own* authoring conventions: docx deviations, placeholder syntax, `repeat:per-*` engine markers) is instructions for whoever maintains the template file, not content for the rendered document. Replace it with an export-provenance comment instead: source artifact(s) + version + approval date/approver, a pointer to `TRACE_MAP.md`, and "do not hand-edit — re-export after editing the source artifact." Carrying the authoring comment through verbatim is residue, even though it happens to be invisible (HTML comment) — a reader who opens the raw file sees template-maintenance notes that don't belong in a delivered document.
- **Audience register** — each target declares `Audience: stakeholder | engineer` in the manifest. For a **stakeholder** target (e.g. PRD): translate technical identifiers in rendered prose into their business meaning (an API path → the business action, a DB column → the business concept, a class/method name → never carried at all) — the technical form stays auditable via the source artifact + `TRACE_MAP.md`. For an **engineer** target (e.g. SDD): keep technical detail verbatim. Numbers/thresholds are not identifiers — they render in both.
- **Labeled proposals render as-is** — content the source marks `📝P-nn` (inferred, pending confirmation — see `/spec` §Goals proposal) IS renderable content: carry it through **with its label** (phrased per the audience register), never strip the label or promote a proposal to fact. Confirmation happens in the source flow (`/spec` Amended row), never at export.
- **Language:** boilerplate keeps the template's language; filled prose follows `Project Profile → Output Language`; if the two differ, **the template's language wins** (it is the receiving organization's form).

### Phase 3 — Gate (orchestrator disk-check; blocking)

Run §Quality Gate below yourself on disk, then present: the output path(s), the `[NEEDS …]` marker list (each = a human handoff), the **`📝P-nn` proposal list** (inferred content awaiting PO confirmation — count must match the source), the `N/A` list, and — on refresh — the per-section diff summary. The user carries the file into the company's own approval flow; **the kit gate is not the company's signature**.

---

## Transform rules (canonical)

### Transform enum

| Transform | Meaning |
|-----------|---------|
| `verbatim` | Copy content, change only the framing |
| `restructure` | Same data, different table/column shape |
| `derive` | Computed from ≥ 2 sources (FR catalogue, FMA table, link census…) |
| `convert-diagram` | ASCII/Mermaid-source → Mermaid target — node & edge sets preserved **1:1**, no invented components |
| `id-transform` | Apply §Scenario-ID transform |
| `static` | Fixed content declared in the manifest itself (DoD gate mapping, RACI) |

### Scenario-ID transform — 1:1, stable

Company convention `AC-{US}.{Scenario}.{Case}` ← kit convention `@US-XXX-Snn`:

```
AC-{us}.{n}.01   where {us} = story number (pad 2), {n} = scenario number Snn (no pad), {Case} fixed "01"

@US-001-S03 @negative  →  AC-01.3.01 ❌
@US-012-S01 @happy     →  AC-12.1.01 ✅
```

- Class tag → label: `@happy` → ✅ · `@negative` → ❌ · `@edge` → ⚠️.
- Reverse mapping is trivial: compare numerically, ignore padding.
- **Why 1:1 instead of grouping scenarios under each happy path:** grouping looks closer to the company example but is **unstable** — a DELTA inserting one new happy scenario shifts every later group number, changing already-published company AC IDs between exports. 1:1 is append-only forever (same philosophy as `references/scenario-traceability.md`). Single-case scenario groups are valid under the company convention (its own example contains one).

### FR numbering + status (PRD Feature Catalogue)

- **FR = Epic** in `SPEC.md`. Numbers are assigned in order of **first appearance** and recorded in `TRACE_MAP` §2 — a refresh **never renumbers**; a new epic appends the next FR.
- **Status is derived from Revision History** relative to the `last-exported spec version` stored in `TRACE_MAP`: an FR whose stories appear in newer `Added` rows → 🆕; in newer `Changed`/`Amended` rows → 🔄; no newer row → ✅. On the **first export** the `Baseline` row counts as `Added` (a first release is all-new → every FR is 🆕). Deterministic — no judgment call.

### Diagram conversion fidelity

Converting ASCII → Mermaid (`flowchart` for C4 L1/L2, `sequenceDiagram` for flows, `stateDiagram-v2` for state machines, `erDiagram` for data models): the node set and edge set of the output MUST match the source **1:1** — every Mermaid node/participant name must appear in the source diagram text, and no source node may be dropped. The gate greps this.

### C4 section granularity (templates with Context → Container → Component sections)

When the target template mirrors the C4 ladder, map kit sources **one level per section**: `diagrams/system-context` → the Context section (L1) · `diagrams/container` → the Container section (L2) · `diagrams/component` → the **Component section (L3 — code building blocks: controllers, services, repositories, adapters, external-service clients)**. NEVER fill a Component section with container-level rows (API process, DB, cache, queue) — that duplicates the Container section; corporate templates' own example rows often make exactly this mistake, so follow the ladder, not the example. No component diagram exists in `architecture/diagrams/` → the Component section takes the manifest's On-missing treatment (`[NEEDS /arch]`…), never a granularity downgrade.

### API sample derivation (templates with request/response sample slots)

When a template's per-endpoint block carries sample slots (`Request:` / `Response (201):`…), derive the samples from `architecture/api/openapi.yaml` — never free-hand:

- **Keys** — every key in a sample MUST be a property of the endpoint's request/response schema; all schema-`required` keys present; no key the schema does not declare.
- **Values** — a property with `example` in the schema → carry it **verbatim**. Otherwise construct a syntactically valid placeholder from the schema's `format` / `enum` / constraints (`format: email` → an email-shaped value, `format: uuid` → a UUID-shaped value, `enum` → its first value; respect min/max bounds and any documented policy — e.g. a password sample must satisfy the declared password rules). Constructed values → one note at the top of the section: "sample values are illustrative, derived from the schema" (phrased per Output Language).
- **Request envelope** (request line + headers) — only what the contract declares: the resolved path (`servers` base + path + declared query parameters) and the endpoint's security scheme (`Authorization: Bearer <jwt>` when auth is required). NEVER add a header the API does not declare — e.g. no `Idempotency-Key` when the contract has none, even if the company template's own example shows one.
- **No body** — a `204`/bodyless response renders an explicit "(no body)" note, never an invented payload; a bodyless request sample is just its request line + declared headers.

### System-scope ID qualification

A system-level document aggregates repos whose local IDs collide (`US-001`, `AC-01.1.01` exist in every repo). Every per-repo ID carried into a `Scope: system` render is **qualified by `Service id`**: kit side `payment:US-012`, company side `AC-{svc}.{us}.{n}` (e.g. `AC-payment.12.1`). `@SYS-US-NNN` ids are already system-unique — carried as-is. The root `exports/TRACE_MAP.md` is **separate** from the per-repo TRACE_MAPs and append-only in the same way.

### TRACE_MAP format (`exports/TRACE_MAP.md`)

```markdown
## §1 Scenario map
| Kit ID | Company AC ID | Class | Story |
|--------|---------------|-------|-------|
| @US-001-S01 | AC-01.1.01 | ✅ | Tạo snippet |

## §2 FR map
| FR | Epic | US | Status | First exported (spec version) |
|----|------|----|--------|-------------------------------|
| FR01 | Vòng đời snippet | US-001…US-004 | 🆕 | v1.0 |

## §3 Export log
| Date | Target | Spec/Arch version | Output |
```

Both tables are **append/update-only**: an existing Kit ID ↔ AC ID pair and an existing FR number are immutable.

---

## Output

- `exports/<TARGET>.md` — the rendered company document (md is the source of truth).
- `exports/TRACE_MAP.md` — bidirectional ID map + FR registry + export log.
- Need `.docx` for submission? Convert outside the kit: `pandoc exports/PRD.md -o exports/PRD.docx` — do not hand-edit the docx; edit artifacts → re-export.

## Quality Gate — Export

Blocking checklist (run per export):

- [ ] **Heading census** — the output contains every heading of the template, same order (diff the heading lists)
- [ ] **Zero placeholder residue** — no template placeholder pattern (declared per target in the manifest) survives, except valid `[NEEDS <role/command>]` markers — count + list each one
- [ ] **Internal cross-refs resolve** — every "mục N / §N / Section N" mention points to an existing heading
- [ ] **TRACE_MAP bidirectional & complete** — every in-scope `@US-XXX-Snn` has exactly one `AC-x.y.z` and vice versa; story/scenario counts in the export == counts in `SPEC.md` (no silent drop)
- [ ] **ID stability** — every pair and FR number present in the previous `TRACE_MAP` is unchanged (additions only)
- [ ] **(sources carrying `📝P-nn`) Label fidelity** — every `📝P-nn` in the in-scope source appears in the export **with its label** (grep both sides: count + ids match 1:1); a stripped label or a proposal promoted to confirmed fact = gate FAIL — an unconfirmed inferred goal rendered as approved content is precisely the fabrication class this command exists to block
- [ ] **(Diagram-carrying targets) Diagram fidelity** — every Mermaid node/edge name in the export exists in the source diagram; no source node dropped. Applies to ANY target whose sections render diagrams (SDD §1–§4, PRD §5.1/§7.1/§8.x.2, …) — a source that is already Mermaid is carried 1:1, never redrawn
- [ ] **(API-carrying targets) Sample fidelity** — every JSON key in a rendered request/response sample exists as a schema property in `architecture/api/openapi.yaml`; every schema-`required` key is present; request envelopes carry no undeclared header (§API sample derivation)
- [ ] **(--draft) Watermark present** on line 1

### Orchestrator disk-check (run BEFORE presenting)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation:

- [ ] Re-run the mechanical checks above yourself (grep + count on disk — heading census, residue patterns, cross-refs, ID counts)
- [ ] Re-derive the ID transform + FR table independently and compare with what the sub-agent embedded — any mismatch → trust your derivation, fix on disk
- [ ] `git status`: nothing created/modified outside `exports/` (sources are read-only to this command)
- [ ] (workspace) the workspace disk-check applies — outputs live in the **target repo's** `exports/`, or the **workspace root** `exports/` for `Scope: system` targets

Any mismatch → fix on disk first; never hand the user an export that fails its own gate.

## Non-goals

- Does NOT generate `.docx` directly (md is canonical; pandoc note above).
- Does NOT modify source artifacts — gaps route back to `/spec` / `/arch` / `/secure`.
- Does NOT replace the company's approval flow — every sign-off cell stays `[NEEDS <role>]`.

## Agent

Per manifest: PRD → **Business Analyst** · SDD → **Systems Architect** (the owners of the source artifacts' semantics; compilation stays in-domain — no dedicated exporter agent).

**Phase ownership** — the sub-agent cannot converse with the user:

| Phase | Runs in | Why |
|-------|---------|-----|
| 0 (preconditions) · 1 (collect + pre-compute) · 3 (gate + present) | **Orchestrator (main loop)** | STOP decisions, deterministic tables, disk-checks, user review |
| 2 (fill the template) | **BA / SA sub-agent** | Pure fill-only rendering with all inputs provided; a gap the inputs cannot resolve → return early with the item (it becomes `N/A`/`[NEEDS …]` or routes back to `/spec`/`/arch`) |

> Sub-agent prompt MUST include: "Output language: \<declared language — resolve from Project Profile → Output Language\> for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language). Exception: the company template's own boilerplate language wins for this export."

## Next Step

- PRD approved by the company flow → keep developing; re-run `/export-docs prd` after every approved spec change-set.
- SDD is a **living document**: re-run `/export-docs sdd` after `/arch` changes, and after `/test` / `/verify` / `/deploy` produce real measurements for §7/§10/§11.

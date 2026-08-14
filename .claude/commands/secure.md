---
name: secure
description: Pre-development security review with threat modeling (STRIDE)
---

# /secure — Pre-Development Security Review

> "Security by design, not afterthought."

## Purpose

Review architecture for security concerns **BEFORE** writing any code. Identify threats, define security requirements, and establish controls upfront.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

## Scope

**This command is DESIGN-LEVEL threat modeling — no code exists yet.**

- ✅ STRIDE on architecture, ADR review, security requirements, OWASP Top 10 compliance check
- ❌ NOT: code scanning, dependency audit, SAST, secret-grep — those belong to `/scan` (post-development)

If a finding requires reading source code to confirm, defer it to `/scan`.

## Prerequisites

**Input files (must exist before `/secure` starts):**

- `specs/SPEC.md` — for asset inventory, data sensitivity, NFRs, and the **Permission Matrix** (the business authz basis for IDOR / Elevation-of-Privilege threats — the downstream contract `spec.md` §Permission Matrix declares)
- `architecture/ARCHITECTURE.md` + its **Open Questions** section
- `architecture/adr/*.md` — every ADR is a design decision with security implications; read them all *(brownfield delta: read the ADRs touching the delta surface — see §Brownfield Mode)*
- `plans/plan.md` — for mitigation → task ID mapping (Phase 3). **Required for a per-change run only**; a whole-system **baseline run** (brownfield, no active change-set) legitimately has no plan yet and uses evidence ids / Backlog owners instead — see §Brownfield Mode → Baseline run.
- `.claude/rules/security.md` — non-negotiables

**Boilerplate templates (fixed — the agent fills in data, does not re-author structure):**

- `.claude/templates/STRIDE_TEMPLATE.md` — Asset inventory, STRIDE reference, Risk matrix, Threat block, Highest-Risk Surface table, THREAT_MODEL skeleton
- `.claude/templates/OWASP_TEMPLATE.md` — OWASP Top 10 (2021) 10-row table, Security Requirements 6-domain checklist, Residual Risks table

**Required resolution:** every unresolved Open Question in `ARCHITECTURE.md §Open Questions` MUST be resolved in `PRE_DEV_REVIEW.md` (with rationale + v2 trigger) or explicitly deferred with stakeholder acknowledgment recorded. An unresolved OQ blocks the gate.

**Understanding required:**

- Data sensitivity and compliance requirements (GDPR, PCI, HIPAA — where applicable)
- The single highest-risk active surface (see Phase 3.5)

---

## Workflow

> **Time-optimization principle:** Every fixed structure (STRIDE 6 categories, Risk matrix, OWASP Top 10 rows, Security Requirements 6 domains, Residual Risk table) is already templated in `.claude/templates/`. The agent **only fills in feature-specific data** — do NOT re-write the template structure on every `/secure`.

### Phase 1: Asset Identification

**Template:** `STRIDE_TEMPLATE.md §A`

1. Read the reference asset categories in `§A.1` (10 standard asset types) — select the ones present in the feature.
2. Add feature-specific assets (e.g. `Uploaded document URL`, `Shared resource token`).
2b. **Brownfield — harvest assets from the `/discover` inventories**, which are attack-surface catalogs in disguise: `CODEBASE_MAP.md` **§DB-object inventory** (procs/triggers/functions — dynamic SQL, privilege escalation) · **§Connection inventory** (credentials + endpoints; a `Config source outside repo` row is itself a secrets-handling finding) · **§Messaging inventory** (topics — tampering/replay) · **§Cache-structure inventory** (keys — poisoning, information disclosure) · `db/schema-snapshot/` (the real column-level shape of stored data). Reading these is what keeps the threat model from covering only what the HTTP layer makes obvious.
3. Copy the `§A.2` table into `THREAT_MODEL.md §Assets`, fill in rows.

**Output:** The `Assets` table in `THREAT_MODEL.md`.

### Phase 2: STRIDE Reference

**Template:** `STRIDE_TEMPLATE.md §B`

Do NOT re-write the STRIDE 6-category table. The agent uses `§B` as a reference when analyzing each component to determine which category a threat belongs to. This table is a constant — do not copy it into THREAT_MODEL unless an in-line copy is needed.

### Phase 3: Threat Analysis

**Template:** `STRIDE_TEMPLATE.md §C` (Risk matrix) + `§D` (Threat block)

1. Copy the Risk matrix `§C` into `THREAT_MODEL.md` — this table is FIXED, do not modify it.
2. For each threat identified: copy the `§D` block, fill in the `[…]` placeholders.
3. Apply the rule in `§C` consistently:
   - **Critical/High** → MUST `[Required for v1]` mitigation
   - **Medium** → `[Required for v1]` OR `[Deferred to v2 with trigger]`
   - **Low** → `[Accepted]` allowed (with a rationale)
4. **Every mitigation MUST have a real owner.** Per-change run → an existing task ID in `plans/plan.md`; if it fits no task → escalate to the PM before expanding scope. Baseline run (§Brownfield Mode) → an **evidence id** for a control already implemented, or `Backlog — task id assigned when /plan runs` **plus a matching Residual-Risk row**. **Never invent a task ID**: a fabricated reference reads like ownership and is worse than an openly unowned mitigation.

**Output:** One or more threat blocks in `THREAT_MODEL.md §Threats (STRIDE)`, grouped by S/T/R/I/D/E.

### Phase 3.5: Highest-Risk Active Surface — Deep Dive

**Template:** `STRIDE_TEMPLATE.md §E`

You MUST identify **1 surface** with the highest risk:

1. Consult the `§E.1` candidate list (10 commonly encountered surface types). Pick 1.
2. Copy the `§E.2` table, fill in ≥3 controls (if <3, the surface is not risky enough to be called the "highest"). Each control gets a **stable id `RC-N`** (N sequential within `PRE_DEV_REVIEW.md`) — this is the **Required Control id** that `/review` cites (`Relates-to: RC-N`) and `/build` implements against. A control from an existing ADR may cite the ADR-id instead of RC-N.
3. Each `[NEW]` control (beyond existing ADRs) **MUST** have an `RC-N` and reappear in `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"` with the same `RC-N`.

One deep table beats 15 shallow paragraphs.

### Phase 4: Security Requirements

**Template:** `OWASP_TEMPLATE.md §B`

1. Copy the 6-domain checklist `§B` into `SECURITY_REQUIREMENTS.md`.
2. Mark `[x]` for every applicable control + add evidence (specific file/attribute/header/flag).
3. Mark `[N/A]` for controls that do not apply + a rationale.

**Actionability rule:** Every requirement must be **mechanically implementable**. The Backend Developer must be able to copy-paste it into code.

> ❌ Bad: "Validate JWTs properly."
> ✅ Good: "In `Program.cs`, `AddJwtBearer` MUST set `TokenValidationParameters.ValidAlgorithms = new[] { \"HS256\" }` and `ClockSkew = TimeSpan.Zero`."

### Phase 5: OWASP Top 10 Compliance + Residual Risks

**Templates:** `OWASP_TEMPLATE.md §A` (OWASP Top 10) + `§C` (Residual Risks)

1. Copy the `§A` 10-row table into `PRE_DEV_REVIEW.md`. Fill in the **Status** and **Evidence** columns for **all 10 rows** (A01–A10), leaving none blank.
   - Only A06 may be `Deferred to /scan`. The other categories must be `Addressed` / `Partial` / `N/A` with a rationale.
2. Copy the `§C` Residual Risks table into `PRE_DEV_REVIEW.md`. Each `[Deferred to v2]` or `[Accepted]` mitigation from Phase 3 MUST have one RR-N row.
3. The v2 trigger MUST be an **observable condition** (measurable, verifiable), not vague ("when we have time").

### Phase 6: Output Structure

```text
security/
├── THREAT_MODEL.md              # Generated from STRIDE_TEMPLATE §F skeleton (Asset + STRIDE block + Highest-Risk Surface)
├── SECURITY_REQUIREMENTS.md     # Generated from OWASP_TEMPLATE §B checklist
├── PRE_DEV_REVIEW.md            # Contains OWASP Top 10 (§A) + Residual Risks (§C) + Controls added beyond ADRs + Approval
└── data-flow/                   # Data flow diagrams (optional, if there is sensitive data flow)
    └── sensitive-data-flow.md
```

---

## Threat Model Document Skeleton

Already defined in `STRIDE_TEMPLATE.md §F` — copy it verbatim; the agent only fills in the `[…]` placeholders.

---

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

`/secure` runs **per-change in Phase B** (typically B1, when a change opens a new/changed surface). It is **delta-scoped**, not a whole-system re-model:

- **Scope STRIDE to the delta surface** — threat-model only the new/changed surface; do NOT re-run STRIDE on unchanged surfaces.
- **Reference existing controls, don't re-derive** — controls already in the baseline `THREAT_MODEL.md` / `PRE_DEV_REVIEW.md` or in (inferred) ADRs are cited by ID; only add NEW controls the delta surface needs.
- **Read only the relevant ADRs** — those touching the delta surface, not all.
- **Regression-security is an acceptance criterion** — the change MUST NOT weaken an existing control (drop an `[Authorize]`, widen CORS, expose a field). Add a check asserting the existing posture is preserved — the security counterpart of `/plan`'s backward-compat AC.
- **Widen scope when cross-cutting** — if the delta touches a shared control (auth, rate limiter, error contract), widen STRIDE to every surface that control protects. Delta-scoping must not hide a cross-cutting regression.
- **Baseline run (no change-set) — auto-detected, no flag.** Brownfield + no `plans/plan.md` + no `security/THREAT_MODEL.md` → this is a **whole-system baseline**, not a delta: **announce it** ("no active change-set → running a baseline threat model over the whole as-is system") and apply three adaptations, all recorded in `PRE_DEV_REVIEW.md §Scope` so the reader knows which rules were bent and why:
  1. **Mitigation owner** — implemented control → cite its **evidence id**: an **ADR id**, an **`ARCHITECTURE.md` section**, or — brownfield, where the control already exists in the codebase — the **`file:line` where it is wired** (that IS the evidence; `/discover` produces no security-posture inventory, so never cite one); missing control → `Backlog — task id assigned when /plan runs` **+ a Residual-Risk row with an observable trigger**. Never a fabricated task id.
  2. **"Required for v1" means "the system as it runs today"** — already-implemented → `[Implemented as-is]` + evidence; gaps: Critical/High → `[Required before next release]` + Backlog owner · Medium → `[Deferred]` + observable trigger · Low → `[Accepted]` + rationale. Template vocabulary otherwise unchanged.
  3. **Open Questions** — resolve the ones that are genuinely `/secure`-scoped (e.g. encryption-at-rest); the rest get `Deferred — awaiting ack` and are surfaced to the user. The auditor never acknowledges on the user's behalf.
  A later run over the same system is a **pure delta** against this baseline. *(Partial variant: a delta arrives before any baseline exists → establish the baseline for the affected subsystem first, then proceed with the delta.)*

> **B5 (architecture upgrade) exception:** a redesign may move trust boundaries → re-model the affected boundaries fully (with ADR), not just a delta.

## Quality Gate 4 — Pre-Dev Security Review ⛔ BLOCKING

> Step optional per CLAUDE.md §Quality Gates — **BLOCKING if run**.

> **Brownfield (delta mode):** the OWASP Top 10 + Security Requirements coverage below is assessed **for the delta surface**; categories the change does not touch **cite the baseline `PRE_DEV_REVIEW.md`** instead of being re-filled. Whole-system completeness is required only on the baseline run (or B5). See §Brownfield Mode.

Run the §Orchestrator disk-check (below) first, then review.

**Development CANNOT proceed** without:

- [ ] Threat model completed — every threat has a unique ID, a risk rating from the `STRIDE_TEMPLATE §C` matrix, and a `Required for v1?` decision
- [ ] All Critical/High risks have a `[Required for v1]` mitigation
- [ ] Every mitigation has a real owner (Phase 3 Owner field) — **per-change:** an existing `plans/plan.md` task ID · **baseline run:** an evidence id, or `Backlog` **with** its Residual-Risk row. No fabricated ids.
- [ ] All `ARCHITECTURE.md §Open Questions` resolved or explicitly deferred with ack
- [ ] Phase 3.5 deep-dive table generated from `STRIDE_TEMPLATE §E.2` (≥3 controls), **each control has an `RC-N` id**; `[NEW]` controls also have an `RC-N`
- [ ] OWASP Top 10 (2021) table filled in for all 10 rows per `OWASP_TEMPLATE §A` (Status + Evidence, no blanks)
- [ ] **A05 (Security Misconfiguration)** explicitly assesses **security headers + CORS** (Status ≠ blank, no ambiguity / `N/A` without a rationale) — this is the pre-dev line that blocks the "missing security headers" class
- [ ] Security Requirements checklist from `OWASP_TEMPLATE §B` marked (applicable controls have evidence, N/A controls have a rationale)
- [ ] Residual risks from `OWASP_TEMPLATE §C` documented with an observable v2 trigger
- [ ] Security requirements mechanically implementable (file/attribute/header/flag specified)
- [ ] `[NEW]` controls in Phase 3.5 relisted in `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"`
- [ ] Security Auditor approval recorded in `PRE_DEV_REVIEW.md`
- [ ] PRE_DEV_REVIEW.md marked as APPROVED

### Orchestrator disk-check (run BEFORE presenting for Gate 4 sign-off)

A sub-agent's "done" report is NOT ground truth — same discipline as `CLAUDE.md` §Verification After Delegation, applied at artifact level (mechanical invariants only; threat judgment stays human at sign-off). Template self-checks are the agent's own claim — re-verify on disk:

- [ ] **Files exist** — `security/THREAT_MODEL.md`, `SECURITY_REQUIREMENTS.md`, `PRE_DEV_REVIEW.md`.
- [ ] **OWASP table** — all 10 rows A01–A10 present, no blank Status/Evidence cell; only A06 is `Deferred to /scan`. *(Brownfield delta: a cell citing the baseline `PRE_DEV_REVIEW.md` counts as filled.)*
- [ ] **A05 names the two controls** — the A05 (Security Misconfiguration) row explicitly mentions **security headers** AND **CORS/same-origin**, each with a mechanism or an explicit `/secure`-deferral carrying an OQ id. The bare word "Addressed" does not satisfy this row — it is the line that blocks the "missing security headers" class the Gate item was written for.
- [ ] **Threat blocks** — threat IDs unique; every Critical/High threat has a `[Required for v1]` mitigation.
- [ ] **Residual-risk completeness** — every threat whose `Required for v1?` is `Deferred` / `Accepted` has a matching RR-N row in `PRE_DEV_REVIEW.md §Residual Risks` (diff the two sets).
- [ ] **Owner cross-check** — **per-change:** every `Owner task(s)` id cited in `THREAT_MODEL.md` exists in `plans/plan.md` (diff the two sets yourself; a mitigation pointing at a non-existent task is an unowned mitigation). **Baseline run:** no `plans/plan.md` exists, so instead verify each owner is an evidence id that resolves (the cited ADR file / CODEBASE_MAP row exists) or the literal `Backlog` — and every `Backlog` owner has an RR row. A task-id-shaped string with no plan on disk = fabricated → FAIL.
- [ ] **RC table** — the Phase 3.5 table has ≥3 controls with `RC-N` ids; every `[NEW]` control reappears in §"Controls added beyond ADRs" with the same id.
- [ ] **OQ reconciliation** — every row of `ARCHITECTURE.md §Open Questions` appears in `PRE_DEV_REVIEW.md` as resolved or deferred-with-ack (no row silently dropped).
- [ ] **No template residue** — no unfilled `[…]` placeholders left in `security/`.

Any mismatch → fix on disk first; never present a review that fails its own gate mechanics.

## Agent

Invoke: **Security Auditor**

**Phase ownership** — the Security Auditor sub-agent cannot converse with the user: a mitigation that fits no existing plan task (Phase 3 "escalate to the PM"), or an Open Question that needs stakeholder acknowledgment to defer → **return early** with the item instead of deciding alone. The orchestrator obtains the ack / routes the plan change, runs the Gate 4 disk-check, and presents the review for sign-off in the main loop.

```text
"As Security Auditor, perform pre-development security review for [feature].
Mode: <greenfield | brownfield delta — surface: [...] | brownfield baseline (no active change-set)> — resolved by the orchestrator per §Brownfield Mode; a delta run cites baseline controls by id, a baseline run applies the three §Baseline-run adaptations.
Use .claude/templates/STRIDE_TEMPLATE.md and .claude/templates/OWASP_TEMPLATE.md
as boilerplate — fill feature-specific data, do NOT re-author template structure.
Output language: <Output Language from Project Profile> for prose/artifacts, English for code and technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After security approved, run `/build` to implement with security controls.

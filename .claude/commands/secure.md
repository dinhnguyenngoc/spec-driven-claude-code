---
name: secure
description: Pre-development security review with threat modeling (STRIDE)
---

# /secure — Pre-Development Security Review

> "Security by design, not afterthought."

## Purpose

Review architecture for security concerns **BEFORE** writing any code. Identify threats, define security requirements, and establish controls upfront.

## Scope

**This command is DESIGN-LEVEL threat modeling — no code exists yet.**

- ✅ STRIDE on architecture, ADR review, security requirements, OWASP Top 10 compliance check
- ❌ NOT: code scanning, dependency audit, SAST, secret-grep — those belong to `/scan` (post-development)

If a finding requires reading source code to confirm, defer it to `/scan`.

## Prerequisites

**Input files (must exist before `/secure` starts):**

- `specs/SPEC.md` — for asset inventory, data sensitivity, NFRs
- `architecture/ARCHITECTURE.md` + its **Open Questions** section
- `architecture/adr/*.md` — every ADR is a design decision with security implications; read them all *(brownfield delta: read the ADRs touching the delta surface — see §Brownfield Mode)*
- `plans/plan.md` — for mitigation → task ID mapping (see Phase 4)
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
4. Each mitigation MUST map to an existing task ID in `plans/plan.md`. If it does not fit → escalate to the PM before expanding scope.

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
2. Copy the `§C` Residual Risks table into `PRE_DEV_REVIEW.md`. Each `[Deferred to v2]` or `[Accepted]` mitigation from Phase 3 SHOULD have one RR-N row.
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
- **Baseline fallback** — if no baseline threat model exists, this run first establishes one for the affected subsystem, then proceeds with the delta; later runs are pure delta.

> **B5 (architecture upgrade) exception:** a redesign may move trust boundaries → re-model the affected boundaries fully (with ADR), not just a delta.

## Quality Gate 4 — Pre-Dev Security Review ⛔ BLOCKING

> Step optional per CLAUDE.md §Quality Gates — **BLOCKING if run**.

> **Brownfield (delta mode):** the OWASP Top 10 + Security Requirements coverage below is assessed **for the delta surface**; categories the change does not touch **cite the baseline `PRE_DEV_REVIEW.md`** instead of being re-filled. Whole-system completeness is required only on the baseline run (or B5). See §Brownfield Mode.

**Development CANNOT proceed** without:

- [ ] Threat model completed — every threat has a unique ID, a risk rating from the `STRIDE_TEMPLATE §C` matrix, and a `Required for v1?` decision
- [ ] All Critical/High risks have a `[Required for v1]` mitigation
- [ ] Every mitigation maps to a `plans/plan.md` task ID (Phase 3 Owner field)
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

## Agent

Invoke: **Security Auditor**

```text
"As Security Auditor, perform pre-development security review for [feature].
Use .claude/templates/STRIDE_TEMPLATE.md and .claude/templates/OWASP_TEMPLATE.md
as boilerplate — fill feature-specific data, do NOT re-author template structure.
Output language: Vietnamese for prose/artifacts, English for technical identifiers
(see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After security approved, run `/build` to implement with security controls.

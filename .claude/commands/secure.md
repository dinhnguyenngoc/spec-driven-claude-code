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

**Boilerplate templates (cố định — agent fill data, không re-author structure):**

- `.claude/templates/STRIDE_TEMPLATE.md` — Asset inventory, STRIDE reference, Risk matrix, Threat block, Highest-Risk Surface table, THREAT_MODEL skeleton
- `.claude/templates/OWASP_TEMPLATE.md` — OWASP Top 10 (2021) 10-row table, Security Requirements 6-domain checklist, Residual Risks table

**Required resolution:** every unresolved Open Question in `ARCHITECTURE.md §Open Questions` MUST be resolved in `PRE_DEV_REVIEW.md` (with rationale + v2 trigger) or explicitly deferred with stakeholder acknowledgment recorded. An unresolved OQ blocks the gate.

**Understanding required:**

- Data sensitivity and compliance requirements (GDPR, PCI, HIPAA — where applicable)
- The single highest-risk active surface (see Phase 3.5)

---

## Workflow

> **Nguyên tắc tối ưu thời gian:** Mọi structure cố định (STRIDE 6 categories, Risk matrix, OWASP Top 10 hàng, Security Requirements 6 domain, Residual Risk table) đã được template hoá trong `.claude/templates/`. Agent **chỉ fill data feature-specific** — KHÔNG re-write template structure mỗi lần `/secure`.

### Phase 1: Asset Identification

**Template:** `STRIDE_TEMPLATE.md §A`

1. Đọc reference asset categories ở `§A.1` (10 loại asset chuẩn) — chọn loại có trong feature.
2. Bổ sung asset feature-specific (vd: `Uploaded document URL`, `Shared resource token`).
3. Copy `§A.2` table vào `THREAT_MODEL.md §Assets`, fill rows.

**Output:** Bảng `Assets` trong `THREAT_MODEL.md`.

### Phase 2: STRIDE Reference

**Template:** `STRIDE_TEMPLATE.md §B`

KHÔNG re-write bảng STRIDE 6 categories. Agent dùng `§B` như reference khi phân tích từng component để xác định threat thuộc loại nào. Bảng này là constant — không copy vào THREAT_MODEL trừ khi cần in-line.

### Phase 3: Threat Analysis

**Template:** `STRIDE_TEMPLATE.md §C` (Risk matrix) + `§D` (Threat block)

1. Copy Risk matrix `§C` vào `THREAT_MODEL.md` — bảng này CỐ ĐỊNH, không sửa.
2. Với mỗi threat phát hiện: copy `§D` block, fill `[…]` placeholder.
3. Áp dụng đồng nhất rule trong `§C`:
   - **Critical/High** → MUST `[Required for v1]` mitigation
   - **Medium** → `[Required for v1]` HOẶC `[Deferred to v2 with trigger]`
   - **Low** → `[Accepted]` được phép (kèm lý do)
4. Mỗi mitigation MUST map tới task ID có sẵn trong `plans/plan.md`. Không fit → escalate PM trước khi expand scope.

**Output:** Một hoặc nhiều threat block trong `THREAT_MODEL.md §Threats (STRIDE)`, nhóm theo S/T/R/I/D/E.

### Phase 3.5: Highest-Risk Active Surface — Deep Dive

**Template:** `STRIDE_TEMPLATE.md §E`

BẮT BUỘC identify **1 surface** rủi ro cao nhất:

1. Tham khảo `§E.1` candidate list (10 loại surface thường gặp). Chọn 1.
2. Copy `§E.2` table, fill ≥3 controls (nếu <3, surface chưa đủ rủi ro để gọi là "highest"). Mỗi control nhận **id ổn định `RC-N`** (N tuần tự trong `PRE_DEV_REVIEW.md`) — đây là **Required Control id** mà `/review` cite (`Relates-to: RC-N`) và `/build` implement theo. Control từ ADR có sẵn có thể cite ADR-id thay vì RC-N.
3. Mỗi control `[NEW]` (ngoài ADR có sẵn) **PHẢI** có `RC-N` và xuất hiện lại trong `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"` với cùng `RC-N`.

Một deep table hơn 15 paragraph shallow.

### Phase 4: Security Requirements

**Template:** `OWASP_TEMPLATE.md §B`

1. Copy checklist 6 domain `§B` vào `SECURITY_REQUIREMENTS.md`.
2. Đánh dấu `[x]` cho mọi control áp dụng + thêm evidence (file/attribute/header/flag cụ thể).
3. Đánh `[N/A]` cho control không áp dụng + lý do.

**Actionability rule:** Mỗi requirement phải **mechanically implementable**. Backend Developer phải copy-paste được vào code.

> ❌ Bad: "Validate JWTs properly."
> ✅ Good: "In `Program.cs`, `AddJwtBearer` MUST set `TokenValidationParameters.ValidAlgorithms = new[] { \"HS256\" }` and `ClockSkew = TimeSpan.Zero`."

### Phase 5: OWASP Top 10 Compliance + Residual Risks

**Templates:** `OWASP_TEMPLATE.md §A` (OWASP Top 10) + `§C` (Residual Risks)

1. Copy `§A` bảng 10 hàng vào `PRE_DEV_REVIEW.md`. Fill cột **Status** và **Evidence** cho **đủ 10 hàng** (A01–A10), không bỏ trống.
   - Chỉ A06 được `Deferred to /scan`. Các category khác phải `Addressed` / `Partial` / `N/A` với lý do.
2. Copy `§C` Residual Risks table vào `PRE_DEV_REVIEW.md`. Mỗi `[Deferred to v2]` hoặc `[Accepted]` mitigation từ Phase 3 NÊN có 1 row RR-N.
3. v2 trigger PHẢI là **observable condition** (đo được, kiểm tra được), không vague ("when we have time").

### Phase 6: Output Structure

```text
security/
├── THREAT_MODEL.md              # Sinh từ STRIDE_TEMPLATE §F skeleton (Asset + STRIDE block + Highest-Risk Surface)
├── SECURITY_REQUIREMENTS.md     # Sinh từ OWASP_TEMPLATE §B checklist
├── PRE_DEV_REVIEW.md            # Chứa OWASP Top 10 (§A) + Residual Risks (§C) + Controls added beyond ADRs + Approval
└── data-flow/                   # Data flow diagrams (optional, nếu có sensitive data flow)
    └── sensitive-data-flow.md
```

---

## Threat Model Document Skeleton

Đã được định nghĩa ở `STRIDE_TEMPLATE.md §F` — copy nguyên xi, agent chỉ fill `[…]` placeholder.

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

- [ ] Threat model completed — every threat có ID duy nhất, risk rating từ matrix `STRIDE_TEMPLATE §C`, và `Required for v1?` decision
- [ ] All Critical/High risks có `[Required for v1]` mitigation
- [ ] Every mitigation map tới `plans/plan.md` task ID (Phase 3 Owner field)
- [ ] All `ARCHITECTURE.md §Open Questions` resolved hoặc explicitly deferred với ack
- [ ] Phase 3.5 deep-dive table sinh từ `STRIDE_TEMPLATE §E.2` (≥3 controls), **mỗi control có `RC-N` id**; control `[NEW]` cũng có `RC-N`
- [ ] OWASP Top 10 (2021) table filled đủ 10 hàng theo `OWASP_TEMPLATE §A` (Status + Evidence, no blanks)
- [ ] **A05 (Security Misconfiguration)** đánh giá explicit **security headers + CORS** (Status ≠ blank, không để mơ hồ/`N/A` thiếu lý do) — đây là tuyến pre-dev chặn lớp "thiếu security headers"
- [ ] Security Requirements checklist từ `OWASP_TEMPLATE §B` đã đánh dấu (control áp dụng có evidence, control N/A có lý do)
- [ ] Residual risks từ `OWASP_TEMPLATE §C` documented với observable v2 trigger
- [ ] Security requirements mechanically implementable (file/attribute/header/flag specified)
- [ ] Controls `[NEW]` trong Phase 3.5 đã được liệt kê lại trong `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"`
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

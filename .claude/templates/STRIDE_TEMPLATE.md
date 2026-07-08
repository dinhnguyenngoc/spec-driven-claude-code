# STRIDE Template — Threat Modeling Boilerplate

> **Purpose:** Provide a fixed framework for threat modeling using STRIDE. The `/secure` agent uses this template instead of re-authoring from scratch each time — it only **fills feature-specific data** into the predefined blocks.
>
> **When to use:** `/secure` Phase 1 (Asset), Phase 2 (STRIDE), Phase 3 (Threat block), Phase 3.5 (Highest-Risk Surface).
>
> **How to use:** Copy the needed section into `security/THREAT_MODEL.md`, then fill in the `[…]` fields and tables. Do **NOT re-write** the template structure.

---

## §A. Asset Inventory (Phase 1)

### A.1 — Default asset categories (reference, not mandatory to copy)

Common asset types — the agent picks the ones present in the feature and **adds feature-specific assets** if any:

| Asset | Sensitivity | Impact if Compromised |
|-------|-------------|----------------------|
| User credentials (password hash, MFA secret) | Critical | Account takeover |
| Session/auth tokens (JWT, refresh token) | Critical | Impersonation, lateral movement |
| Payment data (card number, CVV) | Critical | Financial loss, PCI violation |
| Personal data (PII: email, phone, address, DOB) | High | Privacy breach, GDPR violation |
| Health data (PHI) | Critical | HIPAA violation |
| API keys / secrets (DB password, third-party token) | Critical | Full system compromise |
| Business logic / pricing rules | Medium | Competitive disadvantage |
| Audit log / security event log | High | Cover-up of malicious actions |
| User-generated content (UGC) | Medium | XSS vector, brand damage |
| Internal config / feature flags | Medium | Information disclosure |

### A.2 — Asset table to fill in `THREAT_MODEL.md`

```markdown
## Assets (feature: [FEATURE NAME])

| Asset | Classification | Owner | Notes |
|-------|---------------|-------|-------|
| [Asset name 1 — e.g.: Uploaded document URL] | [Critical/High/Medium/Low] | [Team/Module] | [Classification reason — e.g.: contains user's private URL] |
| [Asset name 2] | ... | ... | ... |
```

---

## §B. STRIDE Reference Table (Phase 2)

> **This is a fixed reference — copy verbatim if needed, do not modify.** The agent uses it only as a reminder when analyzing each component.

| Threat | Description | Questions to Ask | Typical Mitigations |
|--------|-------------|------------------|---------------------|
| **S**poofing | Pretending to be someone else | Can identity be faked? Is auth strong (MFA, BCrypt cost ≥12)? Are session tokens unpredictable? | Strong auth, MFA, JWT signature validation, mTLS service-to-service |
| **T**ampering | Modifying data or code | Can data be altered in transit/at rest? Are there integrity checks (HMAC, digital sig)? | TLS 1.3, HMAC, optimistic concurrency (`rowversion`), parameterized queries |
| **R**epudiation | Denying actions | Can users deny they did X? Is there audit log with actor + timestamp + outcome? | Audit log (immutable, append-only), correlation ID, signed receipts |
| **I**nformation Disclosure | Exposing data | Can data leak via error messages, logs, side channels, IDOR? Via **missing security headers** (clickjacking, MIME-sniff, TLS downgrade) or **CORS misconfig** (`AllowAnyOrigin` + credentials)? | `ProblemDetails` (no stack trace in prod), Serilog destructure-redact, `[Authorize]` + ownership predicate, **security-headers middleware (HSTS/CSP/X-Frame-Options/X-Content-Type-Options/Referrer-Policy)**, **CORS allowlist** |
| **D**enial of Service | Making system unavailable | Can service be overwhelmed (volumetric, slowloris, query of death, unbounded recursion)? | Rate limiting (token bucket / sliding window), request size limits, query timeout, circuit breaker |
| **E**levation of Privilege | Gaining unauthorized access | Can roles be bypassed? IDOR? Path traversal? Mass-assignment? | RBAC + policy + resource ownership check, allowlist (not denylist), input whitelisting |

---

## §C. Risk Matrix (Phase 3)

> **Fixed table — copy verbatim into `THREAT_MODEL.md`, do not redesign.**

| L \ I    | Low | Medium | High | Critical |
|----------|-----|--------|------|----------|
| High     | M   | H      | H    | Critical |
| Medium   | L   | M      | H    | H        |
| Low      | L   | L      | M    | H        |

**Rules applied uniformly to every threat:**
- **Critical / High** risk → **MUST** have a `[Required for v1]` mitigation
- **Medium** → `[Required for v1]` OR `[Deferred to v2 with trigger]`
- **Low** → `[Accepted]` is allowed (with reason)

---

## §D. Threat Block Template (Phase 3 — 1 block / threat)

> Copy the block below for each threat found. **Fixed structure, only fill the `[…]`.**

```markdown
## Threat: [Short name] — [ID: S1 / T1 / R1 / I1 / D1 / E1]

**Category**: [S / T / R / I / D / E]
**Component**: [Affected component — e.g.: `OrderController.Create`]
**Description**: [Describe the attack — 1–3 sentences]
**Likelihood**: [High / Medium / Low]
**Impact**: [Critical / High / Medium / Low]
**Risk**: [Critical / High / Medium / Low — look up in §C]

### Attack Scenario
1. [Attacker does X]
2. [System reacts Y]
3. [Attacker achieves Z]

### Mitigations
- [ ] [Mitigation 1 — mechanically implementable: specific file/attribute/header/flag]
- [ ] [Mitigation 2 — ...]

### Acceptance Criteria
- [ ] [Specific security test name + plan task ID — e.g.: `OrderTests.RejectsForeignUserId` / Task 3.4]

**Required for v1?**: [Yes / Deferred to v2 with trigger: <observable condition> / Accepted: <reason>]
**Owner task(s)**: plan Task X.X, X.Y  ← EVERY mitigation must map to a task ID that already exists in `plans/plan.md`
**Slot into existing task?**: [Yes — no new task / No — escalate PM, plan change needed]
```

**Discipline:** Prefer slotting a mitigation into an existing task in `plans/plan.md`. If it doesn't fit, escalate to PM before expanding scope — do NOT silently add a task.

---

## §E. Highest-Risk Active Surface — Deep Dive (Phase 3.5)

> **Every `/secure` MUST** identify **1 active surface** with the highest risk and do a deep dive. One deep table beats 15 shallow paragraphs.

### E.1 — Active surface candidate list (reference, pick 1)

Surface types that commonly carry high risk:

| Surface type | Typical threat sub-vectors |
|--------------|------------------------------|
| URL-fetching / SSRF | `file://`, `gopher://`, DNS rebinding, cloud metadata IP (169.254.169.254), redirect chain |
| File upload | Path traversal, MIME spoofing, ZIP bomb, polyglot file, executable masquerading |
| Deserialization (JSON/XML/binary) | Type confusion, gadget chain, billion laughs, XXE |
| Server-side template rendering | SSTI (`{{7*7}}`), sandbox escape |
| OAuth callback / SSO | Open redirect, state CSRF, scope escalation, token theft |
| Webhook receiver | Signature bypass, replay, host-header injection |
| Payment gateway integration | Idempotency replay, amount tampering, MITM |
| Image/PDF processing | ImageTragick, ghostscript RCE, memory exhaustion |
| Search query (Lucene/SQL/NoSQL) | Injection, ReDoS, query-of-death |
| Email/SMS dispatch | Header injection, phishing relay, rate-limit bypass |
| HTTP response surface (headers/CORS) | Missing HSTS/CSP/X-Frame-Options/X-Content-Type-Options, `AllowAnyOrigin` + credentials, Server header leak |

### E.2 — Control-to-Test Mapping Table (MUST fill)

```markdown
## Phase 3.5: Highest-Risk Active Surface — Deep Dive

**Surface chosen:** [Surface name — e.g.: URL-fetching for link/document title preview]
**Reason for choosing:** [Why this is the highest-risk surface in this feature]

| RC id | Control | Threat sub-vector closed | Test in plan task | Source |
|-------|---------|--------------------------|-------------------|--------|
| RC-1 | [Control 1 — e.g.: URL scheme allowlist] | [Blocks `file://`, `gopher://`] | [Task X.Y / `TitleFetcherTests.RejectsNonHttpScheme`] | [ADR-NNN] |
| RC-2 | [Control 2 — e.g.: DNS rebinding mitigation] | [Connect to resolved IP, not hostname] | [Task X.Y / test name] | [ADR-NNN] |
| RC-3 | [Control 3 — e.g.: Block cloud metadata IPs] | [Blocks 169.254.169.254, 100.100.100.200] | [Task X.Y / test name] | **[NEW]** |
| RC-… | ... | ... | ... | [ADR-NNN or **[NEW]**] |

> **`RC-N` = stable Required Control id** (sequential within `PRE_DEV_REVIEW.md`). Downstream cites it: `/review` → `Relates-to: RC-N`; `/build` implements per RC-N. A control derived from an existing ADR may cite the ADR id instead; every `[NEW]` control MUST carry an `RC-N`.
```

> Every control marked `[NEW]` (added beyond an existing ADR) **MUST** reappear in `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"` with the same sequence number.

---

## §F. Threat Model Document Skeleton

> The file `security/THREAT_MODEL.md` uses this skeleton — the agent fills `[…]`, does not modify the structure.

```markdown
# Threat Model: [Feature Name]

## Document Info
- **Author**: [Name]
- **Date**: [YYYY-MM-DD]
- **Status**: [Draft / In Review / Approved]
- **Reviewers**: [Name]

## System Overview
[Short description + link to `architecture/ARCHITECTURE.md`]

## Assets
[Copy §A.2 — fill the table]

## Trust Boundaries
[Diagram (ASCII or link to `architecture/diagrams/`) — show the boundary between untrusted ↔ trusted zones]

## Threats (STRIDE)

### Spoofing (S)
[One or more threat blocks §D — category = S]

### Tampering (T)
[Threat block §D — category = T]

### Repudiation (R)
[Threat block §D — category = R]

### Information Disclosure (I)
[Threat block §D — category = I]

### Denial of Service (D)
[Threat block §D — category = D]

### Elevation of Privilege (E)
[Threat block §D — category = E]

## Highest-Risk Active Surface
[Copy §E.2 — fill the table]

## Security Requirements
[Link to `security/SECURITY_REQUIREMENTS.md` — generated from `OWASP_TEMPLATE.md §B`]

## Approval

| Role | Name | Date | Status |
|------|------|------|--------|
| Security Lead | | | Pending |
| Tech Lead | | | Pending |

## Open Issues
- [ ] [Issue to resolve before approval]
```

---

## Self-check checklist (agent uses before submitting)

- [ ] Every threat has a unique ID (S1, T1, …) — no duplicates
- [ ] Every threat has a Risk rating looked up from §C (not self-assigned)
- [ ] Every Critical/High threat has at least 1 `[Required for v1]` mitigation
- [ ] Every mitigation maps to an existing `plans/plan.md` task ID
- [ ] The Phase 3.5 deep-dive table has ≥3 controls (if <3, the surface is not risky enough to be called the "highest")
- [ ] Every `[NEW]` control is re-listed in `PRE_DEV_REVIEW.md`
- [ ] STRIDE reference (§B) and Risk matrix (§C) are **not modified** from the template

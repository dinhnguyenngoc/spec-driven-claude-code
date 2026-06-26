# STRIDE Template — Threat Modeling Boilerplate

> **Mục đích:** Cung cấp khung cố định cho threat modeling theo STRIDE. Agent `/secure` dùng template này thay vì re-author từ đầu mỗi lần — chỉ **fill data feature-specific** vào các block đã định sẵn.
>
> **Khi nào dùng:** `/secure` Phase 1 (Asset), Phase 2 (STRIDE), Phase 3 (Threat block), Phase 3.5 (Highest-Risk Surface).
>
> **Cách dùng:** Copy section cần thiết vào `security/THREAT_MODEL.md` rồi điền vào các ô `[…]` và bảng. **KHÔNG re-write** structure của template.

---

## §A. Asset Inventory (Phase 1)

### A.1 — Default asset categories (reference, không bắt buộc copy)

Các loại asset thường gặp — agent chọn loại có trong feature, **bổ sung asset feature-specific** nếu có:

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
## Assets (feature: [TÊN FEATURE])

| Asset | Classification | Owner | Notes |
|-------|---------------|-------|-------|
| [Tên asset 1 — vd: Uploaded document URL] | [Critical/High/Medium/Low] | [Team/Module] | [Lý do classification — vd: chứa private URL người dùng] |
| [Tên asset 2] | ... | ... | ... |
```

---

## §B. STRIDE Reference Table (Phase 2)

> **Đây là reference cố định — copy nguyên xi nếu cần, không sửa.** Agent chỉ dùng để gợi nhớ khi phân tích từng component.

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

> **Bảng cố định — copy nguyên xi vào `THREAT_MODEL.md`, không tự design lại.**

| L \ I    | Low | Medium | High | Critical |
|----------|-----|--------|------|----------|
| High     | M   | H      | H    | Critical |
| Medium   | L   | M      | H    | H        |
| Low      | L   | L      | M    | H        |

**Rules áp dụng đồng nhất cho mọi threat:**
- **Critical / High** risk → **MUST** có `[Required for v1]` mitigation
- **Medium** → `[Required for v1]` HOẶC `[Deferred to v2 with trigger]`
- **Low** → `[Accepted]` được phép (kèm lý do)

---

## §D. Threat Block Template (Phase 3 — 1 block / threat)

> Copy block dưới cho mỗi threat phát hiện. **Cấu trúc cố định, chỉ điền `[…]`.**

```markdown
## Threat: [Tên ngắn gọn] — [ID: S1 / T1 / R1 / I1 / D1 / E1]

**Category**: [S / T / R / I / D / E]
**Component**: [Component bị ảnh hưởng — vd: `OrderController.Create`]
**Description**: [Mô tả cách tấn công — 1–3 câu]
**Likelihood**: [High / Medium / Low]
**Impact**: [Critical / High / Medium / Low]
**Risk**: [Critical / High / Medium / Low — tra từ §C]

### Attack Scenario
1. [Attacker làm X]
2. [System phản ứng Y]
3. [Attacker đạt Z]

### Mitigations
- [ ] [Mitigation 1 — mechanically implementable: file/attribute/header/flag cụ thể]
- [ ] [Mitigation 2 — ...]

### Acceptance Criteria
- [ ] [Tên security test cụ thể + plan task ID — vd: `OrderTests.RejectsForeignUserId` / Task 3.4]

**Required for v1?**: [Yes / Deferred to v2 with trigger: <observable condition> / Accepted: <reason>]
**Owner task(s)**: plan Task X.X, X.Y  ← MỌI mitigation phải map tới task ID có sẵn trong `plans/plan.md`
**Slot into existing task?**: [Yes — không tạo task mới / No — escalate PM, cần plan change]
```

**Discipline:** Ưu tiên slot mitigation vào task có sẵn trong `plans/plan.md`. Nếu không fit, escalate PM trước khi expand scope — KHÔNG silently add task.

---

## §E. Highest-Risk Active Surface — Deep Dive (Phase 3.5)

> **Mỗi `/secure` BẮT BUỘC** identify **1 active surface** rủi ro cao nhất và làm deep dive. Một deep table hơn 15 paragraph shallow.

### E.1 — Active surface candidate list (reference, chọn 1)

Các loại surface thường có rủi ro cao:

| Surface type | Threat sub-vectors điển hình |
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

### E.2 — Control-to-Test Mapping Table (BẮT BUỘC điền)

```markdown
## Phase 3.5: Highest-Risk Active Surface — Deep Dive

**Surface chọn:** [Tên surface — vd: URL-fetching for link/document title preview]
**Lý do chọn:** [Vì sao đây là surface rủi ro cao nhất trong feature này]

| RC id | Control | Threat sub-vector closed | Test in plan task | Source |
|-------|---------|--------------------------|-------------------|--------|
| RC-1 | [Control 1 — vd: URL scheme allowlist] | [Blocks `file://`, `gopher://`] | [Task X.Y / `TitleFetcherTests.RejectsNonHttpScheme`] | [ADR-NNN] |
| RC-2 | [Control 2 — vd: DNS rebinding mitigation] | [Connect to resolved IP, not hostname] | [Task X.Y / test name] | [ADR-NNN] |
| RC-3 | [Control 3 — vd: Block cloud metadata IPs] | [Blocks 169.254.169.254, 100.100.100.200] | [Task X.Y / test name] | **[NEW]** |
| RC-… | ... | ... | ... | [ADR-NNN hoặc **[NEW]**] |

> **`RC-N` = stable Required Control id** (sequential within `PRE_DEV_REVIEW.md`). Downstream cites it: `/review` → `Relates-to: RC-N`; `/build` implements per RC-N. A control derived from an existing ADR may cite the ADR id instead; every `[NEW]` control MUST carry an `RC-N`.
```

> Mọi control đánh dấu `[NEW]` (bổ sung thêm ngoài ADR có sẵn) **PHẢI** xuất hiện lại trong `PRE_DEV_REVIEW.md §"Controls added beyond ADRs"` với cùng số thứ tự.

---

## §F. Threat Model Document Skeleton

> File `security/THREAT_MODEL.md` dùng skeleton này — agent fill `[…]`, không sửa structure.

```markdown
# Threat Model: [Tên Feature]

## Document Info
- **Author**: [Tên]
- **Date**: [YYYY-MM-DD]
- **Status**: [Draft / In Review / Approved]
- **Reviewers**: [Tên]

## System Overview
[Mô tả ngắn + link tới `architecture/ARCHITECTURE.md`]

## Assets
[Copy §A.2 — điền bảng]

## Trust Boundaries
[Diagram (ASCII hoặc link tới `architecture/diagrams/`) — chỉ ra ranh giới giữa zone untrusted ↔ trusted]

## Threats (STRIDE)

### Spoofing (S)
[Một hoặc nhiều threat block §D — category = S]

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
[Copy §E.2 — điền bảng]

## Security Requirements
[Link tới `security/SECURITY_REQUIREMENTS.md` — sinh từ `OWASP_TEMPLATE.md §B`]

## Approval

| Role | Name | Date | Status |
|------|------|------|--------|
| Security Lead | | | Pending |
| Tech Lead | | | Pending |

## Open Issues
- [ ] [Vấn đề cần resolve trước khi approve]
```

---

## Checklist tự kiểm (agent dùng trước khi submit)

- [ ] Mọi threat có ID duy nhất (S1, T1, …) — không trùng
- [ ] Mọi threat có Risk rating tra từ §C (không tự đặt)
- [ ] Mọi Critical/High threat có ít nhất 1 mitigation `[Required for v1]`
- [ ] Mọi mitigation map tới `plans/plan.md` task ID có sẵn
- [ ] Phase 3.5 deep-dive table có ≥3 control (nếu <3, surface chưa đủ rủi ro để gọi là "highest")
- [ ] Mọi control `[NEW]` được liệt kê lại trong `PRE_DEV_REVIEW.md`
- [ ] STRIDE reference (§B) và Risk matrix (§C) **không bị sửa** so với template

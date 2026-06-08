# OWASP Top 10 + Security Requirements Template

> **Mục đích:** Cung cấp 3 boilerplate cố định cho `/secure`:
> - §A — OWASP Top 10 (2021) compliance table (10 hàng skeleton)
> - §B — Default Security Requirements checklist (6 domain)
> - §C — Residual Risks Accepted table
>
> Agent `/secure` **chỉ fill cột Status + Evidence** (cho §A), **đánh dấu áp dụng / không** (cho §B), **fill RR-N feature-specific** (cho §C). KHÔNG re-author structure.

---

## §A. OWASP Top 10 (2021) Compliance Table — REQUIRED trong `PRE_DEV_REVIEW.md`

> **Bảng cố định 10 hàng — copy nguyên xi, chỉ fill cột `Status` và `Evidence`.**

```markdown
## OWASP Top 10 (2021) Compliance

| # | Category | Status | Evidence |
|---|----------|--------|----------|
| A01 | Broken Access Control | [Addressed / Partial / N/A — <reason>] | [vd: `[Authorize]` class-level + composite predicate `WHERE Id = @id AND UserId = @uid`] |
| A02 | Cryptographic Failures | [...] | [vd: BCrypt cost 12; secrets via env var only; TLS 1.3 enforced in prod (`UseHttpsRedirection`)] |
| A03 | Injection | [...] | [vd: EF Core LINQ only; KHÔNG dùng `FromSqlRaw`; FluentValidation length caps trên mọi input] |
| A04 | Insecure Design | [...] | [vd: Threat model này + các ADR document trade-off; Phase 3.5 deep dive] |
| A05 | Security Misconfiguration | [...] | [vd: `ExceptionHandlingMiddleware` đầu pipeline; developer exception page disabled non-Dev; security headers via middleware] |
| A06 | Vulnerable & Outdated Components | Deferred to `/scan` | SCA gate enforced post-build (`dotnet list package --vulnerable`, `npm audit`, Trivy) |
| A07 | Identification & Authentication Failures | [...] | [vd: BCrypt cost 12 + rate-limit `auth` policy + strong password policy (8+/upper/lower/digit/symbol)] |
| A08 | Software & Data Integrity Failures | [...] | [vd: JWT `ValidateIssuerSigningKey = true`; algorithm pinned `ValidAlgorithms = ["HS256"]`; `ClockSkew = Zero`] |
| A09 | Security Logging & Monitoring Failures | [...] | [vd: Serilog destructure-redact `PasswordHash`/`Token`; failed auth log Warning level; `/health` endpoint] |
| A10 | Server-Side Request Forgery (SSRF) | [...] | [vd: Xem Phase 3.5 deep dive — URL scheme allowlist + DNS rebinding mitigation + cloud-metadata-IP block] |
```

**Status options (chuẩn — không thêm option khác):**
- **Addressed** — controls đầy đủ, có evidence cụ thể
- **Partial** — một số controls có, ghi residual risk vào §C
- **N/A** — không áp dụng cho feature này, ghi lý do
- **Deferred to `/scan`** — chỉ chấp nhận cho A06

**Quy tắc fill:**
- KHÔNG bỏ trống ô nào (10 hàng × 2 cột data = 20 ô bắt buộc)
- Evidence phải **mechanically verifiable** — chỉ tên file/attribute/header/flag, không từ ngữ chung chung như "validate properly"

---

## §B. Default Security Requirements Checklist — REQUIRED trong `SECURITY_REQUIREMENTS.md`

> **6 domain cố định — copy nguyên xi. Agent đánh dấu `[x]` cho mọi control có áp dụng + thêm evidence/file reference; đánh `[N/A]` nếu không áp dụng (kèm lý do).**

```markdown
## Security Requirements

### 1. Authentication
- [ ] JWT với short expiry (≤15 min access token) — file: `Program.cs` `AddJwtBearer.TokenValidationParameters`
- [ ] Refresh token rotation (≤7 days, single-use, invalidate on reuse) — entity: `RefreshToken`
- [ ] Password hashing với BCrypt cost ≥12 — service: `IPasswordHasher`
- [ ] MFA cho sensitive operations (admin action, payment, password change) — flag: `RequireMfaAttribute`
- [ ] Account lockout sau N failed attempts (vd: 5 trong 15 phút) — middleware: `AccountLockoutMiddleware`
- [ ] [N/A] _Liệt kê control không áp dụng + lý do_

### 2. Authorization
- [ ] Role-Based Access Control (RBAC) — `[Authorize(Roles = "...")]` hoặc policy
- [ ] Resource ownership validation — predicate `WHERE Id = @id AND UserId = @currentUser`
- [ ] Principle of least privilege — DB user có quyền tối thiểu (no `db_owner`)
- [ ] IDOR prevention — KHÔNG expose sequential ID; dùng GUID hoặc opaque token
- [ ] [N/A] _..._

### 3. Input Validation
- [ ] Schema validation (FluentValidation) trên mọi input DTO — assembly: `*.Validators`
- [ ] Parameterized queries only — EF Core LINQ / Dapper với `@param`, KHÔNG `FromSqlRaw` với user input
- [ ] HTML sanitization cho user-generated content — library: `Ganss.Xss` (`HtmlSanitizer`)
- [ ] File upload validation: MIME type whitelist + magic-byte check + size cap
- [ ] URL whitelist cho outbound HTTP request (chống SSRF) — `HttpClient` factory với `DelegatingHandler`
- [ ] [N/A] _..._

### 4. Data Protection
- [ ] TLS 1.3 cho data in transit — `UseHttpsRedirection` + HSTS header
- [ ] Encryption at rest cho sensitive field (PII, payment) — SQL Server Always Encrypted hoặc app-level (Data Protection API)
- [ ] KHÔNG log sensitive data — Serilog `Destructure.ByTransforming<T>` để redact
- [ ] PII masking trong non-prod environment — seed data hoặc anonymizer
- [ ] Secrets KHÔNG hardcode — User Secrets (dev), Key Vault / Secrets Manager (prod)
- [ ] [N/A] _..._

### 5. Rate Limiting & Abuse Prevention
- [ ] Global rate limit (per IP / per user) — `AddRateLimiter` + `GlobalLimiter`
- [ ] Auth endpoint throttling (stricter: 5 attempts / 15 min) — policy `"auth"`
- [ ] CAPTCHA hoặc proof-of-work sau N failed attempts
- [ ] Request size limit — `MaxRequestBodySize` config
- [ ] Query timeout — `CommandTimeout(30)` trên EF Core
- [ ] [N/A] _..._

### 6. Monitoring & Audit
- [ ] Security event logging — failed auth, permission deny, admin action, data export
- [ ] Correlation ID propagation — `X-Correlation-ID` header end-to-end
- [ ] Audit log immutable — append-only, có actor + target + timestamp + outcome
- [ ] Anomaly alert — failed auth > N/min, 5xx rate > 1%, unusual data egress
- [ ] Security headers — `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, CSP, HSTS
- [ ] CORS allowlist — KHÔNG `AllowAnyOrigin` trong prod
- [ ] [N/A] _..._
```

**Quy tắc fill (Actionability):**
- Mỗi control phải **mechanically implementable** — ghi rõ file/attribute/header/flag/package
- ❌ Sai: `- [x] Validate JWTs properly`
- ✅ Đúng: `- [x] In Program.cs, AddJwtBearer set TokenValidationParameters.ValidAlgorithms = ["HS256"] + ClockSkew = TimeSpan.Zero`
- Nếu một control `[N/A]`, ghi lý do — KHÔNG silently skip

---

## §C. Residual Risks Accepted — REQUIRED trong `PRE_DEV_REVIEW.md`

> **Template cố định — copy nguyên xi, agent điền feature-specific RR-N rows.**

```markdown
## Residual Risks Accepted

| # | Residual risk | Why accepted for v1 | v2 upgrade trigger |
|---|---------------|---------------------|---------------------|
| RR-1 | [vd: No account lockout sau N failed attempts] | [vd: single-user MVP, BCrypt cost 12 + rate-limit `auth` policy đã đủ defense-in-depth] | [vd: Public exposure HOẶC multi-user >100 active accounts] |
| RR-2 | [vd: No MFA] | [vd: B2B internal tool, customer chưa request] | [vd: Có customer trong regulated industry — finance/health] |
| RR-3 | ... | ... | ... |
```

**Quy tắc fill (Trigger discipline):**
- v2 trigger PHẢI là **observable condition** — đo được, kiểm tra được
- ❌ Sai: "when we have time", "in future iterations", "if needed"
- ✅ Đúng: "Khi DAU > 1000", "Khi có customer trong EU (GDPR)", "Khi feature `/export` được enable"
- Mỗi `[Deferred to v2 with trigger]` hoặc `[Accepted]` mitigation từ `STRIDE_TEMPLATE.md §D` **NÊN** có 1 row RR-N tương ứng

---

## Checklist tự kiểm (agent dùng trước khi submit)

- [ ] §A: bảng OWASP có đủ 10 hàng (A01–A10), KHÔNG bỏ trống Status hoặc Evidence
- [ ] §A: chỉ A06 được `Deferred to /scan`; các category khác phải `Addressed`/`Partial`/`N/A` với lý do
- [ ] §B: mọi control `[x]` có evidence mechanically verifiable (file/attribute/header/flag)
- [ ] §B: mọi control `[N/A]` có lý do giải thích
- [ ] §C: mỗi RR-N có v2 trigger là observable condition (đo được, không vague)
- [ ] §C: mỗi `Deferred to v2` / `Accepted` từ THREAT_MODEL có 1 RR-N tương ứng

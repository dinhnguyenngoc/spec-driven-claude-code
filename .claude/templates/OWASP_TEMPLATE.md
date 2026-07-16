# OWASP Top 10 + Security Requirements Template

> **Purpose:** Provide 3 fixed boilerplates for `/secure`:
> - §A — OWASP Top 10 (2021) compliance table (10-row skeleton)
> - §B — Default Security Requirements checklist (6 domains)
> - §C — Residual Risks Accepted table
>
> The `/secure` agent **only fills the Status + Evidence columns** (for §A), **marks applicable / not** (for §B), and **fills feature-specific RR-N rows** (for §C). Do NOT re-author the structure.

---

## §A. OWASP Top 10 (2021) Compliance Table — REQUIRED in `PRE_DEV_REVIEW.md`

> **Fixed 10-row table — copy verbatim, only fill the `Status` and `Evidence` columns.**

```markdown
## OWASP Top 10 (2021) Compliance

| # | Category | Status | Evidence |
|---|----------|--------|----------|
| A01 | Broken Access Control | [Addressed / Partial / N/A — <reason>] | [e.g.: `[Authorize]` class-level + composite predicate `WHERE Id = @id AND UserId = @uid`] |
| A02 | Cryptographic Failures | [...] | [e.g.: BCrypt cost 12; secrets via env var only; TLS 1.3 enforced in prod (`UseHttpsRedirection`)] |
| A03 | Injection | [...] | [e.g.: EF Core LINQ only; no `FromSqlRaw`; FluentValidation length caps on every input] |
| A04 | Insecure Design | [...] | [e.g.: This threat model + ADRs documenting trade-offs; Phase 3.5 deep dive] |
| A05 | Security Misconfiguration | [...] | [e.g.: `ExceptionHandlingMiddleware` at start of pipeline; developer exception page disabled non-Dev; security headers via middleware] |
| A06 | Vulnerable & Outdated Components | Deferred to `/scan` | SCA gate enforced post-build (`dotnet list package --vulnerable`, `npm audit`, Trivy) |
| A07 | Identification & Authentication Failures | [...] | [e.g.: BCrypt cost 12 + rate-limit `auth` policy + strong password policy (8+/upper/lower/digit/symbol)] |
| A08 | Software & Data Integrity Failures | [...] | [e.g.: JWT `ValidateIssuerSigningKey = true`; algorithm pinned `ValidAlgorithms = ["HS256"]`; `ClockSkew = Zero`] |
| A09 | Security Logging & Monitoring Failures | [...] | [e.g.: Serilog destructure-redact `PasswordHash`/`Token`; failed auth log Warning level; `/health` endpoint] |
| A10 | Server-Side Request Forgery (SSRF) | [...] | [e.g.: See Phase 3.5 deep dive — URL scheme allowlist + DNS rebinding mitigation + cloud-metadata-IP block] |
```

**Status options (standard — do not add other options):**
- **Addressed** — controls complete, with concrete evidence
- **Partial** — some controls present, record residual risk in §C
- **N/A** — not applicable to this feature, record reason
- **Deferred to `/scan`** — only accepted for A06

**Fill rules:**
- Do NOT leave any cell blank (10 rows × 2 data columns = 20 mandatory cells)
- Evidence must be **mechanically verifiable** — only file/attribute/header/flag names, no vague wording like "validate properly"

---

## §B. Default Security Requirements Checklist — REQUIRED in `SECURITY_REQUIREMENTS.md`

> **6 fixed domains — copy verbatim. The agent marks `[x]` for every applicable control + adds evidence/file reference; marks `[N/A]` if not applicable (with reason).**

```markdown
## Security Requirements

### 1. Authentication
- [ ] JWT with short expiry (≤15 min access token) — file: `Program.cs` `AddJwtBearer.TokenValidationParameters`
- [ ] Refresh token rotation (≤7 days, single-use, invalidate on reuse) — entity: `RefreshToken`
- [ ] Password hashing with BCrypt cost ≥12 — service: `IPasswordHasher`
- [ ] MFA for sensitive operations (admin action, payment, password change) — flag: `RequireMfaAttribute`
- [ ] Account lockout after N failed attempts (e.g.: 5 within 15 minutes) — middleware: `AccountLockoutMiddleware`
- [ ] [N/A] _List controls that do not apply + reason_

### 2. Authorization
- [ ] Role-Based Access Control (RBAC) — `[Authorize(Roles = "...")]` or policy
- [ ] Resource ownership validation — predicate `WHERE Id = @id AND UserId = @currentUser`
- [ ] Principle of least privilege — DB user has minimal privileges (no `db_owner`)
- [ ] IDOR prevention — do NOT expose sequential ID; use GUID or opaque token
- [ ] [N/A] _..._

### 3. Input Validation
- [ ] Schema validation (FluentValidation) on every input DTO — assembly: `*.Validators`
- [ ] Parameterized queries only — EF Core LINQ / Dapper with `@param`, no `FromSqlRaw` with user input
- [ ] HTML sanitization for user-generated content — library: `Ganss.Xss` (`HtmlSanitizer`)
- [ ] File upload validation: MIME type whitelist + magic-byte check + size cap
- [ ] URL whitelist for outbound HTTP requests (SSRF protection) — `HttpClient` factory with `DelegatingHandler`
- [ ] [N/A] _..._

### 4. Data Protection
- [ ] TLS 1.3 for data in transit — `UseHttpsRedirection` + HSTS header
- [ ] Encryption at rest for sensitive fields (PII, payment) — SQL Server Always Encrypted or app-level (Data Protection API)
- [ ] Do NOT log sensitive data — Serilog `Destructure.ByTransforming<T>` to redact
- [ ] PII masking in non-prod environments — seed data or anonymizer
- [ ] Secrets NOT hardcoded — User Secrets (dev), Key Vault / Secrets Manager (prod)
- [ ] [N/A] _..._

### 5. Rate Limiting & Abuse Prevention
- [ ] Global rate limit (per IP / per user) — `AddRateLimiter` + `GlobalLimiter`
- [ ] Auth endpoint throttling (stricter: 5 attempts / 15 min) — policy `"auth"`
- [ ] CAPTCHA or proof-of-work after N failed attempts
- [ ] Request size limit — `MaxRequestBodySize` config
- [ ] Query timeout — `CommandTimeout(30)` on EF Core
- [ ] [N/A] _..._

### 6. Monitoring & Audit
- [ ] Security event logging — failed auth, permission deny, admin action, data export
- [ ] Correlation ID propagation — `X-Correlation-ID` header end-to-end
- [ ] Audit log immutable — append-only, with actor + target + timestamp + outcome
- [ ] Anomaly alert — failed auth > N/min, 5xx rate > 1%, unusual data egress
- [ ] Security headers — `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, CSP, HSTS
- [ ] CORS allowlist — no `AllowAnyOrigin` in prod
- [ ] [N/A] _..._
```

**Fill rules (Actionability):**
- Every control must be **mechanically implementable** — clearly state the file/attribute/header/flag/package
- ❌ Wrong: `- [x] Validate JWTs properly`
- ✅ Right: `- [x] In Program.cs, AddJwtBearer set TokenValidationParameters.ValidAlgorithms = ["HS256"] + ClockSkew = TimeSpan.Zero`
- If a control is `[N/A]`, record the reason — do NOT silently skip

---

## §C. Residual Risks Accepted — REQUIRED in `PRE_DEV_REVIEW.md`

> **Fixed template — copy verbatim, the agent fills feature-specific RR-N rows.**

```markdown
## Residual Risks Accepted

| # | Residual risk | Why accepted for v1 | v2 upgrade trigger |
|---|---------------|---------------------|---------------------|
| RR-1 | [e.g.: No account lockout after N failed attempts] | [e.g.: single-user MVP, BCrypt cost 12 + rate-limit `auth` policy already sufficient defense-in-depth] | [e.g.: Public exposure OR multi-user >100 active accounts] |
| RR-2 | [e.g.: No MFA] | [e.g.: B2B internal tool, customer has not requested it] | [e.g.: A customer in a regulated industry — finance/health] |
| RR-3 | ... | ... | ... |
```

**Fill rules (Trigger discipline):**
- v2 trigger MUST be an **observable condition** — measurable, checkable
- ❌ Wrong: "when we have time", "in future iterations", "if needed"
- ✅ Right: "When DAU > 1000", "When there is a customer in the EU (GDPR)", "When the `/export` feature is enabled"
- Every `[Deferred to v2 with trigger]` or `[Accepted]` mitigation from `STRIDE_TEMPLATE.md §D` **MUST** have a corresponding RR-N row

---

## Self-check checklist (agent uses before submitting)

- [ ] §A: the OWASP table has all 10 rows (A01–A10), with no blank Status or Evidence
- [ ] §A: only A06 may be `Deferred to /scan`; other categories must be `Addressed`/`Partial`/`N/A` with a reason
- [ ] §B: every `[x]` control has mechanically verifiable evidence (file/attribute/header/flag)
- [ ] §B: every `[N/A]` control has an explanatory reason
- [ ] §C: every RR-N has a v2 trigger that is an observable condition (measurable, not vague)
- [ ] §C: every `Deferred to v2` / `Accepted` from THREAT_MODEL has a corresponding RR-N

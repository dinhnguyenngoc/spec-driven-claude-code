---
name: scan
description: Post-development security scanning and vulnerability assessment
---

# /scan — Security Scan

> "Trust but verify."

## Purpose

Comprehensive security scan of completed code **before deployment**. Detect vulnerabilities, insecure dependencies, and security misconfigurations.

## Prerequisites

**Required:**
- Code implementation complete (`/build` done)
- Tests passing (`/test` done)

**Optional (if available):**
- Code review approved (`reports/CODE_REVIEW.md` from `/review`)

**Quick reference:** [`references/security-checklist.md`](../references/security-checklist.md) — pre-deploy security verification checklist (cross-check before composing SCAN_REPORT).

**Automation script (đã chuẩn bị sẵn — agent KHÔNG chạy thủ công từng tool):**
- [`.claude/scripts/scan-all.sh`](../scripts/scan-all.sh) — chạy mọi scanner có sẵn, fallback nếu missing
- [`.claude/scripts/scan-summarize.py`](../scripts/scan-summarize.py) — merge output → `security/SCAN_SUMMARY.json`

---

## Workflow

> **Nguyên tắc tối ưu thời gian:** Toàn bộ tooling execution (gitleaks, semgrep, dotnet vuln, npm audit, trivy, hadolint, ESLint, XSS grep, secrets grep, Roslyn analyzers) đã được script hoá. Agent chỉ chạy **1 lệnh** và đọc **1 file summary** thay vì gõ ~25 commands tuần tự.
>
> **Phần CẦN não bộ agent (không tự động hoá):** STRIDE re-evaluation matrix + Finding triage + Approval narrative. Đây là Phase 2–4 dưới đây.

### Phase 0: Run Automation Script (1 lệnh duy nhất)

```bash
bash .claude/scripts/scan-all.sh
```

Script tự làm:
1. **Tool inventory** → `security/sast-results/tooling-availability.txt`
2. **Secrets scan** (gitleaks → fallback regex grep nếu missing)
3. **.NET dependency vuln** (`dotnet list package --vulnerable`, loop qua từng .csproj nếu không có .sln)
4. **Roslyn analyzers** (`dotnet build /p:RunAnalyzers=true -warnaserror`)
5. **Semgrep** (csharp + security-audit + owasp-top-ten configs, nếu có)
6. **Frontend** — `npm audit` (prod + full), `eslint --max-warnings=0`, XSS pattern grep (nếu có `web/`)
7. **Container** — `trivy image` (nếu image đã build) + `trivy fs` + `hadolint` (nếu có Dockerfile)
8. **Summarize** → `security/SCAN_SUMMARY.json` với findings đã chuẩn hoá severity

**Compensating control matrix** — script tự ghi vào `SCAN_SUMMARY.json §compensating_controls` khi tool missing. Agent KHÔNG cần tự build matrix.

**Output files:**

```text
security/
├── SCAN_SUMMARY.json                    # ← agent đọc file NÀY trước tiên
├── sast-results/
│   ├── tooling-availability.txt
│   ├── scan-all.log
│   ├── gitleaks.json (hoặc secrets-grep.txt)
│   ├── roslyn.log
│   ├── semgrep.json
│   ├── eslint.json
│   ├── frontend-xss-grep.txt
│   └── hadolint.json
├── dependency-audit/
│   ├── nuget-vulnerable.json
│   ├── nuget-outdated.txt
│   ├── npm-audit.json (production runtime)
│   ├── npm-audit-full.json (incl. dev — informational)
│   └── npm-outdated.json
└── container-scan/
    ├── trivy-fs.json
    └── trivy-<image>.json
```

### Phase 1: Đọc SCAN_SUMMARY.json

```bash
jq '.' security/SCAN_SUMMARY.json | less
# hoặc
python3 -c "import json; s=json.load(open('security/SCAN_SUMMARY.json')); print(f'Totals: {s[\"totals\"]}'); print(f'Tools missing: {s[\"tools_missing\"]}')"
```

`SCAN_SUMMARY.json` schema:

```json
{
  "scan_date": "YYYY-MM-DD HH:MM:SS",
  "totals": {"critical": N, "high": N, "medium": N, "low": N, "unknown": N},
  "tools_installed": ["dotnet", "semgrep", ...],
  "tools_missing": ["gitleaks", "trivy", ...],
  "compensating_controls": [{"missing_tool": "...", "fallback_used": "...", "must_add_to_pipeline": true}],
  "findings": [
    {"id": "F-001", "source": "...", "severity": "...", "category": "...", "title": "...", "file": "path:line", "details": "...", "fix": "..."}
  ]
}
```

### Phase 2: STRIDE Re-evaluation (MANDATORY nếu có `security/THREAT_MODEL.md`)

**Đây là phần agent BẮT BUỘC tự làm — script không tự động hoá được vì cần đọc file:line trong source code và verify mitigation logic.**

Walk **mọi** threat ID trong `security/THREAT_MODEL.md` và confirm mitigation đã sống trong code. Đây là artifact load-bearing nhất `/scan` produces — chứng minh threat model không phải paperwork.

Status legend (dùng đúng các giá trị này):
- **Verified** — code + tests prove mitigation
- **Partial** — implemented nhưng có gap (link gap → Finding F-### trong SCAN_SUMMARY)
- **Deferred** — explicitly accepted với trigger condition còn valid (link → §Accepted MVP Risks)
- **Not implemented** — missing; MUST surface as Finding F-### mới

1 subsection / STRIDE category:

```markdown
### Spoofing
| ID | Threat | Status | Evidence |
|---|---|---|---|
| S1 | <threat name> | Verified | [File.cs:NN](../src/...#LNN); brief one-line reason |
| S2 | … | Partial → F-M2 | … |

### Tampering
…
(repeat for R, I, D, E)
```

End tally:

```markdown
**Totals**: NN Verified, NN Partial, NN Not implemented, NN Deferred — out of NN threats total.
```

Bất kỳ **Not implemented** count > 0 means ít nhất 1 Finding open against pre-dev threat — gate decision phải reference nó trong §Approval.

### Phase 3: Live Verification (MANDATORY cho high-risk surface)

Static analysis catches code patterns. Live verification proves **running binary** refuses attack. Script KHÔNG tự chạy live test (cần test framework đã setup). Agent identify các surface cần test:

| Surface | Trigger condition | Required live test |
|---|---|---|
| **SSRF** | Code path fetches user-supplied URL (URL preview, webhook, image proxy, RSS, OAuth callback) | Integration test DI-resolve REAL fetcher, attempt: `127.0.0.1`, RFC1918 (`10.x`, `192.168.x`, `172.16.x`), `169.254.169.254` (AWS metadata), `fe80::`, `file://`, `gopher://`, `ftp://`, `dict://`. Assert ALL blocked + 1 positive control pass. |
| **File upload** | Endpoint nhận `multipart/form-data` | Test upload: (a) oversize, (b) MIME/magic-byte mismatch, (c) `evil.jpg.exe`, (d) `../../etc/passwd`, (e) zip bomb. Assert reject at boundary. |
| **Auth bypass / IDOR** | `[Authorize]` hoặc ownership-checked endpoint | Test: (a) no token, (b) expired, (c) wrong-key signed, (d) user A token accessing user B resource. Assert 401/404 (NOT 403 — leaks existence). |

Tag tests với `[Trait("Category", "RequiresNetwork")]` để default `dotnet test` không pick up. Chạy explicitly trong `/scan` và cite file path + pass count trong report.

> **Why mandatory:** SAST-clean result KHÔNG chứng minh binary block attack. Chỉ live probe mới làm được.

### Phase 4: Compose SCAN_REPORT.md

Agent tự viết `security/SCAN_REPORT.md` từ inputs:
- `SCAN_SUMMARY.json` — findings + totals + tools_missing + compensating_controls
- STRIDE re-eval matrix (Phase 2 trên)
- Live verification results (Phase 3 trên)
- OWASP Top 10 checklist (đã cover trong `OWASP_TEMPLATE.md §A` từ `/secure`)

Template ở §Scan Report Template phía dưới.

---

## Scan Report Template

```markdown
# Security Scan Report

## Summary
- **Date**: <from SCAN_SUMMARY.json scan_date>
- **Commit**: [SHA]
- **Tools run**: <from SCAN_SUMMARY.json tools_installed>
- **Tools missing + compensating controls**: <from SCAN_SUMMARY.json compensating_controls>
- **Overall Status**: [PASS/FAIL]

## Pre-Dev Security Review (if applicable)

| Item | Status |
|------|--------|
| THREAT_MODEL.md | Found / Not found |
| Open mitigations | 0 / N |
| Verification | PASS / FAIL / SKIPPED |

## STRIDE Re-evaluation — Threat-Model Verification (MANDATORY if `security/THREAT_MODEL.md` exists)

[Insert STRIDE matrix từ Phase 2 — 1 subsection per category + Totals tally]

## Findings Summary (auto-aggregated từ SCAN_SUMMARY.json)

| Severity | Count |
|----------|-------|
| Critical | <totals.critical> |
| High     | <totals.high> |
| Medium   | <totals.medium> |
| Low      | <totals.low> |

## Critical/High Findings

[Liệt kê từ SCAN_SUMMARY.json findings nơi severity in (Critical, High). Mỗi finding theo format:]

### [F-NNN] <title>
- **Severity**: <severity>
- **Source**: <source tool>
- **Location**: <file>
- **Details**: <details>
- **Remediation**: <fix>
- **Status**: [OPEN / FIXED in commit <sha>]

## Dependency Vulnerabilities

[Filter findings where category == "dependency" — bảng package + severity + fix]

## OWASP Top 10 Compliance

[Tham chiếu sang OWASP_TEMPLATE.md §A đã fill trong /secure — kiểm lại Status còn đúng không sau khi code thực sự ship]

| Category | Status | Notes |
|----------|--------|-------|
| A01: Broken Access Control | PASS/FAIL | <evidence file:line> |
| ... (đủ 10 hàng A01–A10) | | |

## Live Verification (Phase 3)

| Surface | Test file | Pass count | Status |
|---------|-----------|------------|--------|
| SSRF | `LiveSsrfProbeTests.cs` | 13/13 | PASS |
| File upload | `FileUploadSecurityTests.cs` | N/A or X/Y | PASS/FAIL/N-A |
| Auth bypass / IDOR | `AuthBypassTests.cs` | X/Y | PASS/FAIL |

## Recommendations

> Priority vocabulary — `/deploy` cross-references chính các tag này (RELEASE_NOTES §3 "Hardening landed", DEPLOY_RUNBOOK §1 "/scan P0 items implemented"):
> **[P0]** = must implement BEFORE promote · **[P1]** = next release · **[P2]** = backlog.

1. **[P0]** <finding bắt buộc xử lý trước khi promote — cross-ref F-###>
2. **[P1]** <finding cho release kế tiếp — cross-ref F-###>
3. **[P2]** <từ findings Medium/Low — backlog>


## Approval

| Role | Name | Date | Decision |
|------|------|------|----------|
| Security Lead | | | APPROVED/REJECTED |
```

---

## Quality Gate 8 — Security Scan ⛔ BLOCKING

> Step optional per CLAUDE.md §Quality Gates — **BLOCKING if run**.

**Deployment CANNOT proceed** if:

- Any **Critical** vulnerability trong `SCAN_SUMMARY.json` (`totals.critical > 0`)
- Any **High** vulnerability without approved exception (`totals.high > 0` trừ khi có exception ghi rõ)
- OWASP Top 10 checks fail (any category ≠ PASS/N/A)
- Security Lead has not approved
- **STRIDE Re-evaluation matrix is missing** khi `security/THREAT_MODEL.md` exists — every threat ID phải có `Verified / Partial / Deferred / Not implemented` status với file:line evidence
- Compensating control trong `SCAN_SUMMARY.json §compensating_controls` có `must_add_to_pipeline: true` nhưng chưa được flagged trong report

## Severity Definitions

| Severity | Definition | SLA |
|----------|------------|-----|
| Critical | Exploitable, high impact, public-facing | Block deploy, fix immediately |
| High | Exploitable with effort, significant impact | Fix before deploy |
| Medium | Limited exploitability or impact | Fix within sprint |
| Low | Minimal risk | Fix when convenient |

---

## Agent

Invoke: **Security Auditor**

```text
"As Security Auditor, perform security scan.
1. Chạy: bash .claude/scripts/scan-all.sh
2. Đọc: security/SCAN_SUMMARY.json
3. Làm STRIDE re-eval matrix (Phase 2) — verify mọi threat ID trong THREAT_MODEL.md
4. Identify live verification tests cần thiết (Phase 3) cho high-risk surface
5. Compose security/SCAN_REPORT.md theo template
6. Output language: Vietnamese for prose, English for technical identifiers
   (see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After scan passed, run `/infra` for infrastructure setup.

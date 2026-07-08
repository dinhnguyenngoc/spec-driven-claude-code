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

**Automation script (already prepared — the agent does NOT run each tool manually):**
- [`.claude/scripts/scan-all.sh`](../scripts/scan-all.sh) — runs every available scanner, with a fallback if one is missing
- [`.claude/scripts/scan-summarize.py`](../scripts/scan-summarize.py) — merges output → `security/SCAN_SUMMARY.json`

---

## Workflow

> **Time-optimization principle:** The entire tooling execution (gitleaks, semgrep, dotnet vuln, npm audit, trivy, hadolint, ESLint, XSS grep, secrets grep, Roslyn analyzers) is already scripted. The agent runs just **1 command** and reads **1 summary file** instead of typing ~25 commands sequentially.
>
> **The part that NEEDS the agent's brain (not automated):** STRIDE re-evaluation matrix + Finding triage + Approval narrative. These are Phase 2–4 below.

### Phase 0: Run Automation Script (a single command)

```bash
bash .claude/scripts/scan-all.sh
```

> **Script architecture:** Phase 1 inventory + **auto-detect stack** → Phase 2 universal (secrets) → Phase 3 **dispatch per-stack** via `scripts/scanners/{dotnet,nodejs,python,docker}.sh` → Phase 4 summarize. The list below is the **union** of scans that may run; any step that does not match the detected stack is skipped automatically.

The script does automatically:
1. **Tool inventory** → `security/sast-results/tooling-availability.txt`
2. **Secrets scan** (gitleaks → fallback regex grep if missing)
3. **.NET dependency vuln** (`dotnet list package --vulnerable`, looping over each .csproj if there is no .sln)
4. **Roslyn analyzers** (`dotnet build /p:RunAnalyzers=true -warnaserror`)
5. **Semgrep** (csharp + security-audit + owasp-top-ten configs, if available)
6. **Frontend** — `npm audit` (prod + full), `eslint --max-warnings=0`, XSS pattern grep (if `web/` exists)
7. **Container** — `trivy image` (if the image is built) + `trivy fs` + `hadolint` (if a Dockerfile exists)
8. **Summarize** → `security/SCAN_SUMMARY.json` with findings normalized by severity

**Compensating control matrix** — the script writes it into `SCAN_SUMMARY.json §compensating_controls` automatically when a tool is missing. The agent does NOT need to build the matrix itself.

**Output files:**

```text
security/
├── SCAN_SUMMARY.json                    # ← the agent reads THIS file first
├── sast-results/
│   ├── tooling-availability.txt
│   ├── scan-all.log
│   ├── gitleaks.json (or secrets-grep.txt)
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

### Phase 1: Read SCAN_SUMMARY.json

```bash
jq '.' security/SCAN_SUMMARY.json | less
# or
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

### Phase 2: STRIDE Re-evaluation (MANDATORY if `security/THREAT_MODEL.md` exists)

**This is the part the agent MUST do itself — the script cannot automate it because it requires reading file:line in the source code and verifying mitigation logic.**

Walk **every** threat ID in `security/THREAT_MODEL.md` and confirm the mitigation lives in the code. **If `security/PRE_DEV_REVIEW.md` exists, also walk every `RC-X.Y` Required Control** (minted by `/secure`) — confirm it is implemented + cite file:line, using the same status legend below; an RC that is `Not implemented` → a new Finding F-### (feeds Gate 8 like a threat). This is the most load-bearing artifact `/scan` produces — it proves the threat model + required controls are not paperwork.

Status legend (use exactly these values):
- **Verified** — code + tests prove mitigation
- **Partial** — implemented but has a gap (link the gap → Finding F-### in SCAN_SUMMARY)
- **Deferred** — explicitly accepted with a trigger condition still valid (link → §Accepted MVP Risks)
- **Not implemented** — missing; MUST surface as a new Finding F-###

1 subsection per STRIDE category:

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

Any **Not implemented** count > 0 means at least 1 Finding open against a pre-dev threat — the gate decision must reference it in §Approval.

### Phase 3: Live Verification (MANDATORY cho high-risk surface)

Static analysis catches code patterns. Live verification proves the **running binary** refuses attack. The script does NOT run live tests itself (it needs a test framework already set up). The agent identifies the surfaces that need testing:

| Surface | Trigger condition | Required live test |
|---|---|---|
| **SSRF** | Code path fetches user-supplied URL (URL preview, webhook, image proxy, RSS, OAuth callback) | Integration test DI-resolve REAL fetcher, attempt: `127.0.0.1`, RFC1918 (`10.x`, `192.168.x`, `172.16.x`), `169.254.169.254` (AWS metadata), `fe80::`, `file://`, `gopher://`, `ftp://`, `dict://`. Assert ALL blocked + 1 positive control pass. |
| **File upload** | Endpoint accepts `multipart/form-data` | Test upload: (a) oversize, (b) MIME/magic-byte mismatch, (c) `evil.jpg.exe`, (d) `../../etc/passwd`, (e) zip bomb. Assert reject at boundary. |
| **Auth bypass / IDOR** | `[Authorize]` or ownership-checked endpoint | Test: (a) no token, (b) expired, (c) wrong-key signed, (d) user A token accessing user B resource. Assert 401/404 (NOT 403 — leaks existence). |

Tag tests with `[Trait("Category", "RequiresNetwork")]` so the default `dotnet test` does not pick them up. Run them explicitly in `/scan` and cite the file path + pass count in the report.

> **Why mandatory:** A SAST-clean result does NOT prove the binary blocks the attack. Only a live probe can.

### Phase 4: Compose SCAN_REPORT.md

The agent writes `security/SCAN_REPORT.md` itself from these inputs:
- `SCAN_SUMMARY.json` — findings + totals + tools_missing + compensating_controls
- STRIDE re-eval matrix (Phase 2 above)
- Live verification results (Phase 3 above)
- OWASP Top 10 checklist (already covered in `OWASP_TEMPLATE.md §A` from `/secure`)

The template is in §Scan Report Template below.

---

## Scan Report Template

```markdown
# Security Scan Report

## Summary
- **Date**: <from SCAN_SUMMARY.json scan_date>
- **Commit**: [SHA]
- **Tools run**: <from SCAN_SUMMARY.json tools_installed>
- **Tools missing + compensating controls**: <from SCAN_SUMMARY.json compensating_controls>
- **SAST scope**: <from SCAN_SUMMARY.json sast_scope — "whole-repo" or "semgrep diff vs <base>; other scans whole-repo">
- **Overall Status**: [PASS/FAIL]

## Pre-Dev Security Review (if applicable)

| Item | Status |
|------|--------|
| THREAT_MODEL.md | Found / Not found |
| Open mitigations | 0 / N |
| Verification | PASS / FAIL / SKIPPED |

## STRIDE Re-evaluation — Threat-Model Verification (MANDATORY if `security/THREAT_MODEL.md` exists)

[Insert STRIDE matrix from Phase 2 — 1 subsection per category + Totals tally]

## Findings Summary (auto-aggregated from SCAN_SUMMARY.json)

| Severity | Count |
|----------|-------|
| Critical | <totals.critical> |
| High     | <totals.high> |
| Medium   | <totals.medium> |
| Low      | <totals.low> |

## Critical/High Findings

[List from SCAN_SUMMARY.json findings where severity is in (Critical, High). Each finding follows the format:]

### [F-NNN] <title>
- **Severity**: <severity>
- **Source**: <source tool>
- **Location**: <file>
- **Details**: <details>
- **Remediation**: <fix>
- **Status**: [OPEN / FIXED in commit <sha>]

## Dependency Vulnerabilities

[Filter findings where category == "dependency" — a table of package + severity + fix]

## OWASP Top 10 Compliance

[Cross-reference the OWASP_TEMPLATE.md §A already filled in during /secure — re-check whether the Status is still correct after the code actually ships]

| Category | Status | Notes |
|----------|--------|-------|
| A01: Broken Access Control | PASS/FAIL | <evidence file:line> |
| ... (all 10 rows A01–A10) | | |

## Live Verification (Phase 3)

| Surface | Test file | Pass count | Status |
|---------|-----------|------------|--------|
| SSRF | `LiveSsrfProbeTests.cs` | 13/13 | PASS |
| File upload | `FileUploadSecurityTests.cs` | N/A or X/Y | PASS/FAIL/N-A |
| Auth bypass / IDOR | `AuthBypassTests.cs` | X/Y | PASS/FAIL |

## Recommendations

> Priority vocabulary — `/deploy` cross-references exactly these tags (RELEASE_NOTES §3 "Hardening landed", DEPLOY_RUNBOOK §1 "/scan P0 items implemented"):
> **[P0]** = must implement BEFORE promote · **[P1]** = next release · **[P2]** = backlog.

1. **[P0]** <finding that must be handled before promoting — cross-ref F-###>
2. **[P1]** <finding for the next release — cross-ref F-###>
3. **[P2]** <from Medium/Low findings — backlog>


## Approval

| Role | Name | Date | Decision |
|------|------|------|----------|
| Security Lead | | | APPROVED/REJECTED |
```

---

## Brownfield Mode (when `Project Profile → Mode: brownfield`)

For a **large legacy repo**, a per-change `/scan` should not re-run whole-tree **semgrep** every time (it re-surfaces thousands of pre-existing legacy findings + is slow). Scope **semgrep only**:

- **Set the diff base** so semgrep scopes to the change (everything else stays whole-repo):
  ```bash
  SCAN_DIFF_BASE=origin/main bash .claude/scripts/scan-all.sh
  ```
  semgrep then runs only on files changed since the merge-base with `origin/main` (committed **and** uncommitted). If the base can't be resolved, the script **falls back to a whole-repo semgrep** — it never silently skips.
- **Everything else stays whole-repo** — SCA (`dotnet list --vulnerable`, `npm audit`, `retire`, `trivy`), secrets (gitleaks), Roslyn analyzers, ESLint, XSS-grep. A vulnerable dependency or leaked secret anywhere is in scope regardless of the diff; the script enforces this — only semgrep is scoped.
- **Disclosure is mandatory** — `SCAN_SUMMARY.json.sast_scope` records the scope; carry it into `SCAN_REPORT.md §Summary`. A diff-scoped scan must never be presented as a full scan.
- **Keep a periodic FULL baseline** — run `/scan` **without** `SCAN_DIFF_BASE` before a release (or on a cadence) so semgrep's cross-file rules + newly-reachable legacy code are covered. Per-change = semgrep diff; baseline = whole-repo.

> Greenfield / baseline run: do **not** set `SCAN_DIFF_BASE` → full whole-repo scan (unchanged behavior).

## Quality Gate 8 — Security Scan ⛔ BLOCKING

> Step optional per CLAUDE.md §Quality Gates — **BLOCKING if run**.

**Deployment CANNOT proceed** if:

- Any **Critical** vulnerability in `SCAN_SUMMARY.json` (`totals.critical > 0`)
- Any **High** vulnerability without approved exception (`totals.high > 0` unless there is an explicitly recorded exception)
- OWASP Top 10 checks fail (any category ≠ PASS/N/A)
- Security Lead has not approved
- **STRIDE Re-evaluation matrix is missing** when `security/THREAT_MODEL.md` exists — every threat ID must have a `Verified / Partial / Deferred / Not implemented` status with file:line evidence
- A compensating control in `SCAN_SUMMARY.json §compensating_controls` has `must_add_to_pipeline: true` but is not flagged in the report
- **A diff-scoped scan is not disclosed** — if `SCAN_SUMMARY.json.sast_scope` ≠ `"whole-repo"` but the report does NOT state the scope, OR this release has no recent full whole-repo baseline scan (newly-reachable code not yet covered)

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
1. Run: bash .claude/scripts/scan-all.sh
2. Read: security/SCAN_SUMMARY.json
3. Do the STRIDE re-eval matrix (Phase 2) — verify every threat ID in THREAT_MODEL.md
4. Identify the live verification tests needed (Phase 3) for high-risk surfaces
5. Compose security/SCAN_REPORT.md per the template
6. Output language: Vietnamese for prose, English for technical identifiers
   (see .claude/CLAUDE.md → Output Language)."
```

## Next Step

After scan passed, run `/infra` for infrastructure setup.

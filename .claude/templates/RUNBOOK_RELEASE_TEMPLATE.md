# DEPLOY_RUNBOOK + RELEASE_NOTES Template — `/deploy` Output Boilerplate

> **Purpose:** Fixed framework for the 2 mandatory `/deploy` artifacts. The agent (Release Manager) **only fills** — does NOT re-author the structure.
>
> Detailed rules (all-or-nothing gate, digest match, never `:latest`): [`../commands/deploy.md`](../commands/deploy.md) §Required artifacts.

---

## §A. `reports/DEPLOY_RUNBOOK.md` skeleton — 8 mandatory sections

````markdown
# Deploy Runbook — <product> v<X.Y.Z> (STAGING)

## 1. Pre-deploy checklist
Docker daemon up, `.env` present, /scan P0 items implemented, current image tags noted for rollback.

## 2. Deploy (staging)
Exact build + up commands. Image tagging with `:v<X.Y.Z>` (never `:latest`).

## 3. Post-deploy smoke verification
**Explicitly list every service** in compose + expected status (`Up (healthy)` or `Up` + whitelist note). This section MUST contain a table with columns `Service | Image tag | Expected status | Actual status | Healthcheck command`. A missing service = deploy did not pass the gate, no "STAGED" release notes produced.

Then: concrete `curl` smoke commands hitting `/health`, `/health/ready`, `/api/v1/version` (or your project's smoke endpoint), and 1-2 happy-path API calls. Each with expected response.

## 4. Rollback (target < 1 minute — valid while the schema stays backward-compatible with the previous image)
**Rollback path for THIS release (mandatory — `/deploy` Exit Criteria requires it; `/hotfix` Step-1 triage reads it):** image-tag (no schema change / schema backward-compatible) · expand-contract phase in flight (name the phase) · backup-restore (state RTO + the data-loss window). Then: stop + restart with previous image tag (or the stated alternative). Database rollback notes (and pre-deploy backup pointer if migrations are involved). After rollback: re-run §3 smoke pack — rollback is not complete until smoke passes.

## 5. Common operations
Logs, restart, shell access, cleanup commands.

## 6. Troubleshooting
Top 3-5 known failure modes with diagnostic + fix. Link to `docs/troubleshooting.md` for developer-facing issues.

## 7. Escalation
On-call contact, severity thresholds, when to roll back vs hold.

## 8. Promote production (MANUAL — outside kit scope)
> The kit stops at `STAGED`. This section is a HANDOFF document for whoever performs the promote after
> the human test team approves on staging. The promoter follows the checklist; the kit does not automate this step.

- **Digest pin (MOST IMPORTANT):** production MUST run exactly the image digest the test team approved:
  `<api-image>@sha256:<digest>` (+ web/worker if any — copy from `reports/verify-artifact.lock`).
  **Do NOT rebuild from source** — a rebuild produces a new digest ⇒ all test/UAT results on staging become INVALID.
- **Move the exact image:** via registry (`docker push/pull <image>@sha256:…`) or `docker save | docker load`.
  After pulling to production: `docker inspect --format='{{.Id}}'` must == the digest pinned above.
- **Diff config staging ↔ production (checklist to review before up):** env vars & secrets (JWT, connection
  string), `ASPNETCORE_ENVIRONMENT`/`NODE_ENV`, CORS allowlist/origins, security headers (HSTS/CSP),
  Swagger/debug endpoints MUST be disabled, ports/TLS/reverse-proxy, migration strategy on the production DB
  (back up BEFORE applying).
- **Prod smoke after promote:** re-run the exact curl pack from §3 pointed at the production URL + 1 happy-path
  that writes to the DB. Smoke fail → roll back production immediately (section below), do not keep a broken build "to watch".
- **Rollback production:** record the image tag/digest of the production build CURRENTLY running before promoting;
  the revert procedure = §4 applied to the production environment.
- **Recording (audit):** fill the "Production promote (manual)" section in `RELEASE_NOTES` — date, promoter,
  digest, smoke result. Not filled = the promote is not complete on the record.
````

## §B. `reports/RELEASE_NOTES_v<X.Y.Z>.md` skeleton — 6 sections (1 file / release tag; §1–5 filled by the kit when STAGED, §6 filled MANUALLY when promoting production)

````markdown
# <product> — Release Notes v<X.Y.Z>

- **Version**: <X.Y.Z>
- **Release date**: YYYY-MM-DD
- **Container tags**: `<api-image>:<X.Y.Z>`, `<spa-image>:<X.Y.Z>` (etc.)
- **Status**: STAGED / FAILED / ROLLED-BACK  *(STAGED = the highest Status the kit declares on its own; "SUCCEEDED (production)" is only filled MANUALLY in the "Production promote" section below, after a manual promote + prod smoke pass)*

## 1. Summary
One paragraph: what this release ships, the MVP/scope boundary, what's NOT in it.

## 2. Quality gates passed
Reference each gate (1-10) with link to its artifact (`reports/CODE_REVIEW.md`, `reports/TEST_REPORT.md`, `security/SCAN_REPORT.md`, etc.). Note any documented exceptions.

## 3. Hardening landed in this release
List every P0/P1 item from `security/SCAN_REPORT.md` §Recommendations that this release implements. Cross-reference `F-#` IDs.

## 4. Rollback procedure
Image tags to revert to, DB rollback notes, smoke verification. Link to `reports/DEPLOY_RUNBOOK.md` §4.

## 5. Sign-off
Release Manager, Tech Lead, Security Auditor — each with date + decision.
**QA/UAT lead** (after the human test round on staging): date + go/no-go + notes — missing this line means NOT yet promoted.

## 6. Production promote (manual — filled MANUALLY after the promote, outside kit scope)
| Field | Value |
|--------|---------|
| Promote date | YYYY-MM-DD |
| Promoter | <name> |
| Promoted digest (== approved staging digest) | `sha256:…` |
| Prod smoke (§3 curl pack on the production URL) | PASS / FAIL |
| Final status | SUCCEEDED (production) / ROLLED-BACK |
> Detailed procedure: `DEPLOY_RUNBOOK §8`. This table not filled = the release stops at STAGED.
````

> `CHANGELOG.md` (Deliverable #3) uses the Keep a Changelog format — entry template at [`../agents/release-manager.md`](../agents/release-manager.md) §CHANGELOG Entry Template.

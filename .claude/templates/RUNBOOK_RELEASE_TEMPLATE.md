# DEPLOY_RUNBOOK + RELEASE_NOTES Template — `/deploy` Output Boilerplate

> **Mục đích:** Khung cố định cho 2 artifact bắt buộc của `/deploy`. Agent (Release Manager) **chỉ fill** — KHÔNG re-author structure.
>
> Quy tắc chi tiết (gate all-or-nothing, digest match, never `:latest`): [`../commands/deploy.md`](../commands/deploy.md) §Required artifacts.

---

## §A. `reports/DEPLOY_RUNBOOK.md` skeleton — 7 section bắt buộc

````markdown
# Deploy Runbook — <product> v<X.Y.Z>

## 1. Pre-deploy checklist
Docker daemon up, `.env` present, /scan P0 items implemented, current image tags noted for rollback.

## 2. Deploy
Exact build + up commands. Image tagging with `:v<X.Y.Z>` (never `:latest`).

## 3. Post-deploy smoke verification
**Explicitly list every service** in compose + expected status (`Up (healthy)` or `Up` + whitelist note). This section MUST contain a table with columns `Service | Image tag | Expected status | Actual status | Healthcheck command`. A missing service = deploy did not pass the gate, no "SUCCEEDED" release notes produced.

Then: concrete `curl` smoke commands hitting `/health`, `/health/ready`, `/api/v1/version` (or your project's smoke endpoint), and 1-2 happy-path API calls. Each with expected response.

## 4. Rollback (target < 1 minute)
Stop + restart with previous image tag. Database rollback notes (and pre-deploy backup pointer if migrations are involved). After rollback: re-run §3 smoke pack — rollback is not complete until smoke passes.

## 5. Common operations
Logs, restart, shell access, cleanup commands.

## 6. Troubleshooting
Top 3-5 known failure modes with diagnostic + fix. Link to `docs/troubleshooting.md` for developer-facing issues.

## 7. Escalation
On-call contact, severity thresholds, when to roll back vs hold.
````

## §B. `reports/RELEASE_NOTES_v<X.Y.Z>.md` skeleton — 5 section bắt buộc (1 file / release tag)

````markdown
# <product> — Release Notes v<X.Y.Z>

- **Version**: <X.Y.Z>
- **Release date**: YYYY-MM-DD
- **Container tags**: `<api-image>:<X.Y.Z>`, `<spa-image>:<X.Y.Z>` (etc.)
- **Status**: SUCCEEDED / FAILED / ROLLED-BACK

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
````

> `CHANGELOG.md` (Deliverable #3) dùng format Keep a Changelog — entry template ở [`../agents/release-manager.md`](../agents/release-manager.md) §CHANGELOG Entry Template.

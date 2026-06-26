---
name: hotfix
description: Restore a live/released system fast — triage rollback vs fix-forward, patch, re-verify, redeploy with audit trail
---

# /hotfix — Production Hotfix

> "Restore service first, then make it permanent."

## Purpose

Restore a **released artifact currently running live** to a correct state, under time pressure, **with a full audit trail**. `/hotfix` is a **thin orchestrator**: it does NOT re-implement the bug-fixing logic (reuses `/fix-issue`), does NOT re-implement artifact testing (reuses `/verify`), does NOT re-implement promotion (reuses `/deploy`). Its unique value lies in the 3 things those other commands deliberately do not do:

> **`/verify` policy override:** In the standard pipeline, Gate 11 (`/verify`) is **step optional · BLOCKING if run**. Inside `/hotfix`, Gate 11 is **promoted to REQUIRED** — no exceptions. The patch must PASS `/verify` on the new digest before `/deploy` promotes it. When calling `/deploy` from Step 5, set env `HOTFIX_MODE=1` so `/deploy` enforces that `reports/VERIFY_REPORT.md` exists.

1. **Rollback-vs-fix-forward triage** — decide the fastest & safest recovery *before* touching code.
2. **Patch release ceremony** — bump patch version, CHANGELOG, release notes for the patch.
3. **Post-incident** — re-verify the patch on the real artifact + update the runbook so it doesn't happen again.

## When to Use

Use `/hotfix` only when **all three** conditions are true: (a) the artifact is **deployed / live**, (b) it is **affecting real users** / has a severity level, (c) the patch must be **shipped again with version + audit**.

| Situation | Correct command |
|-----------|-----------------|
| `/build` or `/test` fails during coding | `/debug` |
| Bug report but **not yet released** / normal sprint flow | `/fix-issue` |
| Bug on a **live artifact**, needs urgent patch + re-ship | **`/hotfix`** |
| Project has **never been deployed** (still in dev) | `/fix-issue` (nothing "hot" to fix) |

> One-sentence rule: *if what's live is not working correctly and real users are affected → `/hotfix`; if the bug is still inside the dev cycle → `/debug` / `/fix-issue`.*

## Usage

```text
/hotfix "Users get Network error on register"   # from production symptom
/hotfix INC-204                                  # from incident ticket
/hotfix JIRA-456 --severity=critical             # with severity level
```

> `--severity` (critical / high / medium) = **incident priority** — recorded in the incident note (Step 6) and drives triage urgency (how fast Step 1 must decide rollback-vs-fix-forward). It does NOT change the 6-step flow itself.

## Scope Clarification — thin orchestrator

| Step | Reuses command | Content |
|------|----------------|---------|
| 1. Triage | — (unique) | rollback or fix-forward? |
| 2. Fix | `/fix-issue` (or `/debug` first if root cause is unclear) | root cause + targeted fix + regression test |
| 3. Release wrapper | — (unique) | patch version + CHANGELOG + RELEASE_NOTES |
| 4. Re-verify | `/verify` | prove the patch on the new digest (Gate 11) |
| 5. Redeploy | `/deploy` | promote rollback-ready |
| 6. Post-incident | — (unique) | update runbook troubleshooting + incident note |

`/hotfix` orchestrates; the heavy lifting lives in the sub-commands. No duplication.

---

## Workflow

### Step 1 — Triage: rollback or fix-forward (UNIQUE — done BEFORE touching code)

The first question of an incident is NOT "what's the root cause" but "what's the fastest way to recover". Decide using this table:

| Condition | Recovery action |
|-----------|-----------------|
| A recent last-known-good digest exists **and** the bug was caused by the most recent release **and** there's no non-revertable migration involved | **ROLLBACK first** (recovery < 1 minute), then fix-forward calmly afterwards via normal `/fix-issue` |
| Bug has existed for a long time / no good version to revert to / rollback would cause data loss | **FIX-FORWARD** (proceed to Step 2) |
| Unsure | **ROLLBACK first** (limit damage), investigate later |

> Principle: **minimize user impact first, patch cleanly later**. If rollback is chosen → execute via `/deploy` §Rollback (switch to the previous tag, re-run smoke), open an incident note, and convert the underlying bug into a high-priority `/fix-issue` for the next release. `/hotfix` may end here if rollback has already restored service.

### Step 2 — Fix (REUSES `/fix-issue`)

If fix-forward: delegate to `/fix-issue` (or `/debug` first if you cannot reproduce yet).

Mandatory requirements (inherited from `/fix-issue`):
- Reproduce the bug (ideal: write a regression test that **fails before the fix**).
- Root cause at `file:line`, do not patch symptoms.
- Targeted fix, minimal change.
- Regression test green after the fix.
- Test suite + build green.

### Step 3 — Patch release ceremony (UNIQUE)

The patch must have its own **identity** for audit & rollback:

- **Bump patch version** per SemVer: `vX.Y.Z` → `vX.Y.(Z+1)` (e.g., `v0.1.0` → `v0.1.1`).
- **CHANGELOG.md** — add a new entry at `## [X.Y.Z+1]` with a `### Fixed` section (and `### Security` if it's a vulnerability).
- **`reports/RELEASE_NOTES_vX.Y.Z+1.md`** — the patch is a release, so it must have its own release notes: bug summary, root cause, fix, new digest, incident link.

### Step 4 — Re-verify the patch (REUSES `/verify`)

**This is where `/hotfix` differs most strongly from `/fix-issue`.** "Tests green locally" is NOT enough — the patch must be proven on the **real rebuilt artifact**:

- Rebuild + retag the artifact with the new version → record the digest in `reports/verify-artifact.lock`.
- Run `/verify` against the new digest (minimum: liveness + contract suite covering the bug area + scenarios from the related user story).
- Mandatory addition: a verify test that **reproduces the exact incident scenario** (e.g., for a CORS bug: cross-origin preflight from the actual origin) — to prove the production symptom is gone.
- Gate 11 must PASS on the new digest before proceeding to Step 5.

### Step 5 — Redeploy rollback-ready (REUSES `/deploy`)

- Promote the verified digest via `/deploy` with env **`HOTFIX_MODE=1`** — `/deploy` will enforce that VERIFY_REPORT.md exists (Gate 11 promoted from optional → REQUIRED).
- Keep the old digest ready to revert in < 1 minute (per `/deploy` §Rollback).
- Run post-deploy smoke (including the incident scenario) to confirm on the live environment.

### Step 6 — Post-incident (UNIQUE)

- **Update `reports/DEPLOY_RUNBOOK.md` §Troubleshooting**: add the new failure mode + how to detect it + how to fix → make it a known-issue for next time.
- **Incident note** (`reports/incidents/INC-<id>.md` or in the release notes): timeline, detection → recovery time (MTTR), affected users, root cause, preventive action.
- **Prevent recurrence**: which layer should have caught this bug? If it's a class of error that `/verify` or `/test` should have caught → add a permanent test at that layer (not just a regression for this one case).

---

## Output — artifacts (MANDATORY)

| File | Content |
|------|---------|
| `CHANGELOG.md` | `[X.Y.Z+1]` entry with `### Fixed` / `### Security` |
| `reports/RELEASE_NOTES_vX.Y.Z+1.md` | release notes for the patch (bug, root cause, fix, digest, incident link) |
| `reports/VERIFY_REPORT.md` | Gate 11 PASS on the new digest (including the incident-reproduction test) |
| `reports/verify-artifact.lock` | digest verified == digest promoted |
| `reports/DEPLOY_RUNBOOK.md` (§Troubleshooting) | new failure mode |
| Incident note — `reports/incidents/INC-<id>.md` (recommended location) **or** folded into the release notes (per Step 6) | timeline + detection→recovery MTTR + root cause + preventive action — **content mandatory; location flexible** |
| Regression test | test that failed-before-fix, now green (in `tests/` — inherited from `/fix-issue`) |

---

## Quality Gate — Exit Criteria

- [ ] **Deliberate triage** — rollback-vs-fix-forward decided and recorded (do not default to fix-forward)
- [ ] If fix-forward: regression test **fails before fix, passes after fix**; root cause `file:line` identified
- [ ] **Patch version bump** + CHANGELOG entry + RELEASE_NOTES for the patch
- [ ] **`/verify` Gate 11 PASS on the new digest**, including a test that reproduces the incident scenario
- [ ] `/deploy` promotes the verified digest, rollback-ready, post-deploy smoke passes on live
- [ ] DEPLOY_RUNBOOK §Troubleshooting updated with the new failure mode
- [ ] **Incident note recorded** — timeline + detection→recovery (MTTR) + root cause + preventive action, in `reports/incidents/INC-<id>.md` (recommended) or the release notes — do not skip (audit trail is a core deliverable of `/hotfix`)
- [ ] Permanent preventive test added at the layer that should-have-caught (not just a regression for this case)

---

## Boundary & principles

- **Restore-first**: prioritize reducing user impact (rollback) over a clean patch right away. The clean patch can come after the service is stable.
- **Do not skip re-verify**: under pressure, the biggest temptation is "fix and push straight to prod". `/hotfix` exists to block that — the patch must go through `/verify` on the real artifact.
- **Patch, not feature**: `/hotfix` contains only the minimum change needed to restore. Do not bundle features / refactors into a hotfix.
- **Transparency**: every decision (rollback or fix-forward, which scenario is waived) is recorded in the incident note.

---

## Agent

Invoke: **Release Manager** (incident commander — owns triage, version, rollback, promotion), collaborating with:
- **Backend / Frontend Developer** — implements the fix via `/fix-issue`.
- **Test Engineer** — re-verifies the patch via `/verify`.

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Next Step

- Service restored + patch verified & promoted → close the incident, write the post-mortem (blameless — per `rules/principles-and-practices.md` §2.4).
- If Step 1 chose rollback-only → open a high-priority `/fix-issue` to fix-forward properly for the next release.

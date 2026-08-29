---
name: inspect
description: Answer a question about the software's current state/features — read-only, 3 evidence tiers, mismatch detection
---

# /inspect — Interrogate Current State

> "Answer with evidence, not memory."

## Purpose

Answer **a specific question** about the software's current state (*"does feature X exist/work?"*, *"how is Y configured?"*, *"does a newly added bookmark get checked for duplicates?"*) using **3 independent evidence tiers**, and **detect mismatches** among them. Read-only — changes nothing, no gate, no artifact pipeline.

> **Workspace Mode:** if the session root declares `Mode: workspace` → resolve the target repo per `CLAUDE.md` §Workspace Mode **before anything else**; every path, probe, and gate below is relative to the **target repo**, and the workspace disk-check applies at the gate.

> **Free-text goes down this same path:** the user asks a current-state question in plain language (without typing `/inspect`) → the orchestrator answers per **this command's exact output contract** (see `CLAUDE.md` §Natural-Language Task Routing). `/inspect` is only the explicit entry point; the answering discipline is one and the same.

## Usage

| Invocation | Result |
|----------|---------|
| `/inspect <question>` | **Default:** Tier 1 (records) + Tier 2 (code) — no running stack required |
| `/inspect --live <question>` | Adds Tier 3: probe the running artifact (**opt-in** — requires the stack up, may write throwaway test data) |
| `/inspect --report <question>` | As above + save the answer to `reports/inspect/INSPECT-<slug>.md` (**opt-in** — by default answers only on chat) |

Examples: `/inspect does a newly added bookmark get checked for duplicates` · `/inspect --live is the rate limit on /auth/login working` · `/inspect is the refresh token rate-limited`

## Scope Clarification (how it differs from neighboring commands)

| Command | Answers the question | How `/inspect` DIFFERS |
|------|-----------------|----------------------|
| `/discover` | "What is this repo?" (whole-repo survey, run once at onboarding) | 1 targeted question, targeted read, run as many times as you like |
| `/verify` | "Do ALL acceptance criteria pass on the artifact?" (gate, heavy) | No gate, no promote verdict, scope narrowed to exactly the question |
| `/debug` | "Why is it BROKEN?" (there's an error symptom, find root cause) | No symptom needed — asks about current state, even when everything works fine |
| free-text | Like `/inspect` but with an ad-hoc format | **Mandatory output contract** (3-tier table + evidence rating + mismatch flag + citations) — free-text is routed to the same contract |

## Workflow

### Phase 0 — Map the question onto traceability

Grep the question's keywords in `specs/` (`SPEC.md` — and `specs/user-stories/*.md` in the split layout) → identify the related `@US-XXX(-Snn)` / NFR / OQ.

- Can't be mapped anywhere → **that is itself part of the answer** ("not in the spec — the feature either doesn't exist yet or isn't documented") + cite the closest item found. DO NOT guess, do not infer from memory.

### Phase 1 — RECORDS evidence (always runs)

Trace the traceability chain: `specs/SPEC.md` (+ `specs/user-stories/*` in the split layout) → `architecture/` (related ADR) → `plans/` → `reports/TEST_REPORT.md` → `reports/VERIFY_MATRIX.md` (+ digest in `reports/verify-artifact.lock`) → `reports/DEPLOY_RUNBOOK.md` (ops state — §3 per-service smoke table, §4 the release's declared rollback path) → `reports/RELEASE_NOTES_*`. The spec's **Revision History** table is Tier-1 evidence for *when/why* a behavior changed (version · date · flow · approver) — cite its row when the question is about a change over time.

**MUST rate the evidence** (especially important for brownfield):

- **PROVEN** — there is a PASSing test/verify pointing at the exact scenario, recorded with the **digest that proved it**;
- **DESCRIBED (as-is)** — the reverse spec only *describes* behavior read from code, with no dedicated test proving it (e.g. the baseline stories after `/discover`).

### Phase 2 — CODE evidence (always runs)

Read the specific implementing code — use `docs/CODEBASE_MAP.md` as the index, **DO NOT scan the whole tree** (brownfield's consume-don't-re-scan principle). For a **story-anchored** question, `specs/EVIDENCE.md` (the REVERSE evidence map, if present) gives the direct `US-ID → file:line` jump — check its `Citations valid as of commit:` sha against HEAD first; a stale sha means line numbers may have drifted, so re-locate the cited symbol instead of trusting the line. Cite `file:line` for every assertion. A question that requires a broad scan → spawn **Explore** (read-only). For a **DB-resident object** question (stored proc / trigger / view / index), the index is `CODEBASE_MAP.md` §DB-object inventory → read the **committed DDL under `db/schema-snapshot/`** — that snapshot is the repo-side truth (`rules/database.md` §DB-resident objects are source code); a live probe (Phase 3) never replaces it.

### Phase 3 — LIVE evidence (only when `--live`)

Probe the running artifact, scope narrowed to exactly the question:

1. Determine the **running digest** FIRST (`docker inspect`) — so the answer records which build the live evidence is tied to.
2. Minimal probe (e.g. 2 curls: POST → 201, duplicate POST → 409).
3. Discipline:
   - A data-writing probe → use **throwaway data** (prefix `inspect-<timestamp>`), declared explicitly in the answer.
   - **Write-probes only against a stack the kit/user stood up** (local compose / staging). Target is **production → read-only probes only** (GET/HEAD) — no data-writing probe, throwaway prefix or not; state the limitation in the answer (*"write path not probed — production target"*). `/inspect` is a question-answering command, not an ops tool: the kit never mutates production state (same boundary as `/deploy` stopping at STAGED and rollback being operator-run).
   - DO NOT "fix things to make them run" — anything at all. Stack not running → report back, do not stand it up yourself.
   - **Database questions** — probe with the engine's own client (locally, or containerised: `docker run --rm …` / `docker exec <db-container> …`), scoped to the single question. The kit does **not** rely on a database MCP server for this (rationale: `discover.md` §Phase 1b — safety guarantees drift between releases and coverage is uneven). If your environment happens to have one configured and you choose to use it, the **only** dependable guard is a **database account restricted to `SELECT`** — never the server's own read-only flag, which has been removed from at least one popular server between minor versions while `execute_sql` stayed write-capable by default.
   - Whatever the probe, live evidence stays **DESCRIBED/live-at-probe-time** — it never upgrades the evidence rating and never becomes SPEC/ARCH content: KB artifacts are built from the repo.
   - Remember the rate-limit gotcha (`verify.md` §throttle): a repeated probe may hit 429 on itself — recognize it as an artifact of the probe, don't mistakenly conclude it's an app bug.

### Phase 4 — Verdict + MISMATCH FLAG (the core value)

Compare the 3 tiers against one another. Any pair that diverges → **⚠️ MISMATCH flag** + a short diagnosis + the next-command route:

| Kind of mismatch | Diagnosis | Route |
|-----------|-----------|-------|
| Records say YES ≠ code says NO (or vice versa) | Docs↔code drift | `/spec` DELTA (update the baseline) or `/fix-issue` (code is wrong) |
| Code says YES ≠ live says NO | Running artifact is old/stale | Check the digest → re-`/deploy` |
| Snapshot/migrations say X ≠ live DB says Y | **Schema drift** — the database was changed outside migrations (hand edit); a redeploy will NOT fix this | Repo is source of truth (`database.md` §DB-resident objects): investigate, then author the **corrective migration** — and note this is the reverse smell `/review` watches for |
| PROVEN on digest X, live is running digest Y | Evidence does not apply to the running build | Flag it clearly in the answer — must not borrow evidence across digests |

## Output contract (MANDATORY — every answer follows this frame, including free-text)

```markdown
**Question:** …
**Verdict:** YES / NO / PARTIAL / ⚠️ MISMATCH  (with a 1-sentence summary)

| Tier | Source | Finding | Citation | Rating |
|-----|-------|-----------|-----------|------|
| Records | SPEC US-… / VERIFY_MATRIX / ADR-… | … | @US-XXX-Snn · digest sha256:… | PROVEN / DESCRIBED |
| Code | … | … | file:line | — |
| Live (if --live) | running digest sha256:… | … | probe command + actual status code | — |

**Mismatch flag:** (if any) tier A says X ≠ tier B says Y → diagnosis + suggested next command
**Not asserted:** what this answer does NOT say (e.g. race condition, behavior under load, related Out-of-Scope/OQ item)
```

## Boundaries

- **Strictly read-only** on `src/**`, `web/**`, and every pipeline artifact. Found a bug → suggest `/fix-issue`, do not fix it yourself.
- Does NOT replace `/verify` — `/inspect` issues no gate/promote verdict, even when a live probe passes entirely.
- The answer must state the **confidence level** clearly: PROVEN ≠ DESCRIBED ≠ "live at probe time". Do not upgrade the evidence rating.
- `--report` writes into `reports/inspect/` (a separate folder) — it does not touch the gate reports (`TEST_REPORT`, `VERIFY_REPORT`…).

## Agent

No dedicated sub-agent — the orchestrator answers inline (a question = targeted read, spawning an agent is wasteful). A question that requires a broad scan → spawn **Explore** (read-only). Output language: per Project Profile → Output Language for prose, keep technical identifiers as-is (see `.claude/CLAUDE.md` → Output Language).

## Next Step

`/inspect` has no fixed next step — it serves a decision. Common routes: a mismatch is found → `/fix-issue` / `/spec` DELTA / re-`/deploy` (Phase 4 table); the question turns into a change request → §Natural-Language Task Routing (flow B).

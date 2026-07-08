# Brownfield Rules — Working on Legacy Code

> **Summary:** A discipline set that is **mandatory when modifying code that is running / already released** (`Project Profile → Mode: brownfield`). The number-one constraint shifts from *"what am I building"* (greenfield) to **"I must NOT break anything"** — so every principle below revolves around **building a safety net before touching the code**. **Greenfield skips this entire file.**
>
> Principle source: Michael Feathers — *Working Effectively with Legacy Code* (characterization test, seams) + strangler-fig pattern.

---

## Definition

**Legacy code** = code that is running / already released but **lacking tests, spec, or documentation** describing intent. The core problem is not "old code" but **the lack of a safety net to change with confidence**.

---

## 4 core principles

### 1. Measure vs Verify — draw the distinction

**Meaning:** the same command may be *measuring the current state* (measure) or *verifying against requirements* (verify) — only "verify" needs a spec. Draw the distinction so you don't go checking "right/wrong" when there is not yet a spec defining what "right" is.

| Activity | Needs spec? | Belongs to phase |
|-----------|:---------:|-----------------|
| **Measure** — measure the current state (existing coverage, does the suite pass?, complexity, vuln) | ❌ No | Discovery (read-only) |
| **Verify** — check behavior matches acceptance criteria | ✅ Yes | Per-change (after there is a spec) |

> **Consequence:** any step that involves acceptance criteria (`/test` verify, `/review` Correctness axis) **cannot come before reverse-`/spec`** — with no spec there is no "right" to check against. Discovery only *measures*; *verify* is for per-change.

### 2. Upfront vs Per-change — don't do it in bulk upfront

**Meaning:** *one-time* work (code map, baseline) is done at Discovery; *per-change* work is done only for **exactly the area being touched** — do not retrofit the whole repo.

| Done once upfront (Discovery) | Done per-change (flow B) |
|-------------------------------|--------------------------|
| Codebase map (`/discover`) | Characterization test for **exactly the area about to be touched** |
| Baseline spec/arch (reverse) | Full `/review` Five-Axis for **the slice I'm modifying** |
| Light health snapshot + red-flag | `/test` verify for the specific change |

> Don't write characterization tests for the whole codebase, don't review the whole repo — only for the area the change touches.
>
> **WRITE per delta — RUN everything:** the rule above only limits the *newly written* part (test, characterization, review effort); the suite/verify-suite that is **already automated** is RUN in full every round — only a green regression net proves the unchanged part is not affected. Lookup table for `/test` · `/review` · `/verify` + decision tree for 9 situations: [`../references/brownfield-pipeline.md`](../references/brownfield-pipeline.md) §Scope per-change.

### 3. Backward compatibility by default

**Meaning:** by default **do not break** what clients / data / integrated systems rely on.

- API contract, response shape, DB schema, event/message format, public behavior **must not be broken** unless there is an ADR + migration plan.
- Breaking changes → bump major version + deprecation window + migration path.
- Every brownfield PR must be able to answer: *"does this change break a running client/data/integration?"*

### 4. Only an ADR authorizes changing the architecture

**Meaning:** only change the architecture when there is an **ADR** (Architecture Decision Record) — don't change it "on a whim" while doing other work.

- Development / feature-modification flows (B1, B2): **keep the architecture unchanged** — `/arch` in conformance-gate mode.
- Only the upgrade flow (B5) may change the architecture, **requiring an ADR** (with a v2-trigger) + migration plan.
- Don't change patterns/structure "on a whim" while doing other work.

---

## Characterization Test — the central technique

> **Definition:** a test that captures the **current behavior of the code** (not the behavior that is *correct* per spec), serving as a safety net before modifying. It's needed because legacy usually lacks both tests and spec — you must know "what the code *is* doing" to be able to distinguish an intentional change vs an accidental regression.

Different from greenfield TDD:

| | Greenfield TDD | Characterization (brownfield) |
|---|----------------|-------------------------------|
| Test written to | describe the **desired** behavior | capture the **existing** behavior (even when wrong) |
| Initial state | RED (fail, no code yet) | GREEN (pass, code already running) |
| Purpose | drive implementation | detect regression when modifying |

### Procedure when modifying legacy code without tests

```
1. Write a characterization test capturing the CURRENT behavior of the area about to be modified → run PASS (confirm the net is correct)
2. Make the change
3. The characterization test FAILs exactly where behavior changed → review: is this change INTENTIONAL?
   - Intentional → update the test to the new behavior (this is the part allowed to change)
   - Unintended → a regression has been caught, fix it back
4. Behavior not meant to change → the test still PASSes (the net stays intact)
```

### Seams (cut points to test hard-to-test code)

**Seam** = a place where you can change behavior **without modifying the code at that spot**. Legacy usually has hard dependencies (direct `new`, static call, no DI) → you need a seam to make it testable **without changing behavior**:

- Create a seam by: extract interface, virtual method, parameterize constructor.
- Prefer the lowest-risk seam; record it if you must refactor to create a seam — this is the **only exception** to "no gratuitous refactor", and it **must be surrounded by a characterization test first**.

---

## Strangler-Fig — replace gradually (for B5)

**Strangler-fig** = replace **gradually**, not a one-shot rewrite (big-bang):

1. Stand up the new implementation **in parallel** behind an abstraction/interface.
2. Route a portion of traffic/calls through the new version (feature-flag).
3. Measure, expand gradually; the old version shrinks until it can be removed.
4. Backward-compat throughout — cache miss / new path errors → fallthrough to the old version.

> Example: `ICacheService` is designed from day one (recorded via an ADR when running `/arch`) so that Redis can later be plugged in without touching callers — that is a seam for strangler-fig.

---

## No Gratuitous Refactor

Only refactor **within the scope being touched**, serving the current change:

- Do not "clean up" unrelated code in the same PR (it breaks review + increases regression risk).
- Tech debt discovered → record it in the backlog (a separate `/simplify`), don't fold it into the feature/fix.
- Exception: minimal seam-creating refactor to make the code about to be modified testable — must have a characterization test first.

---

## Links with Project Profile & commands

- **Project Profile** (file `.claude/PROJECT_PROFILE.md` — resolution rule: `CLAUDE.md` §Project Mode & Profile) declares `Mode`, `Database`, `Observability`, `Structure`. This rule is only active when `Mode: brownfield`.
- Peripheral technologies differing from the default (Oracle/MySQL/ELK…) → follow `rules/overrides/*` that the Profile declares.
- `/spec`, `/arch`, `/plan` read the Mode to switch behavior (see §Brownfield Mode in each command).

### `/arch` role by flow (summary)

| Flow | `/arch` mode | Default |
|-------|-------------|----------|
| Discovery (Phase A) | **reverse** | describe as-is + ADR inferred |
| B1 new feature / B2 modify feature | **conformance-gate** | keep the architecture unchanged |
| B5 upgrade | **redesign** | change with ADR + migration |

---

## Brownfield checklist (every flow B)

- [ ] There is already a baseline `specs/` + `architecture/` (from Discovery) to reference
- [ ] The area about to be modified: if it has no tests → **write a characterization test first** (capture current behavior, PASS)
- [ ] The area being modified calls DB-resident logic (stored procedure / trigger / DB function) → its defining DDL exists in the repo (snapshot committed — any path, indexed by `CODEBASE_MAP.md` §DB-object inventory) **BEFORE** modifying, and the characterization test covers that object's behavior (fixture applies the repo DDL into the TestContainer — `testing.md` §Template B)
- [ ] Before `/test`: every external registration in the legacy composition root (`Program.cs` DI, `IHostedService` consumers, auto-migrate at startup) is replaced/disabled **inside the test fixture, runtime-only** — real connection strings appear in NO test execution path, and no production config file is edited to make tests pass (`git status` after the suite: `appsettings*.json` / `Program.cs` / `docker-compose*.yml` unchanged → the artifact ships with its original connections)
- [ ] The change **does not break** a running API/contract/schema/behavior (or has an ADR + migration)
- [ ] `/arch` conformance-gate confirms **no architecture change is needed** (B1/B2), or there is an ADR (B5)
- [ ] No refactoring of code outside the scope being touched
- [ ] Migration with **backfill/computed logic** → follow `testing.md §Dual-Implementation Parity`: prefer backfill that **calls the app code itself**; if reimplementing in SQL → **differential test** enumerating enough input classes (a per-side test where both sides are green is NOT enough — drift still slips through)
- [ ] Old tests still PASS (regression net kept intact) + new tests for the change
- [ ] `/verify` proves it on the real artifact before promote (Gate 11)

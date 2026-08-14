# Output Style — Clarity & Readability

> **Scope:** governs **how every SDLC artifact reads** — `specs/`, `architecture/`, `plans/`, `security/`, `reports/`, `docs/`, release notes, and any prose a command emits. Applies to **all commands and agents**, no exception.
> **Relationship to other rules:** this is about *clarity*; `.claude/CLAUDE.md` § Output Language governs *which language* (Profile-declared prose language / English identifiers). The two compose — write clearly **and** in the declared language.
> **Principle:** an artifact that the intended reader cannot follow has not done its job, even if it is technically correct.

---

## 1. Audience-first — write to the reader, not to yourself

Name who reads each artifact and pitch the register to them. Clarity ≠ one tone for everything.

| Artifact | Primary reader | Register |
|----------|----------------|----------|
| `SPEC.md`, wireframes, `RELEASE_NOTES` | Stakeholder / PO / everyone | **Plainest** — minimal jargon; every term defined |
| `ARCHITECTURE.md`, ADRs, `CODE_REVIEW`, `TEST_REPORT`, `SCAN_REPORT` | Engineers | Technical **allowed**, but still lead with a summary and explain *why* |
| `troubleshooting.md`, `DEPLOY_RUNBOOK` | Operator / on-call | Step-by-step, unambiguous, action-first |

> Rule of thumb: if a non-author of the artifact's audience would stall on a sentence, rewrite it.

## 2. Lead with a plain-language summary (mandatory)

Every artifact (and every major section) opens with **2–4 sentences in plain language**: *what this is · why it matters · for whom* — **before** any deep detail. A reader should grasp the gist without reading the whole thing.

```markdown
> **In short:** This spec defines an order management feature — create, track, and search orders.
> It covers auth, order CRUD, status tracking, and search for a single tenant; it does NOT cover refunds or a mobile app.
```

## 3. Progressive disclosure — summary → detail → reference

Structure top-down: the conclusion/decision first, supporting detail next, deep references last. Never make the reader wade through mechanics to find the point. Put the **decision in bold** at the top of a section, not buried in the last paragraph.

## 4. Plain-language mechanics

- **Short sentences, one idea each.** Prefer active voice and concrete subjects ("The service rejects the request" not "Requests are subject to rejection").
- **Scannable structure** — headings, tables, and lists beat dense paragraphs. **Bold the key decision/outcome.**
- **Cut filler** — no throat-clearing ("It should be noted that…"), no restating the heading.
- **Concrete over abstract** — name the file/endpoint/number, don't gesture vaguely.

## 5. Define jargon — no unexplained acronyms

- Spell out an acronym/standard on first use, with a 3–8 word gloss: *"RFC 7807 (the standard HTTP error format)"*, *"IDOR (accessing another user's record by its id)"*.
- Keep technical identifiers and standard names **as-is** (per § Output Language) — but the surrounding prose must make them understandable.
- Maintain a **Glossary** in artifacts that introduce domain terms (already required for `SPEC.md`).

## 6. Explain the *why*, not just the *what*

- Every non-obvious decision carries a **one-line rationale**. ("We soft-delete *so that* an accidental delete is recoverable.")
- Every number/threshold states its basis. ("Timeout 2s — chosen to keep p95 < 300ms while still usually fetching the title.")
- This is what turns a record into a *decision* a future reader can trust or revisit.

## 7. Show, don't just tell

When a concept is easier shown than described, add a short example, a before/after, or a tiny table. One concrete example often replaces a paragraph of abstraction.

## 8. Clarity ≠ dumbing down

Do not sacrifice accuracy for simplicity. Keep the precise term, then explain it — never replace it with a vague approximation. The goal is *understandable AND correct*, not *simple but wrong*.

## 9. Concise — the shortest version that stays clear and correct

Clear is **not** the same as long. The "add" rules above (§2 summary, §5 gloss, §6 *why*, §7 example) earn their place only when they genuinely help — applied mechanically they bloat the artifact. Once it reads clearly, cut further:

- **Shortest version that keeps clarity + accuracy** — never add words just to fill space or look thorough.
- **One summary, not three** — add a gloss / rationale / example only when it actually helps; do **not** gloss a term the intended audience already knows.
- **Say it once** — each point lives in exactly one place; elsewhere, link to it instead of repeating.
- **On collision with §2 / §5 / §6 / §7** — prefer *stop when clear enough* over stacking every "add" mandate.

> Balance, not contradiction: §1–§8 make it *understandable*; §9 keeps it *tight*. A good artifact is the smallest one its reader can fully follow.

---

## Anti-patterns (rewrite if you see these)

| Anti-pattern | Fix |
|--------------|-----|
| Wall of dense text | Break into headings / tables / lists; bold the decision |
| Detail before the point | Add a plain summary on top; move mechanics down |
| Unexplained acronym / jargon | Gloss on first use; add to glossary |
| Passive, vague subject | Active voice, concrete subject |
| Decision with no reason | Add a one-line *why* |
| Number with no basis | State where the threshold comes from |
| Same tone for stakeholder & engineer docs | Match register to the audience (§1) |
| Explaining the obvious / glossing a term the reader knows | Cut it; trust the audience (§9) |
| Same point repeated in several places | State it once, link from the rest (§9) |

## Self-check before emitting an artifact

- [ ] Opens with a plain-language summary (what / why / for whom)
- [ ] The key decision/outcome of each section is visible in the first lines (and bold)
- [ ] No unexplained acronym or jargon for the intended audience
- [ ] Every non-obvious decision and every threshold has a one-line rationale
- [ ] Dense paragraphs broken into headings / tables / lists
- [ ] Register matches the reader (stakeholder vs engineer vs operator)
- [ ] Still accurate — no term replaced by a misleading simplification
- [ ] Nothing can be cut without losing clarity — no filler, no glossing the obvious, no repetition (§9)

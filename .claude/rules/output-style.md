# Output Style — Clarity & Readability

> **Scope:** governs **how every SDLC artifact reads** — `specs/`, `architecture/`, `plans/`, `security/`, `reports/`, `docs/`, release notes, and any prose a command emits. Applies to **all commands and agents**, no exception.
> **Relationship to other rules:** this is about *clarity*; `.claude/CLAUDE.md` § Output Language governs *which language* (Profile-declared prose language / English identifiers). The two compose — write clearly **and** in the declared language.
> **Principle:** an artifact that the intended reader cannot follow has not done its job, even if it is technically correct.

---

## 1. Audience-first — write to the reader, not to yourself

Name who reads each artifact and pitch the register to them. Clarity ≠ one tone for everything.

| Artifact | Primary reader | Register |
|----------|----------------|----------|
| `SPEC.md` + user stories/AC, wireframes, `RELEASE_NOTES`, PRD-class `/export-docs` renders | **Non-specialist stakeholder / PO** — fluent with computers, not with software engineering | **Non-specialist floor — §10** (checkable rules, not "plainest") |
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

- **Short, complete sentences — one idea each.** Full subject-verb sentences, not telegram-style fragments: brevity comes from cutting ideas and filler, never from dropping the sentence's grammar. Prefer active voice and concrete subjects ("The service rejects the request" not "Requests are subject to rejection").
- **Arrow chains are notation, not grammar** — `A → B → C` is welcome when it depicts a real ordered flow (a command pipeline, a traceability chain `spec → code → test`, a uniform cause→effect column in a list). It becomes a telegram fragment only when the arrow replaces the sentence's verb ("task done → tick"). Keep the surrounding sentence complete; the chain sits inside it as a noun.
- **Scannable structure** — headings, tables, and lists beat dense paragraphs. **Bold the key decision/outcome.**
- **Cut filler** — no throat-clearing ("It should be noted that…"), no restating the heading.
- **Concrete over abstract** — name the file/endpoint/number, don't gesture vaguely.

## 5. Define jargon — no unexplained acronyms

- Spell out an acronym/standard on first use, with a 3–8 word gloss: *"RFC 7807 (the standard HTTP error format)"*, *"IDOR (accessing another user's record by its id)"*.
- **The gloss renders in the artifact's Output Language** when that is not English — *"cổng kiểm soát chất lượng (Quality Gate)"* — while the term itself stays English (§ Output Language).
- **A term that would need a long gloss → replace it in the prose** with a self-explanatory phrase and keep the term in parentheses: *"a small but complete, end-to-end runnable piece of the feature (vertical slice)"* beats a three-clause explanation. Rename, don't lecture — this keeps §8 intact because the precise term survives in the parentheses.
- **Kit-internal vocabulary stays internal** — command phase names and gate numbers (`Phase 0`, `Gate 6`) mean nothing to an artifact's reader; name the observable effect (*"`/spec` detects the mismatch itself"*), not the internal step.
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

> Balance, not contradiction: §1–§8 and §10 make it *understandable*; §9 keeps it *tight*. A good artifact is the smallest one its reader can fully follow.

## 10. Non-specialist floor — artifacts a stakeholder must be able to act on

**Applies to:** `specs/SPEC.md` + user stories + Acceptance Criteria · `specs/wireframes/` · `RELEASE_NOTES` · the PRD-class renders of `/export-docs` · every **confirmation question and Open Questions row** an agent puts to the user. Also the kit's own onboarding docs (`README*`, `quick-start.md`, `getting-started-*.md`).

**Does NOT apply to** — these keep their §1 register: `architecture/` + ADRs · `reports/` (CODE_REVIEW · TEST_REPORT · SCAN_REPORT · VERIFY_REPORT) · `security/THREAT_MODEL` · `specs/EVIDENCE.md` · `docs/troubleshooting.md` + `DEPLOY_RUNBOOK`.

**The reader:** fluent with computers and the internet for daily work; does **not** know SDLC vocabulary, the kit's command/phase names, code structure, or architecture-pattern names. **Checkable test:** a sentence this reader would have to look up before acting on it must be rewritten.

- **One word, one meaning per artifact.** Never reuse a word for two concepts — an "artifact" meaning *a document the kit generates* in one section and *the build being shipped* in another forces the reader to guess. When the output language lacks two words, coin two and use each consistently throughout.
- **Name the actor and the action for anything the reader must do.** No passive voice where a person must act ("the architecture has been reviewed" → "**you approve** the architecture Claude presents"), and state the *physical action* ("approve by replying in the chat"), not just the obligation.
- **Acceptance criteria and gate conditions are measurable, never adjectival.** "Docs are complete" fails; "all 4 docs present: getting-started · API · deploy · troubleshooting" passes. If the reader cannot check it, it is not a criterion.
- **State the safety net and the red branch.** Where a reader might freeze fearing they broke something, give the real consequence ("skipping this is fine — `/spec` detects the mismatch and asks"). Where an instruction can fail, cover the failure path too ("a red gate means stop: have Claude fix it, then re-run that step").
- **A kind-noun precedes every identifier** — *the file* `specs/SPEC.md`, *the command* `/spec`, *the folder* `.claude/`. The reader should never have to infer whether a name is a file, a folder, or a command.

> **§9 still arbitrates.** This floor raises *what must be understandable*, not *how much to write*: prefer §5's "rename, don't lecture" over adding explanation, and stop as soon as the reader can act. A SPEC that doubled in length to gloss everything has failed this section, not satisfied it.

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
| Telegram-style fragment ("task done → tick") | Write the full sentence; cut ideas, not grammar (§4); an arrow chain depicting a real ordered flow is notation — keep it |
| Hard term + a long inline explanation | Swap the prose to a self-explanatory phrase + term in parentheses (§5) |
| Internal phase/gate name in reader-facing prose | Name the observable effect instead (§5) |
| One word carrying two meanings in the same artifact | Coin two distinct words, use each consistently (§10) |
| Obligation stated without the action ("review and approve it") | Name the actor and the physical action (§10) |
| Criterion stated as an adjective ("complete", "sufficient") | Replace with something countable or checkable (§10) |
| Bare identifier with no kind-noun | *the file* / *the command* / *the folder* + the name (§10) |

## Self-check before emitting an artifact

- [ ] Opens with a plain-language summary (what / why / for whom)
- [ ] The key decision/outcome of each section is visible in the first lines (and bold)
- [ ] No unexplained acronym or jargon for the intended audience
- [ ] Every non-obvious decision and every threshold has a one-line rationale
- [ ] Dense paragraphs broken into headings / tables / lists
- [ ] Register matches the reader (stakeholder vs engineer vs operator)
- [ ] Still accurate — no term replaced by a misleading simplification
- [ ] Full sentences throughout — no telegram fragments; hard terms replaced by self-explanatory phrases (term kept in parentheses), not explained at length
- [ ] No kit-internal phase/gate names in reader-facing prose
- [ ] **(stakeholder-tier artifacts, §10)** No word carries two meanings; every action names its actor + physical step; every criterion is countable; identifiers carry a kind-noun
- [ ] **(stakeholder-tier artifacts, §10)** Safety net stated where the reader could freeze; failure path stated where a step can fail
- [ ] Nothing can be cut without losing clarity — no filler, no glossing the obvious, no repetition (§9)

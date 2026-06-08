# Legacy Code Guide — REPLACED

> ⚠️ **DEPRECATED.** This file (a passive mapping table of "which command to use for legacy", written specifically for .NET, not a canonical source) has been replaced by the active brownfield mechanism in the kit.

## Use instead

| Need | Read / use |
|------|-----------|
| Legacy work discipline (characterization test, backward-compat, ADR-to-change, measure-vs-verify) | [`../rules/brownfield.md`](../rules/brownfield.md) — **active rule**, active when `Mode: brownfield` |
| Declare the repo's mode + peripheral stack | `## Project Profile` in [`../CLAUDE.md`](../CLAUDE.md) (§Project Mode & Profile) |
| First-time onboarding of a legacy repo (Phase A) | [`../commands/discover.md`](../commands/discover.md) → `/spec` (reverse) → `/arch` (reverse) |
| Continued development on legacy (B1–B5) | Brownfield pipeline in CLAUDE.md §Project Mode & Profile; `/arch` reverse/conformance/redesign roles |
| Peripheral technologies that differ from the default (Oracle/MySQL/ELK) | [`../rules/overrides/`](../rules/overrides/) |

> Keep this file as a pointer to avoid dangling links. Do not add new content here — all brownfield discipline lives in `rules/brownfield.md`.

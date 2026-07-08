# `.claude/local/` — EXTENSION layer (user-owned)

> **This directory belongs to your repo, NOT to the kit.** A kit upgrade **never touches** anything here (layering contract: `CLAUDE.md` §Kit Layering). Files in here are **tracked by git normally** in your repo — "local" means *local to the kit*, not *local to git*.

## What it is used for

| File / subdirectory | Purpose |
|---|---|
| `CLAUDE.local.md` | Team/project-specific rules — read **AFTER** the kit's `CLAUDE.md`, and **WINS** on conflict (precedence: `local/` > `PROJECT_PROFILE` > kit base) |
| `rules/*.md` | Custom rules: company naming conventions, internal compliance, additional review standards… Write them in the spirit of the kit's `rules/overrides/`: **only record what differs** from the base |
| `KIT_DEVIATIONS.md` | A log of the places where you were **forced to modify a kit CORE file** — so the next upgrade can re-apply them deliberately (see that file) |

## What it is NOT used for

- **Do not** place commands (slash commands) here — Claude Code only auto-discovers commands in `.claude/commands/`. Repo-specific commands: put them directly in `commands/` with a **dedicated prefix** (e.g. `my-*.md`) — the kit guarantees it will not ship commands with a matching prefix.
- **Do not** place the Project Profile here — it has its own home: `.claude/PROJECT_PROFILE.md` (CONFIG layer).
- **Do not** copy an entire kit rule file here just to change a few lines — record only the **difference** (delta), otherwise upgrades to the base will be fully shadowed.

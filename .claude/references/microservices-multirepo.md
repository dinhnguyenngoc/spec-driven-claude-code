# Microservices Multi-Repo — Quick Lookup

> How to use the kit for a microservices product made of **multiple repos** (each repo = 1 service / bounded context). It supplements the per-repo pipeline, it does NOT replace it. Per-service legacy discipline still follows [`../rules/brownfield.md`](../rules/brownfield.md).

## Core principles

- **Pipeline unit = 1 repo / 1 service.** Each service runs its own pipeline (its own Project Profile, its own stack via `overrides/*`, its own tests, its own deploy). Do NOT lump N repos into a single `/discover` run — a single-valued `Project Profile` cannot represent N stacks.
- **System layer = system-understanding documentation, ONE-WAY.** `/discover-system` reads the per-repo output → builds a system-wide map. Per-repo does **not** have a runtime dependency on the system layer.
- **Cross-service safety = backward-compat discipline** (repo-local), NOT a runtime dependency on the system layer. See [`../rules/brownfield.md`](../rules/brownfield.md).

## Two repo layout patterns

| Pattern | When | What `/discover-system` reads |
|---|---|---|
| **A. Workspace** | All repos cloned side by side under a single parent directory | Reads the per-repo artifacts in the subfolders |
| **B. Separate repos** (common) | Each service repo is independent | Create a **temporary workspace** (clone them all under one parent) then run it as A |

> Both reduce to: having **one workspace** containing the repos side by side for `/discover-system` to read.

## Flow — one-way ↑

```
1. Create the workspace: clone all service repos under a single parent directory.

2. [per-repo, in parallel]  each repo Phase A:
   /discover → /spec(reverse) → /arch(reverse)
   → CODEBASE_MAP · SPEC(@US) · ARCHITECTURE + openapi + §Service Contracts

3. [workspace, once]  /discover-system
   → architecture/system/ (catalog · context · container · journeys · contract catalog · traceability)
   → commit into the platform repo (documentation, shared)

4. [per-repo, per feature]  Phase B brownfield (B1–B5) INDEPENDENTLY per service.
   Cross-service safety = backward-compat. Do NOT read back the system layer in day-to-day work.
```

## Precondition of `/discover-system`

Per-repo Phase A must be complete for **each** service: every repo has `docs/CODEBASE_MAP.md` + `specs/SPEC.md` (with `@US`) + `architecture/ARCHITECTURE.md` including **§Service Contracts** (exposed/consumed table — see [`../commands/arch.md`](../commands/arch.md) §3.2) + declares a `Service id` in the Project Profile. If any repo is missing → the catalog tags it `⚠️ incomplete`, no fabrication.

## Role of each system-layer artifact

| File | Content |
|---|---|
| `service-catalog.md` | Service table: `id · repo · responsibility · stack · owner · last-synced` |
| `system-context.md` | C4 L1 — product boundary + actors + all services |
| `container.md` | C4 L2 — services + bus + gateway + `api↔api` edges (assembled from §Service Contracts) |
| `journeys/*.md` | Cross-service sequences + `@SYS-US` (marked `inferred` if derived from event/async) |
| `contracts/event-catalog.md` | `topic · schema · producer · consumers` + cross-service REST |
| `traceability.md` | `@SYS-US → {service:@US}` |

## Advanced (for later — opt-in, NOT needed for the first version)

- **Auto contract-break detection:** a service's `/test`/`/review` cross-checks the contract it *consumes* against the partner's openapi (reading one contract file, not the whole system layer); or consumer-driven contract testing (Pact-style).
- **Blast-radius on a B5 breaking change:** manually read `container.md` to learn who *consumes* the contract about to be broken → draw up a migration plan.
- **Cross-service E2E:** a dedicated `e2e` repo holding the cross-service journeys (default: each service tests independently).
- **Downward sync:** submodule / sync a slice of the system layer into each repo if later you want per-repo automatic referencing.

## Greenfield multi-service (opposite direction — note)

Designing N services **from scratch** = **system-first**: spec/arch at the system level (decompose the product → services + contracts) FIRST, then per-service. This reverses the order relative to the reverse flow above. The kit is currently optimized for **brownfield/reverse**; greenfield multi-service is done manually following this principle.

## See also

- [`../commands/discover-system.md`](../commands/discover-system.md) — the command that builds the system layer
- [`../commands/arch.md`](../commands/arch.md) §3.2 Service Contracts — keystone input
- [`brownfield-pipeline.md`](brownfield-pipeline.md) — per-repo pipeline (Phase A + B)
- [`../rules/brownfield.md`](../rules/brownfield.md) — backward-compat discipline (cross-service safety)

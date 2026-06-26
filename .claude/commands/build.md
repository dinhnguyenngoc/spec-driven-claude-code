---
name: build
description: Implement tasks incrementally using TDD and vertical slices
---

# /build — Incremental Implementation

> "The simplest thing that could work."

## Purpose

Implement tasks one at a time using Test-Driven Development. Each increment leaves the system in a working, testable state.

> **Stack Profile note:** examples use the **default profile** (SQL Server). If `Project Profile` (CLAUDE.md) declares Oracle/MySQL → follow `rules/overrides/database-*.md` for data access + test setup. Core C#/ASP.NET Core/EF Core does not change. Brownfield: follow `rules/brownfield.md` (characterization test before modifying legacy code that has no tests).

## Prerequisites

**Required:**
- A plan exists — `plans/plan.md` (task detail: AC, **Scenarios covered**, Files to modify, Tests to add) + `plans/todo.md` (the actionable checklist)
- Understanding of task acceptance criteria
- .NET SDK 8.0 installed

**Optional (if available):**
- Pre-development security review (`security/PRE_DEV_REVIEW.md` from `/secure`)
- Threat model (`security/THREAT_MODEL.md` from `/secure`)

## Agent Selection

| Task Type | Agent to Invoke |
|-----------|-----------------|
| APIs, services, DB, background jobs | 🔧 Backend Developer |
| Components, pages, routing, UI | 🖥️ Frontend Developer |

> Sub-agent prompt MUST include: "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

## Testing Strategy for /build

> **IMPORTANT:** `/build` uses tests that do NOT require Docker.

```text
┌─────────────────────────────────────────────────────────────────┐
│                   /build TESTING APPROACH                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ✅ USED IN /build:                                            │
│   ├── Unit Tests (Mock) ─────────── No Docker required          │
│   └── Integration Tests (In-Memory) ─ No Docker required        │
│                                                                  │
│   ❌ NOT USED IN /build (deferred to /test):                    │
│   ├── Integration Tests (TestContainers) ─ Docker required      │
│   └── E2E Tests (Docker Compose) ─────────── Docker required    │
│                                                                  │
│   Required:  .NET SDK 8.0                                       │
│   Docker:    ❌ NOT REQUIRED                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Test Doubles for /build

```csharp
// Unit Tests: Use Mocks
var mockRepo = new Mock<IUserRepository>();
var mockCache = new Mock<ICacheService>();
var service = new AuthService(mockRepo.Object, mockCache.Object);

// Integration Tests: Use In-Memory providers
services.AddDbContext<AppDbContext>(options =>
    options.UseInMemoryDatabase("TestDb"));  // No SQL Server needed

services.AddDistributedMemoryCache();  // No Redis needed
```

### Running Tests in /build

```bash
# Run all tests EXCEPT those requiring Docker
dotnet test --filter "Category!=RequiresDocker&Category!=E2E"

# Or simply (In-Memory tests don't have special category)
dotnet test
```

## Workflow

> **MANDATORY — Progress tracking is non-negotiable.**
>
> `plans/todo.md` is the single source of truth for what's done. **Every completed task MUST be ticked (`- [x]`) before the agent reports back.** A task without its tick is not done.
>
> **Responsibility (clear chain):**
> - When `/build` runs the workflow directly → the agent doing the work ticks the box (Step 6 below).
> - When `/build` delegates to a sub-agent (e.g. Backend Developer, Frontend Developer) → **the orchestrator owns the tick**, applied after the sub-agent reports success. The sub-agent stays focused on code; the orchestrator updates `plans/todo.md` because only the orchestrator sees the full task list and the boundaries between batches.
> - When a checkpoint is reached → tick the `CHECKPOINT N` line too, with a one-line verification note in `plan.md` if anything surprising came up.
>
> If `plans/todo.md` doesn't match reality at the end of `/build`, Gate 5 fails — see the Exit Criteria at the bottom.

> **Related skills & rules:** invoke the `tdd` skill for the full RED-GREEN-REFACTOR rhythm and `incremental-implementation` for vertical-slice guidance. Test patterns + coverage thresholds live in [`.claude/rules/testing.md`](../rules/testing.md); commit format + pre-commit hooks live in [`.claude/rules/git-workflow.md`](../rules/git-workflow.md).

### For Each Task

#### Step 1: Load Context

```text
1. Read the task's acceptance criteria
2. Identify relevant existing code and patterns
3. Understand types and interfaces involved
```

#### Step 2: RED — Write Failing Test

Write a failing test for the task's claimed scenario (`@US-XXX-Snn`). See the `tdd` skill §RED Phase for the canonical shape (Arrange-Act-Assert + FluentAssertions); the example there is generic — here, assert this task's observable *Then*.

> **Producer→consumer handoff:** if the scenario hands a value from one unit to another (navigation-state key, context, event/message name, shared prop), the failing test must exercise **both ends together** — producer acts → assert the consumer's observable effect — not just the producing side in isolation. See Rules §"Test the handoff" + [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3. (A key/name mismatch passes each side alone yet breaks the feature.)

Run test — confirm it **fails**.

```bash
dotnet test --filter "CreateAsync_WithValidTitle_ReturnsTaskWithId"
```

#### Step 3: GREEN — Minimal Implementation

Write the **minimum** code to pass the test — no extra features, no premature optimization. See the `tdd` skill §GREEN Phase.

Run test — confirm it **passes**.

```bash
dotnet test --filter "CreateAsync_WithValidTitle_ReturnsTaskWithId"
```

#### Step 4: REFACTOR — Improve Code Quality

```csharp
// Clean up while keeping tests green
// - Improve naming
// - Extract helpers if needed
// - Remove duplication
// - Apply clean code patterns
```

Run the task's tests — confirm the refactor kept them **green** (fast inner loop; the single full-suite regression run happens once at Step 5):

```bash
dotnet test --filter "FullyQualifiedName~TaskServiceTests"
```

#### Step 5: Verify & Commit

```bash
# Full regression gate — the single full-suite run for this task (Step 4 ran only the task's tests)
dotnet test

# Enforce code-style.md (pre-commit hook also runs this — see git-workflow.md)
dotnet format --verify-no-changes

# Commit with a Conventional Commit message (type(scope): description — see git-workflow.md)
git add .
git commit -m "feat(tasks): add CreateAsync method to TaskService"
```

> **Per-task compile is guaranteed by `dotnet test`** (it builds the solution in Debug). The full **Release** build runs once per checkpoint (Step 6) and at Gate 5 exit — not on every task.

#### Step 6: Mark Complete — REQUIRED

Tick the task in `plans/todo.md` **before moving to the next task or reporting done.** This is not optional. If a sub-agent did the work, the orchestrator applies the tick after receiving the success report.

```markdown
- [x] T-XX: Task description (US-XXX) [S|M|L]
```

When a phase finishes, run the **Release build** (the per-checkpoint artifact check), then tick its checkpoint line and note the verification in `plan.md` if anything diverged from the plan:
```bash
dotnet build --configuration Release
```
```markdown
- [x] CHECKPOINT 1 — Auth slice complete: ...
```

### Frontend TDD (Vitest + React Testing Library)

Same RED → GREEN → REFACTOR loop, different stack. The Backend examples above use xUnit + Moq; for `web/` use Vitest + RTL and query the DOM the way a user would (role / label / text — not implementation details). See [`frontend.md`](../rules/frontend.md) for the full rules.

```tsx
// RED — web/src/components/__tests__/LoginForm.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoginForm } from "../LoginForm";

test("submitting empty form surfaces a Zod validation error", async () => {
  render(<LoginForm onSubmit={vi.fn()} />);
  await userEvent.click(screen.getByRole("button", { name: /sign in/i }));
  expect(await screen.findByRole("alert")).toHaveTextContent(/email is required/i);
});
```

```bash
# Verify (per task)
npm run test -- LoginForm

# Verify (before commit) — mirrors what /test runs again at Gate 6
npm run typecheck && npm run lint && npm run build && npm run test
```

- **Single Zod schema** validates both client (RHF resolver) and server input — never duplicate.
- **No `useEffect + fetch`** — TanStack Query owns cache, retries, error states.
- **Query priority:** role > label > text > testId.

### Rules

| Rule | Why |
|------|-----|
| **100-line limit** | Test before writing more than ~100 lines |
| **Touch only what's needed** | Don't refactor adjacent code |
| **Keep it building** | Project must compile after each increment |
| **No orphan — wire end-to-end** | A slice is "done" only when the new control/handler is **reachable from the application entry point** (mounted / passed / routed), not merely defined. A button/endpoint/handler that nothing invokes from the real app path is incomplete — even if its unit tests pass. |
| **Cover the scenario, not just the unit** | A task is done only when **every `@US-XXX-Snn` it claims** (plan's "Scenarios covered") is exercised by a passing test asserting that scenario's observable *Then* through the wired path — not merely that an isolated class works. |
| **Test the handoff, not just each side** | When a unit produces a value another consumes (navigation-state key, context, event/message name, shared prop contract), ≥ 1 test must exercise **both ends together** (producer acts → consumer's effect asserted). Two sides each unit-passing in isolation does NOT cover the join — a key/name mismatch passes both yet breaks the feature. See [`references/scenario-traceability.md`](../references/scenario-traceability.md) §3. |
| **Feature flags** | Use flags for incomplete features that need merging |
| **Rollback-friendly** | Each increment should be independently revertable |

### When Stuck

If a step fails:

1. **Stop** — Don't push through broken code
2. **Diagnose** — Use `/debug` to find root cause
3. **Fix** — Address the actual problem
4. **Guard** — Add test to prevent recurrence
5. **Resume** — Continue from where you stopped

## Common Commands

```bash
# Build solution
dotnet build

# Run all tests
dotnet test

# Run tests with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run specific test project
dotnet test tests/MyApp.UnitTests

# Run tests matching filter
dotnet test --filter "FullyQualifiedName~UserServiceTests"

# Watch mode (rebuild on changes)
dotnet watch run --project src/MyApp.Api

# Add EF Core migration FILE (design-time scaffolding — no DB connection)
dotnet ef migrations add MigrationName --project src/MyApp.Infrastructure --startup-project src/MyApp.Api
```

> ⚠️ **Do NOT run `dotnet ef database update` during `/build`.** `/build` uses `UseInMemoryDatabase` for tests — no migrations needed. Applying migrations from `/build` would target the connection string in `appsettings.json` (typically `localhost`) and **write to a real database on your host machine**, which violates the host-isolation contract.
>
> Migrations are applied at well-defined points:
> | Phase | How migrations are applied |
> |-------|----------------------------|
> | `/build` tests | `UseInMemoryDatabase` — no migrations |
> | `/test` integration | TestContainers fixtures call `EnsureCreatedAsync()` on the ephemeral container |
> | `/infra` (local dev) | `docker-compose up` runs migrations against the containerized SQL Server |
> | `/deploy` (prod) | `dotnet ef migrations script --idempotent` → DBA review → apply via CI/CD |

## Red Flags

Stop and reassess if you find yourself:

- Writing > 100 lines without testing
- Mixing unrelated changes in one commit
- Expanding scope mid-task
- Breaking the build between increments
- Creating abstractions "for later"

## Output

- Working, tested code
- Updated `plans/todo.md` with completed items
- Clean git history with atomic commits

## Quality Gate 5 — Exit Criteria

Before proceeding to `/test`:

- [ ] All tasks in `plans/todo.md` marked complete
- [ ] **Every `@US-XXX-Snn` claimed by the completed tasks is reachable from the app entry (no orphan) and backed by a passing test asserting its observable *Then*** — a scenario whose code exists but is unwired, or has only a presence-level test, is NOT done
- [ ] All unit tests pass (`dotnet test`)
- [ ] Code compiles without errors in Release (`dotnet build --configuration Release`)
- [ ] **(If `web/` exists) Frontend gate green** — `npm run typecheck && npm run lint && npm run build && npm run test` all pass, including `tailwindcss/no-custom-classname` (no undefined breakpoint/variant class)
- [ ] No red flags present (see Red Flags section)
- [ ] Git commits are clean and atomic

## Next Step

After all tasks complete, run `/test` for comprehensive testing with real dependencies.

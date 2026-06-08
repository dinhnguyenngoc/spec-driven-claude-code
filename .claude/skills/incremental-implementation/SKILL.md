---
name: incremental-implementation
description: Build features in thin vertical slices with continuous verification
---

# Incremental Implementation Skill

## Philosophy

> "The simplest thing that could work."

Build in thin vertical slices. Each increment leaves the system working and testable.

---

## When to Apply

**Use this skill when:**
- Multi-file changes
- New features
- Refactoring work
- Any change > 100 lines

**Skip for:**
- Single-file, small changes
- Simple bug fixes
- Configuration updates

---

## The Increment Cycle

```
┌─────────────────────────────────────────┐
│  1. Pick smallest complete piece        │
│                 ↓                       │
│  2. Write failing test (RED)            │
│                 ↓                       │
│  3. Implement minimal code (GREEN)      │
│                 ↓                       │
│  4. Refactor if needed                  │
│                 ↓                       │
│  5. Run all tests                       │
│                 ↓                       │
│  6. Commit with clear message           │
│                 ↓                       │
│  7. Repeat for next piece               │
└─────────────────────────────────────────┘
```

---

## Vertical vs Horizontal Slicing

### Vertical Slices (Correct)

Each slice delivers end-to-end functionality:

```
Task 1: User can create a task
        └── DB model + API route + UI component

Task 2: User can view task list
        └── DB query + API endpoint + List component

Task 3: User can complete a task
        └── DB update + API handler + Toggle UI
```

### Horizontal Slices (Anti-pattern)

Layers completed separately:

```
Task 1: Create all DB models
Task 2: Create all API routes
Task 3: Create all UI components

❌ Problem: Nothing works until everything is done
```

---

## Slicing Strategies

### 1. Happy Path First

```
Slice 1: Basic flow works
Slice 2: Add validation
Slice 3: Add error handling
Slice 4: Add edge cases
```

### 2. Risk-First

```
Slice 1: Uncertain/complex piece (reduce risk early)
Slice 2: Dependent pieces (build on verified foundation)
Slice 3: Polish (now safe to invest time)
```

### 3. Contract-First

```
Slice 1: Define API contract (types, endpoints)
Slice 2: Backend implements contract
Slice 3: Frontend implements against contract
```

---

## Rules

### The 100-Line Rule

> Test before writing more than ~100 lines.

If you've written 100+ lines without running tests, stop and verify.

### Touch Only What's Needed

> Don't refactor adjacent code. Don't add unrequested features.

Stay focused on the current task.

### Keep It Building

> Project must compile and tests must pass after each increment.

Never leave the codebase broken between commits.

### Feature Flags for Incomplete Work

```javascript
// Use flags when merging incomplete features
if (featureFlags.newCheckout) {
  return <NewCheckoutFlow />;
}
return <LegacyCheckout />;
```

### Safe Defaults

New code defaults to conservative, disabled behavior:
- New features off by default
- New permissions denied by default
- New validations strict by default

### Rollback-Friendly

Each increment should be independently revertable:

```bash
# If this commit breaks something, revert just this
git revert HEAD
```

---

## Red Flags

**Stop and reassess if you're:**

- Writing > 100 lines without testing
- Mixing unrelated changes in one commit
- Expanding scope mid-task
- Breaking the build between increments
- Creating abstractions "for later"
- Touching files outside the task scope

---

## Commit Strategy

Each increment = one commit:

```bash
# Good: Atomic, focused commits
git commit -m "feat(tasks): add Task model with title and status"
git commit -m "feat(tasks): add POST /api/tasks endpoint"
git commit -m "feat(tasks): add CreateTaskForm component"

# Bad: Large, unfocused commits
git commit -m "Add task feature"  # 500 lines across 10 files
```

---

## When Stuck

If an increment fails:

1. **Stop** — Don't push through
2. **Diagnose** — What specifically failed?
3. **Reduce scope** — Can you make a smaller increment?
4. **Ask for help** — If truly blocked

---

## Verification Checklist

After each increment:

- [ ] Tests pass
- [ ] Build succeeds
- [ ] Code compiles
- [ ] Feature works (manual check if UI)
- [ ] Commit is atomic and focused
- [ ] Message follows conventions

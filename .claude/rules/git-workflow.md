# Git Workflow

## Branch Strategy (Git Flow)

```
main          — Production-ready code only
develop       — Integration branch for features
feature/*     — New features
fix/*         — Bug fixes
hotfix/*      — Urgent production fixes
release/*     — Release preparation
```

## Branch Naming
```
feature/user-authentication
feature/payment-integration
fix/login-redirect-bug
fix/order-calculation-issue
hotfix/critical-security-patch
release/v1.2.0
```

## Commit Message Format (Conventional Commits)

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

### Types
| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Code restructure, no feature/fix |
| `test` | Adding or fixing tests |
| `chore` | Build process, dependencies |
| `perf` | Performance improvement |

### Examples
```
feat(auth): add JWT refresh token support

fix(orders): correct total price calculation when discount applied

docs(api): add Swagger annotations to user endpoints

test(users): add unit tests for UserService.GetByIdAsync

chore(deps): upgrade Microsoft.EntityFrameworkCore to v8.0.5
```

## Pull Request Rules
- PRs must reference an issue: `Closes #123`
- Minimum 1 reviewer approval required
- All CI checks must pass
- No direct commits to `main` or `develop`
- PR title must follow conventional commit format

## Branch Protection (Required on `main` and `develop`)

Configure on the Git host (GitHub / Azure DevOps / GitLab):

- Require pull request before merging — **no direct pushes**
- Require ≥ 1 approving review
- Require status checks to pass: `build`, `test`, `coverage`, `security-scan`
- Require linear history (no merge commits on `main`)
- Require signed commits (recommended)
- Block force-push and branch deletion
- Dismiss stale approvals when new commits are pushed
- Restrict who can push to `main` (release managers only)

## Pre-Commit Hooks

Use a `.git/hooks/pre-commit` (or [Husky.NET](https://github.com/alirezanet/Husky.Net)) that runs **before every commit**:

```bash
# .husky/pre-commit
dotnet format --verify-no-changes              # enforce code-style.md
dotnet build --no-restore -c Release           # must compile
dotnet test --no-build --filter "Category=Unit" # unit tests pass
dotnet list package --vulnerable --include-transitive  # see security.md
```

> Hook must exit non-zero on any failure. Never bypass with `--no-verify` unless explicitly authorized.

### Pre-Push Hook (optional but recommended)
```bash
# .husky/pre-push
dotnet test  # full suite including integration tests
```

## Commit Best Practices
- Commit frequently with small, focused changes
- Each commit should be a single logical change
- Never commit: `appsettings.*.json` with real secrets, `.env`, `bin/`, `obj/`, `*.user`
- Always run tests before committing

## Tags & Releases
```bash
# Tag a release
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

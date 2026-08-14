# Override: Language — PHP

> **Active when** `Project Profile → Core` declares PHP (Laravel / ...). Read alongside `rules/clean-code.md`, `rules/code-style.md`, `rules/naming-conventions.md` (base — C#). This file **only records the differences** for PHP; agnostic principles (SOLID, YAGNI, KISS, single-purpose method, no flag params, no side effects) **remain unchanged**.

---

## Language & runtime baseline

| Aspect | Default choice | Notes |
|--------|---------------|-------|
| Language | **PHP 8.3** (default) | **8.2 minimum** — still in active support. Older runtimes are legacy-only; upgrading them is a B5 task with an ADR, not a side effect. |
| Package manager | **Composer 2** | `composer.lock` MUST be committed. One package manager, no mixing with PEAR/manual vendoring. |
| Autoload | **PSR-4** (`autoload` map in `composer.json`) | No manual `require`/`include` of class files in new code. |
| Strict types | `declare(strict_types=1)` **REQUIRED in every NEW file** | Brownfield: do **NOT** mass-retrofit legacy files — add per-change only (a file you are already modifying may gain it; untouched files stay as-is, per `brownfield.md` §No Gratuitous Refactor). |

---

## Naming conventions

Unlike C# (PascalCase for methods/properties, `I` prefix on interfaces), PHP follows PSR + Laravel conventions:

| Element | Convention | Example |
|---------|------------|---------|
| Class, interface, trait, enum | StudlyCase (PascalCase) | `UserService`, `OrderStatus` |
| Interface | **no `I` prefix** — plain name or `*Interface` suffix | `Clock`, `PaymentGatewayInterface` (not `IPaymentGateway`) |
| Method, variable, property | camelCase | `getUserById`, `$orderTotal` |
| Constant (class + module) | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_SECONDS` |
| Config keys, array keys, DB columns | snake_case | `'user_id'`, `services.mailer.api_key` |
| File name | PSR-4 — one class per file, filename = class name | `UserService.php` |
| Laravel class suffixes | `*Controller`, `*Request` (FormRequest), `*Resource`, `*Job`, `*Listener`, `*Policy`, `*Factory`, `*Seeder` | `BookmarkController`, `StoreBookmarkRequest` |
| Blade views / route names | kebab-case segments + dot notation | `users.show`, `partials.nav-bar` |
| Boolean | `is/has/can` prefix | `isActive`, `hasVerifiedEmail` |

**Brownfield note:** legacy `snake_case` variables/methods in untouched code **stay as-is** — renaming for style is a gratuitous refactor. New code follows the table.

---

## Type safety

- **Typed properties + parameter/return types are mandatory for all new code.** An untyped signature in a new file is a review finding.
- **`mixed` is the `any` equivalent — forbidden without a one-line justification comment** (e.g. genuinely heterogeneous decoded JSON before schema validation).
- **Always `===`/`!==`** — PHP loose equality (`==`) has coercion rules C# does not have; strict comparison is the default, loose comparison needs a justifying comment.

### PHPStan / Larastan — level ≥ 6 with brownfield baseline + ratchet

- **New code analyzes clean at level ≥ 6.**
- **Brownfield:** generate a baseline once (`vendor/bin/phpstan analyse --generate-baseline`) so existing errors do not block, then **ratchet — the baseline error count must not grow**; no mass retrofit of legacy findings (same philosophy as the kit's coverage ratchet, `rules/testing.md` §Coverage Thresholds).

### DTOs — `readonly` classes; enums — backed, not class constants

```php
// ❌ Bad — mutable array-shaped data + magic string states
function createUser(array $data): array { ... }
const STATUS_ACTIVE = 'active';

// ✅ Good — readonly DTO + backed enum
final readonly class CreateUserInput
{
    public function __construct(
        public string $email,
        public string $name,
    ) {}
}

enum UserRole: string
{
    case User = 'user';
    case Admin = 'admin';
}
```

---

## Error handling primitives

Mirror the kit contract (`rules/error-handling.md` — `AppException` with a stable code + status). PHP's base `\Exception` reserves `$code` as an `int`, so the kit's string code lives in `$errorCode`:

```php
// app/Exceptions/AppException.php
declare(strict_types=1);

namespace App\Exceptions;

use Exception;

abstract class AppException extends Exception
{
    public function __construct(
        string $message,
        public readonly string $errorCode,
        public readonly int $statusCode,
    ) {
        parent::__construct($message);
    }
}

final class NotFoundException extends AppException
{
    public function __construct(string $entity, string|int $id)
    {
        parent::__construct("{$entity} with ID '{$id}' not found", 'NOT_FOUND', 404);
    }
}

final class ConflictException extends AppException
{
    public function __construct(string $message)
    {
        parent::__construct($message, 'CONFLICT', 409);
    }
}

/** Domain-level validation only — HTTP input validation under Laravel uses the
 *  framework's own Illuminate\Validation\ValidationException, mapped at the
 *  boundary (see framework-php-laravel.md §C). */
final class ValidationException extends AppException
{
    /** @param array<string, list<string>> $errors */
    public function __construct(public readonly array $errors)
    {
        parent::__construct('Validation failed', 'VALIDATION_ERROR', 400);
    }
}
```

**Rules:**
- **Never return `false` / error-arrays from new code** — the classic legacy PHP pattern (`return false;` on failure, `['error' => ...]` payloads). New code throws a typed `AppException` subclass. **Legacy APIs that do get characterization tests, not rewrites** (`rules/brownfield.md`).
- Do NOT silently swallow with `catch (Throwable $e) {}` — log or rethrow.
- Global handler at the boundary maps `AppException` → HTTP response per RFC 7807 → [`framework-php-laravel.md`](framework-php-laravel.md) §C.

---

## Dependency security baseline

| Check | Tool | Frequency |
|-------|------|-----------|
| Production CVE | `composer audit --no-dev` | Every commit (pre-push) + CI |
| Full audit (incl. dev) | `composer audit` | Weekly (informational) |
| Outdated packages | `composer outdated --direct` | Weekly |
| Abandoned packages | `composer audit` reports them — replace or record an ADR | Weekly |
| Secrets in code | `gitleaks` / regex grep | Every commit |

**Rule:** Dev-tool advisories (pint, phpstan, pest plugins) **do not block** Gate 8 — they do not ship to users. Production-runtime findings (laravel/framework, guzzle, sanctum, ...) **block** (same rule as the Node.js override).

---

## Linting & formatting

| Tool | Purpose | Config file |
|------|---------|-------------|
| **Laravel Pint** | Formatting (PSR-12 preset) | `pint.json` |
| **PHPStan + Larastan** | Static analysis, level ≥ 6 | `phpstan.neon` |

```jsonc
// pint.json
{
    "preset": "psr12"
}
```

```neon
# phpstan.neon
includes:
    - vendor/larastan/larastan/extension.neon
    - phpstan-baseline.neon   # brownfield only — generated once, ratcheted down

parameters:
    level: 6
    paths:
        - app
```

**Pre-commit hook:** run `vendor/bin/pint --test` + `vendor/bin/phpstan analyse` before every commit (same discipline as `rules/git-workflow.md` §Pre-Commit Hooks; hook must exit non-zero on failure).

---

## What stays unchanged (still follows base rules)

- SOLID, YAGNI, KISS, DRY (with discipline) — `principles-and-practices.md`
- Composition > Inheritance, Tell-Don't-Ask, Law of Demeter — `clean-code.md`
- ≤3 parameters per method, single-responsibility method, no flag params — `clean-code.md`
- Idempotency, ADR, postmortem, code review — `principles-and-practices.md`
- Audit columns (`created_at`, `updated_at`, `created_by`, `updated_by`), soft delete, optimistic concurrency — `principles-and-practices.md §4.5`
- Docker baseline 20 must-haves — `principles-and-practices.md §4`
- Brownfield discipline (characterization test, backward compat, ADR-to-change) — `brownfield.md`

---

## See also (PHP stack specifically)

- Framework patterns (Laravel) → [`framework-php-laravel.md`](framework-php-laravel.md)
- Test framework (Pest / PHPUnit) → [`test-php.md`](test-php.md)
- Database dialect (MySQL / PostgreSQL are the common Laravel pairings) → [`database-mysql.md`](database-mysql.md) / [`database-postgres.md`](database-postgres.md)

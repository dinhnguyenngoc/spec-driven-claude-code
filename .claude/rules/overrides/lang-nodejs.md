# Override: Language — Node.js (JavaScript / TypeScript)

> **Active when** `Project Profile → Core` declares Node.js (Express / NestJS / Fastify / ...). Read alongside `rules/clean-code.md`, `rules/code-style.md`, `rules/naming-conventions.md` (base — C#). This file **only records the differences** for JavaScript/TypeScript; agnostic principles (SOLID, YAGNI, KISS, single-purpose method, no flag params, async correctness, no side effects) **remain unchanged**.

---

## Language & runtime baseline

| Aspect | Default choice | Notes |
|--------|---------------|-------|
| Language | **TypeScript 5.x** (strict) | JavaScript is only accepted for legacy not yet migrated. All new code = TS. |
| Runtime | Node.js **20 LTS** (or 22 LTS) | Track LTS, do not use odd-version. |
| Package manager | npm (default) / pnpm / yarn berry — pick 1, do NOT mix | Lock file MUST be committed. |
| Module system | ESM (`"type": "module"` in `package.json`) | CommonJS only for legacy. |
| TypeScript config | `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`, `exactOptionalPropertyTypes: true` | See `rules/frontend.md` §TypeScript — apply the same way for backend. |

---

## Naming conventions

Unlike C# (PascalCase for method/property), Node.js uses camelCase for every runtime identifier:

| Element | Convention | Example |
|---------|------------|---------|
| Variable, function, method | camelCase | `getUserById`, `orderTotal` |
| Class, interface, type, enum | PascalCase | `UserService`, `OrderStatus` |
| Constant (module-level immutable) | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_MS` |
| Private field (class) | `#privateField` (modern) or `_privateField` (TS) | `#repository`, `_logger` |
| Type parameter (generic) | TPascalCase | `TEntity`, `TKey` |
| File name | kebab-case | `user.service.ts`, `order-repository.ts` |
| Folder | kebab-case | `user-management/`, `order-items/` |
| Test file | `<source>.test.ts` or `<source>.spec.ts` | `user.service.test.ts` |
| Async function | NO `Async` suffix needed (unlike C#) — the `async` keyword is clear enough | `getUser()` instead of `getUserAsync()` |
| Boolean | `is/has/can` prefix | `isActive`, `hasPermission` |

**Why NO `Async` suffix:** in JS/TS, the `async` keyword + return type `Promise<T>` is already clear enough. The `Async` suffix (following the C# convention) is considered noise. Apply this convention specifically for the Node.js stack.

---

## Type safety (TypeScript strict)

### Do NOT use `any` — always `unknown` + narrow

```typescript
// ❌ Bad
function parse(input: any) { return JSON.parse(input); }

// ✅ Good
function parse(input: unknown): User {
  const data = JSON.parse(String(input));
  return UserSchema.parse(data); // Zod validate
}
```

### Type vs Interface

- `type` for union/intersection/mapped types: `type UserRole = "user" | "admin"`
- `interface` for object shapes that can be extended: `interface UserProps { ... }`

### Schema validation at the boundary

- Default library: **Zod** (BE + FE, reusable schema)
- Every input coming from outside (HTTP body, query, env var, message queue payload) MUST be parsed through a schema before going deeper into the logic.

```typescript
import { z } from "zod";

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
});
type CreateUserInput = z.infer<typeof CreateUserSchema>;

// At the boundary (controller / route handler)
const input = CreateUserSchema.parse(req.body); // throws ZodError if invalid
```

---

## Async/await — discipline

- **Use async/await for all I/O**, not Promise `.then()` chains (except simple pipelines).
- **Do NOT block the event loop** — `fs.readFileSync`, `JSON.parse` on a large payload, and `bcrypt.hashSync` all block. Use the async variant.
- **Do NOT use `forEach` with async** — `Array.prototype.forEach` does not await the callback. Use `for ... of` or `Promise.all(map(...))`.

```typescript
// ❌ Bad — forEach does not await
users.forEach(async (u) => await sendEmail(u));

// ✅ Good — concurrent
await Promise.all(users.map((u) => sendEmail(u)));

// ✅ Good — serial (when order matters)
for (const u of users) {
  await sendEmail(u);
}
```

- **Unhandled rejection**: enable `process.on("unhandledRejection", handler)` at the entry point to log + alert.

---

## Linting & formatting

| Tool | Purpose | Config file |
|------|----------|-------------|
| **ESLint** | Lint rules + security | `eslint.config.js` (flat config, ESLint 9+) |
| **Prettier** | Formatting | `.prettierrc` |
| **typescript-eslint** | TS-aware rules | Plugin `@typescript-eslint` |
| **eslint-plugin-security** | OWASP security rules (node) | Plugin `security` |
| **eslint-plugin-n** | Node.js best practices | Plugin `n` |

Minimal ESLint config (security-focused):

```javascript
// eslint.config.js
import tseslint from "typescript-eslint";
import securityPlugin from "eslint-plugin-security";

export default tseslint.config(
  ...tseslint.configs.strictTypeChecked,
  securityPlugin.configs.recommended,
  {
    rules: {
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-new-func": "error",
      "no-script-url": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error", // await is mandatory
      "@typescript-eslint/no-misused-promises": "error",
      "security/detect-object-injection": "warn",
      "security/detect-non-literal-fs-filename": "warn",
      "security/detect-child-process": "error",
    },
  },
);
```

**Pre-commit hook** (Husky + lint-staged): run `eslint --max-warnings=0` + `prettier --check` + `tsc --noEmit` before every commit.

---

## Error handling primitives

Unlike C# (`AppException` extends `Exception`), in TS use the `Error` base class:

```typescript
// shared/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number,
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace?.(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(entity: string, id: string | number) {
    super(`${entity} with ID '${id}' not found`, "NOT_FOUND", 404);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, "CONFLICT", 409);
  }
}

export class ValidationError extends AppError {
  constructor(public readonly errors: Record<string, string[]>) {
    super("Validation failed", "VALIDATION_ERROR", 400);
  }
}
```

**Rules:**
- Do NOT throw a `string` or plain object — always throw a subclass of `Error` (so you get a stack trace).
- Do NOT silently swallow with `catch (e)` — log or rethrow.
- Global error handler at the boundary (Express middleware / NestJS exception filter / Fastify error handler) → map `AppError` → HTTP response per RFC 7807.

---

## Imports & module organization

```typescript
// Import order (top → bottom)
// 1. Node built-in
import { readFile } from "node:fs/promises";
import path from "node:path";

// 2. External packages
import express from "express";
import { z } from "zod";

// 3. Internal alias (e.g. @/lib, @/services)
import { db } from "@/db";
import { UserService } from "@/services/user.service";

// 4. Relative
import { mapper } from "./mapper";
```

Enable `eslint-plugin-import` + rule `import/order` to enforce.

**Path alias** in `tsconfig.json`:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

---

## Dependency security baseline

| Check | Tool | Frequency |
|-------|------|---------|
| Production CVE | `npm audit --omit=dev` | Every commit (pre-push) + CI |
| Full audit (incl. dev) | `npm audit` | Weekly (informational) |
| Outdated packages | `npm outdated` | Weekly |
| License check | `license-checker` | Pre-release |
| Static security rules | `eslint-plugin-security` | Every build |
| Secrets in code | `gitleaks` / regex grep | Every commit |
| Retired/vulnerable JS libs | `retire.js` | Every build |

**Rule:** Dev-tool advisories (vite, jest, eslint plugins) **do not block** Gate 8 — they do not ship to users. Production-runtime findings (express, react, axios, zod, ...) **block**.

---

## What stays unchanged (still follows base rules)

- SOLID, YAGNI, KISS, DRY (with discipline) — `principles-and-practices.md`
- Composition > Inheritance, Tell-Don't-Ask, Law of Demeter — `clean-code.md`
- ≤3 parameters per method, single-responsibility method, no flag params — `clean-code.md`
- Idempotency, ADR, postmortem, code review — `principles-and-practices.md`
- Audit columns (`createdAt`, `updatedAt`, `createdBy`, `updatedBy`), soft delete, optimistic concurrency — `principles-and-practices.md §4.5`
- Docker baseline 20 must-haves — `principles-and-practices.md §4`
- Brownfield discipline (characterization test, backward compat, ADR-to-change) — `brownfield.md`

---

## See also (Node.js stack specifically)

- Framework patterns (Express / NestJS / Fastify) → [`framework-nodejs-web.md`](framework-nodejs-web.md)
- Test framework (Jest / Vitest) → [`test-nodejs.md`](test-nodejs.md)
- Frontend (Next.js/Vue/Angular) → base `rules/frontend.md` (already covers Next.js); other frontend overrides → `frontend-<framework>.md`

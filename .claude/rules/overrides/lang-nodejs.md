# Override: Language — Node.js (JavaScript / TypeScript)

> **Active when** `Project Profile → Core` declares Node.js (Express / NestJS / Fastify / ...). Read alongside `rules/clean-code.md`, `rules/code-style.md`, `rules/naming-conventions.md` (base — C#). This file **only records the differences** for JavaScript/TypeScript; agnostic principles (SOLID, YAGNI, KISS, single-purpose method, no flag params, async correctness, no side effects) **remain unchanged**.

---

## Language & runtime baseline

| Aspect | Default choice | Notes |
|--------|---------------|-------|
| Language | **TypeScript 5.x** (strict) | JavaScript chỉ chấp nhận cho legacy chưa migrate. Mọi code mới = TS. |
| Runtime | Node.js **20 LTS** (hoặc 22 LTS) | Track LTS, không dùng odd-version. |
| Package manager | npm (default) / pnpm / yarn berry — chọn 1, KHÔNG mix | Lock file PHẢI commit. |
| Module system | ESM (`"type": "module"` trong `package.json`) | CommonJS chỉ cho legacy. |
| TypeScript config | `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`, `exactOptionalPropertyTypes: true` | Tham khảo `rules/frontend.md` §TypeScript — áp dụng tương tự cho backend. |

---

## Naming conventions

Khác với C# (PascalCase cho method/property), Node.js dùng camelCase cho mọi runtime identifier:

| Element | Convention | Example |
|---------|------------|---------|
| Variable, function, method | camelCase | `getUserById`, `orderTotal` |
| Class, interface, type, enum | PascalCase | `UserService`, `OrderStatus` |
| Constant (module-level immutable) | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_MS` |
| Private field (class) | `#privateField` (modern) hoặc `_privateField` (TS) | `#repository`, `_logger` |
| Type parameter (generic) | TPascalCase | `TEntity`, `TKey` |
| File name | kebab-case | `user.service.ts`, `order-repository.ts` |
| Folder | kebab-case | `user-management/`, `order-items/` |
| Test file | `<source>.test.ts` hoặc `<source>.spec.ts` | `user.service.test.ts` |
| Async function | KHÔNG cần `Async` suffix (khác C#) — `async` keyword đủ rõ | `getUser()` thay vì `getUserAsync()` |
| Boolean | `is/has/can` prefix | `isActive`, `hasPermission` |

**Lý do KHÔNG suffix `Async`:** trong JS/TS, `async` keyword + return type `Promise<T>` đã đủ rõ. Suffix `Async` (theo C# convention) bị xem là noise. Áp dụng riêng quy ước này cho Node.js stack.

---

## Type safety (TypeScript strict)

### KHÔNG dùng `any` — luôn `unknown` + narrow

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

- `type` cho union/intersection/mapped types: `type UserRole = "user" | "admin"`
- `interface` cho object shape có thể extend: `interface UserProps { ... }`

### Schema validation tại boundary

- Default library: **Zod** (BE + FE, schema reusable)
- Mọi input đến từ ngoài (HTTP body, query, env var, message queue payload) PHẢI parse qua schema trước khi đi sâu vào logic.

```typescript
import { z } from "zod";

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
});
type CreateUserInput = z.infer<typeof CreateUserSchema>;

// Tại boundary (controller / route handler)
const input = CreateUserSchema.parse(req.body); // throws ZodError nếu invalid
```

---

## Async/await — discipline

- **Mọi I/O dùng async/await**, không Promise `.then()` chains (trừ pipeline đơn giản).
- **KHÔNG block event loop** — `fs.readFileSync`, `JSON.parse` trên payload lớn, `bcrypt.hashSync` đều block. Dùng async variant.
- **KHÔNG `forEach` với async** — `Array.prototype.forEach` không await callback. Dùng `for ... of` hoặc `Promise.all(map(...))`.

```typescript
// ❌ Bad — forEach không await
users.forEach(async (u) => await sendEmail(u));

// ✅ Good — concurrent
await Promise.all(users.map((u) => sendEmail(u)));

// ✅ Good — serial (khi cần thứ tự)
for (const u of users) {
  await sendEmail(u);
}
```

- **Unhandled rejection**: bật `process.on("unhandledRejection", handler)` ở entry point để log + alert.

---

## Linting & formatting

| Tool | Mục đích | Config file |
|------|----------|-------------|
| **ESLint** | Lint rules + security | `eslint.config.js` (flat config, ESLint 9+) |
| **Prettier** | Formatting | `.prettierrc` |
| **typescript-eslint** | TS-aware rules | Plugin `@typescript-eslint` |
| **eslint-plugin-security** | OWASP security rules (node) | Plugin `security` |
| **eslint-plugin-n** | Node.js best practices | Plugin `n` |

ESLint config tối thiểu (security-focused):

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
      "@typescript-eslint/no-floating-promises": "error", // bắt buộc await
      "@typescript-eslint/no-misused-promises": "error",
      "security/detect-object-injection": "warn",
      "security/detect-non-literal-fs-filename": "warn",
      "security/detect-child-process": "error",
    },
  },
);
```

**Pre-commit hook** (Husky + lint-staged): chạy `eslint --max-warnings=0` + `prettier --check` + `tsc --noEmit` trước mỗi commit.

---

## Error handling primitives

Khác với C# (`AppException` extends `Exception`), trong TS dùng class `Error` base:

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

**Quy tắc:**
- KHÔNG throw `string` hoặc plain object — luôn throw subclass của `Error` (để có stack trace).
- KHÔNG `catch (e)` swallow silent — log hoặc rethrow.
- Global error handler tại boundary (Express middleware / NestJS exception filter / Fastify error handler) → map `AppError` → HTTP response theo RFC 7807.

---

## Imports & module organization

```typescript
// Thứ tự import (top → bottom)
// 1. Node built-in
import { readFile } from "node:fs/promises";
import path from "node:path";

// 2. External packages
import express from "express";
import { z } from "zod";

// 3. Internal alias (vd: @/lib, @/services)
import { db } from "@/db";
import { UserService } from "@/services/user.service";

// 4. Relative
import { mapper } from "./mapper";
```

Bật `eslint-plugin-import` + rule `import/order` để enforce.

**Path alias** trong `tsconfig.json`:
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

| Check | Tool | Tần suất |
|-------|------|---------|
| Production CVE | `npm audit --omit=dev` | Mỗi commit (pre-push) + CI |
| Full audit (incl. dev) | `npm audit` | Weekly (informational) |
| Outdated packages | `npm outdated` | Weekly |
| License check | `license-checker` | Pre-release |
| Static security rules | `eslint-plugin-security` | Mỗi build |
| Secrets in code | `gitleaks` / regex grep | Mỗi commit |
| Retired/vulnerable JS libs | `retire.js` | Mỗi build |

**Rule:** Dev-tool advisories (vite, jest, eslint plugins) **không block** Gate 8 — chúng không ship to users. Production-runtime findings (express, react, axios, zod, ...) **block**.

---

## What stays unchanged (vẫn theo base rules)

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
- Frontend (Next.js/Vue/Angular) → base `rules/frontend.md` (đã cover Next.js); override khác frontend → `frontend-<framework>.md`

# Override: Testing — Node.js (Jest / Vitest)

> **Active when** `Project Profile → Core` declares Node.js. Read alongside `rules/testing.md` (base — xUnit + FluentAssertions + Moq + TestContainers). This file **only records the differences**; agnostic principles (testing pyramid, 80% coverage threshold, naming convention `{Method}_{Scenario}_{Expected}`, Arrange-Act-Assert, no shared state, TestContainers for integration) **remain unchanged**.

---

## Test framework choice

| Framework | Best fit | Avoid when |
|-----------|----------|-----------|
| **Jest** (default for most) | Mature, plugin rich, widely used, NestJS default | ESM-only project (Jest's ESM configuration is still cumbersome) |
| **Vitest** (modern, recommended for Vite-based / pure ESM) | Vite project, ESM native, fast, Jest-compatible API | NestJS (officially supports Jest) |
| **node:test** (built-in from Node 20+) | Project that wants 0 dependencies | Needs a rich fixture / mock framework |

**Default recommendation:**
- NestJS → **Jest** (official)
- Express / Fastify → **Vitest** (greenfield) or **Jest** (existing brownfield)
- Library / SDK package → **Vitest** or **node:test**

---

## Test file organization

```
src/
├── users/
│   ├── user.service.ts
│   ├── user.service.test.ts          # ← next to source (recommended)
│   └── user.controller.test.ts
├── orders/
│   └── ...
tests/
├── integration/                       # cross-module, in-memory DB
│   └── users.integration.test.ts
├── e2e/                              # full HTTP stack with TestContainers
│   └── user-registration.e2e.test.ts
├── helpers/
│   └── test-app.ts                    # build Express/NestJS/Fastify app for test
└── fixtures/
    └── users.fixture.ts
```

**Rule:** Unit tests next to source (`*.test.ts`), integration + E2E in the `tests/` root.

---

## Test naming convention

Keep the base: **`{method}_{scenario}_{expected}`** (or use the `describe` + `it` pattern):

```typescript
describe("UserService.findById", () => {
  it("returns user when exists", async () => { ... });
  it("throws NotFoundError when user not found", async () => { ... });
});
```

Or flat (closer to xUnit style):
```typescript
test("findById_whenUserExists_returnsUser", async () => { ... });
test("findById_whenUserNotFound_throwsNotFoundError", async () => { ... });
```

---

## Unit test — Jest example

```typescript
// src/users/user.service.test.ts
import { UserService } from "./user.service";
import type { UserRepository } from "./user.repository";
import { NotFoundError } from "@/shared/errors";

describe("UserService", () => {
  let userService: UserService;
  let mockRepo: jest.Mocked<UserRepository>;

  beforeEach(() => {
    mockRepo = {
      findById: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    } as unknown as jest.Mocked<UserRepository>;
    userService = new UserService(mockRepo);
  });

  describe("findById", () => {
    it("returns user when exists", async () => {
      // Arrange
      const userId = "abc-123";
      const expected = { id: userId, email: "test@example.com", name: "Test" };
      mockRepo.findById.mockResolvedValue(expected);

      // Act
      const result = await userService.findById(userId);

      // Assert
      expect(result).toEqual(expected);
      expect(mockRepo.findById).toHaveBeenCalledWith(userId);
      expect(mockRepo.findById).toHaveBeenCalledTimes(1);
    });

    it("throws NotFoundError when user not found", async () => {
      // Arrange
      mockRepo.findById.mockResolvedValue(null);

      // Act + Assert
      await expect(userService.findById("missing")).rejects.toThrow(NotFoundError);
      await expect(userService.findById("missing")).rejects.toMatchObject({
        code: "NOT_FOUND",
        statusCode: 404,
      });
    });
  });

  describe.each([
    ["", "Email is required"],
    ["not-an-email", "Invalid email"],
    [" ", "Email is required"],
  ])("create with invalid email '%s'", (email, expectedError) => {
    it(`throws ValidationError: ${expectedError}`, async () => {
      await expect(userService.create({ email, name: "X", password: "Password123!" }))
        .rejects.toThrow("Validation");
    });
  });
});
```

### Vitest equivalent (95% Jest-compatible API)

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { UserService } from "./user.service";
// ... replace jest.fn() → vi.fn(), jest.Mocked → ReturnType<typeof vi.mocked>
```

---

## Integration test — pick template by phase

Same as base `rules/testing.md` §Integration Test Templates — there are **2 templates** split by phase:

| Phase | DB backend | Docker | Speed | Catches |
|-------|-----------|--------|-------|---------|
| `/build` | In-memory (Prisma test env / SQLite memory) | ❌ | ms | Logic, mapping, validation |
| `/test` | **TestContainers** (Postgres/MySQL real container) | ✅ | seconds | Index, transaction, collation, dialect bugs |

### Template A — In-memory (for `/build`)

```typescript
// tests/helpers/in-memory-app.ts
import { PrismaClient } from "@prisma/client";
import { execSync } from "node:child_process";
import { buildApp } from "@/app";

export async function createInMemoryApp() {
  // SQLite memory or test DB schema
  process.env.DATABASE_URL = "file::memory:?cache=shared";
  execSync("npx prisma db push --skip-generate", { stdio: "inherit" });
  const prisma = new PrismaClient();
  const app = buildApp({ prisma });
  return { app, prisma, cleanup: async () => prisma.$disconnect() };
}
```

```typescript
// src/users/__tests__/users.integration.test.ts (NO RequiresDocker tag)
describe("UsersController (integration, in-memory)", () => {
  let app, prisma, cleanup;
  beforeAll(async () => ({ app, prisma, cleanup } = await createInMemoryApp()));
  afterAll(async () => cleanup());

  it("POST /api/v1/users returns 201", async () => {
    const res = await request(app).post("/api/v1/users").send({
      email: `test-${Date.now()}@example.com`,
      name: "Test",
      password: "Password123!",
    });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ email: expect.any(String) });
  });
});
```

### Template B — TestContainers (for `/test`)

```typescript
// tests/helpers/testcontainers-app.ts
import { PostgreSqlContainer, StartedPostgreSqlContainer } from "@testcontainers/postgresql";
import { PrismaClient } from "@prisma/client";
import { execSync } from "node:child_process";

let container: StartedPostgreSqlContainer;
let prisma: PrismaClient;

export async function startTestApp() {
  container = await new PostgreSqlContainer("postgres:16-alpine").start();
  process.env.DATABASE_URL = container.getConnectionUri();
  execSync("npx prisma migrate deploy", { stdio: "inherit" });
  prisma = new PrismaClient();
  return { prisma, app: buildApp({ prisma }) };
}

export async function stopTestApp() {
  await prisma?.$disconnect();
  await container?.stop();
}
```

```typescript
// tests/e2e/users.e2e.test.ts
// @testcategory:RequiresDocker — by file-name convention or tag
describe("Users E2E (TestContainers Postgres)", () => {
  beforeAll(async () => { ({ prisma, app } = await startTestApp()); }, 60_000);
  afterAll(stopTestApp);

  // ... real HTTP tests
});
```

**Marking a test that needs Docker:** Jest uses `testPathIgnorePatterns` per config; Vitest uses `--exclude` or a test name pattern. Do NOT use xUnit `[Trait]` (C#).

Run by category:
```bash
# Default: run every test that does NOT need Docker
npm test

# Run E2E only
npm test -- tests/e2e

# Skip E2E
npm test -- --testPathIgnorePatterns="tests/e2e"
```

---

## Assertions — mapping FluentAssertions → Jest/Vitest

| FluentAssertions (C#) | Jest / Vitest |
|----------------------|---------------|
| `result.Should().NotBeNull()` | `expect(result).not.toBeNull()` |
| `result.Should().Be(expected)` | `expect(result).toBe(expected)` (referential) or `toEqual` (deep) |
| `result.Should().BeEquivalentTo(expected)` | `expect(result).toEqual(expected)` |
| `users.Should().HaveCount(3)` | `expect(users).toHaveLength(3)` |
| `users.Should().Contain(u => u.email == "x")` | `expect(users).toContainEqual(expect.objectContaining({ email: "x" }))` |
| `email.Should().Contain("@")` | `expect(email).toContain("@")` |
| `total.Should().BeGreaterThan(0)` | `expect(total).toBeGreaterThan(0)` |
| `act.Should().ThrowAsync<NotFoundError>()` | `await expect(act()).rejects.toThrow(NotFoundError)` |
| `actual.Should().BeEquivalentTo(expected, opt => opt.Excluding(u => u.CreatedAt))` | `expect(actual).toMatchObject({ ...expected, createdAt: expect.any(Date) })` |

---

## Mocking strategy

Preference order **unchanged** from base:
1. **Real implementation** (in-memory DB via Prisma, real HTTP with supertest)
2. **Fake** (custom in-memory implementation)
3. **Stub** (canned response via `jest.fn().mockResolvedValue(...)`)
4. **Mock** (verify interaction via `expect(fn).toHaveBeenCalledWith(...)` — use sparingly)

```typescript
// Stub example
const mockRepo = { findById: jest.fn().mockResolvedValue(user) };

// Mock verify example
expect(mockLogger.info).toHaveBeenCalledWith(
  expect.objectContaining({ userId }),
  "User created"
);
```

---

## Coverage thresholds (keep base 80%)

### Jest config (`jest.config.ts`)

```typescript
export default {
  coverageThreshold: {
    global: { branches: 75, functions: 80, lines: 80, statements: 80 },
  },
  coverageReporters: ["text", "lcov", "html"],
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/*.test.ts",
    "!src/server.ts", // bootstrap does not count
  ],
};
```

### Vitest config (`vitest.config.ts`)

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      thresholds: { branches: 75, functions: 80, lines: 80, statements: 80 },
      exclude: ["src/**/*.d.ts", "src/server.ts", "src/**/*.test.ts"],
    },
  },
});
```

Run coverage:
```bash
# Jest
npm test -- --coverage

# Vitest
npm test -- --coverage
```

---

## Common pitfalls

1. **Test is flaky because of shared state** — do NOT use module-level mutable singletons. Each test should seed its own data + clean up in `afterEach`/`afterAll`.
2. **Async not awaited** — Jest/Vitest **do not fail** a test when an async assertion is not awaited. Enable the ESLint rule `@typescript-eslint/no-floating-promises` to catch it.
3. **TestContainers is slow on macOS arm64** — pin the image with the `-alpine` or `arm64` tag for faster pulls.
4. **`describe.only` / `it.only` leaks into main** — enable the ESLint rule `jest/no-focused-tests` (Jest) or `vitest/no-focused-tests`.
5. **Mock not reset between tests** — enable `clearMocks: true` in the Jest config; Vitest resets automatically.

---

## Checklist

- [ ] Every public function/method has a unit test
- [ ] Edge cases (null, empty, boundary, **wrong-type** — see `../testing.md` §Wrong-type input) tested
- [ ] Error paths (exception, validation fail) tested
- [ ] Integration test for each controller / route
- [ ] E2E test for the main user journeys (registration, login, main CRUD)
- [ ] Independent tests (no shared state)
- [ ] Test names are meaningful
- [ ] Coverage ≥ 80% line, ≥ 75% branch
- [ ] Unit tests < 10s total
- [ ] No `.only` leaks into the main branch

---

## See also

- Language baseline → [`lang-nodejs.md`](lang-nodejs.md)
- Web framework patterns → [`framework-nodejs-web.md`](framework-nodejs-web.md)
- Base testing rules → [`../testing.md`](../testing.md)

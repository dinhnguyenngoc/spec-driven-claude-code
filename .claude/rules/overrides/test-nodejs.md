# Override: Testing — Node.js (Jest / Vitest)

> **Active when** `Project Profile → Core` declares Node.js. Read alongside `rules/testing.md` (base — xUnit + FluentAssertions + Moq + TestContainers). This file **only records the differences**; agnostic principles (testing pyramid, 80% coverage threshold, naming convention `{Method}_{Scenario}_{Expected}`, Arrange-Act-Assert, no shared state, TestContainers for integration) **remain unchanged**.

---

## Test framework choice

| Framework | Best fit | Tránh khi |
|-----------|----------|-----------|
| **Jest** (default cho hầu hết) | Mature, plugin rich, dùng nhiều, NestJS default | ESM-only project (Jest cấu hình ESM còn rườm rà) |
| **Vitest** (modern, recommend cho Vite-based / pure ESM) | Vite project, ESM native, fast, API tương thích Jest | NestJS (chính thức support Jest) |
| **node:test** (built-in từ Node 20+) | Project muốn 0 dependency | Cần fixture / mock framework phong phú |

**Khuyến nghị mặc định:**
- NestJS → **Jest** (chính thức)
- Express / Fastify → **Vitest** (greenfield) hoặc **Jest** (brownfield đã có)
- Library / SDK package → **Vitest** hoặc **node:test**

---

## Test file organization

```
src/
├── users/
│   ├── user.service.ts
│   ├── user.service.test.ts          # ← cạnh source (recommend)
│   └── user.controller.test.ts
├── orders/
│   └── ...
tests/
├── integration/                       # cross-module, in-memory DB
│   └── users.integration.test.ts
├── e2e/                              # full HTTP stack với TestContainers
│   └── user-registration.e2e.test.ts
├── helpers/
│   └── test-app.ts                    # build Express/NestJS/Fastify app cho test
└── fixtures/
    └── users.fixture.ts
```

**Quy tắc:** Unit test cạnh source (`*.test.ts`), integration + E2E trong `tests/` root.

---

## Test naming convention

Giữ nguyên base: **`{method}_{scenario}_{expected}`** (hoặc dùng `describe` + `it` pattern):

```typescript
describe("UserService.findById", () => {
  it("returns user when exists", async () => { ... });
  it("throws NotFoundError when user not found", async () => { ... });
});
```

Hoặc flat (closer to xUnit style):
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

### Vitest equivalent (API tương thích Jest 95%)

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { UserService } from "./user.service";
// ... thay jest.fn() → vi.fn(), jest.Mocked → ReturnType<typeof vi.mocked>
```

---

## Integration test — pick template by phase

Giống base `rules/testing.md` §Integration Test Templates — có **2 template** tách theo phase:

| Phase | DB backend | Docker | Speed | Catches |
|-------|-----------|--------|-------|---------|
| `/build` | In-memory (Prisma test env / SQLite memory) | ❌ | ms | Logic, mapping, validation |
| `/test` | **TestContainers** (Postgres/MySQL real container) | ✅ | seconds | Index, transaction, collation, dialect bugs |

### Template A — In-memory (cho `/build`)

```typescript
// tests/helpers/in-memory-app.ts
import { PrismaClient } from "@prisma/client";
import { execSync } from "node:child_process";
import { buildApp } from "@/app";

export async function createInMemoryApp() {
  // SQLite memory hoặc test DB schema
  process.env.DATABASE_URL = "file::memory:?cache=shared";
  execSync("npx prisma db push --skip-generate", { stdio: "inherit" });
  const prisma = new PrismaClient();
  const app = buildApp({ prisma });
  return { app, prisma, cleanup: async () => prisma.$disconnect() };
}
```

```typescript
// src/users/__tests__/users.integration.test.ts (KHÔNG có RequiresDocker tag)
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

### Template B — TestContainers (cho `/test`)

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
// @testcategory:RequiresDocker — bằng convention tên file hoặc tag
describe("Users E2E (TestContainers Postgres)", () => {
  beforeAll(async () => { ({ prisma, app } = await startTestApp()); }, 60_000);
  afterAll(stopTestApp);

  // ... real HTTP tests
});
```

**Marking test cần Docker:** Jest dùng `testPathIgnorePatterns` per config; Vitest dùng `--exclude` hoặc test name pattern. KHÔNG dùng xUnit `[Trait]` (C#).

Run by category:
```bash
# Mặc định: chạy mọi test KHÔNG cần Docker
npm test

# Chỉ chạy E2E
npm test -- tests/e2e

# Skip E2E
npm test -- --testPathIgnorePatterns="tests/e2e"
```

---

## Assertions — mapping FluentAssertions → Jest/Vitest

| FluentAssertions (C#) | Jest / Vitest |
|----------------------|---------------|
| `result.Should().NotBeNull()` | `expect(result).not.toBeNull()` |
| `result.Should().Be(expected)` | `expect(result).toBe(expected)` (referential) hoặc `toEqual` (deep) |
| `result.Should().BeEquivalentTo(expected)` | `expect(result).toEqual(expected)` |
| `users.Should().HaveCount(3)` | `expect(users).toHaveLength(3)` |
| `users.Should().Contain(u => u.email == "x")` | `expect(users).toContainEqual(expect.objectContaining({ email: "x" }))` |
| `email.Should().Contain("@")` | `expect(email).toContain("@")` |
| `total.Should().BeGreaterThan(0)` | `expect(total).toBeGreaterThan(0)` |
| `act.Should().ThrowAsync<NotFoundError>()` | `await expect(act()).rejects.toThrow(NotFoundError)` |
| `actual.Should().BeEquivalentTo(expected, opt => opt.Excluding(u => u.CreatedAt))` | `expect(actual).toMatchObject({ ...expected, createdAt: expect.any(Date) })` |

---

## Mocking strategy

Preference order **giữ nguyên** base:
1. **Real implementation** (in-memory DB qua Prisma, real HTTP với supertest)
2. **Fake** (custom in-memory implementation)
3. **Stub** (canned response qua `jest.fn().mockResolvedValue(...)`)
4. **Mock** (verify interaction qua `expect(fn).toHaveBeenCalledWith(...)` — dùng tiết kiệm)

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

## Coverage thresholds (giữ nguyên base 80%)

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
    "!src/server.ts", // bootstrap không count
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

1. **Test bị flaky vì shared state** — KHÔNG dùng module-level mutable singletons. Mỗi test tự seed data + cleanup trong `afterEach`/`afterAll`.
2. **Async chưa await** — Jest/Vitest **không fail** test khi async assertion chưa await. Bật ESLint rule `@typescript-eslint/no-floating-promises` để bắt.
3. **TestContainers chậm trên macOS arm64** — pin image với tag `-alpine` hoặc `arm64` để pull nhanh hơn.
4. **`describe.only` / `it.only` lọt vào main** — Bật ESLint rule `jest/no-focused-tests` (Jest) hoặc `vitest/no-focused-tests`.
5. **Mock không reset giữa test** — bật `clearMocks: true` trong Jest config; Vitest tự reset.

---

## Checklist

- [ ] Mọi public function/method có unit test
- [ ] Edge case (null, empty, boundary) tested
- [ ] Error path (exception, validation fail) tested
- [ ] Integration test cho mỗi controller / route
- [ ] E2E test cho user journey chính (đăng ký, login, CRUD chính)
- [ ] Test độc lập (no shared state)
- [ ] Tên test rõ ý nghĩa
- [ ] Coverage ≥ 80% line, ≥ 75% branch
- [ ] Unit test < 10s tổng
- [ ] Không `.only` lọt vào main branch

---

## See also

- Language baseline → [`lang-nodejs.md`](lang-nodejs.md)
- Web framework patterns → [`framework-nodejs-web.md`](framework-nodejs-web.md)
- Base testing rules → [`../testing.md`](../testing.md)

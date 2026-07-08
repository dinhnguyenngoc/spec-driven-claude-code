# Override: Web Framework — Node.js (Express / NestJS / Fastify)

> **Active when** `Project Profile → Core` declares Node.js + 1 web framework. Read alongside `rules/api-conventions.md`, `rules/error-handling.md`, `rules/security.md`, `rules/project-structure.md` (base — ASP.NET Core). This file **only records the differences**; agnostic principles (REST design, HTTP status codes, ProblemDetails error contract, versioning, rate limiting strategy, CORS allowlist) **remain unchanged**.

> This document supports 3 popular Node frameworks. Depending on the Project Profile, pick **1** as primary; do NOT mix multiple frameworks in the same project.

---

## When to choose which framework

| Framework | Best fit | Avoid when |
|-----------|----------|-----------|
| **Express** | Brownfield already using it, team familiar, no need for heavy features | New greenfield (Express is stagnant; less opinionated → easily inconsistent) |
| **NestJS** | Greenfield enterprise, team with Angular/.NET background, needs DI + module system + decorators | Small project (high boilerplate) |
| **Fastify** | High-throughput API, needs performance + schema-first | Team new to Node (smaller community than Express) |

---

## §A. Project structure (per framework)

### Express
```
src/
├── server.ts                  # bootstrap: app + listen
├── app.ts                     # build Express instance
├── config/                    # env loading (zod-validated)
├── middlewares/
│   ├── error-handler.ts
│   ├── request-logger.ts
│   └── auth.ts
├── routes/
│   ├── v1/
│   │   ├── users.routes.ts
│   │   └── orders.routes.ts
│   └── index.ts
├── controllers/
├── services/                  # business logic — does NOT know express
├── repositories/              # data access — does NOT know express
├── domain/                    # entities + value objects
├── shared/
│   ├── errors.ts              # AppError, NotFoundError, ...
│   └── logger.ts              # pino instance
└── types/
```

### NestJS (closest to ASP.NET Clean Architecture)
```
src/
├── main.ts                    # bootstrap NestFactory
├── app.module.ts              # root module
├── modules/
│   ├── users/
│   │   ├── users.module.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── dto/
│   │   │   ├── create-user.dto.ts
│   │   │   └── update-user.dto.ts
│   │   ├── entities/user.entity.ts
│   │   └── users.repository.ts
│   └── orders/
├── common/
│   ├── filters/exception.filter.ts
│   ├── interceptors/logging.interceptor.ts
│   ├── guards/auth.guard.ts
│   └── pipes/validation.pipe.ts
└── infrastructure/
    ├── database/
    └── messaging/
```

### Fastify
```
src/
├── server.ts
├── app.ts                     # Fastify factory + plugin registration
├── plugins/                   # encapsulated plugins
│   ├── auth.plugin.ts
│   ├── db.plugin.ts
│   └── error-handler.plugin.ts
├── routes/                    # auto-loaded via @fastify/autoload
│   └── v1/
│       ├── users/
│       │   ├── index.ts       # route definition
│       │   └── schema.ts      # JSON Schema (Fastify native)
│       └── orders/
├── services/
├── repositories/
└── shared/
```

**General rule (every framework):** Service + Repository do NOT import from the framework — writing tests does not require starting an HTTP server.

---

## §B. Routing & HTTP conventions

URL pattern, status code, pagination, idempotency — **UNCHANGED** per `api-conventions.md` (base). Only the route declaration syntax differs:

### Express
```typescript
import { Router } from "express";
import { asyncHandler } from "@/middlewares/async-handler";
import { UsersController } from "@/controllers/users.controller";

const router = Router();
const controller = new UsersController();

router.get("/", asyncHandler(controller.getAll));
router.get("/:id", asyncHandler(controller.getById));
router.post("/", asyncHandler(controller.create));
router.put("/:id", asyncHandler(controller.update));
router.delete("/:id", asyncHandler(controller.delete));

export default router;
// Mount in app.ts: app.use("/api/v1/users", usersRouter);
```

The `asyncHandler` wrapper is mandatory — Express 4 does not automatically forward async errors to the error middleware:
```typescript
export const asyncHandler =
  <T extends Request>(fn: (req: T, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: T, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
```
> Express 5 (official in 2024) forwards async errors automatically → you can drop the wrapper. Check the version first.

### NestJS
```typescript
import { Controller, Get, Post, Put, Delete, Param, Body, HttpCode } from "@nestjs/common";

@Controller("api/v1/users")
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@Query() filter: UserFilterDto) {
    return this.usersService.findAll(filter);
  }

  @Get(":id")
  findById(@Param("id") id: string) {
    return this.usersService.findById(id);
  }

  @Post()
  @HttpCode(201)
  create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }
}
```

### Fastify (schema-first — bonus: auto-generate OpenAPI + validate input)
```typescript
import type { FastifyPluginAsync } from "fastify";

const usersRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get("/", {
    schema: {
      querystring: UserFilterSchema,
      response: { 200: PagedUsersResponseSchema },
    },
    handler: async (request) => fastify.usersService.findAll(request.query),
  });

  fastify.post("/", {
    schema: {
      body: CreateUserSchema,
      response: { 201: UserResponseSchema },
    },
    handler: async (request, reply) => {
      const user = await fastify.usersService.create(request.body);
      reply.code(201);
      return user;
    },
  });
};

export default usersRoutes;
```

---

## §C. Error handling — global handler

Map `AppError` (defined in [`lang-nodejs.md §Error handling primitives`](lang-nodejs.md)) to `ProblemDetails` (RFC 7807) per base `error-handling.md`.

### Express
```typescript
import type { ErrorRequestHandler } from "express";
import { ZodError } from "zod";
import { AppError } from "@/shared/errors";
import { logger } from "@/shared/logger";

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const traceId = req.headers["x-correlation-id"] ?? crypto.randomUUID();

  if (err instanceof ZodError) {
    const errors = err.flatten().fieldErrors;
    logger.warn({ traceId, errors }, "Validation failed");
    return res.status(400).type("application/problem+json").json({
      type: "https://tools.ietf.org/html/rfc7231#section-6.5.1",
      title: "Bad Request",
      status: 400,
      detail: "Validation failed",
      instance: req.originalUrl,
      code: "VALIDATION_ERROR",
      errors,
      traceId,
    });
  }

  if (err instanceof AppError) {
    logger.warn({ traceId, err }, "App error");
    return res.status(err.statusCode).type("application/problem+json").json({
      status: err.statusCode,
      title: err.name,
      detail: err.message,
      instance: req.originalUrl,
      code: err.code,
      traceId,
    });
  }

  logger.error({ traceId, err }, "Unhandled exception");
  return res.status(500).type("application/problem+json").json({
    status: 500,
    title: "Internal Server Error",
    detail: "An unexpected error occurred",
    instance: req.originalUrl,
    code: "INTERNAL_ERROR",
    traceId,
  });
};

// Register LAST in app.ts
app.use(errorHandler);
```

### NestJS — Exception Filter
```typescript
import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from "@nestjs/common";
import { AppError } from "@/shared/errors";

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse();
    const req = ctx.getRequest();
    const traceId = req.headers["x-correlation-id"] ?? crypto.randomUUID();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let body: Record<string, unknown> = {
      status, title: "Internal Server Error", detail: "Unexpected", code: "INTERNAL_ERROR",
    };

    if (exception instanceof AppError) {
      status = exception.statusCode;
      body = { status, title: exception.name, detail: exception.message, code: exception.code };
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      body = { status, ...(exception.getResponse() as object) };
    }

    res.status(status).type("application/problem+json").json({ ...body, instance: req.url, traceId });
  }
}

// main.ts: app.useGlobalFilters(new GlobalExceptionFilter());
```

### Fastify
```typescript
fastify.setErrorHandler((err, request, reply) => {
  const traceId = request.headers["x-correlation-id"] ?? crypto.randomUUID();

  if (err instanceof AppError) {
    return reply.code(err.statusCode).type("application/problem+json").send({
      status: err.statusCode, title: err.name, detail: err.message,
      instance: request.url, code: err.code, traceId,
    });
  }

  // Fastify validation error (from JSON Schema)
  if (err.validation) {
    return reply.code(400).type("application/problem+json").send({
      status: 400, title: "Bad Request", detail: "Validation failed",
      instance: request.url, code: "VALIDATION_ERROR", errors: err.validation, traceId,
    });
  }

  request.log.error({ err, traceId });
  return reply.code(500).type("application/problem+json").send({
    status: 500, title: "Internal Server Error", detail: "Unexpected",
    instance: request.url, code: "INTERNAL_ERROR", traceId,
  });
});
```

---

## §D. Input validation

| Framework | Default validator | Pattern |
|-----------|------------------|---------|
| Express | **Zod** + manual parse in the controller | `const input = CreateUserSchema.parse(req.body);` |
| NestJS | **class-validator** + `ValidationPipe` (built-in) OR **Zod** + custom pipe | Decorators `@IsEmail()`, `@MinLength(8)` on the DTO class |
| Fastify | **JSON Schema** (native) OR **Zod** + `@fastify/type-provider-zod` | Schema in the route definition |

**General rule:** The schema MUST be reused between runtime validation + TS type. With Zod: `type X = z.infer<typeof XSchema>`. With class-validator: use the class directly as the DTO type.

---

## §E. Authentication (JWT)

C# `AddJwtBearer` → Node equivalents:

| Framework | Library | Pattern |
|-----------|---------|---------|
| Express | `jsonwebtoken` + custom middleware OR `passport` + `passport-jwt` | Middleware verifies the token → attaches `req.user` |
| NestJS | `@nestjs/jwt` + `@nestjs/passport` + `passport-jwt` | Guard `@UseGuards(JwtAuthGuard)` |
| Fastify | `@fastify/jwt` | `fastify.jwt.verify()` in the `preHandler` hook |

**Security rules** (apply to every framework — base `security.md` is agnostic):
- Algorithm MUST be pinned: `algorithms: ["HS256"]` or `["RS256"]` — do NOT allow `none`
- `expiresIn`: 15 minutes for the access token, 7 days for the refresh token
- Verify `iss` (issuer), `aud` (audience)
- Refresh token: store it hashed in the DB, single-use, rotate

```typescript
// Express example
import jwt from "jsonwebtoken";
const decoded = jwt.verify(token, secret, {
  algorithms: ["HS256"], // ✅ pin algorithm
  issuer: config.JWT_ISSUER,
  audience: config.JWT_AUDIENCE,
});
```

---

## §F. Password hashing

C# `BCrypt.HashPassword(pw, workFactor: 12)` → Node:

```typescript
import bcrypt from "bcrypt";
const SALT_ROUNDS = 12; // equivalent to C# BCrypt workFactor
const hash = await bcrypt.hash(plainPassword, SALT_ROUNDS);
const isValid = await bcrypt.compare(plainPassword, hash);
```

Alternative (stronger, OWASP recommends 2024+): **argon2** (`argon2` package).

---

## §G. Rate limiting

| Framework | Library |
|-----------|---------|
| Express | `express-rate-limit` (in-memory) + `rate-limit-redis` (distributed) |
| NestJS | `@nestjs/throttler` (built-in) |
| Fastify | `@fastify/rate-limit` |

Configuration similar to ASP.NET (base `security.md`):
- Global: 100 req/min per IP/user
- `/auth/login`: 5 req/15min per IP

---

## §H. Security headers

| C# / ASP.NET | Node equivalent |
|--------------|-----------------|
| `NetEscapades.AspNetCore.SecurityHeaders` | **`helmet`** (Express, NestJS) or `@fastify/helmet` (Fastify) |
| `UseHttpsRedirection()` | Express: `express-sslify` or a reverse proxy (nginx) |

```typescript
import helmet from "helmet";
app.use(helmet({
  contentSecurityPolicy: { directives: { "default-src": ["'self'"] } },
  strictTransportSecurity: { maxAge: 31536000, includeSubDomains: true },
  // X-Frame-Options, X-Content-Type-Options, Referrer-Policy auto-set
}));
```

---

## §I. CORS

```typescript
// Express
import cors from "cors";
app.use(cors({
  origin: ["https://myapp.com", "https://admin.myapp.com"],
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  credentials: true,
}));
```

`@nestjs/common` → `app.enableCors({...})`. Fastify → `@fastify/cors`.

---

## §J. Database & ORM

| Layer | C# default | Node equivalent (pick 1) |
|-------|-----------|--------------------------|
| Strong + type-safe ORM | EF Core | **Prisma** (recommended for greenfield) or **TypeORM** (NestJS familiar) |
| Lightweight / SQL-first | Dapper | **Kysely** (type-safe query builder) or **postgres** (`postgres` npm) |
| Legacy migration | EF Core migrations | Prisma Migrate / TypeORM migrations / Knex |

General rules (unchanged from base `database.md`):
- Parameterized query (Prisma/TypeORM/Kysely auto-handle)
- Transaction for multi-step write
- N+1 prevention: Prisma `include`, TypeORM `relations`, Kysely explicit join
- Connection pool size: tune per load test
- Do NOT log sensitive data (password hash, token) — Prisma has the `omit` field

```typescript
// Prisma example
const user = await prisma.user.findUnique({
  where: { id },
  include: { orders: true }, // eager load → no N+1
  omit: { passwordHash: true }, // exclude from result
});
```

---

## §K. Logging

| C# | Node equivalent |
|----|-----------------|
| Serilog (structured JSON) | **pino** (recommended — fastest) or **winston** |
| `Enrich.WithProperty("CorrelationId", ...)` | pino: `logger.child({ correlationId })` |

```typescript
import pino from "pino";
export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  redact: ["password", "passwordHash", "token", "authorization"], // do NOT log secrets
});

// Per-request logger with correlation ID (middleware)
app.use((req, _res, next) => {
  const correlationId = req.headers["x-correlation-id"] ?? crypto.randomUUID();
  req.logger = logger.child({ correlationId });
  next();
});
```

---

## §L. Health check

| Framework | Pattern |
|-----------|---------|
| Express | Write your own routes `/health`, `/health/ready`, `/health/live` |
| NestJS | `@nestjs/terminus` (built-in HealthCheck system) |
| Fastify | `@fastify/healthcheck` plugin or write your own route |

3 mandatory endpoints (unchanged from base):
- `/health` — process alive (200 OK)
- `/health/live` — Kubernetes liveness probe
- `/health/ready` — DB + Redis + Kafka reachable (Kubernetes readiness)

---

## What stays unchanged (still follows base rules)

- REST URL pattern, plural noun, kebab-case multi-word, versioned `/api/v1/...` — `api-conventions.md`
- HTTP status codes (200/201/204/400/401/403/404/409/500) — `api-conventions.md`
- ProblemDetails RFC 7807 contract — `error-handling.md`
- Authentication discipline (short-lived JWT + refresh rotation + MFA for sensitive ops) — `security.md`
- Authorization: RBAC + resource ownership check + IDOR prevention — `security.md`
- Rate limit budget (100/min global, 5/15min auth) — `security.md`
- Security headers list — `security.md`
- Audit log + correlation ID propagation — `principles-and-practices.md §4.6`
- The 12 Project Structure conventions (Service does not know HTTP, Repository does not know Service, ...) — `project-structure.md` (mapping conceptually)

---

## See also

- Language baseline → [`lang-nodejs.md`](lang-nodejs.md)
- Test framework (Jest / Vitest) → [`test-nodejs.md`](test-nodejs.md)
- Base error contract → [`../error-handling.md`](../error-handling.md)
- Base security rules → [`../security.md`](../security.md)
- Base API conventions → [`../api-conventions.md`](../api-conventions.md)

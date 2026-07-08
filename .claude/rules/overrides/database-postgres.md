# Override: Database — PostgreSQL

> **Active when** `Project Profile → Database: PostgreSQL`. Read alongside `rules/database.md` (base — SQL Server). This file **only records the differences**; agnostic principles (parametrized query, projection, transaction, N+1 prevention, async, no logging of sensitive data) **remain unchanged**.
>
> This file supports both stack branches: **ASP.NET Core** (EF Core + Npgsql / Dapper) and **Node.js** (pg / Prisma / TypeORM / Kysely). Pick the section that matches the Project Profile.

---

## §A. Provider & connection

### A.1 — ASP.NET Core (EF Core + Npgsql)

```xml
<!-- replace Microsoft.EntityFrameworkCore.SqlServer -->
<PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.*" />
```

```csharp
services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        configuration.GetConnectionString("DefaultConnection"),
        o => o.EnableRetryOnFailure(3, TimeSpan.FromSeconds(10), null)));
```

Connection string: `Host=db.example.com;Port=5432;Database=app;Username=app;Password=...;Pooling=true;Maximum Pool Size=100`

**Dapper:** use `Npgsql` (`NpgsqlConnection`) — the same pattern as base, only the param prefix differs (still `@param` — Npgsql normalizes it).

### A.2 — Node.js

Choose the ORM/driver according to the Project Profile:

| Library | When to use | Setup |
|---------|---------|-------|
| **Prisma** | Greenfield + needs type-safe + automatic migration (recommended) | `npm install prisma @prisma/client` + `prisma init` |
| **TypeORM** | NestJS familiar, decorator-based entity | `npm install typeorm pg reflect-metadata` |
| **Kysely** | Type-safe query builder, closer to SQL | `npm install kysely pg` |
| **pg (raw)** | Performance critical, schema already exists | `npm install pg` |

**Connection string (every library):** `postgresql://app:password@db.example.com:5432/app?sslmode=require`

**Prisma example:**
```typescript
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid()) @db.Uuid
  email     String   @unique
  createdAt DateTime @default(now()) @db.Timestamptz(6)
  @@index([email])
}
```

**TypeORM example:**
```typescript
TypeOrmModule.forRoot({
  type: "postgres",
  url: process.env.DATABASE_URL,
  entities: [User, Order],
  synchronize: false, // NEVER true in prod — use migration
  extra: { max: 100 },
});
```

**Connection pool:** The default is usually low (10). Tune it per load test — `max` ~ (CPU * 2) + spindle count, or `pgbouncer` if you need to share across multiple services.

---

## §B. Dialect differences (vs SQL Server)

| Aspect | SQL Server (base) | PostgreSQL (override) |
|--------|-------------------|-----------------------|
| PK gen — UUID | `uniqueidentifier DEFAULT NEWID()` | `uuid DEFAULT gen_random_uuid()` (needs extension `pgcrypto`) OR app-side (`uuidv7` recommended for time-ordered) |
| PK gen — int | `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` (SQL standard) OR legacy `SERIAL` / `BIGSERIAL` |
| Default timestamp | `GETUTCDATE()` | `now() AT TIME ZONE 'UTC'` OR store `TIMESTAMPTZ` directly (recommended) |
| Auto-increment | `IDENTITY` | `IDENTITY` (PG 10+) / `SERIAL` (legacy) |
| Paging | `OFFSET @s ROWS FETCH NEXT @n ROWS ONLY` | `LIMIT :n OFFSET :s` — EF Core / Prisma / TypeORM auto-translate |
| Boolean | `bit` (0/1) | `BOOLEAN` (`true`/`false`) — standard type |
| String type | `nvarchar(n)` | `VARCHAR(n)` OR `TEXT` (no hard limit; PG stores them the same way) |
| Identifier quote | `[name]` | `"name"` (double quote) — quoted = case-sensitive |
| Case-sensitivity | tables case-insensitive | **Tables/columns case-sensitive if quoted**; unquoted auto-lowercase. Convention: use `snake_case` instead of `PascalCase` to avoid quoting |
| Schema | `dbo` (default) | `public` (default) — you can create multiple schemas per module |
| Param prefix | `@param` | `$1, $2` (raw `pg`) / `:param` (TypeORM) / `@param` (Npgsql normalize) |
| JSON | `nvarchar(max)` + manual parse | **`JSONB`** (binary JSON, indexable, query-able) — a strong feature of PG |
| Array type | NOT supported natively | `INTEGER[]`, `TEXT[]` — native array type |
| Full-text search | SQL Server FTS | `tsvector` + `tsquery` + GIN index — good for most use cases |
| Upsert | `MERGE` (SQL Server 2008+) | `INSERT ... ON CONFLICT (col) DO UPDATE SET ...` (clean syntax) |

---

## §C. PostgreSQL-specific features worth using

### C.1 — `JSONB` for semi-structured data

When a schema has fields of varied structure (e.g. user preferences, metadata) — use `JSONB` instead of serializing to `TEXT`:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    preferences JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on a specific field inside JSONB
CREATE INDEX idx_users_pref_theme ON users ((preferences->>'theme'));

-- Query
SELECT * FROM users WHERE preferences->>'theme' = 'dark';
SELECT * FROM users WHERE preferences @> '{"notifications": {"email": true}}';
```

**Warning:** Do NOT abuse JSONB for everything — a column with a fixed schema should still use a regular column (faster query, type-safe).

### C.2 — `TIMESTAMPTZ` instead of `TIMESTAMP`

- `TIMESTAMP` — has no timezone, easily buggy when the server changes timezone
- `TIMESTAMPTZ` — stores UTC internally, returns per the session timezone — **always use this** for every time column

### C.3 — `citext` for case-insensitive (e.g. email)

```sql
CREATE EXTENSION IF NOT EXISTS citext;
CREATE TABLE users (
    email CITEXT NOT NULL UNIQUE  -- "User@Example.com" = "user@example.com" automatically
);
```

→ Removes the need for `LOWER(email) = LOWER(@input)` at the query layer.

### C.4 — `unaccent` for diacritic-insensitive search (Vietnamese)

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE INDEX idx_products_name_unaccent ON products (unaccent(lower(name)));

-- Query: "Tiếng Việt" finds "tieng viet" and vice versa
SELECT * FROM products WHERE unaccent(lower(name)) LIKE unaccent(lower(:query)) || '%';
```

> This is an alternative to the `*Normalized` column pattern in base `database.md`. Both are OK; `unaccent`'s advantage: no app-side normalize needed, simpler schema. Downside: costs CPU per query (reduced if there is an index expression as above).

### C.5 — Partial index

```sql
-- Index only non-deleted rows → smaller, faster
CREATE INDEX idx_users_active_email ON users(email) WHERE deleted_at IS NULL;
```

### C.6 — `INSERT ... ON CONFLICT` (upsert)

```sql
INSERT INTO users (email, name) VALUES (:email, :name)
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, updated_at = now()
RETURNING id;
```

→ A common pattern for an idempotent endpoint. Cleaner than SQL Server's `MERGE`.

### C.7 — `LISTEN`/`NOTIFY` (lightweight pub/sub)

If you need notification between processes **within the same DB** and do not want to bring in Kafka/Redis yet:

```sql
-- Publisher
NOTIFY user_updated, '{"id": "abc-123"}';

-- Subscriber (Node.js pg)
client.query("LISTEN user_updated");
client.on("notification", (msg) => { ... });
```

**Warning:** use only for dev / small scale. Production scale → Kafka / Redis Pub/Sub (per `principles-and-practices.md §5`).

---

## §D. Naming convention — PostgreSQL idiom

Unlike base SQL Server (PascalCase) — PostgreSQL community convention:

| Element | SQL Server (base) | PostgreSQL (recommended) |
|---------|-------------------|------------------------|
| Table | `Users`, `OrderItems` | `users`, `order_items` (snake_case, plural) |
| Column | `Id`, `UserId`, `CreatedAt` | `id`, `user_id`, `created_at` |
| Index | `IX_Users_Email` | `idx_users_email` (lowercase) |
| FK | `FK_Orders_Users_UserId` | `fk_orders_users_user_id` |
| Unique constraint | `UQ_Users_Email` | `uq_users_email` |

**Why:** An unquoted identifier in PG is auto-lowercased → using `Users` and then quoting it creates a bug when mixing raw SQL with migrations. Snake_case + unquoted = consistent + zero confusion.

**ORM mapping:**
- EF Core: `[Table("users")]` + `[Column("user_id")]` OR use the `UseSnakeCaseNamingConvention()` extension
- Prisma: `@@map("users")` + `@map("user_id")` on the field
- TypeORM: `@Entity("users")` + `@Column({ name: "user_id" })` OR `namingStrategy: new SnakeNamingStrategy()`

---

## §E. Migration & testing

### Migration

- **EF Core:** `dotnet ef migrations add ...` with the Npgsql provider — the generated script is auto-converted to the PG dialect (review it to check `SERIAL` vs `IDENTITY`, snake_case, extension `pgcrypto` created in the first migration)
- **Prisma:** `npx prisma migrate dev --name <desc>` — auto-generate SQL diff, idempotent
- **TypeORM:** `npm run typeorm migration:generate` — diff entity vs DB
- **Flyway / Sqitch / Liquibase:** SQL-first migration tool — use if the team does not trust auto-generated migrations

**General rules:**
- Commit migrations into git, do NOT edit a migration that has already been released
- Every migration must be reversible (has a rollback path)
- Extensions (`pgcrypto`, `citext`, `unaccent`) are created in the first migration with `CREATE EXTENSION IF NOT EXISTS`

### TestContainers for `/test`

**ASP.NET (.NET):**
```csharp
private readonly PostgreSqlContainer _pg = new PostgreSqlBuilder()
    .WithImage("postgres:16-alpine")
    .Build();

// In ConfigureWebHost: services.AddDbContext(opts => opts.UseNpgsql(_pg.GetConnectionString()));
```

**Node.js:**
```typescript
import { PostgreSqlContainer } from "@testcontainers/postgresql";

const container = await new PostgreSqlContainer("postgres:16-alpine").start();
process.env.DATABASE_URL = container.getConnectionUri();
execSync("npx prisma migrate deploy"); // or TypeORM / Flyway
```

**Image recommend:** `postgres:16-alpine` (arm64 ✓ on macOS M1/M2/M3) or `postgres:17-alpine` (latest).

---

## §F. Pgbouncer / connection pooling

When the Node.js backend has multiple instances (e.g. K8s replicas) → each instance keeps its own pool → DB connections explode. Solution: **pgbouncer** in the middle:

```
[app instances × N] → [pgbouncer pool] → [postgres]
                       (transaction mode)
```

- **transaction pooling mode** (default): the connection returns to the pool after each transaction → high concurrency, low DB connection count
- Limitation: you CANNOT use session-state features (prepared statement, `SET LOCAL`, cross-tx advisory lock). Prisma / TypeORM need their own config.

**When do you start needing pgbouncer?** When `pg_stat_activity` shows connection count > 50% of the `max_connections` config.

---

## §G. Important notes / gotchas

1. **Timezone** — always `TIMESTAMPTZ`, store UTC, client converts. Server timezone (`SET TIME ZONE`) only affects display.
2. **`SERIAL` deprecated for greenfield** — use `GENERATED ALWAYS AS IDENTITY` (SQL standard). Legacy `SERIAL` has a sequence-ownership bug that is hard to debug.
3. **Long-running transaction = bloat** — VACUUM cannot clean a dead tuple blocked by an old transaction. Limit TX time via `idle_in_transaction_session_timeout`.
4. **`SELECT *` + JSON serialize** — PG has many types that do not serialize by default (e.g. `bytea`, `numeric` precision). Test early.
5. **`LIKE` does not use an index by default on ICU collation** — needs the text_pattern_ops opclass: `CREATE INDEX ON t(col text_pattern_ops);` so `LIKE 'prefix%'` can use the index.
6. **PostgreSQL has no `READ UNCOMMITTED`** — a request for `READ UNCOMMITTED` is silently auto-promoted to `READ COMMITTED`. Code should not depend on dirty reads.
7. **`max_connections` low default (100)** — production needs to tune it up + pgbouncer. Too many connections → each one costs ~10MB RAM.

---

## §H. Unchanged (still follows base `database.md`)

- Parametrized query (Npgsql / pg / Prisma / TypeORM all automatic)
- `AsNoTracking()` (EF Core) / `select` projection (Prisma) for read-only
- Eager loading: `Include` (EF Core) / `include` (Prisma) / `relations` (TypeORM) — prevents N+1
- Transaction for multi-step write — `BeginTransactionAsync` (.NET) / `prisma.$transaction()` / `queryRunner.startTransaction()` (TypeORM)
- Batch operations
- Compiled query (if hot path)
- **Do NOT string-concat SQL** with user input — always parametrize
- **Do NOT log sensitive data** (password hash, token) — Prisma has `omit`, EF Core uses `Destructure.ByTransforming`

---

## See also

- Base database rule → [`../database.md`](../database.md)
- Stack-specific overrides (if using Node.js):
  - Language → [`lang-nodejs.md`](lang-nodejs.md)
  - Web framework → [`framework-nodejs-web.md`](framework-nodejs-web.md)
  - Testing → [`test-nodejs.md`](test-nodejs.md)
- Master design principles → [`../principles-and-practices.md`](../principles-and-practices.md)

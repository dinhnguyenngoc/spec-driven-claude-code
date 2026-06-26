# Override: Database — PostgreSQL

> **Active when** `Project Profile → Database: PostgreSQL`. Read alongside `rules/database.md` (base — SQL Server). This file **only records the differences**; agnostic principles (parametrized query, projection, transaction, N+1 prevention, async, no logging of sensitive data) **remain unchanged**.
>
> File này hỗ trợ cả 2 nhánh stack: **ASP.NET Core** (EF Core + Npgsql / Dapper) và **Node.js** (pg / Prisma / TypeORM / Kysely). Chọn section phù hợp với Project Profile.

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

**Dapper:** dùng `Npgsql` (`NpgsqlConnection`) — pattern y hệt base, chỉ khác param prefix (vẫn `@param` — Npgsql normalize).

### A.2 — Node.js

Tuỳ ORM/driver chọn theo Project Profile:

| Library | Khi dùng | Setup |
|---------|---------|-------|
| **Prisma** | Greenfield + cần type-safe + migration tự động (recommend) | `npm install prisma @prisma/client` + `prisma init` |
| **TypeORM** | NestJS familiar, decorator-based entity | `npm install typeorm pg reflect-metadata` |
| **Kysely** | Type-safe query builder, gần SQL hơn | `npm install kysely pg` |
| **pg (raw)** | Performance critical, đã có schema | `npm install pg` |

**Connection string (mọi library):** `postgresql://app:password@db.example.com:5432/app?sslmode=require`

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
  synchronize: false, // KHÔNG bao giờ true trong prod — dùng migration
  extra: { max: 100 },
});
```

**Connection pool:** Default thường thấp (10). Tune theo load test — `max` ~ (CPU * 2) + spindle count, hoặc `pgbouncer` nếu cần share giữa nhiều service.

---

## §B. Dialect differences (vs SQL Server)

| Aspect | SQL Server (base) | PostgreSQL (override) |
|--------|-------------------|-----------------------|
| PK gen — UUID | `uniqueidentifier DEFAULT NEWID()` | `uuid DEFAULT gen_random_uuid()` (cần extension `pgcrypto`) HOẶC app-side (`uuidv7` recommend cho time-ordered) |
| PK gen — int | `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` (chuẩn SQL) HOẶC legacy `SERIAL` / `BIGSERIAL` |
| Default timestamp | `GETUTCDATE()` | `now() AT TIME ZONE 'UTC'` HOẶC store `TIMESTAMPTZ` trực tiếp (recommend) |
| Auto-increment | `IDENTITY` | `IDENTITY` (PG 10+) / `SERIAL` (legacy) |
| Paging | `OFFSET @s ROWS FETCH NEXT @n ROWS ONLY` | `LIMIT :n OFFSET :s` — EF Core / Prisma / TypeORM auto-translate |
| Boolean | `bit` (0/1) | `BOOLEAN` (`true`/`false`) — kiểu chuẩn |
| String type | `nvarchar(n)` | `VARCHAR(n)` HOẶC `TEXT` (không có hard limit; PG store cùng cách) |
| Identifier quote | `[name]` | `"name"` (double quote) — quoted = case-sensitive |
| Case-sensitivity | tables case-insensitive | **Tables/columns case-sensitive nếu quoted**; unquoted auto-lowercase. Convention: dùng `snake_case` thay vì `PascalCase` để tránh quoted |
| Schema | `dbo` (mặc định) | `public` (mặc định) — có thể tạo nhiều schema per module |
| Param prefix | `@param` | `$1, $2` (raw `pg`) / `:param` (TypeORM) / `@param` (Npgsql normalize) |
| JSON | `nvarchar(max)` + manual parse | **`JSONB`** (binary JSON, indexable, query-able) — feature mạnh của PG |
| Array type | KHÔNG hỗ trợ native | `INTEGER[]`, `TEXT[]` — native array type |
| Full-text search | SQL Server FTS | `tsvector` + `tsquery` + GIN index — tốt cho most use case |
| Upsert | `MERGE` (SQL Server 2008+) | `INSERT ... ON CONFLICT (col) DO UPDATE SET ...` (clean syntax) |

---

## §C. PostgreSQL-specific features đáng dùng

### C.1 — `JSONB` cho dữ liệu semi-structured

Khi schema có field cấu trúc đa dạng (vd: user preferences, metadata) — dùng `JSONB` thay vì serialize sang `TEXT`:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    preferences JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index trên field cụ thể trong JSONB
CREATE INDEX idx_users_pref_theme ON users ((preferences->>'theme'));

-- Query
SELECT * FROM users WHERE preferences->>'theme' = 'dark';
SELECT * FROM users WHERE preferences @> '{"notifications": {"email": true}}';
```

**Cảnh báo:** KHÔNG abuse JSONB cho mọi thứ — column có schema cố định vẫn nên dùng column thường (query nhanh hơn, type-safe).

### C.2 — `TIMESTAMPTZ` thay vì `TIMESTAMP`

- `TIMESTAMP` — không có timezone, dễ bug khi server đổi timezone
- `TIMESTAMPTZ` — lưu UTC internal, return theo session timezone — **luôn dùng cái này** cho mọi cột thời gian

### C.3 — `citext` cho case-insensitive (vd: email)

```sql
CREATE EXTENSION IF NOT EXISTS citext;
CREATE TABLE users (
    email CITEXT NOT NULL UNIQUE  -- "User@Example.com" = "user@example.com" tự động
);
```

→ Loại bỏ nhu cầu `LOWER(email) = LOWER(@input)` ở query layer.

### C.4 — `unaccent` cho diacritic-insensitive search (tiếng Việt)

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE INDEX idx_products_name_unaccent ON products (unaccent(lower(name)));

-- Query: "Tiếng Việt" tìm thấy "tieng viet" và ngược lại
SELECT * FROM products WHERE unaccent(lower(name)) LIKE unaccent(lower(:query)) || '%';
```

> Đây là alternative cho `*Normalized` column pattern trong base `database.md`. Cả 2 đều OK; `unaccent` ưu điểm: không cần app-side normalize, schema đơn giản hơn. Nhược: tốn CPU per query (giảm nếu có index expression như trên).

### C.5 — Partial index

```sql
-- Chỉ index hàng chưa xoá → nhỏ hơn, nhanh hơn
CREATE INDEX idx_users_active_email ON users(email) WHERE deleted_at IS NULL;
```

### C.6 — `INSERT ... ON CONFLICT` (upsert)

```sql
INSERT INTO users (email, name) VALUES (:email, :name)
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, updated_at = now()
RETURNING id;
```

→ Pattern phổ biến cho idempotent endpoint. Clean hơn `MERGE` của SQL Server.

### C.7 — `LISTEN`/`NOTIFY` (lightweight pub/sub)

Nếu cần notification giữa process **trong cùng DB**, không muốn đưa Kafka/Redis ngay:

```sql
-- Publisher
NOTIFY user_updated, '{"id": "abc-123"}';

-- Subscriber (Node.js pg)
client.query("LISTEN user_updated");
client.on("notification", (msg) => { ... });
```

**Cảnh báo:** chỉ dùng cho dev / small scale. Production scale → Kafka / Redis Pub/Sub (theo `principles-and-practices.md §5`).

---

## §D. Naming convention — PostgreSQL idiom

Khác base SQL Server (PascalCase) — PostgreSQL community convention:

| Element | SQL Server (base) | PostgreSQL (recommend) |
|---------|-------------------|------------------------|
| Table | `Users`, `OrderItems` | `users`, `order_items` (snake_case, plural) |
| Column | `Id`, `UserId`, `CreatedAt` | `id`, `user_id`, `created_at` |
| Index | `IX_Users_Email` | `idx_users_email` (lowercase) |
| FK | `FK_Orders_Users_UserId` | `fk_orders_users_user_id` |
| Unique constraint | `UQ_Users_Email` | `uq_users_email` |

**Lý do:** Unquoted identifier trong PG tự lowercase → dùng `Users` rồi quote sẽ tạo bug khi mix raw SQL với migration. Snake_case + unquoted = consistent + zero confusion.

**ORM mapping:**
- EF Core: `[Table("users")]` + `[Column("user_id")]` HOẶC dùng `UseSnakeCaseNamingConvention()` extension
- Prisma: `@@map("users")` + `@map("user_id")` trên field
- TypeORM: `@Entity("users")` + `@Column({ name: "user_id" })` HOẶC `namingStrategy: new SnakeNamingStrategy()`

---

## §E. Migration & testing

### Migration

- **EF Core:** `dotnet ef migrations add ...` với Npgsql provider — script generated tự convert sang PG dialect (review để check `SERIAL` vs `IDENTITY`, snake_case, extension `pgcrypto` được tạo trong migration đầu)
- **Prisma:** `npx prisma migrate dev --name <desc>` — auto-generate SQL diff, idempotent
- **TypeORM:** `npm run typeorm migration:generate` — diff entity vs DB
- **Flyway / Sqitch / Liquibase:** SQL-first migration tool — dùng nếu team không tin auto-generated migration

**Quy tắc chung:**
- Migration commit vào git, KHÔNG sửa migration đã release
- Mọi migration phải reversible (có rollback path)
- Extension (`pgcrypto`, `citext`, `unaccent`) tạo trong migration đầu tiên với `CREATE EXTENSION IF NOT EXISTS`

### TestContainers cho `/test`

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
execSync("npx prisma migrate deploy"); // hoặc TypeORM / Flyway
```

**Image recommend:** `postgres:16-alpine` (arm64 ✓ trên macOS M1/M2/M3) hoặc `postgres:17-alpine` (latest).

---

## §F. Pgbouncer / connection pooling

Khi backend Node.js có nhiều instance (vd: K8s replica) → mỗi instance giữ pool của riêng nó → DB connection bùng nổ. Giải pháp: **pgbouncer** ở giữa:

```
[app instances × N] → [pgbouncer pool] → [postgres]
                       (transaction mode)
```

- **transaction pooling mode** (default): connection trả về pool sau mỗi transaction → high concurrency, low DB connection count
- Hạn chế: KHÔNG dùng được session-state feature (prepared statement, `SET LOCAL`, advisory lock cross-tx). Prisma / TypeORM cần config riêng.

**Khi nào bắt đầu cần pgbouncer?** Khi `pg_stat_activity` cho thấy connection count > 50% `max_connections` config.

---

## §G. Important notes / gotchas

1. **Timezone** — luôn `TIMESTAMPTZ`, store UTC, client convert. Server timezone (`SET TIME ZONE`) chỉ ảnh hưởng display.
2. **`SERIAL` deprecated cho greenfield** — dùng `GENERATED ALWAYS AS IDENTITY` (SQL standard). `SERIAL` legacy có sequence-ownership bug khó debug.
3. **Long-running transaction = bloat** — VACUUM không thể clean dead tuple bị transaction old chặn. Giới hạn TX time qua `idle_in_transaction_session_timeout`.
4. **`SELECT *` + JSON serialize** — PG có nhiều type không serialize default (vd: `bytea`, `numeric` precision). Test sớm.
5. **`LIKE` không dùng index theo default trên ICU collation** — cần text_pattern_ops opclass: `CREATE INDEX ON t(col text_pattern_ops);` để `LIKE 'prefix%'` dùng được index.
6. **PostgreSQL không có `READ UNCOMMITTED`** — request `READ UNCOMMITTED` silently auto-promoted lên `READ COMMITTED`. Code đừng phụ thuộc dirty read.
7. **`max_connections` thấp default (100)** — production cần tune lên + pgbouncer. Quá nhiều connection → mỗi cái tốn ~10MB RAM.

---

## §H. Unchanged (vẫn theo base `database.md`)

- Parametrized query (Npgsql / pg / Prisma / TypeORM tất cả auto)
- `AsNoTracking()` (EF Core) / `select` projection (Prisma) cho read-only
- Eager loading: `Include` (EF Core) / `include` (Prisma) / `relations` (TypeORM) — chống N+1
- Transaction cho multi-step write — `BeginTransactionAsync` (.NET) / `prisma.$transaction()` / `queryRunner.startTransaction()` (TypeORM)
- Batch operations
- Compiled query (nếu hot path)
- **KHÔNG string-concat SQL** với user input — luôn parametrize
- **KHÔNG log sensitive data** (password hash, token) — Prisma có `omit`, EF Core dùng `Destructure.ByTransforming`

---

## See also

- Base database rule → [`../database.md`](../database.md)
- Stack-specific overrides (nếu đang dùng Node.js):
  - Language → [`lang-nodejs.md`](lang-nodejs.md)
  - Web framework → [`framework-nodejs-web.md`](framework-nodejs-web.md)
  - Testing → [`test-nodejs.md`](test-nodejs.md)
- Master design principles → [`../principles-and-practices.md`](../principles-and-practices.md)

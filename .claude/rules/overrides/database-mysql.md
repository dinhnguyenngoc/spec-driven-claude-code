# Override: Database — MySQL

> **Active when** `Project Profile → Database: MySQL`. Read alongside `rules/database.md` (base). This file **only records the differences** from SQL Server; agnostic principles in the base **remain unchanged**.

## Provider & connection

```xml
<!-- replace Microsoft.EntityFrameworkCore.SqlServer -->
<PackageReference Include="Pomelo.EntityFrameworkCore.MySql" Version="8.*" />
```

```csharp
var cs = configuration.GetConnectionString("DefaultConnection");
services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(cs, ServerVersion.AutoDetect(cs),
        o => o.EnableRetryOnFailure(3, TimeSpan.FromSeconds(10), null)));
```

Connection string: `Server=host;Port=3306;Database=app;Uid=app;Pwd=...;` — add `CharSet=utf8mb4`.

## Dialect differences (vs SQL Server)

| Aspect | SQL Server (base) | MySQL (override) |
|--------|-------------------|------------------|
| PK gen | `uniqueidentifier DEFAULT NEWID()` | `CHAR(36)` + app-side `Guid.NewGuid()`, or `BINARY(16)`; auto-int uses `BIGINT AUTO_INCREMENT` |
| Default timestamp | `GETUTCDATE()` | `UTC_TIMESTAMP()` (store UTC; avoid `CURRENT_TIMESTAMP` which depends on session timezone) |
| Auto-increment | `IDENTITY(1,1)` | `AUTO_INCREMENT` |
| Paging | `OFFSET/FETCH` | `LIMIT :n OFFSET :s` — EF Core translates automatically |
| Boolean | `bit` | `TINYINT(1)` (MySQL maps `BOOLEAN` → `TINYINT(1)`) |
| String type | `nvarchar(n)` | `VARCHAR(n)` with **`CHARACTER SET utf8mb4`** (mandatory for full Unicode + emoji); `TEXT` for long content |
| Identifier quote | `[name]` | `` `name` `` (backtick) |
| Case-sensitivity | tables case-insensitive | **depends on collation + OS**: `utf8mb4_unicode_ci` (insensitive) vs `_bin`. Set collation explicitly for consistency across Linux/Windows |
| Schema | `dbo` | = database name |

## Diacritic-insensitive search (`*Normalized` column)

**Keep the app-side approach** (lowercase + strip-diacritic, query `LIKE`). MySQL can use collation `utf8mb4_0900_ai_ci` (accent+case insensitive) as an option, but the `*Normalized` column is still the portable + consistent-with-base approach — prefer to keep it.

## Dapper

```csharp
const string sql = "SELECT * FROM users WHERE email = @Email";  // @ still works with Pomelo
var user = await _conn.QueryFirstOrDefaultAsync<User>(sql, new { Email = email });
```

## Migration & testing

- Migration: `dotnet ef migrations` with Pomelo provider; review DDL (AUTO_INCREMENT, charset/collation per table).
- TestContainers (`/test`): `Testcontainers.MySql` with image `mysql:8.0` (arm64 native ✅). Replace `MsSqlBuilder` → `MySqlBuilder`, port 3306, set `utf8mb4`.

## Important notes

- **Always `utf8mb4`** (not legacy `utf8` — only 3-byte, loses emoji + some characters). Set at DB, table, and connection level.
- Set **explicit collation** to avoid case-sensitivity differences between dev (macOS) and prod (Linux).

## Unchanged (still follows base `database.md`)

Parametrized query, `AsNoTracking()`, projection, transaction, `Include`, batch ops, **no string-concat SQL**, no logging of sensitive data.

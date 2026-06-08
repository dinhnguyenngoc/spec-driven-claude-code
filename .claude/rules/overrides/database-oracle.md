# Override: Database — Oracle

> **Active when** `Project Profile → Database: Oracle`. Read alongside `rules/database.md` (base). This file **only records the differences** from SQL Server; all agnostic principles in the base (parametrized query, `AsNoTracking`, projection, transaction, N+1 prevention, async) **remain unchanged**.

## Provider & connection

```xml
<!-- replace Microsoft.EntityFrameworkCore.SqlServer -->
<PackageReference Include="Oracle.EntityFrameworkCore" Version="8.*" />
```

```csharp
services.AddDbContext<AppDbContext>(options =>
    options.UseOracle(
        configuration.GetConnectionString("DefaultConnection"),
        o => o.UseOracleSQLCompatibility(OracleSQLCompatibility.DatabaseVersion19)));
```

Connection string: `User Id=app;Password=...;Data Source=//host:1521/SERVICE`.

## Dialect differences (vs SQL Server)

| Aspect | SQL Server (base) | Oracle (override) |
|--------|-------------------|-------------------|
| PK gen | `uniqueidentifier DEFAULT NEWID()` | `RAW(16)` + `SYS_GUID()`, or `NUMBER` + **SEQUENCE** + identity (`GENERATED ... AS IDENTITY`, 12c+) |
| Default timestamp | `GETUTCDATE()` | `SYS_EXTRACT_UTC(SYSTIMESTAMP)` |
| Auto-increment | `IDENTITY(1,1)` | `IDENTITY` (12c+) or `SEQUENCE` + trigger (legacy) |
| Paging | `OFFSET @s ROWS FETCH NEXT @n ROWS ONLY` | `OFFSET :s ROWS FETCH NEXT :n ROWS ONLY` (12c+) — EF Core translates automatically |
| Boolean | `bit` | NO boolean type — use `NUMBER(1)` (0/1) |
| String type | `nvarchar(n)` | `NVARCHAR2(n)` (max 4000 bytes), `CLOB` for longer |
| Param prefix | `@param` | `:param` (Dapper/raw SQL must be changed) |
| Identifier case | case-insensitive | **UPPERCASE by default** when unquoted → be careful with column name mapping |
| Schema | `dbo` | = user/schema name (e.g. `APP`) |

## Diacritic-insensitive search (equivalent to `*Normalized` column)

The `*Normalized` column (app-side) **keeps the same approach** — still store lowercase + strip-diacritic at the application layer, query with `LIKE`. This is the most portable choice; Oracle linguistic collation (`NLS_SORT=BINARY_AI`) is an advanced option, not mandatory.

## Dapper

```csharp
// Change @ → : and NEWID()/GETUTCDATE() → Oracle equivalents
const string sql = "SELECT * FROM USERS WHERE EMAIL = :Email";
var user = await _conn.QueryFirstOrDefaultAsync<User>(sql, new { Email = email });
```

## Migration & testing

- Migration: `dotnet ef migrations` works with the Oracle provider; review the generated script as the DDL differs (SEQUENCE, identity).
- TestContainers (`/test`): use `gvenzl/oracle-xe` (some arm64-supported tags) or `container-registry.oracle.com/database/free`. Replace `MsSqlBuilder` → Oracle image, port 1521, healthcheck TCP/listener.
- License note: use Oracle XE/Free for dev/test.

## Unchanged (still follows base `database.md`)

Parametrized query, `AsNoTracking()` for reads, projection, transaction via `BeginTransactionAsync`, eager loading `Include`, batch `ExecuteUpdate/Delete` (EF Core 7+), compiled query, **no string-concat SQL**, no logging of sensitive data.

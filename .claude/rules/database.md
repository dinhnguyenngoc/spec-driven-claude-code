# Database Rules — SQL Server + Entity Framework Core + Dapper

> **Default engine = SQL Server.** If `Project Profile → Database` declares otherwise:
> - **Relational** (Oracle, MySQL, PostgreSQL) → read alongside `rules/overrides/database-oracle.md`, `database-mysql.md`, or `database-postgres.md`. The override only replaces the **dialect-specific** parts (PK gen, time function, paging, provider); the agnostic principles below (parametrized query, `AsNoTracking`, projection, transaction, N+1 prevention) **still apply**.
> - **NoSQL document** (MongoDB) → read `rules/overrides/database-mongodb.md`. **A completely different paradigm** — many SQL-specific parts below DO NOT apply (see §J of the override for which parts still apply).

## General Rules

- **Never** write raw SQL strings concatenated with user input
- Use Entity Framework Core for writes and simple reads
- Use Dapper for complex read-heavy queries requiring performance
- All database calls must be wrapped in try/catch or let exceptions bubble to middleware
- Use **transactions** for multi-step operations
- Always use **async** methods (`ToListAsync`, `FirstOrDefaultAsync`, etc.)

---

## Connection Management

```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlOptions =>
        {
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 3,
                maxRetryDelay: TimeSpan.FromSeconds(10),
                errorNumbersToAdd: null);
            sqlOptions.CommandTimeout(30);
        }));

// For Dapper - register IDbConnection
builder.Services.AddScoped<IDbConnection>(sp =>
    new SqlConnection(builder.Configuration.GetConnectionString("DefaultConnection")));
```

---

## DbContext Configuration

```csharp
// Infrastructure/Data/AppDbContext.cs
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Global query filter for soft delete
        modelBuilder.Entity<User>().HasQueryFilter(u => u.DeletedAt == null);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Auto-set timestamps
        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = DateTime.UtcNow;
                    break;
                case EntityState.Modified:
                    entry.Entity.UpdatedAt = DateTime.UtcNow;
                    break;
            }
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}
```

---

## Entity Configuration

```csharp
// Infrastructure/Data/Configurations/UserConfiguration.cs
public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users");

        builder.HasKey(u => u.Id);
        builder.Property(u => u.Id)
            .HasDefaultValueSql("NEWID()");

        builder.Property(u => u.Email)
            .IsRequired()
            .HasMaxLength(255);

        builder.HasIndex(u => u.Email)
            .IsUnique()
            .HasDatabaseName("IX_Users_Email");

        builder.Property(u => u.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(u => u.PasswordHash)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(u => u.CreatedAt)
            .HasDefaultValueSql("GETUTCDATE()");

        // Relationships
        builder.HasMany(u => u.Orders)
            .WithOne(o => o.User)
            .HasForeignKey(o => o.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        // Index for soft delete queries
        builder.HasIndex(u => u.DeletedAt)
            .HasDatabaseName("IX_Users_DeletedAt")
            .HasFilter("[DeletedAt] IS NULL");
    }
}
```

---

## Query Best Practices

### Select Only Needed Fields (Projection)

```csharp
// Use projection to avoid loading entire entities
var users = await _context.Users
    .AsNoTracking()
    .Where(u => u.IsActive)
    .Select(u => new UserSummaryDto
    {
        Id = u.Id,
        Email = u.Email,
        Name = u.Name
    })
    .ToListAsync();

// Avoid SELECT *
var user = await _context.Users.FindAsync(id);
```

### Pagination

```csharp
public async Task<PagedResult<UserDto>> GetPagedAsync(int page, int pageSize)
{
    var query = _context.Users
        .AsNoTracking()
        .Where(u => u.IsActive);

    var totalCount = await query.CountAsync();

    var items = await query
        .OrderByDescending(u => u.CreatedAt)
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .Select(u => new UserDto { Id = u.Id, Email = u.Email, Name = u.Name })
        .ToListAsync();

    return new PagedResult<UserDto>
    {
        Items = items,
        TotalCount = totalCount,
        Page = page,
        PageSize = pageSize
    };
}
```

### Eager Loading (Prevent N+1)

```csharp
// N+1 Problem - BAD
var orders = await _context.Orders.ToListAsync();
foreach (var order in orders)
{
    // This executes N additional queries!
    var items = await _context.OrderItems
        .Where(i => i.OrderId == order.Id)
        .ToListAsync();
}

// GOOD - Use Include
var orders = await _context.Orders
    .AsNoTracking()
    .Include(o => o.Items)
    .Include(o => o.User)
    .ToListAsync();

// GOOD - Use ThenInclude for nested
var orders = await _context.Orders
    .AsNoTracking()
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)
    .ToListAsync();

// BEST - Use projection when you don't need full entities
var orders = await _context.Orders
    .AsNoTracking()
    .Select(o => new OrderDto
    {
        Id = o.Id,
        TotalAmount = o.TotalAmount,
        ItemCount = o.Items.Count,
        UserName = o.User.Name
    })
    .ToListAsync();
```

---

## Transactions

```csharp
// Using EF Core transaction
public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
{
    await using var transaction = await _context.Database.BeginTransactionAsync();

    try
    {
        var order = new Order
        {
            UserId = request.UserId,
            Status = OrderStatus.Pending
        };
        _context.Orders.Add(order);

        foreach (var item in request.Items)
        {
            var product = await _context.Products.FindAsync(item.ProductId)
                ?? throw new NotFoundException($"Product {item.ProductId} not found");

            if (product.Stock < item.Quantity)
                throw new ConflictException($"Insufficient stock for {product.Name}");

            product.Stock -= item.Quantity;

            _context.OrderItems.Add(new OrderItem
            {
                OrderId = order.Id,
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                Price = product.Price
            });
        }

        order.TotalAmount = order.Items.Sum(i => i.Price * i.Quantity);

        await _context.SaveChangesAsync();
        await transaction.CommitAsync();

        return order;
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
}

// Using execution strategy for retries
public async Task<Order> CreateOrderWithRetryAsync(CreateOrderRequest request)
{
    var strategy = _context.Database.CreateExecutionStrategy();

    return await strategy.ExecuteAsync(async () =>
    {
        await using var transaction = await _context.Database.BeginTransactionAsync();

        // ... same logic as above

        await transaction.CommitAsync();
        return order;
    });
}
```

---

## Dapper for Complex Reads

Use Dapper when:
- Query is complex with multiple JOINs
- Performance is critical
- EF Core generates inefficient SQL
- Reporting/analytics queries

```csharp
// Infrastructure/Repositories/ReportRepository.cs
public class ReportRepository : IReportRepository
{
    private readonly IDbConnection _connection;

    public ReportRepository(IDbConnection connection)
    {
        _connection = connection;
    }

    public async Task<IEnumerable<SalesReportDto>> GetMonthlySalesAsync(int year, int month)
    {
        const string sql = @"
            SELECT 
                p.Id AS ProductId,
                p.Name AS ProductName,
                c.Name AS CategoryName,
                SUM(oi.Quantity) AS TotalQuantity,
                SUM(oi.Quantity * oi.Price) AS TotalRevenue
            FROM OrderItems oi
            INNER JOIN Orders o ON o.Id = oi.OrderId
            INNER JOIN Products p ON p.Id = oi.ProductId
            INNER JOIN Categories c ON c.Id = p.CategoryId
            WHERE YEAR(o.CreatedAt) = @Year
              AND MONTH(o.CreatedAt) = @Month
              AND o.Status = @Status
            GROUP BY p.Id, p.Name, c.Name
            ORDER BY TotalRevenue DESC";

        return await _connection.QueryAsync<SalesReportDto>(sql, new
        {
            Year = year,
            Month = month,
            Status = (int)OrderStatus.Completed
        });
    }

    public async Task<UserDashboardDto?> GetUserDashboardAsync(Guid userId)
    {
        const string sql = @"
            SELECT 
                u.Id,
                u.Email,
                u.Name,
                COUNT(DISTINCT o.Id) AS TotalOrders,
                ISNULL(SUM(o.TotalAmount), 0) AS TotalSpent,
                MAX(o.CreatedAt) AS LastOrderDate
            FROM Users u
            LEFT JOIN Orders o ON o.UserId = u.Id AND o.Status = @CompletedStatus
            WHERE u.Id = @UserId
            GROUP BY u.Id, u.Email, u.Name";

        return await _connection.QueryFirstOrDefaultAsync<UserDashboardDto>(sql, new
        {
            UserId = userId,
            CompletedStatus = (int)OrderStatus.Completed
        });
    }
}
```

### Dapper with Multiple Result Sets

```csharp
public async Task<OrderDetailsDto> GetOrderDetailsAsync(Guid orderId)
{
    const string sql = @"
        SELECT Id, UserId, TotalAmount, Status, CreatedAt
        FROM Orders WHERE Id = @OrderId;

        SELECT Id, ProductId, Quantity, Price
        FROM OrderItems WHERE OrderId = @OrderId;";

    using var multi = await _connection.QueryMultipleAsync(sql, new { OrderId = orderId });

    var order = await multi.ReadFirstOrDefaultAsync<OrderDto>();
    if (order == null) return null;

    var items = await multi.ReadAsync<OrderItemDto>();

    return new OrderDetailsDto
    {
        Order = order,
        Items = items.ToList()
    };
}
```

---

## Migrations

### Migration Commands

```bash
# Add migration
dotnet ef migrations add InitialCreate \
    --project src/MyApp.Infrastructure \
    --startup-project src/MyApp.Api

# Update database
dotnet ef database update \
    --project src/MyApp.Infrastructure \
    --startup-project src/MyApp.Api

# Generate SQL script (for production)
dotnet ef migrations script \
    --project src/MyApp.Infrastructure \
    --startup-project src/MyApp.Api \
    --output migrations.sql \
    --idempotent

# Remove last migration (if not applied)
dotnet ef migrations remove \
    --project src/MyApp.Infrastructure \
    --startup-project src/MyApp.Api

# List migrations
dotnet ef migrations list \
    --project src/MyApp.Infrastructure \
    --startup-project src/MyApp.Api
```

### Migration Best Practices

```csharp
// Migrations/20240101120000_AddUserRole.cs
public partial class AddUserRole : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Add column with default value
        migrationBuilder.AddColumn<int>(
            name: "Role",
            table: "Users",
            type: "int",
            nullable: false,
            defaultValue: 0);

        // Add index
        migrationBuilder.CreateIndex(
            name: "IX_Users_Role",
            table: "Users",
            column: "Role");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_Users_Role",
            table: "Users");

        migrationBuilder.DropColumn(
            name: "Role",
            table: "Users");
    }
}
```

---

## Naming Conventions

> **Single source of truth: [`naming-conventions.md`](naming-conventions.md) §Database Naming** — tables (PascalCase plural), columns (`{ReferencedTable}Id`, `{Event}At`, `Is{Adjective}`), indexes (`IX_{Table}_{Columns}`, `UQ_`), foreign keys (`FK_{Child}_{Parent}_{Column}`). Do not restate here.

---

## Performance Tips

### Use AsNoTracking for Read-Only Queries

```csharp
// Read-only - no tracking needed
var users = await _context.Users
    .AsNoTracking()
    .Where(u => u.IsActive)
    .ToListAsync();
```

### Avoid Loading Full Entities

```csharp
// Check existence without loading
var exists = await _context.Users.AnyAsync(u => u.Email == email);

// Get count
var count = await _context.Orders.CountAsync(o => o.UserId == userId);

// Get single value
var email = await _context.Users
    .Where(u => u.Id == id)
    .Select(u => u.Email)
    .FirstOrDefaultAsync();
```

### Batch Operations

```csharp
// Batch delete (EF Core 7+)
await _context.Users
    .Where(u => u.DeletedAt < DateTime.UtcNow.AddYears(-1))
    .ExecuteDeleteAsync();

// Batch update (EF Core 7+)
await _context.Products
    .Where(p => p.CategoryId == categoryId)
    .ExecuteUpdateAsync(s => s
        .SetProperty(p => p.IsActive, false)
        .SetProperty(p => p.UpdatedAt, DateTime.UtcNow));
```

### Compiled Queries (Hot Path)

```csharp
// Define compiled query
private static readonly Func<AppDbContext, Guid, Task<User?>> GetUserById =
    EF.CompileAsyncQuery((AppDbContext context, Guid id) =>
        context.Users.FirstOrDefault(u => u.Id == id));

// Use compiled query
var user = await GetUserById(_context, userId);
```

---

## Security

- **Never** log query results containing sensitive data (passwords, tokens)
- **Always** use parameterized queries (EF Core/Dapper handle this)
- **Never** concatenate user input into SQL strings
- Apply **row-level security** for multi-tenant apps
- Use **connection string encryption** in production
- Limit database user permissions (principle of least privilege)

```csharp
// NEVER DO THIS
var sql = $"SELECT * FROM Users WHERE Email = '{email}'"; // SQL Injection!

// ALWAYS use parameters
var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);

// Dapper with parameters
var user = await _connection.QueryFirstOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Email = @Email",
    new { Email = email });
```

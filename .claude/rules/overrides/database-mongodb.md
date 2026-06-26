# Override: Database — MongoDB

> **Active when** `Project Profile → Database: MongoDB`. Read alongside `rules/database.md` (base — SQL Server / relational). **Cảnh báo quan trọng:** MongoDB là **NoSQL document store** — KHÔNG phải dialect SQL như Oracle/MySQL/PostgreSQL. Nhiều thứ trong base `database.md` (EF Core LINQ, Dapper raw SQL, `AsNoTracking`, parametrized `@`-syntax) **KHÔNG áp dụng**. Đọc kỹ §A "Paradigm differences" trước khi áp dụng pattern nào.
>
> File này hỗ trợ cả 2 nhánh stack: **ASP.NET Core** (`MongoDB.Driver`) và **Node.js** (`mongodb` driver / `mongoose` ODM).

---

## §A. Paradigm differences vs SQL (quan trọng — đọc trước)

| Khái niệm | SQL (base) | MongoDB |
|----------|-----------|---------|
| Storage unit | Row | **Document** (BSON — Binary JSON) |
| Group | Table | **Collection** |
| Schema | Strict (DDL) | **Flexible** — document trong cùng collection có thể khác shape (nhưng nên enforce qua validator) |
| Relationship | Foreign key + JOIN | **Embed** (denormalize) HOẶC **Reference** (`$lookup` aggregation) — chọn theo access pattern |
| Primary key | `Id UUID` / `IDENTITY` | `_id` (ObjectId 12-byte mặc định, hoặc tự assign UUID/string) |
| Query | SQL | **Query language MongoDB** (JSON-style) + **Aggregation Pipeline** |
| Transaction | Default ACID per statement | **Single-document atomic** by default; **multi-document transaction** chỉ trong replica set / sharded cluster (4.0+), tốn perf — tránh nếu có thể |
| Constraints | FK, CHECK, UNIQUE | Chỉ có **unique index**; KHÔNG có FK constraint, KHÔNG có cascade delete |
| Index | Per column | **Per field hoặc compound** — order quan trọng (ESR rule: Equality → Sort → Range) |
| Migration | DDL statement (ALTER TABLE) | **Không cần migration cho schema**; chỉ cần migration khi đổi shape data (data-migration script) hoặc đổi index |
| Pagination | `OFFSET / LIMIT` | `skip()` + `limit()` (chậm với large offset) HOẶC **cursor-based** (recommend) |
| Connection model | Pool per process | `MongoClient` là pool — **chỉ tạo 1 instance / app**, reuse |

**Hệ quả thực tế:**
- KHÔNG có "JOIN N+1 prevention" theo nghĩa SQL — vấn đề chuyển thành "embed-vs-reference decision"
- KHÔNG có "parametrized SQL string concat" risk — query là JSON object, driver tự escape
- VÀ ngược lại: rủi ro mới = **NoSQL injection** khi pass user input thẳng vào query operator (`$gt`, `$ne`, `$where`) — xem §H

---

## §B. Provider & connection

### B.1 — ASP.NET Core (MongoDB.Driver)

```xml
<!-- KHÔNG dùng EF Core với MongoDB (EF Core Mongo provider unofficial, ít maintain) -->
<PackageReference Include="MongoDB.Driver" Version="3.*" />
```

```csharp
// Singleton — MongoClient tự pool connection
services.AddSingleton<IMongoClient>(_ =>
    new MongoClient(configuration.GetConnectionString("MongoDb")));

services.AddSingleton(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase(configuration["MongoDb:DatabaseName"]));

// Repository nhận IMongoDatabase, lấy collection trong constructor
public class UserRepository
{
    private readonly IMongoCollection<User> _users;
    public UserRepository(IMongoDatabase db) => _users = db.GetCollection<User>("users");
}
```

Connection string: `mongodb://app:password@db1:27017,db2:27017,db3:27017/myapp?replicaSet=rs0&authSource=admin&retryWrites=true&w=majority`

### B.2 — Node.js

| Library | Khi dùng | Setup |
|---------|---------|-------|
| **`mongodb` (official driver)** | Cần control low-level, performance critical, không muốn ODM overhead | `npm install mongodb` |
| **Mongoose** | Greenfield cần schema enforcement + middleware + populate (default cho Express/NestJS) | `npm install mongoose` |
| **Prisma** (MongoDB connector, beta) | Đã dùng Prisma cho relational + muốn unified API | `npm install prisma @prisma/client` |

**`mongodb` driver example:**
```typescript
import { MongoClient } from "mongodb";

// Singleton — KHÔNG tạo nhiều MongoClient
const client = new MongoClient(process.env.MONGO_URL!, {
  maxPoolSize: 100,        // default 100 — tune theo load
  minPoolSize: 5,
  serverSelectionTimeoutMS: 5000,
});
await client.connect();
export const db = client.db("myapp");
export const users = db.collection<User>("users");
```

**Mongoose example:**
```typescript
import mongoose, { Schema, model } from "mongoose";

const UserSchema = new Schema({
  email: { type: String, required: true, unique: true, index: true },
  name:  { type: String, required: true, maxlength: 100 },
  createdAt: { type: Date, default: Date.now, immutable: true },
}, { timestamps: true });

export const User = model("User", UserSchema);
await mongoose.connect(process.env.MONGO_URL!);
```

**Connection pool:** `MongoClient` đã tự pool. KHÔNG tạo nhiều instance per request — anti-pattern phổ biến.

---

## §C. Schema design — Embed vs Reference

Đây là **quyết định kiến trúc quan trọng nhất** trong MongoDB. Sai → query chậm hoặc data inconsistency.

### Embed (nhúng) — chọn khi:
- Quan hệ 1-1 hoặc 1-few (vd: User → Address)
- Data cùng access pattern (luôn query cùng lúc)
- Child KHÔNG độc lập (không tồn tại nếu thiếu parent)
- Tổng size document < 16MB (giới hạn cứng MongoDB)

```json
{
  "_id": "u-001",
  "email": "user@example.com",
  "addresses": [
    { "type": "home",     "city": "HCM", "street": "123 Le Loi" },
    { "type": "shipping", "city": "Hanoi" }
  ]
}
```

→ Lấy user kèm addresses = 1 read, không cần JOIN.

### Reference (tham chiếu) — chọn khi:
- Quan hệ 1-many với "many" lớn / unbounded (vd: User → Orders — có thể hàng nghìn)
- Child entity độc lập, có lifecycle riêng (Order vẫn tồn tại sau khi User xoá account)
- Child được query/update độc lập với parent
- Cần share child giữa nhiều parent (Many-to-many)

```json
// users collection
{ "_id": "u-001", "email": "...", "name": "..." }

// orders collection — reference user qua user_id
{ "_id": "o-1001", "user_id": "u-001", "total": 99.99, "status": "completed" }
```

→ Query order của user: `orders.find({ user_id: "u-001" })` + index trên `user_id`.

### Anti-pattern: "Unbounded array embedded"

```json
// ❌ BAD — orders growth → document size bùng nổ → resize cost cao + cap 16MB
{ "_id": "u-001", "orders": [ ...10000 items... ] }

// ✅ GOOD — tách orders collection, reference user_id
{ "_id": "u-001", "orderCount": 10000 }  // cache count nếu cần
```

> Rule of thumb: nếu array có thể grow > 100 items → tách collection riêng.

---

## §D. Indexing — ESR rule + compound index

### Rule of order: **E**quality → **S**ort → **R**ange

```javascript
// Query: find active users in city, sort by createdAt
db.users.find({ status: "active", city: "HCM" }).sort({ createdAt: -1 })

// Compound index theo ESR:
db.users.createIndex({ status: 1, city: 1, createdAt: -1 })
//                     [Equality]  [Equality]  [Sort]
```

### Index types đáng dùng

| Loại | Khi dùng |
|------|---------|
| **Single field** | Query trên 1 field |
| **Compound** | Query trên nhiều field — theo ESR rule |
| **Multikey** | Field là array — index từng element |
| **Text** | Full-text search (đơn giản, không bằng Elasticsearch) |
| **Geospatial** (`2dsphere`) | Location query |
| **TTL** | Auto-delete document sau N giây (vd: session, log retention) |
| **Partial** | Index chỉ subset (vd: `WHERE deleted_at IS NULL` equivalent) |
| **Unique** | Constraint duy nhất (vd: email) |

### Anti-pattern: missing index

`db.collection.find(...).explain("executionStats")` → check `executionStages.stage`. Nếu thấy `COLLSCAN` (full collection scan) → cần index.

```bash
# Trong mongosh
db.users.find({ email: "x@y.com" }).explain("executionStats")
# winningPlan.stage: "COLLSCAN" → BAD, cần createIndex
# winningPlan.stage: "IXSCAN"   → GOOD
```

---

## §E. Aggregation Pipeline (thay cho JOIN/GROUP BY)

```javascript
// "Top 10 users by total order amount, status=completed"
db.users.aggregate([
  { $match: { status: "active" } },                            // WHERE
  { $lookup: {                                                  // LEFT JOIN
      from: "orders",
      localField: "_id",
      foreignField: "user_id",
      as: "orders",
      pipeline: [{ $match: { status: "completed" } }]           // filter trong $lookup
  }},
  { $addFields: { totalSpent: { $sum: "$orders.total" } } },    // computed field
  { $sort: { totalSpent: -1 } },                                // ORDER BY
  { $limit: 10 },                                               // LIMIT
  { $project: { email: 1, name: 1, totalSpent: 1, _id: 0 } }    // SELECT cột
]);
```

**Cảnh báo:** `$lookup` cross-collection **chậm** với data lớn — đó là lý do nên embed nếu access pattern cho phép. Dùng `$lookup` khi:
- Báo cáo, dashboard (chạy ít)
- Data set sau `$match` đã nhỏ
- Index đầy đủ trên `foreignField`

---

## §F. Transactions

**Mặc định:** single-document write là atomic. Đủ cho 90% case nếu schema design đúng (embed thay vì 2 documents).

**Multi-document transaction** (chỉ replica set / sharded cluster, 4.0+):

```csharp
// .NET
using var session = await mongoClient.StartSessionAsync();
session.StartTransaction();
try {
    await ordersColl.InsertOneAsync(session, order);
    await inventoryColl.UpdateOneAsync(session, filter, update);
    await session.CommitTransactionAsync();
} catch {
    await session.AbortTransactionAsync();
    throw;
}
```

```typescript
// Node.js
const session = client.startSession();
try {
  await session.withTransaction(async () => {
    await orders.insertOne(order, { session });
    await inventory.updateOne(filter, update, { session });
  });
} finally {
  await session.endSession();
}
```

**Quy tắc:**
- Transaction time **≤ 60 giây** (default `transactionLifetimeLimitSeconds`)
- KHÔNG dùng transaction cho long-running operation
- Standalone MongoDB (không replica set) → **KHÔNG hỗ trợ transaction** → dev local cần init replica set 1-node hoặc dùng MongoDB Atlas

---

## §G. Migration & testing

### Migration

MongoDB không có DDL → "migration" thực tế là:
1. **Index creation/drop** — script chạy 1 lần khi deploy
2. **Data shape change** — script transform document trong collection (vd: split `name` → `firstName` + `lastName`)
3. **Validator change** — `db.runCommand({ collMod: ..., validator: {...} })`

Tool đề xuất:
- **`migrate-mongo`** (Node.js) — migration framework giống Knex/Flyway nhưng cho Mongo
- **`Mongo.Migration`** (.NET) — migration cho MongoDB.Driver
- **`MongoFramework.Migrations`** — alternative .NET

Pattern: mỗi migration là 1 file với `up()` + `down()`, commit vào git, idempotent.

```javascript
// migrations/20260601-add-index-email.js
module.exports = {
  async up(db) { await db.collection("users").createIndex({ email: 1 }, { unique: true }); },
  async down(db) { await db.collection("users").dropIndex("email_1"); }
};
```

### TestContainers

**ASP.NET (.NET):**
```csharp
private readonly MongoDbContainer _mongo = new MongoDbBuilder()
    .WithImage("mongo:7.0")
    .Build();

// In ConfigureWebHost: services.AddSingleton<IMongoClient>(new MongoClient(_mongo.GetConnectionString()));
```

**Node.js — 2 lựa chọn:**

| Tool | Khi dùng |
|------|---------|
| **`@testcontainers/mongodb`** | Cần fidelity 100% với prod (replica set, transactions) |
| **`mongodb-memory-server`** | Test nhanh, không cần Docker, chạy in-memory MongoDB binary |

```typescript
// Option A: TestContainers (replica set support)
import { MongoDBContainer } from "@testcontainers/mongodb";
const container = await new MongoDBContainer("mongo:7.0").start();

// Option B: mongodb-memory-server (faster, no Docker)
import { MongoMemoryServer } from "mongodb-memory-server";
const mongod = await MongoMemoryServer.create();
process.env.MONGO_URL = mongod.getUri();
```

**Image recommend:** `mongo:7.0` (LTS) trên arm64 macOS ✓.

---

## §H. Common pitfalls — đọc kỹ

1. **NoSQL injection** — pass user input thẳng vào query operator:
   ```typescript
   // ❌ BAD — user gửi { email: { "$ne": null } } → trả về MỌI user
   await users.findOne({ email: req.body.email });
   
   // ✅ GOOD — coerce sang string trước
   await users.findOne({ email: String(req.body.email) });
   // Hoặc dùng Zod/class-validator validate type
   ```
   Mongoose có `sanitizeFilter: true` option. Driver thuần — tự sanitize.

2. **`$where` với JavaScript expression** — KHÔNG dùng (server-side eval, RCE risk). Dùng aggregation `$expr` thay thế.

3. **Unbounded array growth** — document max 16MB. Embed array sẽ break khi growth. Tách collection.

4. **`skip()` + `limit()` cho large offset** — chậm tuyến tính. Dùng cursor pagination với `_id` hoặc indexed field:
   ```typescript
   // ❌ skip(10000) — phải đọc 10000 doc bỏ
   await users.find({}).skip(10000).limit(20);
   
   // ✅ Cursor-based
   await users.find({ _id: { $gt: lastId } }).limit(20).sort({ _id: 1 });
   ```

5. **Multiple `MongoClient` instances** — anti-pattern. Mỗi instance pool riêng → connection bùng nổ. Tạo singleton 1 lần.

6. **`findAndModify` thiếu `returnDocument`** — .NET driver mặc định return document **TRƯỚC** update. Nếu cần after-version: `ReturnDocument.After`.

7. **Index không cover query → `IXSCAN` + `FETCH`** — query trả về field không trong index → cần FETCH document. Add field vào index để có **covered query**.

8. **Default Read/Write Concern không strict** — production nên set `writeConcern: { w: "majority", j: true }` để đảm bảo durability trên replica set.

9. **Schema drift** — flexible schema có thể tạo document inconsistent. Enforce qua:
   - Mongoose Schema validation
   - MongoDB native `$jsonSchema` validator: `db.runCommand({ collMod: "users", validator: { $jsonSchema: {...} } })`
   - Zod parse trước khi insert/update (Node.js)

10. **Timestamp** — MongoDB dùng `Date` (BSON Date = milliseconds from epoch UTC). KHÔNG có timezone metadata. Store UTC, convert client-side.

---

## §I. Naming convention

| Element | Convention |
|---------|------------|
| Collection name | snake_case, plural — `users`, `order_items` (giống SQL convention sau khi sang Node) |
| Field name | camelCase — `userId`, `createdAt` (JS-native, ánh xạ thẳng sang JSON) |
| `_id` | Mặc định `ObjectId`. Nếu cần readable (vd: user-facing): UUID v7 (time-ordered) hoặc nanoid |
| Index name | Auto-generated `field_1`, `field_-1` HOẶC tự đặt qua option `name` để dễ track |

---

## §J. What stays unchanged (vẫn theo base `database.md`)

Phần lớn base SQL-specific KHÔNG áp dụng. Phần CÒN áp dụng:

- **Validate / sanitize user input tại boundary** (Zod / FluentValidation / class-validator) — vẫn bắt buộc
- **KHÔNG log sensitive data** (password hash, token) — vẫn bắt buộc
- **Async/await mọi I/O** — vẫn bắt buộc
- **Transaction cho multi-step write** (với caveat §F về replica set requirement)
- **Eager load related data cẩn thận** — với MongoDB là embed-vs-reference decision (§C)
- **Connection pool tune theo load test** — vẫn bắt buộc, chỉ khác cách config
- **Naming convention** snake_case cho collection (giống PostgreSQL convention)

Phần **KHÔNG** áp dụng:
- ❌ Parametrized SQL với `@param` / `$1` — MongoDB query là JSON object
- ❌ `AsNoTracking()` EF Core — MongoDB driver không track
- ❌ Compiled query EF Core
- ❌ `INSERT ... ON CONFLICT` upsert syntax — Mongo dùng `updateOne({}, {}, { upsert: true })`
- ❌ FK constraint, cascade delete — Mongo không có
- ❌ `LIKE 'prefix%'` index pattern — Mongo dùng regex `^prefix` với `caseSensitive: false`

---

## See also

- Base database rule → [`../database.md`](../database.md) (xem kỹ phần nào còn áp dụng)
- Stack overrides (nếu đang dùng Node.js):
  - Language → [`lang-nodejs.md`](lang-nodejs.md)
  - Web framework → [`framework-nodejs-web.md`](framework-nodejs-web.md)
  - Testing → [`test-nodejs.md`](test-nodejs.md)
- System design / scaling → [`../system-design.md`](../system-design.md) (sharding section áp dụng cho MongoDB sharded cluster)
- Master principles → [`../principles-and-practices.md`](../principles-and-practices.md)

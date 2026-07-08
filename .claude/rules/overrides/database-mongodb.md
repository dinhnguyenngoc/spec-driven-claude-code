# Override: Database — MongoDB

> **Active when** `Project Profile → Database: MongoDB`. Read alongside `rules/database.md` (base — SQL Server / relational). **Important warning:** MongoDB is a **NoSQL document store** — NOT a SQL dialect like Oracle/MySQL/PostgreSQL. Many things in base `database.md` (EF Core LINQ, Dapper raw SQL, `AsNoTracking`, parametrized `@`-syntax) **do NOT apply**. Read §A "Paradigm differences" carefully before applying any pattern.
>
> This file supports both stack branches: **ASP.NET Core** (`MongoDB.Driver`) and **Node.js** (`mongodb` driver / `mongoose` ODM).

---

## §A. Paradigm differences vs SQL (important — read first)

| Concept | SQL (base) | MongoDB |
|----------|-----------|---------|
| Storage unit | Row | **Document** (BSON — Binary JSON) |
| Group | Table | **Collection** |
| Schema | Strict (DDL) | **Flexible** — documents in the same collection can have different shapes (but you should enforce via a validator) |
| Relationship | Foreign key + JOIN | **Embed** (denormalize) OR **Reference** (`$lookup` aggregation) — choose per access pattern |
| Primary key | `Id UUID` / `IDENTITY` | `_id` (ObjectId 12-byte by default, or assign your own UUID/string) |
| Query | SQL | **MongoDB query language** (JSON-style) + **Aggregation Pipeline** |
| Transaction | Default ACID per statement | **Single-document atomic** by default; **multi-document transaction** only in a replica set / sharded cluster (4.0+), costs perf — avoid if possible |
| Constraints | FK, CHECK, UNIQUE | Only a **unique index**; NO FK constraint, NO cascade delete |
| Index | Per column | **Per field or compound** — order matters (ESR rule: Equality → Sort → Range) |
| Migration | DDL statement (ALTER TABLE) | **No migration needed for schema**; migration is only needed when changing the data shape (data-migration script) or changing an index |
| Pagination | `OFFSET / LIMIT` | `skip()` + `limit()` (slow with a large offset) OR **cursor-based** (recommended) |
| Connection model | Pool per process | `MongoClient` is a pool — **create only 1 instance / app**, reuse it |

**Practical consequences:**
- There is NO "JOIN N+1 prevention" in the SQL sense — the problem becomes the "embed-vs-reference decision"
- There is NO "parametrized SQL string concat" risk — a query is a JSON object, the driver escapes it automatically
- And conversely: a new risk = **NoSQL injection** when passing user input straight into a query operator (`$gt`, `$ne`, `$where`) — see §H

---

## §B. Provider & connection

### B.1 — ASP.NET Core (MongoDB.Driver)

```xml
<!-- Do NOT use EF Core with MongoDB (the EF Core Mongo provider is unofficial, poorly maintained) -->
<PackageReference Include="MongoDB.Driver" Version="3.*" />
```

```csharp
// Singleton — MongoClient pools connections automatically
services.AddSingleton<IMongoClient>(_ =>
    new MongoClient(configuration.GetConnectionString("MongoDb")));

services.AddSingleton(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase(configuration["MongoDb:DatabaseName"]));

// Repository receives IMongoDatabase, gets the collection in the constructor
public class UserRepository
{
    private readonly IMongoCollection<User> _users;
    public UserRepository(IMongoDatabase db) => _users = db.GetCollection<User>("users");
}
```

Connection string: `mongodb://app:password@db1:27017,db2:27017,db3:27017/myapp?replicaSet=rs0&authSource=admin&retryWrites=true&w=majority`

### B.2 — Node.js

| Library | When to use | Setup |
|---------|---------|-------|
| **`mongodb` (official driver)** | Need low-level control, performance critical, do not want ODM overhead | `npm install mongodb` |
| **Mongoose** | Greenfield needing schema enforcement + middleware + populate (default for Express/NestJS) | `npm install mongoose` |
| **Prisma** (MongoDB connector, beta) | Already using Prisma for relational + want a unified API | `npm install prisma @prisma/client` |

**`mongodb` driver example:**
```typescript
import { MongoClient } from "mongodb";

// Singleton — do NOT create multiple MongoClients
const client = new MongoClient(process.env.MONGO_URL!, {
  maxPoolSize: 100,        // default 100 — tune per load
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

**Connection pool:** `MongoClient` already pools automatically. Do NOT create multiple instances per request — a common anti-pattern.

---

## §C. Schema design — Embed vs Reference

This is the **most important architectural decision** in MongoDB. Get it wrong → slow queries or data inconsistency.

### Embed — choose when:
- 1-1 or 1-few relationship (e.g. User → Address)
- Data with the same access pattern (always queried together)
- The child is NOT independent (does not exist without the parent)
- Total document size < 16MB (MongoDB's hard limit)

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

→ Getting a user with its addresses = 1 read, no JOIN needed.

### Reference — choose when:
- 1-many relationship with a large / unbounded "many" (e.g. User → Orders — could be thousands)
- The child entity is independent, with its own lifecycle (an Order still exists after the User deletes the account)
- The child is queried/updated independently of the parent
- You need to share the child across multiple parents (Many-to-many)

```json
// users collection
{ "_id": "u-001", "email": "...", "name": "..." }

// orders collection — reference the user via user_id
{ "_id": "o-1001", "user_id": "u-001", "total": 99.99, "status": "completed" }
```

→ Query a user's orders: `orders.find({ user_id: "u-001" })` + an index on `user_id`.

### Anti-pattern: "Unbounded array embedded"

```json
// ❌ BAD — orders growth → document size explodes → high resize cost + 16MB cap
{ "_id": "u-001", "orders": [ ...10000 items... ] }

// ✅ GOOD — split into an orders collection, reference user_id
{ "_id": "u-001", "orderCount": 10000 }  // cache the count if needed
```

> Rule of thumb: if an array can grow > 100 items → split into its own collection.

---

## §D. Indexing — ESR rule + compound index

### Rule of order: **E**quality → **S**ort → **R**ange

```javascript
// Query: find active users in city, sort by createdAt
db.users.find({ status: "active", city: "HCM" }).sort({ createdAt: -1 })

// Compound index per ESR:
db.users.createIndex({ status: 1, city: 1, createdAt: -1 })
//                     [Equality]  [Equality]  [Sort]
```

### Index types worth using

| Type | When to use |
|------|---------|
| **Single field** | Query on 1 field |
| **Compound** | Query on multiple fields — per the ESR rule |
| **Multikey** | Field is an array — indexes each element |
| **Text** | Full-text search (simple, not as good as Elasticsearch) |
| **Geospatial** (`2dsphere`) | Location query |
| **TTL** | Auto-delete a document after N seconds (e.g. session, log retention) |
| **Partial** | Index only a subset (e.g. `WHERE deleted_at IS NULL` equivalent) |
| **Unique** | Uniqueness constraint (e.g. email) |

### Anti-pattern: missing index

`db.collection.find(...).explain("executionStats")` → check `executionStages.stage`. If you see `COLLSCAN` (full collection scan) → you need an index.

```bash
# In mongosh
db.users.find({ email: "x@y.com" }).explain("executionStats")
# winningPlan.stage: "COLLSCAN" → BAD, need createIndex
# winningPlan.stage: "IXSCAN"   → GOOD
```

---

## §E. Aggregation Pipeline (in place of JOIN/GROUP BY)

```javascript
// "Top 10 users by total order amount, status=completed"
db.users.aggregate([
  { $match: { status: "active" } },                            // WHERE
  { $lookup: {                                                  // LEFT JOIN
      from: "orders",
      localField: "_id",
      foreignField: "user_id",
      as: "orders",
      pipeline: [{ $match: { status: "completed" } }]           // filter inside $lookup
  }},
  { $addFields: { totalSpent: { $sum: "$orders.total" } } },    // computed field
  { $sort: { totalSpent: -1 } },                                // ORDER BY
  { $limit: 10 },                                               // LIMIT
  { $project: { email: 1, name: 1, totalSpent: 1, _id: 0 } }    // SELECT columns
]);
```

**Warning:** cross-collection `$lookup` is **slow** with large data — that is why you should embed if the access pattern allows. Use `$lookup` when:
- Reports, dashboards (run infrequently)
- The data set after `$match` is already small
- There is a full index on `foreignField`

---

## §F. Transactions

**Default:** a single-document write is atomic. Enough for 90% of cases if the schema design is right (embed instead of 2 documents).

**Multi-document transaction** (replica set / sharded cluster only, 4.0+):

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

**Rules:**
- Transaction time **≤ 60 seconds** (default `transactionLifetimeLimitSeconds`)
- Do NOT use a transaction for a long-running operation
- Standalone MongoDB (no replica set) → **does NOT support transactions** → local dev needs to init a 1-node replica set or use MongoDB Atlas

---

## §G. Migration & testing

### Migration

MongoDB has no DDL → a "migration" in practice is:
1. **Index creation/drop** — a script run once at deploy
2. **Data shape change** — a script that transforms documents in a collection (e.g. split `name` → `firstName` + `lastName`)
3. **Validator change** — `db.runCommand({ collMod: ..., validator: {...} })`

Suggested tools:
- **`migrate-mongo`** (Node.js) — a migration framework like Knex/Flyway but for Mongo
- **`Mongo.Migration`** (.NET) — migration for MongoDB.Driver
- **`MongoFramework.Migrations`** — .NET alternative

Pattern: each migration is 1 file with `up()` + `down()`, committed into git, idempotent.

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

**Node.js — 2 options:**

| Tool | When to use |
|------|---------|
| **`@testcontainers/mongodb`** | Need 100% fidelity with prod (replica set, transactions) |
| **`mongodb-memory-server`** | Fast test, no Docker needed, runs an in-memory MongoDB binary |

```typescript
// Option A: TestContainers (replica set support)
import { MongoDBContainer } from "@testcontainers/mongodb";
const container = await new MongoDBContainer("mongo:7.0").start();

// Option B: mongodb-memory-server (faster, no Docker)
import { MongoMemoryServer } from "mongodb-memory-server";
const mongod = await MongoMemoryServer.create();
process.env.MONGO_URL = mongod.getUri();
```

**Image recommend:** `mongo:7.0` (LTS) on arm64 macOS ✓.

---

## §H. Common pitfalls — read carefully

1. **NoSQL injection** — passing user input straight into a query operator:
   ```typescript
   // ❌ BAD — user sends { email: { "$ne": null } } → returns EVERY user
   await users.findOne({ email: req.body.email });
   
   // ✅ GOOD — coerce to string first
   await users.findOne({ email: String(req.body.email) });
   // Or use Zod/class-validator to validate the type
   ```
   Mongoose has a `sanitizeFilter: true` option. Plain driver — sanitize it yourself.

2. **`$where` with a JavaScript expression** — do NOT use (server-side eval, RCE risk). Use the aggregation `$expr` instead.

3. **Unbounded array growth** — a document is max 16MB. An embedded array will break as it grows. Split into a collection.

4. **`skip()` + `limit()` for a large offset** — linearly slow. Use cursor pagination with `_id` or an indexed field:
   ```typescript
   // ❌ skip(10000) — must read 10000 docs and discard them
   await users.find({}).skip(10000).limit(20);
   
   // ✅ Cursor-based
   await users.find({ _id: { $gt: lastId } }).limit(20).sort({ _id: 1 });
   ```

5. **Multiple `MongoClient` instances** — an anti-pattern. Each instance has its own pool → connections explode. Create the singleton once.

6. **`findAndModify` missing `returnDocument`** — the .NET driver by default returns the document **BEFORE** the update. If you need the after-version: `ReturnDocument.After`.

7. **Index does not cover the query → `IXSCAN` + `FETCH`** — a query returning a field not in the index → needs to FETCH the document. Add the field into the index to get a **covered query**.

8. **Default Read/Write Concern is not strict** — production should set `writeConcern: { w: "majority", j: true }` to ensure durability on a replica set.

9. **Schema drift** — a flexible schema can create inconsistent documents. Enforce via:
   - Mongoose Schema validation
   - MongoDB native `$jsonSchema` validator: `db.runCommand({ collMod: "users", validator: { $jsonSchema: {...} } })`
   - Zod parse before insert/update (Node.js)

10. **Timestamp** — MongoDB uses `Date` (BSON Date = milliseconds from epoch UTC). It has NO timezone metadata. Store UTC, convert client-side.

---

## §I. Naming convention

| Element | Convention |
|---------|------------|
| Collection name | snake_case, plural — `users`, `order_items` (same as the SQL convention once moving to Node) |
| Field name | camelCase — `userId`, `createdAt` (JS-native, maps straight to JSON) |
| `_id` | Default `ObjectId`. If you need it readable (e.g. user-facing): UUID v7 (time-ordered) or nanoid |
| Index name | Auto-generated `field_1`, `field_-1` OR set your own via the `name` option to track it easily |

---

## §J. What stays unchanged (still follows base `database.md`)

Most of the SQL-specific base does NOT apply. The parts that STILL apply:

- **Validate / sanitize user input at the boundary** (Zod / FluentValidation / class-validator) — still mandatory
- **Do NOT log sensitive data** (password hash, token) — still mandatory
- **Async/await for all I/O** — still mandatory
- **Transaction for multi-step write** (with the §F caveat about the replica set requirement)
- **Eager load related data carefully** — with MongoDB this is the embed-vs-reference decision (§C)
- **Connection pool tuned per load test** — still mandatory, only the config differs
- **Naming convention** snake_case for collections (same as the PostgreSQL convention)

The parts that do **NOT** apply:
- ❌ Parametrized SQL with `@param` / `$1` — a MongoDB query is a JSON object
- ❌ `AsNoTracking()` EF Core — the MongoDB driver does not track
- ❌ Compiled query EF Core
- ❌ `INSERT ... ON CONFLICT` upsert syntax — Mongo uses `updateOne({}, {}, { upsert: true })`
- ❌ FK constraint, cascade delete — Mongo does not have them
- ❌ `LIKE 'prefix%'` index pattern — Mongo uses the regex `^prefix` with `caseSensitive: false`

---

## See also

- Base database rule → [`../database.md`](../database.md) (review carefully which parts still apply)
- Stack overrides (if using Node.js):
  - Language → [`lang-nodejs.md`](lang-nodejs.md)
  - Web framework → [`framework-nodejs-web.md`](framework-nodejs-web.md)
  - Testing → [`test-nodejs.md`](test-nodejs.md)
- System design / scaling → [`../system-design.md`](../system-design.md) (the sharding section applies to a MongoDB sharded cluster)
- Master principles → [`../principles-and-practices.md`](../principles-and-practices.md)

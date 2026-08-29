# Override: Testing — PHP (Pest / PHPUnit)

> **Active when** `Project Profile → Core` declares PHP. Read alongside `rules/testing.md` (base — xUnit + FluentAssertions + Moq + TestContainers). This file **only records the differences**; agnostic principles (testing pyramid, 80% coverage threshold, naming convention `{Method}_{Scenario}_{Expected}`, Arrange-Act-Assert, no shared state, real-service containers for the `/test` tier) **remain unchanged**.

---

## Test framework choice

| Framework | Best fit | Avoid when |
|-----------|----------|-----------|
| **Pest** (recommended default) | Greenfield; Laravel 11+ scaffolds it by default; expressive `it()/expect()`; runs on PHPUnit under the hood | Repo already standardized on PHPUnit (see the brownfield rule) |
| **PHPUnit** (fully supported) | Brownfield repos already on it; teams preferring class-based tests | — |

**Brownfield rule: a repo already on PHPUnit KEEPS PHPUnit — never migrate as part of an unrelated change; migration to Pest only as a deliberate, reasoned task** (its own plan entry + rationale). **One primary runner per repo, declared in the plan.** Examples below cover both.

---

## Test file organization

```
tests/
├── Unit/                          # isolated logic — no framework boot needed
│   └── Services/UserServiceTest.php
├── Feature/                       # in-process integration — boots the HTTP kernel
│   └── Api/V1/BookmarkTest.php    #   (the WebApplicationFactory equivalent of the C# base)
├── Browser/                       # Laravel Dusk E2E (if Dusk chosen)
└── e2e/                           # Playwright E2E (if Playwright chosen)
```

**Mapping onto the kit pyramid:** `tests/Unit` = unit tier · `tests/Feature` = **in-process integration** (full HTTP kernel, in-memory or container DB per template below) · browser E2E is a separate tier, never mixed into Feature.

**Naming** — the base `{method}_{scenario}_{expected}` maps onto `it()`/`test()` descriptions:

```php
// Pest
describe('UserService::findById', function () {
    it('returns user when exists', function () { ... });
    it('throws NotFoundException when user not found', function () { ... });
});

// PHPUnit
public function test_findById_whenUserNotFound_throwsNotFoundException(): void { ... }
```

---

## Integration test — pick template by phase

Same split as base `rules/testing.md` §Test Phases:

| Phase | DB backend | Docker | Speed | Catches |
|-------|-----------|--------|-------|---------|
| `/build` | SQLite `:memory:` + `RefreshDatabase` | ❌ | ms | Logic, mapping, validation |
| `/test` | **Real MySQL/Postgres container** | ✅ | seconds | Index, transaction, collation, dialect bugs |

### Template A — in-memory SQLite (for `/build`)

```xml
<!-- phpunit.xml — the DEFAULT config forces the in-memory tier -->
<php>
    <env name="APP_ENV" value="testing"/>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
    <env name="MAIL_MAILER" value="array"/>
    <env name="QUEUE_CONNECTION" value="sync"/>
    <env name="CACHE_STORE" value="array"/>
</php>
```

```php
// tests/Feature/Api/V1/BookmarkTest.php (Pest)
uses(RefreshDatabase::class);

it('POST /api/v1/bookmarks returns 201 and persists', function () {
    Http::fake();                                  // no real outbound calls (host isolation)
    $user = User::factory()->create();

    $response = $this->actingAs($user)->postJson('/api/v1/bookmarks', [
        'url' => 'https://example.com', 'title' => 'Example',
    ]);

    $response->assertStatus(201)->assertJsonPath('title', 'Example');
    $this->assertDatabaseHas('bookmarks', ['user_id' => $user->id, 'title' => 'Example']);
});

it('POST with invalid url returns validation error with field details', function () {
    $response = $this->actingAs(User::factory()->create())
        ->postJson('/api/v1/bookmarks', ['url' => 'not-a-url']);

    $response->assertStatus(400)                   // kit contract; brownfield keeps 422 (framework-php-laravel.md §C)
        ->assertJsonValidationErrors(['url']);
});
```

```php
// PHPUnit equivalent
class BookmarkTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_withValidData_returns201(): void { /* same arrange/act/assert */ }
}
```

**Fakes for every external side effect:** `Mail::fake()` · `Queue::fake()` · `Http::fake()` · `Storage::fake()` · `Event::fake()` (targeted).

**Honest caveat — SQLite is not MySQL/Postgres.** Tests exercising dialect-specific SQL will not run (or will silently behave differently) on SQLite and **belong to the `/test` tier (Template B)**: FULLTEXT / `MATCH AGAINST`, JSON column operators (`->` path queries), collation-dependent comparisons (utf8mb4 accent/case rules), dialect upserts (`ON DUPLICATE KEY` / `ON CONFLICT`).

### Template B — real DB container (for `/test`)

```bash
# .env.testing — NEW test-only file, committed, NO real/production values
APP_ENV=testing
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=33060            # the test container's published port — never the shared dev DB
DB_DATABASE=app_test
DB_USERNAME=test
DB_PASSWORD=test
```

```bash
# Start the container (compose overlay or docker run), migrate, run
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d mysql-test
php artisan migrate --env=testing
vendor/bin/pest -c phpunit.integration.xml       # or: vendor/bin/phpunit -c phpunit.integration.xml
```

**Config precedence (why two phpunit configs):** phpunit `<env>` values are set **before** Laravel boots, and Laravel's Dotenv never overwrites an existing env var — so the default `phpunit.xml` (sqlite) always wins over `.env.testing`. `phpunit.integration.xml` is a copy **without** the `DB_*` overrides → the container DSN from `.env.testing` applies. Image choice + arm64 notes → [`database-mysql.md`](database-mysql.md) / [`database-postgres.md`](database-postgres.md).

### E2E — Dusk or Playwright

- **Laravel Dusk**: runs against a real served app; use `DatabaseMigrations`/`DatabaseTruncation` — **not** `RefreshDatabase` (see pitfall 1).
- **Playwright**: against `php artisan serve --env=testing` (or the compose stack). Failure artifacts follow `commands/test.md §Run artifacts & failure capture (canonical layout)` — one fixed root, capture policy `retain-on-failure`, paths committed in the runner config:

```ts
// playwright.config.ts
export default defineConfig({
  outputDir: 'reports/test-artifacts/runner',
  use: { trace: 'retain-on-failure', screenshot: 'only-on-failure', video: 'retain-on-failure' },
  reporter: [
    ['json', { outputFile: 'reports/test-artifacts/report/results.json' }],
    ['html', { outputFolder: 'reports/test-artifacts/report/html', open: 'never' }],
  ],
});
```

Dusk screenshots (`tests/Browser/screenshots` by default) are pointed at `reports/test-artifacts/runner/` too.

---

## Host-isolation contract

Mirror of base `testing.md` §host-isolation — checkable at the gate:

- **`.env.testing` is a NEW test-only file** — it contains no real connection string and never points at pre-existing shared infrastructure.
- **NEVER edit `.env` / production config to make tests pass** — the deployed artifact keeps its original connections exactly as-is.
- **Fakes block real side effects** — `Mail::fake()` / `Queue::fake()` / `Http::fake()` mean no real mail, queue payloads, or outbound HTTP leave a test run.
- **Proof:** `git status` after the suite shows production config (`.env*` except `.env.testing`, `config/*.php`, `docker-compose.yml`) unchanged (`CLAUDE.md` §Verification After Delegation).

---

## Assertions — mapping FluentAssertions → Pest / PHPUnit

| FluentAssertions (C#) | Pest | PHPUnit |
|----------------------|------|---------|
| `result.Should().NotBeNull()` | `expect($result)->not->toBeNull()` | `$this->assertNotNull($result)` |
| `result.Should().Be(expected)` | `expect($result)->toBe($expected)` (identity) | `$this->assertSame($expected, $result)` |
| `result.Should().BeEquivalentTo(expected)` | `expect($result)->toEqual($expected)` | `$this->assertEquals($expected, $result)` |
| `users.Should().HaveCount(3)` | `expect($users)->toHaveCount(3)` | `$this->assertCount(3, $users)` |
| `email.Should().Contain("@")` | `expect($email)->toContain('@')` | `$this->assertStringContainsString('@', $email)` |
| `total.Should().BeGreaterThan(0)` | `expect($total)->toBeGreaterThan(0)` | `$this->assertGreaterThan(0, $total)` |
| `act.Should().ThrowAsync<NotFoundException>()` | `expect(fn () => $svc->findById($id))->toThrow(NotFoundException::class)` | `$this->expectException(NotFoundException::class)` |

**Laravel HTTP/DB assertions** (both runners, Feature tier): `assertStatus(201)` · `assertJson([...])` · `assertJsonPath('data.email', ...)` · `assertJsonValidationErrors(['email'])` · `assertDatabaseHas('users', [...])` · `assertSoftDeleted($model)`.

---

## Factories & characterization

- **Model factories per test** — each test creates its own rows (`User::factory()->create()`, factory states for variants); no shared fixtures, no seeded "test user 1" shared across tests.
- **Time control** — `$this->travelTo(...)` / `Carbon::setTestNow(...)`; always restore (`travelBack()`), frozen time leaking across tests is shared state.
- **Characterization / golden-master for legacy PHP** — capture the CURRENT behavior, PASS-first, per `rules/brownfield.md` (the test documents what the code *does*, not what is *correct*):

```php
// tests/Unit/Legacy/PriceCalculatorCharacterizationTest.php
it('legacy_totalPrice_keeps_current_floor_rounding', function () {
    // Characterization: legacy floor()s instead of rounding — captured AS-IS.
    // Changing this value is a spec decision (AC amendment), never a refactor side effect.
    expect(legacy_total_price(3, 9.99))->toBe(29.0);
});
```

---

## Coverage

| Driver | Trade-off |
|--------|-----------|
| **PCOV** | Fast, coverage-only — **line coverage only** |
| **Xdebug** (`XDEBUG_MODE=coverage`) | Slower — required for **branch/path coverage** |

```bash
# Pest — gate line coverage in one flag
vendor/bin/pest --coverage --min=80

# PHPUnit — generate clover, gate in CI
XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-clover coverage/clover.xml
```

- Kit thresholds unchanged: **line ≥ 80% · branch ≥ 75%** (branch measured with Xdebug at the `/test` gate; PCOV covers the day-to-day line gate).
- **Brownfield: delta-coverage + whole-repo ratchet** per base [`../testing.md`](../testing.md) §Coverage Thresholds — the gate is the delta over changed files; whole-repo is informational + must not decrease.

---

## Common pitfalls

1. **`RefreshDatabase` vs `DatabaseTransactions`** — `RefreshDatabase` migrates then wraps each test in a transaction; `DatabaseTransactions` assumes the schema already exists. Transaction-wrapped data is **invisible to a separately-connecting process** — Dusk/Playwright hit a served app on its own DB connection, so browser tests MUST use `DatabaseMigrations`/`DatabaseTruncation`, never `RefreshDatabase`.
2. **Factory/state leakage** — module-level singletons, static caches, and a forgotten `Carbon::setTestNow()` bleed across tests. Each test seeds its own data; restore time/state in teardown.
3. **Focused tests leaking into main** — Pest's `->only()` skips everything else; run CI with `pest --ci` so a leaked `->only()` fails the build (PHPUnit has no focus mechanism — lower risk).
4. **SQLite-vs-MySQL drift** — Template A green does NOT prove dialect-touching SQL works; promote those tests to Template B (see the caveat list in Template A).
5. **`env()` after `config:cache`** — a test (or code under test) reading `env()` outside `config/` gets `null` once config is cached; read via `config()` and run `php artisan config:clear` before the suite when in doubt.

---

## Checklist

- [ ] Every public service/action method has a unit or feature test
- [ ] Edge cases (null, empty, boundary, **wrong-type** — see `../testing.md` §Wrong-type input) tested
- [ ] Error paths tested (exceptions, validation failures — status per the repo's documented contract, 400 or brownfield 422)
- [ ] Feature test for each controller / route
- [ ] E2E test for the main user journeys, with `retain-on-failure` artifacts under `reports/test-artifacts/`
- [ ] Independent tests (no shared state), meaningful names
- [ ] Coverage ≥ 80% line, ≥ 75% branch (brownfield: delta + ratchet)
- [ ] Unit tests < 10s total
- [ ] No `->only()` leaks into the main branch (`pest --ci` guard)
- [ ] `git status` after the suite: production config unchanged (host-isolation contract)

---

## What stays unchanged (still follows base rules)

- Testing pyramid + the `/build` vs `/test` phase split — `../testing.md`
- Coverage thresholds (80% line / 75% branch) + Mode-scoped gate (greenfield whole-repo · brownfield delta + ratchet) — `../testing.md` §Coverage Thresholds
- Arrange-Act-Assert, naming semantics `{method}_{scenario}_{expected}` — `../testing.md`
- Test-double preference order (real → fake → stub → mock, mocks sparingly) — `../testing.md`
- Host-isolation contract (no test ever touches pre-existing infrastructure) — `../testing.md` §Integration Test Templates
- Dual-Implementation Parity (differential test when a rule has ≥ 2 representations) — `../testing.md`
- Characterization-first discipline on legacy — `../brownfield.md`

---

## See also

- Language baseline → [`lang-php.md`](lang-php.md)
- Web framework patterns → [`framework-php-laravel.md`](framework-php-laravel.md)
- Base testing rules → [`../testing.md`](../testing.md)
- DB container images / dialect notes → [`database-mysql.md`](database-mysql.md) / [`database-postgres.md`](database-postgres.md)

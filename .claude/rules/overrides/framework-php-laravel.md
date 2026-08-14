# Override: Web Framework — PHP (Laravel)

> **Active when** `Project Profile → Core` declares PHP + **Laravel** (10 / 11 / 12 supported; examples target **Laravel 11** — detect the running major from `composer.json` before applying version-specific wiring). Read alongside `rules/api-conventions.md`, `rules/error-handling.md`, `rules/security.md`, `rules/project-structure.md` (base — ASP.NET Core). This file **only records the differences**; agnostic principles (REST design, HTTP status codes, ProblemDetails error contract, versioning, rate limiting strategy, CORS allowlist) **remain unchanged**.

---

## §A. Project structure

Laravel's skeleton maps onto the Clean Architecture roles like this:

```
app/
├── Http/
│   ├── Controllers/Api/V1/     # thin controllers — delegate immediately
│   ├── Requests/               # FormRequest = the validation boundary (§D)
│   ├── Resources/              # API Resources = response shaping (DTO-out)
│   └── Middleware/             # correlation id, security headers, ...
├── Services/                   # business logic — never touches HTTP
├── Actions/                    # alternative: one class = one use case (handle())
├── Models/                     # Eloquent (Active Record — see the rule below)
├── Exceptions/                 # AppException hierarchy (lang-php.md)
├── Policies/                   # authorization (§E)
├── Jobs/                       # queued work (§I)
└── Events/ + Listeners/
routes/
├── api.php                     # /api/v1 endpoints
└── web.php
config/                         # ALL env access goes through here (§H)
database/
├── migrations/ · factories/ · seeders/
```

**Rules:**

- **Thin controllers** — validate (FormRequest) → call a Service/Action → return a Resource. No business logic, no queries in controllers.
- **Do NOT cargo-cult the Repository pattern over Eloquent.** Eloquent IS the data layer (Active Record) — unlike the C# base, where the Repository layer exists because EF Core is unit-of-work based (`project-structure.md`). Wrapping every model in a repository that mirrors Eloquent's own API adds a layer with no seam value and fights the framework. A repository interface is justified **only** when swapping persistence is a real, ADR-backed requirement — not as a default.
- **Services/Actions never touch HTTP concerns** — no `request()`, no `Response`, no session. The controller passes validated scalars/DTOs in; testable without booting HTTP.

---

## §B. Routing & HTTP conventions

URL pattern, plural nouns, status codes, pagination — **UNCHANGED** per `api-conventions.md` (base). Laravel syntax:

```php
// routes/api.php
Route::prefix('v1')->group(function () {          // full path: /api/v1/...
    Route::apiResource('bookmarks', BookmarkController::class);
    Route::get('order-items', [OrderItemController::class, 'index']); // kebab-case URIs
});
```

### Route-model binding — IDOR warning (mandatory)

Implicit binding (`public function show(Bookmark $bookmark)`) fetches by primary key **regardless of owner** — the textbook IDOR (accessing another user's record by its id, base `security.md`). Bindings MUST be ownership-scoped:

```php
// ❌ IDOR — returns ANY user's bookmark; adding a Policy that returns 403 still leaks existence
public function show(Bookmark $bookmark)
{
    return new BookmarkResource($bookmark);
}

// ✅ Ownership-scoped — not-found and other-owner return the IDENTICAL 404 (no existence leak)
public function show(Request $request, string $id)
{
    $bookmark = $request->user()->bookmarks()->findOrFail($id); // ModelNotFoundException → 404 (§C)
    return new BookmarkResource($bookmark);
}
```

For nested resources, scoped bindings do the same via the relationship: `Route::apiResource('users.bookmarks', ...)->scoped();`. Whichever mechanism — the observable contract is **404-for-both**.

---

## §C. Error contract — RFC 7807 (ProblemDetails)

Map exceptions to `application/problem+json` per the base error-code table (`error-handling.md`). Laravel 11/12: `bootstrap/app.php` → `->withExceptions()`; **Laravel 10: the same mapping lives in `app/Exceptions/Handler.php::render()`**.

```php
// bootstrap/app.php (Laravel 11/12)
->withExceptions(function (Exceptions $exceptions) {
    $exceptions->render(function (Throwable $e, Request $request) {
        if (! $request->is('api/*')) {
            return null; // web routes keep default rendering
        }

        [$status, $code, $detail, $errors] = match (true) {
            $e instanceof ValidationException =>            // Illuminate\Validation\ValidationException
                [400, 'VALIDATION_ERROR', 'Validation failed', $e->errors()], // 400 = kit contract; brownfield keeps 422 — see rule below
            $e instanceof AppException =>
                [$e->statusCode, $e->errorCode, $e->getMessage(), null],
            $e instanceof ModelNotFoundException,
            $e instanceof NotFoundHttpException =>
                [404, 'NOT_FOUND', 'Resource not found', null],
            $e instanceof AuthenticationException =>
                [401, 'UNAUTHORIZED', 'Authentication required', null],
            $e instanceof AuthorizationException =>
                [403, 'FORBIDDEN', 'Access denied', null],
            default =>
                [500, 'INTERNAL_ERROR', 'An unexpected error occurred', null],
        };

        if ($status >= 500) {
            Log::error($e->getMessage(), ['exception' => $e]); // full stack trace, base rule
        }

        return response()->json(array_filter([
            'status'   => $status,
            'title'    => SymfonyResponse::$statusTexts[$status] ?? 'Error',
            'detail'   => $detail,
            'instance' => $request->getRequestUri(),
            'code'     => $code,
            'errors'   => $errors,
            'traceId'  => $request->attributes->get('correlationId'), // set by middleware, §G
        ], fn ($v) => $v !== null), $status)
            ->header('Content-Type', 'application/problem+json');
    });
})
```

### The 422-vs-400 rule

Laravel's default validation status is **422**. **Greenfield-on-Laravel → align to the kit contract (400) via the handler above. Brownfield → KEEP 422 as-is** — characterize it (a test asserting 422, `rules/brownfield.md`) + document it in the API contract (`architecture/api/`); **never flip a running contract** — deployed clients pattern-match on it.

---

## §D. Validation

- **FormRequest = the boundary.** Every write endpoint has one; `rules()` for input shape, `authorize()` for coarse access (fine-grained ownership goes through Policies, §E).
- Reusable domain rules → custom `Rule` objects (`php artisan make:rule`), not copy-pasted regexes.
- **Never pass `$request->all()` into model writes** — always `$request->validated()` (or `$request->safe()->only([...])`). `all()` carries whatever the client sent, straight into mass assignment (§H).

```php
// app/Http/Requests/StoreUserRequest.php
class StoreUserRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email'    => ['required', 'email', 'max:255'],
            'name'     => ['required', 'string', 'min:2', 'max:100'],
            'password' => ['required', 'string', 'max:128',
                           Password::min(8)->mixedCase()->numbers()->symbols()], // base security.md policy
        ];
    }
}

// Controller
public function store(StoreUserRequest $request): JsonResponse
{
    $user = $this->userService->create($request->validated()); // NOT $request->all()
    return (new UserResource($user))->response()->setStatusCode(201);
}
```

---

## §E. Authentication & authorization

**Sanctum is the recommended default** — first-party, covers SPA cookie auth and mobile/API tokens. A JWT package is justified **only** when stateless multi-client is a real requirement (record via ADR); do not add one by reflex.

| Concern | Laravel implementation | Kit budget (base `security.md`) |
|---------|------------------------|--------------------------------|
| Token lifetime | `config/sanctum.php` → `'expiration' => 15` (minutes) | Access 15 min |
| Refresh | Re-issue flow / rotated long-lived token | Refresh 7 days, single-use, rotate |
| Password hashing | `Hash::make($password)` with bcrypt | `config/hashing.php` → `'bcrypt' => ['rounds' => 12]` |
| Auth rate limit | `RateLimiter::for('auth', ...)` | 5 attempts / 15 min per IP |
| Global rate limit | `RateLimiter::for('api', ...)` | 100 req / min per user-or-IP |

```php
// AppServiceProvider::boot()
RateLimiter::for('auth', fn (Request $r) => Limit::perMinutes(15, 5)->by($r->ip()));
RateLimiter::for('api',  fn (Request $r) => Limit::perMinute(100)->by($r->user()?->id ?: $r->ip()));

// routes/api.php
Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:auth');
```

**Authorization:** Policies per model (`php artisan make:policy`), ownership check inside (`$user->id === $bookmark->user_id`); controllers call `Gate::authorize('update', $bookmark)`. For reads, prefer the §B ownership-scoped query (404-for-both) over a 403-ing Policy.

---

## §F. Eloquent & database

DB **dialect** facts (PK gen, timestamps, charset/collation, paging, TestContainers images) → the existing [`database-mysql.md`](database-mysql.md) / [`database-postgres.md`](database-postgres.md) overrides apply **as-is**; Eloquent-specific patterns live here (same division as the Node.js override's §J).

### N+1 prevention

```php
// AppServiceProvider::boot() — lazy loads THROW in dev/test, stay silent in production
Model::preventLazyLoading(! app()->isProduction());

// ❌ N+1                                    // ✅ eager load
$orders = Order::all();                      $orders = Order::with('items.product')->get();
foreach ($orders as $o) { $o->items; }
```

### Transactions, batches, casts

- Multi-step writes → `DB::transaction(fn () => ...)` (closure form auto-commits/rolls back).
- Large sets → `chunkById()` / `cursor()` / `lazy()`; never `Model::all()` on an unbounded table.
- `casts()` (Laravel 11) / `$casts` for dates, backed enums, encrypted attributes — no manual string juggling.

### Kit data discipline mapped

| Kit rule (`principles-and-practices.md §4.5`) | Laravel implementation |
|-----------------------------------------------|------------------------|
| Soft delete (`DeletedAt`) | `SoftDeletes` trait + `$table->softDeletes()` — global scope auto-filters |
| `created_at` / `updated_at` | Native — `$table->timestamps()` |
| `created_by` / `updated_by` | Small trait (below) or observer |
| Optimistic concurrency | **No native rowversion** → integer `version` column + conditional update (below); record the choice via ADR |

```php
// app/Models/Concerns/HasAuditColumns.php
trait HasAuditColumns
{
    protected static function bootHasAuditColumns(): void
    {
        static::creating(fn ($m) => $m->created_by ??= auth()->id());
        static::updating(fn ($m) => $m->updated_by = auth()->id());
    }
}

// Optimistic concurrency — 0 rows affected means someone else won: 409
$updated = Bookmark::whereKey($id)
    ->where('version', $expectedVersion)
    ->update([...$changes, 'version' => $expectedVersion + 1]);

if ($updated === 0) {
    throw new ConflictException('The record was modified by another request');
}
```

### Migration discipline

- **Never edit a released migration** — additive follow-up migration instead.
- Every migration ships a working `down()`.
- Migrations are committed; schema drift outside migrations is a finding.

---

## §G. Logging & observability

| Base (`monitoring.md`) | Laravel implementation |
|------------------------|------------------------|
| Structured JSON to stdout/stderr | Monolog `JsonFormatter` on the `stderr` channel (below) |
| Correlation ID end-to-end | Middleware echoes `X-Correlation-ID` + pushes into log context (below) |
| Never log sensitive data | Monolog processor / `Log::withContext` discipline — strip `password`, `token`, `authorization` |
| Health endpoints | `/health`, `/health/live`, `/health/ready` — hand-rolled routes or `spatie/laravel-health` |
| Metrics & tracing | **Opt-in** per `principles-and-practices.md §5` triggers — do not preinstall an APM |

```php
// config/logging.php — container-friendly channel
'stderr' => [
    'driver'    => 'monolog',
    'handler'   => Monolog\Handler\StreamHandler::class,
    'formatter' => Monolog\Formatter\JsonFormatter::class,
    'with'      => ['stream' => 'php://stderr'],
],
```

```php
// app/Http/Middleware/CorrelationId.php
class CorrelationId
{
    public function handle(Request $request, Closure $next): SymfonyResponse
    {
        $correlationId = $request->header('X-Correlation-ID') ?? (string) Str::uuid();
        $request->attributes->set('correlationId', $correlationId);
        Log::withContext(['correlationId' => $correlationId]); // every log line carries it

        $response = $next($request);
        $response->headers->set('X-Correlation-ID', $correlationId);
        return $response;
    }
}
```

```php
// routes/api.php (or web.php) — the three mandatory endpoints
Route::get('/health', fn () => response()->json(['status' => 'ok']));
Route::get('/health/live', fn () => response()->json(['status' => 'alive']));
Route::get('/health/ready', function () {
    DB::select('select 1');                 // DB reachable
    Cache::store()->get('health-probe');    // cache reachable
    return response()->json(['status' => 'ready']);
});
```

---

## §H. Security

- **Security headers** — middleware appending the base `security.md` set:

```php
// app/Http/Middleware/SecurityHeaders.php
$response->headers->set('X-Content-Type-Options', 'nosniff');
$response->headers->set('X-Frame-Options', 'DENY');
$response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
$response->headers->set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
$response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
```

- **CORS** — `config/cors.php`: explicit `allowed_origins` list; never `*` together with `supports_credentials => true`.
- **CSRF** — web routes only; `routes/api.php` is stateless (no CSRF middleware). Exception: Sanctum **SPA cookie mode** does use CSRF — the SPA hits `/sanctum/csrf-cookie` and sends `X-XSRF-TOKEN`.
- **`DB::raw` / `whereRaw` with interpolated user input = the string-concat SQL sin** (base `database.md`). Eloquent/Query Builder parameterize automatically; raw fragments take bindings:

```php
// ❌ NEVER                                             // ✅ bindings
->whereRaw("email = '{$request->email}'")               ->whereRaw('email = ?', [$request->email])
```

- **Mass assignment** — `$fillable` is mandatory on every model; **`$guarded = []` is forbidden** (it turns every request key into a writable column).
- **Uploads** — validate `['file', 'mimes:...', 'max:<kb>']`; store outside the public docroot (`storage/app`), never trust client filename/mime; serve via a controlled/signed route.
- **`.env` never committed** (commit `.env.example` only). **`config:cache` caveat:** once config is cached, `env()` calls **outside `config/`** return `null` — all env access goes through `config()` reading a `config/*.php` key.

---

## §I. Queues & jobs

- **Default `QUEUE_CONNECTION=sync`** (YAGNI). Move to Redis + Horizon **only when a `principles-and-practices.md §5` trigger fires** (task > 30s must not block HTTP / scheduled work) — record via ADR.
- Jobs are **idempotent** (safe under retry); `ShouldBeUnique` where duplicate dispatch is possible; explicit `$tries` + backoff; `failed_jobs` table migrated and monitored.

---

## §J. Docker baseline for PHP

Two sanctioned container shapes — pick one per repo:

| Shape | Containers | HEALTHCHECK placement |
|-------|-----------|----------------------|
| **php-fpm + nginx sidecar** (classic) | 2 (fpm + nginx in compose) | nginx container hits `/health`; fpm container uses a FastCGI ping |
| **FrankenPHP / Octane single container** | 1 (serves HTTP itself) | `HEALTHCHECK` hits `/health` directly |

```dockerfile
# docker/Dockerfile — multi-stage, fpm shape (nginx sidecar defined in compose)
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

FROM php:8.3-fpm-alpine
RUN docker-php-ext-install pdo_mysql opcache \
 && adduser -D -u 1000 appuser
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini  # opcache.enable=1, validate_timestamps=0 in prod
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --chown=appuser:appuser . /var/www/html
WORKDIR /var/www/html
USER appuser
```

**The 20 must-haves of `principles-and-practices.md §4` apply unchanged** — non-root user, pinned images, `.dockerignore` at repo root (add `vendor/`, `.env`, `storage/logs`), resource limits, secrets via env, image scan.

---

## §K. Frontend (positioning only — deliberately short)

This section positions Laravel's UI options against the kit; it is **not** a frontend standard:

- **Brownfield keeps whatever exists as-is** — Blade, Livewire, Inertia, jQuery: `/discover` records it; no migration by side effect.
- **A separate React/Vue SPA** → base [`frontend.md`](../frontend.md) applies to the SPA side unchanged.
- **Blade/Livewire server-rendered UI** → the kit's UI obligations still apply: page-level states (loading/error/empty), the accessibility checklist, wireframes at `/spec`, and the responsive checks at `/verify`.

No deep frontend override lives here — if the project needs Blade/Livewire coding standards, that is a separate override file.

---

## What stays unchanged (still follows base rules)

- REST URL pattern, plural noun, kebab-case multi-word, versioned `/api/v1/...` — `api-conventions.md`
- HTTP status codes (200/201/204/400/401/403/404/409/500) — `api-conventions.md`
- ProblemDetails RFC 7807 contract — `error-handling.md` (with the documented brownfield 422 exception, §C)
- Authentication discipline (short-lived access + refresh rotation) — `security.md`
- Rate limit budget (100/min global, 5/15min auth) — `security.md`
- Security headers list — `security.md`
- Audit log + correlation ID propagation — `principles-and-practices.md §4.6`
- Project-structure conventions (Service does not know HTTP, thin controllers, validation at the boundary) — `project-structure.md` (mapped conceptually in §A)

---

## See also

- Language baseline → [`lang-php.md`](lang-php.md)
- Test framework (Pest / PHPUnit) → [`test-php.md`](test-php.md)
- Base error contract → [`../error-handling.md`](../error-handling.md)
- Base security rules → [`../security.md`](../security.md)
- Base API conventions → [`../api-conventions.md`](../api-conventions.md)
- Database dialect overrides → [`database-mysql.md`](database-mysql.md) / [`database-postgres.md`](database-postgres.md)

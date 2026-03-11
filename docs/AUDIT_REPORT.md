# Engineering Audit: LedgerBank API

**Date:** 2025-03-11  
**Scope:** Full repo audit as portfolio project and engineering codebase  
**Rules:** No code changes, no commits, no pushes, no branch touches.

---

## 1. Project Understanding

### What the project claims to be

- **README.md**: "Enterprise-Grade Financial Services API Built with Elixir/Phoenix"; "production-grade"; "clean architecture, sophisticated error handling, security best practices, background job processing"; "Domain-Driven Design"; "1000+ tests"; "Not for Production Use" (demo only).
- **LOCAL_SETUP.md**: Quick local run with Docker (db + Redis), optional manual setup.
- **docs/**: GETTING_STARTED, API_REFERENCE, ARCHITECTURE, DEVELOPER, TESTING_GUIDE, DEPLOYMENT_GUIDE, CHEATSHEET, plus MULTI_NODE, OPENTELEMETRY, STRESS_TESTING, JWT tradeoffs, etc.
- **mix.exs**: Phoenix 1.7, Ecto, Oban, Joken, OpenAPI/Swagger, OpenTelemetry, Prometheus, Fuse (circuit breaker), Absinthe (GraphQL), Redix (Redis), Req, CORS, Bandit. Version 0.1.0.
- **config/**: Layered config (config.exs, dev/test/prod, runtime.exs); financial limits, JWT, cache adapter (ETS/Redis), Oban queues, password hashing (PBKDF2 in config).
- **docker-compose.yml**: db (Postgres 16), redis, web (build from Dockerfile); healthchecks; no REDIS/CACHE_ADAPTER in web env (defaults to ETS unless overridden elsewhere).
- **Dockerfile**: Multi-stage (build → app); Elixir 1.18, release build; entrypoint runs migrations then start.
- **.github/workflows/ci.yml**: Code quality (format, compile --warnings-as-errors), test (Postgres + Redis services), Docker build + health check, optional release on tags.

### What it actually does

- REST API for: auth (login/refresh/logout/me), users (CRUD, list, keyset pagination, stats), profile, payments (CRUD, process, validate, stats), health, metrics, problems (error catalog), webhooks (stubs), API docs (Swagger/OpenAPI).
- GraphQL (Absinthe) mounted at `/api/v1/graphql` and `/api/graphql` with schema and resolvers (users, payments, auth, accounts, transactions).
- Background jobs: PaymentWorker, BankSyncWorker (Oban); workers use a shared WorkerBehavior.
- One real external integration: Monzo (BankApiClient behaviour) for accounts, transactions, balance, token refresh; create_payment hits Monzo “feed” API (not real payments).
- Caching: ETS by default; Redis adapter exists and is wired (config/runtime.exs prod, LOCAL_SETUP) but Redis adapter uses a single Redix connection, not a pool (pool_size config is read but ignored in `start_redix_pool`).
- Auth: JWT (Joken), refresh tokens in DB, role-based access (user/admin/support), constant-time login attempt (documented; implementation uses PasswordService which is PBKDF2, not Argon2).
- Error handling: Central Error struct, ErrorCatalog (reason → category → HTTP/retry), ErrorHandler, ErrorAdapter to HTTP; RFC 9457–style problem details and `/api/problems` registry.
- Observability: Telemetry, Prometheus metrics endpoint, OpenTelemetry (runtime config), structured logging, correlation IDs.

So: it’s a **demo/portfolio “banking API”** with auth, users, payments, one bank integration (Monzo), background jobs, dual REST+GraphQL, and a lot of documented patterns (clean architecture, DDD, circuit breaker, cache adapter, error catalog). It does not move real money; webhooks and “fraud” are stubs.

---

## 2. Structure and Architecture

### Layout (lib/)

- **ledger_bank_api/**  
  - **accounts/**: User, RefreshToken schemas; UserService, AuthService, Token, Policy, Normalize; PasswordService.  
  - **financial/**: Bank, BankBranch, UserBankLogin, UserBankAccount, UserPayment, Transaction schemas; FinancialService; workers (PaymentWorker, BankSyncWorker); integrations (BankApiClient behaviour, MonzoClient); Policy, Normalize; PaymentNotifications.  
  - **core/**: Error, ErrorCatalog, ErrorHandler; ServiceBehavior, WorkerBehavior; Validator; Cache (facade), CacheAdapter (behaviour), EtsAdapter, RedisAdapter; CircuitBreaker; Queryable, SchemaHelpers; FinancialConfig; Tracing.
- **ledger_bank_api_web/**  
  - Controllers (Auth, Users, Payments, Health, Metrics, Problems, ApiDocs, Webhooks, Fallback, BaseController), Plugs (Authenticate, Authorize, RateLimit, SecurityHeaders, SecurityAudit, Cors, ApiVersion, RequestSizeLimit, Tracing), Validation (InputValidator), Adapters (ErrorAdapter), Channels (UserSocket, PaymentChannel), Resolvers + Schema (Absinthe GraphQL), Logger, Telemetry, Endpoint, Router.

### Domains

- **Accounts**: identity, auth, users, tokens, RBAC.  
- **Financial**: banks, branches, logins, accounts, payments, transactions, Monzo, workers.

### Core vs adapters

- **Core**: Error system, ServiceBehavior, WorkerBehavior, Cache adapter pattern, CircuitBreaker, Validator, FinancialConfig.  
- **Adapters/integrations**: Cache (ETS/Redis), BankApiClient (Monzo), HTTP (Req).  
- **Controllers/Plugs**: REST and GraphQL; auth and authz in plugs; BaseController with shared response/error helpers.  
- **Workers**: PaymentWorker, BankSyncWorker via WorkerBehavior.

### Assessment

- **Reasonable**: Context split (accounts vs financial), behaviour-based services and workers, single error catalog, adapter for cache.  
- **Overengineered for a demo**: Both REST and GraphQL for the same domains; two API version scopes (`/api` and `/api/v1`) duplicating routes; Problem Registry (`/api/problems`) and full RFC 9457 for a portfolio app; OpenTelemetry + Prometheus + custom logger; circuit breaker + retry policies + dead-letter semantics in workers.  
- **Inconsistent**: test.exs sets `:bank_client` to `LedgerBankApi.Banking.BankApiClientMock` but there is no `Banking` context and no such mock defined (dead config). FinancialService is injected via `:financial_service` (used by PaymentWorker); BankApiClient is not uniformly injected. GraphQL resolvers call into same services as REST; no single “API facade” so REST and GraphQL are parallel.  
- **Underengineered in places**: Redis “pool” is a single connection; webhooks are stubs; no real idempotency or idempotency keys for payments; Monzo create_payment uses “feed” not real payment API.

**Verdict**: Architecture is **partly clean and justified**, but **inconsistent** (dead config, duplicate routes, REST+GraphQL overlap) and **overengineered** for what the app does (observability stack, problem registry, circuit breaker that’s misused). Not underengineered in terms of structure; the opposite.

---

## 3. Code Quality

### Strong areas

- **Error catalog and ErrorHandler** (`lib/ledger_bank_api/core/error_catalog.ex`, `error_handler.ex`): Central mapping from reason → category → HTTP and retry; consistent `Error` struct; changeset handling and reason inference; good for consistency and evolution.
- **ServiceBehavior** (`lib/ledger_bank_api/core/service_behavior.ex`): Clear macros for get/create/update/delete and context; reduces repetition in services.
- **WorkerBehavior** (`lib/ledger_bank_api/core/worker_behavior.ex`): Workers implement `perform_work/2` and options; retry/telemetry/logging in one place.
- **BaseController** (`lib/ledger_bank_api_web/controllers/base_controller.ex`): `validate_and_execute`, `handle_success`/`handle_error`, correlation ID, auth macros; keeps controllers thin.
- **Policies**: Accounts and Financial Policy modules are pure functions; easy to test and reason about.
- **Normalize modules**: Separate normalization for accounts and financial; keeps controllers/services cleaner.

### Messy or weak areas

- **Circuit breaker** (`lib/ledger_bank_api/core/circuit_breaker.ex`): **Bug**: On *success* the code calls `:fuse.melt(fuse_name)`. In Fuse, `melt` reports a *failure* and increments the failure count. So every successful call is counted as a failure; after N successes the circuit opens. Correct behaviour: call `melt` only on failure; do nothing (or equivalent) on success. This makes the circuit breaker effectively broken in production.
- **Redis adapter** (`lib/ledger_bank_api/core/cache/redis_adapter.ex`): Documents “Connection pooling” but `start_redix_pool/2` ignores `pool_size` and uses a single `Redix.start_link(url, name: @connection_name)`. No pool; config is misleading. `get_entry_details/1` has an unreachable `else` clause (`{:ok, nil} -> nil`) because a successful `{:ok, nil}` from the first GET is already handled in the main branch. `encode_key("*")` in `clear` and `stats` uses `KEYS`; fine for dev/small scale but not suitable for large production key sets.
- **FinancialService** (`lib/ledger_bank_api/financial/financial_service.ex`): Very long (~1000 lines); mix of ServiceBehavior-style helpers and raw `Repo`/`case`; e.g. `get_bank_branch` uses manual case/get, while `get_bank` uses ServiceBehavior. Inconsistent style and a lot of CRUD that could be generated or simplified.
- **Monzo client** (`lib/ledger_bank_api/financial/integrations/monzo_client.ex`): Only `fetch_accounts` uses the circuit breaker; `fetch_transactions`, `fetch_balance`, `create_payment`, `get_payment_status`, `refresh_token` do not. Inconsistent resilience. Uses `Application.compile_env` for `@api_url` (compile-time only). `create_payment` posts to Monzo “feed” (user feed item), not a real payment API.
- **Application startup** (`lib/ledger_bank_api/application.ex`): Fails fast on JWT and financial config (good). Cache init: on Redis failure, app continues with “caching unavailable”; on ETS failure, app raises. Circuit breaker init failure only logs and continues. That’s acceptable but the circuit breaker logic is still wrong (melt on success).
- **Password hashing**: README and docs repeatedly say “Argon2”; config and code use **PBKDF2** (`config/config.exs` `:password_hashing` algorithm `:pbkdf2`, `lib/ledger_bank_api/accounts/password_service.ex`). mix.lock has `argon2_elixir` but it’s not used. So documentation is **wrong** and overstates security (Argon2 vs PBKDF2).
- **Seeds vs README**: Seeds use `alice@example.com` / `password123!` and `admin@example.com` / `admin123!`. README says `password123` and `adminpassword123456`. Anyone following the README will get login wrong.

### AI/vibe-coded feel

- Repetitive “eliminates boilerplate” and “single source of truth” narrative in moduledocs (ServiceBehavior, WorkerBehavior, ErrorCatalog).  
- Long, very structured moduledocs with tables and bullet lists (ErrorHandler, ErrorCatalog) that look template-like.  
- BaseController has many macros (`crud_operation`, `paginated_list`, `batch_operation`, `with_auth`, `with_auth_and_permission`, `with_auth_and_ownership`, `async_operation`, `confirm_operation`); not all are used consistently, and some could be simple functions.  
- Duplication: router defines the same scope tree twice (`/api` and `/api/v1`) with copy-pasted routes.

### Duplication and unnecessary abstraction

- **Router**: Full duplication of scope and routes under `/api` and `/api/v1` (only path prefix differs).  
- **FinancialService**: Large amount of similar get/list/create/update for banks, branches, accounts, etc.; could be a small generic or codegen layer.  
- **BaseController**: `with_auth`, `with_auth_and_permission`, `with_auth_and_ownership` repeat the same “get token → get user → check” flow; could be one plug or function parameterized by policy.

### Naming and responsibilities

- **LedgerBankApi.Banking** is referenced in test config (`:bank_client` → `LedgerBankApi.Banking.BankApiClientMock`) but the real module is `LedgerBankApi.Financial.Integrations.BankApiClient`. Naming (Banking vs Financial.Integrations) is inconsistent and the mock config is dead.  
- **Policy** in BaseController macros: `Policy.has_role?` and `Policy.is_admin?` are used without a module prefix in the macro quote; they assume a single `Policy` in scope (likely Accounts.Policy). Fragile if another context’s policy is needed.  
- **Worker** “perform” vs “perform_work”: Oban calls `perform(job)`; WorkerBehavior wraps it and calls `perform_work(args, context)`. Clear but the double naming is easy to confuse.

---

## 4. Tests

### Structure

- **test/ledger_bank_api/**  
  - accounts: auth_service, constant_time_auth, user_service, user_service_keyset, user_service_oban, policy, normalize, edge_case, token, schemas (user, refresh_token).  
  - core: cache (ETS), cache/redis_adapter, error_catalog_financial, error, validator.  
  - financial: financial_service, financial_service_validation, normalize, payment_business_rules, policy, workers (payment_worker, bank_sync_worker, priority_execution), integrations (monzo_client).  
  - performance: oban_stress, ecto_performance.  
- **test/ledger_bank_api_web/**  
  - controllers: auth, users, users_keyset, payments, profile, health, metrics, problems, webhooks, security_user_creation, authorization, integration_flow; adapters (error_adapter); plugs (rate_limit, security_headers, security_audit, authenticate, authorize); validation (input_validator, input_validator_financial); resolvers (auth, user, payment, transaction, account).  
- **test/support**: DataCase, ConnCase, ObanCase (if present), fixtures (UsersFixtures, BankingFixtures), mocks (Mox defmock for FinancialServiceMock in test_helper.exs).

### What inspires confidence

- **Constant-time auth test** (`constant_time_auth_test.exs`): Explicitly checks timing and that unknown emails don’t short-circuit; documents threat model.  
- **Policy tests**: Pure functions; no DB; clear cases.  
- **Error catalog tests**: Reason → category → HTTP and retry; regression-safe.  
- **Integration-style controller tests**: Auth, users, payments, profile, authorization; use ConnCase and real (or sandbox) DB.  
- **Mox** for FinancialService in workers: PaymentWorker tests inject FinancialServiceMock via config; behaviour is clear.

### What doesn’t

- **mix.exs test aliases**: `test:auth`, `test:banking`, `test:users` point to **non-existent paths** (`test/ledger_bank_api/auth/`, `banking/`, `users/`). Actual structure is `accounts/`, `financial/`. Running `mix test:auth` fails with “Paths given to mix test did not match any directory/file”. So the advertised test commands in README/aliases are broken.  
- **Test count**: README claims “1000+ tests”. No verification of count; if it’s true, a large share is in a few huge files (e.g. integration_flow_test, user_service_test) with many similar cases.  
- **Circuit breaker**: No test found that verifies “melt only on failure”. So the inverted melt-on-success bug is not caught.  
- **Redis adapter**: Tests exist (redis_adapter_test.exs) but the “pool” is never exercised (because there is no pool).  
- **GraphQL**: Resolver tests exist; coverage of schema and auth context for GraphQL is not audited in depth.

### Behaviour vs implementation

- Many tests are **behaviour-focused** (e.g. “login returns token”, “insufficient funds returns 422”).  
- Some are **implementation-coupled**: e.g. checking exact error struct fields or internal representation; worker tests that depend on WorkerBehavior’s retry/error handling.  
- **Fixtures**: UsersFixtures, BankingFixtures; some tests build data inline. Naming sometimes “user_fixture” vs “admin_user_fixture”; generally fine.

### Missing or weak

- No test that **circuit breaker opens after N failures** and **does not open after N successes** (would have caught the melt bug).  
- No test that **README seed credentials** work (would have caught password mismatch).  
- **:bank_client** config points to a non-existent module; if any test or code path used it, it would fail; currently dead so no failure.  
- **Monzo client**: Tests may mock HTTP; no test that only `fetch_accounts` is wrapped with circuit breaker (consistency).

**Summary**: Tests are **substantial and mostly behaviour-oriented**, with good policy and error-catalog coverage and sensible use of Mox. But **test aliases are broken**, **circuit breaker logic is untested**, and **README/seed credential mismatch is untested**, which reduces confidence for a new contributor or reviewer.

---

## 5. Docs and Portfolio Quality

### README and docs

- **README**: Very long; diagrams (ASCII), feature lists, API examples, schema, error matrix, deployment, K8s YAML. Presents the project as “enterprise-grade” and “production-grade” while also saying “not for production”.  
- **Tone**: “Error Excellence”, “Security First”, “Production Patterns”, “Clean Architecture” — marketing-style.  
- **Accuracy**: Wrong on password hashing (Argon2 vs PBKDF2); wrong default credentials (password123 vs password123!; adminpassword123456 vs admin123!); test aliases referenced in README (e.g. test:auth) don’t work.  
- **Bloat**: Multiple long docs (ARCHITECTURE, TESTING_GUIDE, DEPLOYMENT_GUIDE, MULTI_NODE, OPENTELEMETRY, STRESS_TESTING, JWT tradeoffs). For a demo, that’s a lot; some is useful, some is “we have everything.”

### Would it impress?

- **Junior backend recruiters**: Likely yes — tech stack, badges, “enterprise” wording, many features and docs.  
- **Strong Elixir engineers**: Mixed. Positive: behaviours, error catalog, Ecto, Oban, structure. Negative: circuit breaker bug, README vs implementation (Argon2, credentials), dead config, duplicated routes, REST+GraphQL overlap without clear need, overuse of macros.  
- **Senior backend engineers**: Likely skeptical.他们会 spot the circuit breaker bug, the “Argon2” lie, the Redis “pool” that isn’t, and the gap between “production-grade” claims and a demo that doesn’t need half of the machinery. The good parts (error system, ServiceBehavior, WorkerBehavior) are real but buried in buzzwords and inaccuracies.

**Verdict**: Docs make the project **look impressive and clear** but are **misleading** (Argon2, credentials, test commands) and **too enterprise-themed** for a non-production demo. It would impress juniors and some mid-levels; it would make strong engineers **roll their eyes** at the inaccuracies and overclaim.

---

## 6. Practical Engineering Quality

- **Error handling**: Strong. Canonical Error, catalog, adapter to HTTP, retry/category policy.  
- **Config**: Layered; runtime.exs for env; some duplication (e.g. Oban in config.exs and runtime.exs).  
- **Environments**: dev/test/prod and runtime.exs; test disables rate limit, circuit breaker, telemetry, security audit for speed.  
- **API design**: REST consistent (JSON, status codes, problem details). Versioning is duplicated routes rather than real versioning.  
- **Auth/security**: JWT + refresh, constant-time attempt, RBAC, security headers, rate limit, audit plug. Password hashing is PBKDF2; README says Argon2.  
- **Dependencies**: Sensible (Phoenix, Ecto, Oban, Joken, Req, etc.). Both phoenix_swagger and open_api_spex; two ways to do OpenAPI. Absinthe for GraphQL.  
- **Docker**: Dockerfile and compose are fine; entrypoint runs migrations then start. Compose doesn’t set CACHE_ADAPTER or REDIS for web; default is ETS.  
- **CI**: Format, compile --warnings-as-errors, tests with Postgres and Redis, Docker build and health check. Solid.  
- **Observability**: Telemetry, Prometheus, OpenTelemetry, correlation IDs, structured logging. More than needed for a demo but consistent.  
- **Maintainability**: High for error and service/worker patterns; lower for duplicated routes, long FinancialService, and wrong docs.  
- **Simplicity vs complexity**: **Too complex** for “simulate banking, one integration, no real money”: two API styles, two version scopes, problem registry, circuit breaker (and broken), Redis “pool” that isn’t, many macros.  
- **Redis**: Justified only if you actually run multi-node or need shared cache; for single-node demo, ETS is enough. Redis adapter is **not** justified as a “pool” — it’s a single connection and doc says “connection pooling.”  
- **Monzo**: One client, behaviour-based; good. But circuit breaker only on fetch_accounts, and create_payment is feed, not real payments; design is okay, implementation and resilience are inconsistent.  
- **Pleasant to maintain**: For someone who knows the codebase, yes in the core and services. For a new hire, no — too many layers, wrong docs, and a few critical bugs (circuit breaker, credentials).

---

## 7. Blunt Scorecard (1–10)

| Criterion | Score | Explanation |
|-----------|-------|-------------|
| **Architecture** | 6 | Clear domains and behaviours; duplicated routes, dead config, REST+GraphQL overlap and overkill for scope. |
| **Code quality** | 5 | Good error and service/worker patterns; circuit breaker wrong, Redis “pool” fake, FinancialService huge and inconsistent, docs (Argon2, credentials) wrong. |
| **Maintainability** | 5 | Good patterns and structure; long files, duplicated routes, misleading docs and config make changes riskier. |
| **Test quality** | 6 | Many behaviour-focused tests, good use of Mox and policies; broken test aliases, no circuit breaker correctness test, no seed/README credential check. |
| **Realism/practicality** | 4 | Demo-only; many “production” features (circuit breaker, problem registry, dual API) but one is broken and several are unnecessary for the scope. |
| **Portfolio value** | 7 | Looks strong on paper and in README; good for showing knowledge of patterns; inaccuracies and bugs hurt if probed in an interview. |
| **Production readiness** | 3 | Circuit breaker wrong; Redis not pooled; credentials/docs wrong; webhooks stubs; no real idempotency; “not for production” is correct. |
| **Simplicity** | 4 | Far more mechanisms than needed for the actual feature set. |
| **Correctness confidence** | 4 | Core flows (auth, payments, workers) are test-covered; circuit breaker and docs/credentials reduce confidence. |

---

## 8. Brutal Truth

### What is genuinely good

- **Error catalog and Error struct**: Single place for reason → category → HTTP and retry; consistent and extensible.  
- **ServiceBehavior and WorkerBehavior**: Real reduction of boilerplate; clear contract (e.g. `perform_work/2`).  
- **Policies and Normalize**: Pure, testable, clear separation.  
- **BaseController** and **ErrorAdapter**: Thin HTTP layer and consistent error responses.  
- **Test coverage** of auth, users, payments, policies, and error catalog.  
- **CI**: Format, compile, tests, Docker, health check.  
- **Constant-time login** attempt and RBAC design.

### What is fake sophistication / overengineering

- **Circuit breaker** that melts on success: looks “resilient” but is backwards.  
- **Redis “connection pooling”** in docs and config with a single connection.  
- **Problem Type Registry** (`/api/problems`) and full RFC 9457 for a demo.  
- **Two API styles** (REST + GraphQL) and **two version scopes** with the same routes.  
- **OpenTelemetry + Prometheus + custom logger** for a portfolio app.  
- **“Argon2”** in README while using PBKDF2.  
- **“Enterprise-grade”** and **“production-grade”** wording for an explicit non-production demo.

### What would impress people

- Stack (Elixir, Phoenix, Oban, JWT, “clean architecture”).  
- Length and polish of README and docs.  
- Long test list and “1000+ tests”.  
- Presence of circuit breaker, cache adapter, error catalog, GraphQL.

### What would make strong engineers roll their eyes

- **Circuit breaker that opens on success.**  
- **README saying Argon2 and giving wrong passwords.**  
- **“Connection pooling” with one connection.**  
- **Copy-pasted router scope** for “versioning”.  
- **Config for a non-existent module** (`Banking.BankApiClientMock`).  
- **Enterprise buzzwords** for a demo.

### If presenting as a portfolio piece, what to say carefully

- **Do not** claim “production-ready” or “enterprise-grade” without fixing the circuit breaker and doc/config inaccuracies.  
- **Do** say: “Demo API showing patterns I care about: error catalog, service/worker behaviours, auth, payments, one bank integration.”  
- **Be ready** to explain: why both REST and GraphQL; why problem registry; and to fix or remove the circuit breaker and to correct README (Argon2 vs PBKDF2, credentials).  
- **Avoid** saying “comprehensive test suite” without fixing `mix test:auth` (and similar) so the advertised commands work.

### If rewriting, what to simplify first

1. **Fix or remove the circuit breaker** (or use it correctly: melt only on failure).  
2. **Drop one of REST or GraphQL** (or clearly justify both) and **one of `/api` or `/api/v1`** (single set of routes).  
3. **Make README and seeds match** (passwords, and either document PBKDF2 or switch to Argon2).  
4. **Fix test aliases** in mix.exs to real paths (e.g. `accounts/`, `financial/`) or remove them.  
5. **Redis adapter**: Either implement a real pool (e.g. Redix pool) or remove “connection pooling” from docs and config.  
6. **Remove or fix** `:bank_client` (use Financial.Integrations and a proper mock or drop the key).  
7. **Shorten FinancialService** (extract modules or generic CRUD) and **trim BaseController** macros to what’s actually used.  
8. **Reduce docs** to GETTING_STARTED, API_REFERENCE, and one ARCHITECTURE doc; move the rest to a “advanced” or “ops” section or drop.

---

## 9. Final Verdict

- **Is this a good portfolio project?**  
  **Yes, with caveats.** It shows knowledge of Elixir/Phoenix, behaviours, error handling, and structure. It becomes a **bad** portfolio piece if you present it as production-ready or don’t fix the circuit breaker and README/credentials; then it signals carelessness.

- **Is it well engineered?**  
  **Partly.** The core ideas (error catalog, ServiceBehavior, WorkerBehavior, policies, normalization) are well executed. The implementation has **critical bugs** (circuit breaker), **misleading docs** (Argon2, credentials), and **unnecessary complexity** (dual API, duplicated routes, fake pool). So: good design in places, inconsistent and overclaimed in others.

- **Is it trying to do too much?**  
  **Yes.** For “simulate banking with one integration and no real money,” it has two API styles, two version scopes, problem registry, circuit breaker, cache adapter, OpenTelemetry, Prometheus, and many macros. A simpler version (REST only, one scope, ETS only, no circuit breaker or a correct one) would be easier to maintain and defend.

- **Does it look like someone who understands backend engineering, or someone stacking buzzwords?**  
  **Both.** The person clearly understands behaviours, error taxonomy, and OTP. But the circuit breaker bug, the Argon2 claim, the fake pool, and the enterprise wording without production use suggest **stacking features and buzzwords** without always verifying them. Strong engineers will see both the good and the gaps.

- **Top 5 changes that would improve it most**

1. **Fix the circuit breaker**: Call `:fuse.melt` only on failure; add a test that success does not open the circuit.  
2. **Align README and seeds**: Fix default passwords (password123! / admin123!) and either change README to PBKDF2 or switch implementation to Argon2.  
3. **Fix or remove mix test aliases**: Point to real paths (`accounts/`, `financial/`, etc.) or delete the aliases and update README.  
4. **Single route set**: Keep one of `/api` or `/api/v1` and delete the duplicated scope.  
5. **Redis adapter**: Either implement a real connection pool or remove “connection pooling” from docs/config and document “single connection.”

---

*End of audit.*

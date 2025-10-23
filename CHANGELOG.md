# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Major Architectural Improvements (January 2025)

##### Security & Authentication Hardening
- **JWT Verification Bypass Fix** - Resolved critical security vulnerability in token validation
  - Fixed Joken claim validation to properly enforce required claims
  - Enhanced token verification with strict claim checking
  - Added comprehensive test coverage for security scenarios
  - Prevents unauthorized access through token manipulation

- **JWT Configuration Unification** - Standardized JWT settings across environments
  - Unified issuer and audience to `"ledger-bank-api"` across all environments
  - Standardized token expiry configuration (15min access, 7-day refresh)
  - Removed hardcoded values in favor of configuration-driven approach
  - Added JWT secret length validation (minimum 64 characters)

- **Password Hashing Decoupling** - Removed Mix.env() dependencies
  - Created `LedgerBankApi.Accounts.PasswordService` for configuration-driven hashing
  - Decoupled password hashing from development environment detection
  - Added support for multiple hashing algorithms (Pbkdf2, Argon2)
  - Environment-specific hashing configuration for optimal performance

##### Infrastructure & CI/CD Improvements
- **Oban Configuration Consolidation** - Unified queue management
  - Consolidated Oban configuration across base, environment, and runtime configs
  - Documented configuration precedence (Base → Environment → Runtime)
  - Added comprehensive queue configuration examples
  - Environment-specific queue concurrency settings

- **CI Database Readiness** - Hardened Postgres health checks
  - Enhanced CI workflow with proper database readiness checks
  - Added `docker compose exec -T db pg_isready` for reliable health verification
  - Implemented timeout and retry logic for database startup
  - Added comprehensive error handling for CI failures

- **OpenTelemetry Optimization** - Disabled unnecessary instrumentation overhead
  - Commented out OpenTelemetry span processor when instrumentation packages not present
  - Added comprehensive resource attributes for service identification
  - Environment-driven OpenTelemetry configuration
  - Created `docs/OPENTELEMETRY_CONFIGURATION.md` for deployment guidance

- **CI Quality Gates** - Enhanced code quality enforcement
  - Added `mix format --check-formatted` to CI pipeline
  - Added `mix compile --warnings-as-errors` for strict compilation
  - Added `mix test --warnings-as-errors` for comprehensive testing
  - Created `.formatter.exs` for consistent code formatting

##### Performance & Scalability Enhancements
- **Database Index Audit** - Added 20+ optimized indexes
  - Created comprehensive index migration for pagination and query optimization
  - Added indexes for users, payments, transactions, bank accounts, and Oban jobs
  - Optimized for common query patterns (filtering, sorting, pagination)
  - Enhanced performance for large datasets

- **Policy Combinators** - Complex authorization logic
  - Added `Policy.all/1`, `Policy.any/1`, `Policy.negate/1` for policy composition
  - Added role-based helpers: `has_role?/2`, `is_admin?/1`, `is_support?/1`
  - Added action-based helpers: `is_self_action?/2`, `is_other_user_action?/2`
  - Added field-based helpers: `has_only_allowed_fields?/2`, `has_restricted_fields?/2`
  - Added sensitive operation helper: `can_perform_sensitive_operation?/3`
  - Comprehensive test coverage for all policy combinators

- **Controller Helper Macros** - Standardized controller patterns
  - Added `crud_operation/7` for standard CRUD operations
  - Added `paginated_list/7` for paginated list operations with filtering
  - Added `batch_operation/7` for batch operations with progress tracking
  - Added `with_auth/2`, `with_auth_and_permission/3`, `with_auth_and_ownership/3`
  - Added `async_operation/7` for async operations returning job IDs
  - Added `confirm_operation/5` for operations requiring confirmation

- **Queryable Extensions** - Advanced query capabilities
  - Added `apply_text_search/3` for multi-field text search
  - Added `apply_date_range/3` for date range filtering
  - Added `apply_keyset_pagination/2` for cursor-based pagination
  - Added `apply_advanced_filters/2` for complex filtering with multiple operators
  - Added `apply_multi_sort/2` for multi-field sorting
  - Added `apply_custom_filter/3` for field-specific filtering
  - Added `apply_aggregation/3` for aggregation queries (count, sum, etc.)

- **Cache Standardization** - TTL helpers and get_or_put variants
  - Added standardized TTL helpers: `put_short/2`, `put_medium/2`, `put_long/2`, `put_very_long/2`
  - Added `get_or_put` variants for all TTL helpers
  - Added `put_with_ttl/3`, `get_or_put_with_ttl/3` for custom TTLs
  - Added `put_by_type/3`, `get_or_put_by_type/3` for data-type specific TTLs
  - Added `put_by_freshness/3`, `get_or_put_by_freshness/3` for freshness-level TTLs

##### Worker & Background Job Improvements
- **WorkerBehavior Enhancement** - Custom retry logic and telemetry
  - Added `should_retry_with_custom_logic?/2` for custom retry decisions
  - Added `custom_telemetry_metadata/2` for enhanced telemetry
  - Added `pre_work_validation/2` for pre-work validation and setup
  - Added `post_work_cleanup/3` for post-work cleanup and finalization
  - Enhanced telemetry with throughput, memory usage, and custom metadata
  - Dynamic callback invocation using `function_exported?/3` and `apply/3`

- **OpenTelemetry Resource Alignment** - Environment-driven attributes
  - Added comprehensive resource attributes for service identification
  - Added deployment information (version, environment, region)
  - Added Kubernetes attributes (pod, namespace, node)
  - Added cloud infrastructure attributes (provider, instance type)
  - Added application and runtime information
  - Added telemetry SDK information

- **Redis Adapter Consistency** - Cleaned up stale references
  - Removed non-existent Redis adapter references from documentation
  - Updated cache documentation to use generic "distributed adapter" terminology
  - Prepared codebase for future Redis integration
  - Maintained ETS adapter as primary caching solution

##### Documentation & Developer Experience
- **JWT Token Tradeoffs Documentation** - Comprehensive security analysis
  - Created `docs/JWT_TOKEN_TRADEOFFS.md` with detailed security analysis
  - Documented short TTL rationale for financial applications
  - Analyzed claim structure tradeoffs (minimal vs. comprehensive)
  - Documented refresh token strategy and security considerations
  - Provided performance analysis and monitoring recommendations
  - Included alternative architecture comparisons

- **Configuration Precedence Documentation** - Clear setup guidance
  - Enhanced `docs/DEPLOYMENT_GUIDE.md` with Oban configuration section
  - Added JWT configuration section with security considerations
  - Documented configuration precedence for all major components
  - Added troubleshooting guides for common configuration issues

- **Problem Registry Audit** - Verified RFC 9457 compliance
  - Cross-checked Problem Registry implementation against documentation
  - Verified all endpoints work as documented
  - Confirmed RFC 9457 Problem Details compliance
  - Validated error discovery functionality

- **Documentation Clarity** - Marked pseudo-code examples
  - Added `> **📝 Example Usage**` callouts to code blocks in documentation
  - Added `> **📝 Example Configuration Structure**` callouts
  - Added `> **📝 Example Runtime Configuration**` callouts
  - Prevented copy-paste confusion with pseudo-code examples

##### README & Changelog Updates
- **README.md Enhancement** - Reflected all recent improvements
  - Added "Recent Architectural Improvements" section highlighting January 2025 enhancements
  - Updated tech stack to reflect new capabilities
  - Enhanced feature descriptions with new functionality
  - Maintained comprehensive project overview

### Changed
- **JWT Token Generation** - Made claims configuration-driven
  - Removed hardcoded issuer, audience, and expiry values
  - Added configuration validation for required JWT settings
  - Enhanced error handling for missing configuration
  - Improved security through configurable token settings

- **Password Hashing** - Environment-specific configuration
  - Replaced `Mix.env()` conditional logic with configuration-driven approach
  - Added support for different hashing algorithms per environment
  - Enhanced test performance with simplified hashing in test environment
  - Improved production security with configurable hashing parameters

- **CI Workflow** - Enhanced with health dependencies
  - Updated Docker Compose health check dependencies
  - Added proper service startup ordering
  - Enhanced error handling and timeout management
  - Improved CI reliability and debugging

### Fixed
- **JWT Verification** - Resolved critical security bypass
  - Fixed Joken claim validation to properly enforce required claims
  - Enhanced token verification with strict validation
  - Added comprehensive test coverage for security scenarios
  - Prevented unauthorized access through token manipulation

- **Configuration Issues** - Resolved compilation errors
  - Fixed OpenTelemetry configuration compilation issues
  - Resolved function definition errors in config files
  - Enhanced error handling for missing configuration
  - Improved configuration validation

- **Documentation Issues** - Clarified pseudo-code examples
  - Marked all pseudo-code examples to prevent copy-paste confusion
  - Enhanced documentation clarity and usability
  - Improved developer experience with clear examples

### Performance
- **Database Optimization** - Added 20+ performance indexes
  - Enhanced query performance for pagination and filtering
  - Optimized common query patterns across all tables
  - Improved performance for large datasets
  - Reduced query execution time for complex operations

- **Cache Optimization** - Standardized TTL strategies
  - Consistent caching strategies across different data types
  - Optimized cache hit rates with appropriate TTLs
  - Enhanced cache performance monitoring
  - Improved overall application performance

### Security
- **JWT Security** - Enhanced token security
  - Fixed critical JWT verification bypass vulnerability
  - Standardized JWT configuration across environments
  - Enhanced token validation with strict claim checking
  - Improved security through configuration-driven approach

- **Password Security** - Enhanced hashing security
  - Decoupled password hashing from development environment
  - Added support for multiple hashing algorithms
  - Enhanced security through configurable hashing parameters
  - Improved test performance with simplified hashing

### Removed
- **Stale References** - Cleaned up documentation
  - Removed non-existent Redis adapter references
  - Updated cache documentation to use generic terminology
  - Cleaned up outdated configuration examples
  - Improved documentation accuracy

### In Progress
- **Future Enhancements** - Planning next improvements
  - Redis cache adapter implementation
  - Advanced monitoring and observability
  - Performance optimization
  - Additional security enhancements

---

### Added

#### RFC 9457 Problem Details Implementation (2025-10-14)
- **RFC 9457 Compliance** - Standardized error responses with `application/problem+json`
  - Added `type`, `title`, `status`, `detail`, and `instance` fields to all error responses
  - Implemented proper content-type headers for problem details
  - Added `Retry-After` headers for retryable errors
  - Sanitized sensitive data in problem detail responses

- **Problem Type Registry** - New `/api/problems` endpoint for error discovery
  - `GET /api/problems` - List all available problem types with categories
  - `GET /api/problems/:reason` - Get detailed information for specific error types
  - `GET /api/problems/category/:category` - List errors by category
  - Provides descriptions, examples, retry policies, and HTTP status codes
  - Enables client-side error handling and user-friendly error messages

- **Enhanced Error Handling** - Improved error system with RFC 9457 compliance
  - Added new error reasons: `:invalid_reason_format`, `:invalid_category`, `:invalid_category_format`
  - Enhanced `ErrorAdapter` with `to_problem_details/2` function
  - Added `sanitize_context_for_problem/1` for secure error responses
  - Maintained backward compatibility with existing error handling

#### Architecture Improvements (2025-10-14)
- **SchemaHelpers Module** - Reusable changeset validation functions
  - Added 16 common validation functions for Ecto schemas
  - `validate_amount_positive/2` - Validates Decimal amounts > 0
  - `validate_not_future/2` - Validates DateTime fields not in future
  - `validate_currency_field/2` - Validates 3-letter currency codes (USD, GBP, EUR)
  - `validate_direction_field/2` - Validates CREDIT/DEBIT enum
  - `validate_country_code/2` - Validates 2-3 letter country codes
  - `validate_iban_format/2` - Validates IBAN format
  - `validate_swift_format/2` - Validates SWIFT code format
  - `validate_routing_number_format/2` - Validates 9-digit routing numbers
  - `validate_last_four_format/2` - Validates 4-digit last four
  - `validate_url_format/2` - Validates HTTP/HTTPS URLs
  - `validate_decimal_format/2` - Validates Decimal type
  - `validate_external_account_id_format/2` - Validates alphanumeric IDs
  - `validate_username_format/2` - Validates username format (3-50 chars)
  - `validate_description_length/2` - Validates descriptions (1-255 chars)
  - `validate_account_name_length/2` - Validates account names (1-100 chars)
  - `validate_name_length/2` - Validates names (2-100 chars)
  - `validate_balance_limits/1` - Account-type aware balance validation
  - Eliminates ~220 lines of duplicated validation code
  - Provides consistent error messages across all schemas

- **WorkerBehavior Module** - Standardized Oban worker infrastructure
  - Created behaviour for consistent worker patterns
  - Automatic timing and correlation ID generation
  - Structured logging (start, success, failure)
  - Telemetry emission with standard events
  - Retry logic based on Error.should_retry?/1 policy
  - Dead letter queue telemetry for non-retryable errors
  - Customizable context extraction from job args
  - Eliminates ~280 lines of boilerplate across workers

- **CacheAdapter Behaviour** - Pluggable cache backend support
  - Created CacheAdapter behaviour with 8 callbacks
  - Implemented EtsAdapter (preserves existing ETS behavior)
  - Configuration-driven adapter selection
  - Ready for Redis/Memcached without code changes
  - Callbacks: init/0, get/1, put/3, get_or_put/3, delete/1, clear/0, stats/0, cleanup/0
  - Future-proofs for horizontal scaling

- **Queryable Behaviour** - Standardized query building (optional)
  - Created behaviour for consistent filtering/sorting/pagination
  - Explicit field whitelisting for security
  - Type-aware filtering (:string, :boolean, :integer, :date_range)
  - Example implementation: UserQueries module
  - Non-breaking (existing query code still works)

- **Documentation**
  - Added `docs/ARCHITECTURE_IMPROVEMENTS.md` - Full analysis and rationale (613 lines)
  - Added `docs/QUICK_REFERENCE_PATTERNS.md` - Developer quick reference (345 lines)
  - Enhanced inline documentation for all new modules

### Changed
- **Schema Refactoring** - Migrated 6 schemas to use SchemaHelpers
  - `UserPayment` - Now uses SchemaHelpers (-30 lines)
  - `Transaction` - Now uses SchemaHelpers (-30 lines)
  - `UserBankAccount` - Now uses SchemaHelpers (-60 lines)
  - `Bank` - Now uses SchemaHelpers (-40 lines)
  - `BankBranch` - Now uses SchemaHelpers (-50 lines)
  - `UserBankLogin` - Now uses SchemaHelpers (-12 lines)
  - All schemas now use `use LedgerBankApi.Core.SchemaHelpers` instead of separate `use Ecto.Schema` + imports

- **Worker Refactoring** - Migrated 2 workers to use WorkerBehavior
  - `PaymentWorker` - Now uses WorkerBehavior (-180 lines boilerplate)
  - `BankSyncWorker` - Now uses WorkerBehavior (-100 lines boilerplate)
  - Workers now implement 3 callbacks: worker_name/0, timeout/1, perform_work/2
  - Infrastructure code (logging, telemetry, retry) automatically handled
  - Telemetry events maintained: `[:ledger_bank_api, :worker, :payment | :bank_sync, :success | :failure]`

- **Cache Refactoring** - Migrated to adapter pattern
  - `Cache` module now delegates to CacheAdapter
  - ETS implementation extracted to `Cache.EtsAdapter`
  - Configuration added: `:cache_adapter` setting
  - Zero breaking changes to cache API
  - Application initialization updated to use adapter.init()

### Fixed
- Fixed conflicting `timeout/1` callback between Oban.Worker and WorkerBehavior
- Fixed worker name consistency for telemetry events (PaymentWorker, BankSyncWorker)
- Fixed `extract_context_from_args/1` visibility (now properly public callback)

### Performance
- Reduced codebase by ~500 lines of duplicated logic
- Added ~600 lines of reusable infrastructure
- Net change: +100 lines (8% reduction in duplication)
- Improved maintainability through single source of truth
- Faster development of new features (less boilerplate)

### Removed
- Deleted `DASHBOARD_GUIDE.md` (documentation consolidation)
- Removed duplicated validation functions from individual schemas
- Removed duplicated worker infrastructure code

### In Progress
- Planning for Redis cache adapter implementation
- Considering Queryable adoption for additional services
- Evaluating GraphQL API endpoint

---

## [Unreleased] - Previous

### Added
- **Comprehensive Test Suite Expansion** - Added extensive unit and integration tests
  - Added schema-level tests for User and RefreshToken models (2,027 lines)
  - Added Token service tests covering JWT generation, verification, and rotation (639 lines)
  - Added Core.Error module tests for error handling and categorization (786 lines)
  - Added Core.Validator tests for input validation and security (650 lines)
  - Added ErrorAdapter tests for HTTP error responses and sanitization (708 lines)
  - Added Authentication plug tests for JWT validation and security (479 lines)
  - Added Authorization plug tests for RBAC and self-access patterns (574 lines)
  - Added SecurityAudit plug tests for suspicious activity detection (593 lines)
  - Total new test coverage: **6,456 lines** across 8 new test files
  - All 1,448 tests passing successfully ✅

---

## [1.0.0] - 2025-10-10

### Added

#### Authentication & Authorization
- JWT-based authentication with access and refresh tokens
- Token rotation for enhanced security (15-minute access, 7-day refresh)
- Role-based access control (User, Admin, Support)
- Constant-time authentication to prevent timing attacks
- Secure password hashing with Argon2
- Role-based password complexity (8 chars for users, 15 for admins)
- Token revocation and blacklisting support

#### User Management
- User CRUD operations with comprehensive validation
- User profile management endpoints
- User statistics and metrics
- Keyset pagination for better performance on large datasets
- Traditional offset pagination with filtering and sorting
- Admin-only user creation with role selection
- Public user registration (role forced to "user")

#### Financial Operations
- Multi-bank integration via OAuth2
- Bank account management with balance tracking
- Transaction history with advanced filtering
- Payment processing with business rule validation
- Payment validation endpoint (dry run)
- Payment statistics and financial health metrics
- Multi-currency support (USD, EUR, GBP, etc.)
- Support for multiple account types (CHECKING, SAVINGS, CREDIT, INVESTMENT)

#### Background Processing
- Oban integration for reliable job processing
- PaymentWorker with priority queue support
- BankSyncWorker with rate limiting
- Intelligent retry strategies based on error categories
- Dead letter queue handling for non-retryable errors
- Job monitoring and cancellation support
- Telemetry for job performance tracking

#### Error Handling System
- Canonical error structs across all layers
- Error categorization (8 categories)
- Error catalog with 40+ defined error reasons
- Automatic retry logic for transient failures
- Circuit breaker pattern for external services
- Error telemetry with correlation IDs
- Comprehensive error documentation

#### Data Management
- PostgreSQL database with comprehensive migrations
- 9 core tables with proper relationships
- Database constraints and check validations
- Foreign key cascades for data integrity
- Indexes for optimal query performance
- ETS-based caching with TTL support
- Cache statistics and monitoring

#### Security Features
- Security headers (CSP, HSTS, X-Frame-Options, etc.)
- Rate limiting with configurable windows
- Security audit logging for suspicious activities
- Input validation across multiple layers
- SQL injection prevention
- XSS protection
- CSRF protection for session-based auth
- Sensitive data sanitization in logs

#### API Documentation
- OpenAPI/Swagger specification
- Interactive Swagger UI
- Comprehensive endpoint documentation
- Request/response examples
- Error response documentation

#### DevOps & Tooling
- Docker and Docker Compose support
- GitHub Actions CI/CD pipeline
- Health check endpoints (basic, detailed, liveness, readiness)
- Phoenix LiveDashboard for real-time monitoring
- Structured JSON logging with correlation IDs
- Telemetry metrics for performance monitoring
- Production release configuration
- Kubernetes deployment examples

#### Testing
- Comprehensive test suite (12,000+ lines)
- Unit tests for business logic
- Integration tests for controllers
- Security tests (constant-time auth, RBAC)
- Worker tests with Oban integration
- Test fixtures and helpers
- Mock support for external services
- 95%+ test coverage

### Security
- Implemented constant-time authentication to prevent email enumeration
- Added role-based password complexity requirements (NIST 2024 standards)
- Implemented token rotation for refresh tokens
- Added security audit logging for suspicious activities
- Implemented rate limiting to prevent abuse
- Added comprehensive input validation to prevent injection attacks
- Sanitized sensitive data in logs and error responses

### Documentation
- Comprehensive README with architecture diagrams
- API documentation with request/response examples
- Database schema documentation with ERD
- Error handling system documentation
- Security features documentation
- Deployment guide (Docker, Kubernetes)
- Development setup guide
- Contributing guidelines

---

## Version History

### Versioning Scheme

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
  - **MAJOR**: Incompatible API changes
  - **MINOR**: Add functionality (backwards-compatible)
  - **PATCH**: Bug fixes (backwards-compatible)

---

## Categories

Changes are grouped into the following categories:

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future versions
- **Removed**: Features that have been removed
- **Fixed**: Bug fixes
- **Security**: Security-related changes

---

## Future Plans

### Upcoming Features (Roadmap)
- [ ] Two-factor authentication (2FA)
- [ ] Account statements generation (PDF)
- [ ] Email notifications for transactions
- [ ] SMS notifications via Twilio
- [ ] Recurring payments support
- [ ] Payment scheduling
- [ ] Account freeze/unfreeze functionality
- [ ] Transaction dispute management
- [ ] Multi-currency conversion
- [ ] Budget tracking and alerts
- [ ] Savings goals
- [ ] Investment portfolio tracking
- [ ] GraphQL API endpoint
- [ ] WebSocket support for real-time updates
- [ ] Mobile app API endpoints
- [ ] Advanced analytics and reporting

### Performance Improvements
- [ ] Redis integration for distributed caching
- [ ] Query optimization with explain analyze
- [ ] Connection pooling optimization
- [ ] Response compression (gzip)
- [ ] CDN integration for static assets

### Infrastructure
- [ ] Horizontal scaling support
- [ ] Database read replicas
- [ ] Automated backup system
- [ ] Disaster recovery procedures
- [ ] Blue-green deployment strategy

---

## Links

- **Repository**: https://github.com/rafaelRojasVi/ledger-bank-api
- **Issues**: https://github.com/rafaelRojasVi/ledger-bank-api/issues
- **Documentation**: See README.md


# LedgerBank API

<div align="center">

**A Learning Portfolio Project Demonstrating Enterprise Elixir/Phoenix Patterns**

[![Elixir](https://img.shields.io/badge/Elixir-1.18+-purple?style=flat&logo=elixir)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.7+-orange?style=flat&logo=phoenix-framework)](https://phoenixframework.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-blue?style=flat&logo=postgresql)](https://www.postgresql.org/)
[![CI](https://img.shields.io/badge/CI-passing-brightgreen?style=flat&logo=github-actions)](https://github.com/rafaelRojasVi/ledger-bank-api/actions)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[What I Learned](#-what-i-learned) •
[Quick Demo](#-quick-demo) •
[Architecture](#️-architecture) •
[Quick Start](#-quick-start) •
[API Documentation](#-api-documentation)

</div>

---

## 💡 What I Learned

This project started as "build a simple banking API" and evolved into a deep dive on **professional Elixir architecture**. Here's what makes this portfolio piece unique:

### **Key Achievements**

| **Pattern** | **What I Built** | **Why It Matters** |
|------------|-----------------|-------------------|
| 🏗️ **Behaviors for DRY Code** | `WorkerBehavior`, `ServiceBehavior`, `CacheAdapter`, `Queryable` | Eliminated **280+ lines** of boilerplate across workers. Shows I understand abstraction vs premature optimization. |
| 🎯 **Error Catalog System** | 40+ error reasons → 8 categories → HTTP codes + retry policies | Most APIs have inconsistent errors. Mine has a **single source of truth** that drives retry logic, telemetry, and responses. |
| 🔒 **Security by Design** | Constant-time auth, JWT rotation, RBAC with policies, audit logging | Banking-grade security: **timing attack prevention**, token revocation, role-based permissions. |
| 🧪 **Test Quality** | 3,796-line integration test, edge cases (null bytes, timing), performance tests | I test like companies should: integration flows, security vulnerabilities, and performance regression. |
| 🔄 **Background Jobs Done Right** | Oban + error-aware retry, priority queues, dead letter queue | Workers **know which errors to retry** (external API failures) vs fail fast (business rules). |
| 📊 **Data Access Patterns** | Keyset pagination, query behaviors, ETS caching | Shows I care about **performance at scale** beyond CRUD. |

### **Architecture Wins**

I learned **when to abstract** and **when not to**:

✅ **Abstracted** because 4+ schemas needed it:
- `SchemaHelpers` → 220 lines of validation duplication removed
- `Queryable` → Consistent filtering/sorting across all resources
- `WorkerBehavior` → Standard telemetry/logging for all workers
- `CacheAdapter` → Switch ETS → Redis with zero code changes

❌ **Didn't abstract** because it would hurt clarity:
- Controllers - Each has unique validation/authorization
- Policies - Domain-specific rules don't generalize well
- Migrations - Database changes need explicit audit trail

**Lesson:** Abstraction is a trade-off. I chose **clarity first**, then DRY where duplication was painful (4+ instances).

---

## 🎤 Interview Talking Points

When asked about this project, I highlight:

> **"I built a banking API to learn production Elixir patterns. The interesting parts:"**
>
> 1. **Error Catalog System** - Instead of scattered `{:error, "some string"}` everywhere, I built an error taxonomy with 8 categories that drives HTTP codes, retry policies, and telemetry. This meant one change to add circuit breaking for all external API calls.
>
> 2. **Behaviors for Scale** - When I noticed 180 lines of identical code in two Oban workers, I created `WorkerBehavior`. Now adding a new worker is 30 lines vs 200, and all workers get telemetry for free.
>
> 3. **Security Depth** - I implemented constant-time authentication after reading about timing attacks. It's a 10-line change that prevents email enumeration via response time analysis.
>
> 4. **Testing Strategy** - My integration test is 3,796 lines that validates entire user flows: register → login → create payment → process payment. I also test edge cases like null byte injection and concurrent balance updates.

---

## 🌐 Live Demo

**Interactive API Documentation:** [https://your-app.onrender.com/api/docs](https://your-app.onrender.com/api/docs)

**Health Check:** [https://your-app.onrender.com/api/health](https://your-app.onrender.com/api/health)

Try it now:
```bash
curl https://your-app.onrender.com/api/health
```

## 🚀 Quick Demo (Local)

Want to run it locally? Here's a 2-minute setup:

### **Step 1: Start the Server**

```bash
# Clone and setup
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api

# One-command setup (requires Docker)
./test_setup.sh

# Start server
mix phx.server
```

### **Step 2: Explore Interactive API Docs**

Visit **http://localhost:4000/api/docs** to see:

- 📖 **OpenAPI/Swagger UI** with "Try it out" buttons
- 🔐 **JWT authentication** built into the UI
- 📋 **Request/response examples** for every endpoint
- 🧪 **Test endpoints directly** from your browser

### **Step 3: Try the API**

```bash
# 1. Health check (no auth required)
curl http://localhost:4000/api/health

# 2. Login (get JWT token)
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "password123"
  }'

# Response includes access_token - copy it for next requests

# 3. Get user profile (requires auth)
curl http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer <your_access_token>"

# 4. View user statistics (admin only)
curl http://localhost:4000/api/users/stats \
  -H "Authorization: Bearer <admin_token>"
```

**Default credentials after seeding:**
- Regular User: `alice@example.com` / `password123`
- Admin User: `admin@example.com` / `adminpassword123456`

---

## 📖 Overview

LedgerBank API is a **learning project** that implements **production-grade financial services** patterns in Elixir/Phoenix. It demonstrates clean architecture, sophisticated error handling, security best practices, and background job processing—all the patterns you'd find in a real fintech company.

**⚠️ Not for Production Use**: This is a portfolio/learning project. It simulates banking operations but does not integrate with real financial institutions or handle actual money.

### Why This Project Exists

I built this to answer: **"How would I architect a complex Elixir API if I had to do it from scratch?"**

The result:
- 🏗️ **Clean Architecture** - Behaviors, services, policies, and pure functions
- 🔒 **Security First** - JWT rotation, constant-time auth, RBAC, audit logs
- 🎯 **Error Excellence** - Error catalog with retry policies and circuit breakers
- 🚀 **Production Patterns** - Docker, CI/CD, health checks, monitoring
- 📊 **Domain-Driven Design** - Financial and accounts contexts with clear boundaries
- ⚡ **Performance** - Keyset pagination, ETS caching, query optimization

---

## 🌟 Features

### Authentication & Authorization
- ✅ **JWT-based authentication** with access and refresh tokens
- ✅ **Token rotation** for enhanced security
- ✅ **Role-based access control** (User, Admin, Support)
- ✅ **Constant-time authentication** to prevent timing attacks
- ✅ **Secure password hashing** with Argon2
- ✅ **Role-based password complexity** (8 chars for users, 15 for admins)

### Financial Operations
- 💰 **Multi-bank integration** via OAuth2
- 💳 **Account management** with balance tracking
- 📈 **Transaction history** with advanced filtering
- 💸 **Payment processing** with business rule validation
- 🔄 **Bank synchronization** workers for automated updates
- 🏦 **Multi-currency support**

### Banking Integration
- 🔗 **OAuth2 client** for external bank APIs
- 🔄 **Token refresh mechanisms**
- 📊 **Transaction sync** from external sources
- 🏦 **Multi-institution support**
- ⚡ **Real-time balance updates**

### Data Management
- 📄 **Offset pagination** (traditional page/page_size)
- 🔖 **Keyset pagination** (cursor-based for better performance)
- 🔍 **Advanced filtering** by status, role, date, amount
- 🔀 **Multi-field sorting** with direction control
- 📊 **User statistics** and financial health metrics
- 💾 **ETS-based caching** with TTL support

### Error Handling & Resilience
- 🎯 **Canonical error structs** across all layers
- 📋 **Error categorization** (validation, authentication, business rules, etc.)
- 🔄 **Automatic retry logic** for transient failures
- 🔌 **Circuit breaker pattern** for external services
- 📊 **Error telemetry** and correlation IDs
- 🏥 **Health check endpoints**
- 🌐 **RFC 9457 Problem Details** compliance with `application/problem+json`
- 📚 **Problem Type Registry** at `/api/problems` for error discovery
- ⏱️ **Retry-After headers** for retryable errors

### Background Processing
- 🔧 **Oban integration** for reliable job processing
- 💳 **Payment processing workers** with priority queues
- 🔄 **Bank sync workers** with rate limiting
- 🔄 **Job retry strategies** based on error categories
- 📊 **Dead letter queue** handling
- ⏰ **Scheduled jobs** support

### Developer Experience
- 📚 **OpenAPI/Swagger** documentation
- 🐳 **Docker & Docker Compose** support
- 🧪 **Comprehensive test suite** (1000+ tests)
- 📊 **Phoenix LiveDashboard** for monitoring
- 📝 **Structured logging** with correlation IDs
- 🔍 **Security audit logging**

---

## 🏗️ Architecture

### Request Flow (What Happens When You Call the API)

```
┌─────────────────────────────────────────────────────────────┐
│  1. HTTP Request → POST /api/auth/login                     │
└──────────────────┬──────────────────────────────────────────┘
                   │
         ┌─────────▼─────────┐
         │  Router + Plugs   │  ← SecurityHeaders, RateLimit, SecurityAudit
         └─────────┬─────────┘    Adds correlation ID, checks rate limits
                   │
         ┌─────────▼──────────┐
         │   AuthController   │  ← InputValidator validates email/password
         └─────────┬──────────┘    Thin HTTP layer, delegates immediately
                   │
         ┌─────────▼──────────┐
         │   AuthService      │  ← Pure business logic, no HTTP concerns
         │   (login_user)     │    Uses Token.generate_*, UserService.authenticate_user
         └─────────┬──────────┘
                   │
         ┌─────────▼──────────┐
         │   UserService      │  ← authenticate_user: constant-time validation
         │   (authenticate)   │    Checks password BEFORE checking user status (security)
         └─────────┬──────────┘
                   │
         ┌─────────▼──────────┐
         │  User Schema       │  ← Ecto changeset validation
         │  + Repo.get_by     │    Database constraints enforced
         └─────────┬──────────┘
                   │
         ┌─────────▼──────────┐
         │   PostgreSQL       │  ← ACID transactions, unique constraints
         └────────────────────┘
                   │
         ┌─────────▼──────────┐
         │ Response: JWT      │  ← ErrorAdapter maps Error struct → HTTP 200/400/401
         │ + User object      │    Adds correlation ID to response
         └────────────────────┘
```

**Key Insight:** Each layer has **one responsibility** and errors bubble up as `Error` structs, not strings.

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        Web Layer                             │
│  Controllers • Plugs • Validators • Adapters • Router       │
│                                                              │
│  ✅ HTTP concerns only (status codes, headers, JSON)        │
│  ✅ InputValidator converts params → validated data         │
│  ✅ ErrorAdapter converts Error structs → HTTP responses    │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                     Business Layer                           │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Accounts Context│  │ Financial Context│               │
│  │  • UserService   │  │ • FinancialServ. │               │
│  │  • AuthService   │  │ • PaymentWorker  │               │
│  │  • Token         │  │ • BankSyncWorker │               │
│  │  • Policy        │  │ • Policy         │               │
│  │  • Normalize     │  │ • Normalize      │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                              │
│  ✅ Pure business logic, no HTTP knowledge                  │
│  ✅ Policy functions return true/false (easily testable)    │
│  ✅ Normalize functions are pure (no DB, no side effects)   │
│                                                              │
│  ┌────────────────────────────────────────┐                │
│  │           Core Layer                    │                │
│  │  • Error Handling  • Error Catalog     │                │
│  │  • Service Behavior • Validator        │                │
│  │  • Worker Behavior • Cache Adapter     │                │
│  │  • Schema Helpers  • Queryable         │                │
│  └────────────────────────────────────────┘                │
│                                                              │
│  ✅ Shared infrastructure for all contexts                  │
│  ✅ Behaviors define contracts (swap implementations)       │
│  ✅ Error catalog is single source of truth                 │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                      Data Layer                              │
│  Ecto Schemas • Repo • Migrations • PostgreSQL              │
│                                                              │
│  ✅ Database constraints enforced (CHECK, FOREIGN KEY)      │
│  ✅ Changesets validate before hitting database             │
│  ✅ Migrations are explicit and auditable                   │
└─────────────────────────────────────────────────────────────┘
```

### Skills Demonstrated

This project showcases practical experience with:

**Backend Engineering:**
- ✅ RESTful API design with OpenAPI/Swagger documentation
- ✅ Authentication & authorization (JWT, RBAC, OAuth2 simulation)
- ✅ Database design (PostgreSQL, Ecto migrations, indexes, constraints)
- ✅ Background job processing (Oban, priority queues, retry logic)
- ✅ Caching strategies (ETS, adapter pattern for Redis-ready scaling)
- ✅ Error handling (categorization, retry policies, circuit breakers)

**Software Architecture:**
- ✅ Clean architecture (web → business → data layer separation)
- ✅ Domain-driven design (bounded contexts: Accounts, Financial)
- ✅ Behavior-driven development (contracts via Elixir behaviors)
- ✅ Policy-driven authorization (pure functions, easily testable)
- ✅ Adapter pattern (swappable cache/bank clients)

**Testing & Quality:**
- ✅ Comprehensive test coverage (unit, integration, security, performance)
- ✅ Test-driven development (TDD) approach
- ✅ Property-based testing (StreamData)
- ✅ Mock/stub strategies (Mox, Mimic, Bypass)
- ✅ CI/CD pipeline (GitHub Actions)

**DevOps & Operations:**
- ✅ Containerization (Docker, Docker Compose)
- ✅ Health monitoring (liveness, readiness probes)
- ✅ Structured logging with correlation IDs
- ✅ Telemetry & observability
- ✅ Database migrations in production

**Security:**
- ✅ OWASP best practices (Argon2, CSRF, XSS prevention)
- ✅ Timing attack prevention
- ✅ Rate limiting & abuse prevention
- ✅ Security audit logging
- ✅ Input sanitization & validation

---

### Key Design Patterns

#### 1. **Service Behavior Pattern** - DRY Without Macros

All services implement a common behavior for consistent error handling and database operations.

**Before** (Repeated in every service):
```elixir
def get_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, ErrorHandler.business_error(:user_not_found, %{id: id})}
    user -> {:ok, user}
  end
end
```

**After** (ServiceBehavior provides):
```elixir
@behaviour ServiceBehavior

def get_user(id) do
  context = build_context(__MODULE__, :get_user, %{user_id: id})
  ServiceBehavior.get_operation(User, id, :user_not_found, context)
end
```

**Result:** Every service gets standard error handling, context building, and correlation IDs for free.

#### 2. **Error Catalog System** - Single Source of Truth

Instead of ad-hoc error handling, all errors go through a catalog that defines category, HTTP code, and retry behavior.

**Code Example:**
```elixir
# In ErrorCatalog
def reason_codes do
  %{
    :insufficient_funds => :business_rule,      # → 422, no retry
    :bank_api_error => :external_dependency,   # → 503, retry 3x
    :invalid_email_format => :validation       # → 400, no retry
  }
end

# In services, just use the reason:
{:error, ErrorHandler.business_error(:insufficient_funds, context)}

# The catalog automatically:
# - Maps to HTTP 422
# - Sets retryable: false
# - Adds correlation ID
# - Emits telemetry
```

**The Flow:**
```
Error Reason (:insufficient_funds)
    ↓
ErrorCatalog.category_for_reason() → :business_rule
    ↓
ErrorCatalog.http_status_for_category() → 422
    ↓
Error.should_retry?() → false (business rules don't retry)
    ↓
WorkerBehavior sees should_retry?() = false → Dead Letter Queue
```

**Why This Matters:** One change to the catalog affects all workers, services, and controllers. Adding circuit breaking took 5 minutes because the categories were already there.

#### 3. **Policy-Driven Authorization** - Pure Functions

Instead of mixing authorization with business logic, I separated all permission checks into `Policy` modules.

**Benefits:**
```elixir
# Pure, easily testable (no DB, no mocks needed)
def can_update_user?(current_user, target_user, attrs) do
  cond do
    current_user.role == "admin" -> true
    current_user.id == target_user.id -> can_update_self?(attrs)
    current_user.role == "support" -> can_support_update_user?(attrs)
    true -> false
  end
end

# Test with zero setup:
test "users can update their own name but not role" do
  user = %User{id: "123", role: "user"}
  assert Policy.can_update_user?(user, user, %{full_name: "New Name"})
  refute Policy.can_update_user?(user, user, %{role: "admin"})
end
```

**Why:** Permission rules change often. Keeping them in pure functions means:
- ✅ No database needed for tests
- ✅ Easy to audit (all rules in one file)
- ✅ Can be shared with frontend for UI authorization

#### 4. **Normalization Layer** - Data Transformation Isolation

**Problem:** Mixing data cleaning with business logic makes code hard to test.

**Solution:** Pure `Normalize` modules for all contexts.

```elixir
# Input from HTTP
params = %{"email" => " ALICE@EXAMPLE.COM  ", "role" => "AdMiN"}

# Normalize
normalized = Normalize.user_attrs(params)
# => %{"email" => "alice@example.com", "role" => "user"}  # Force role to "user" for security

# Now service just does business logic:
UserService.create_user(normalized)
```

**Security Win:** `Normalize.user_attrs/1` **forces role to "user"** for public registration. Admin creation uses `Normalize.admin_user_attrs/1` which allows role selection but requires admin token.

#### 5. **Worker Behavior** - 280 Lines of Boilerplate Eliminated

**Problem:** Each Oban worker had 180+ lines of identical code (timing, logging, telemetry, retry decisions).

**Solution:** `WorkerBehavior` handles infrastructure, workers implement `perform_work/2` only.

**Before** (PaymentWorker was 245 lines):
```elixir
use Oban.Worker

def perform(%Oban.Job{args: args} = job) do
  start_time = System.monotonic_time(:millisecond)
  correlation_id = Error.generate_correlation_id()
  context = %{worker: "PaymentWorker", job_id: job.id, ...}
  
  Logger.info("Worker started", context)
  
  case process_payment(args["payment_id"]) do
    {:ok, result} ->
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("Worker completed", ...)
      emit_telemetry(:success, duration, ...)
      :ok
    {:error, error} ->
      Logger.error("Worker failed", ...)
      emit_telemetry(:failure, ...)
      if Error.should_retry?(error), do: {:error, error}, else: :discard
  end
end

defp emit_telemetry(...), do: ...  # 30 more lines
defp log_error(...), do: ...       # 20 more lines
# ... (repeat for BankSyncWorker)
```

**After** (PaymentWorker is 80 lines):
```elixir
use LedgerBankApi.Core.WorkerBehavior,
  queue: :payments,
  max_attempts: 5,
  tags: ["payment"]

def worker_name, do: "PaymentWorker"

# WorkerBehavior handles timing, logging, telemetry, retry decisions
def perform_work(%{"payment_id" => id}, context) do
  # Just business logic:
  with {:ok, payment} <- get_payment(id),
       {:ok, result} <- FinancialService.process_payment(id) do
    {:ok, result}
  end
end
```

**Result:** Infrastructure is centralized. Adding `NotificationWorker` requires ~40 lines, not 200.

### Module Organization

```
lib/
├── ledger_bank_api/
│   ├── accounts/              # User & auth context
│   │   ├── schemas/           # User, RefreshToken
│   │   ├── user_service.ex    # User business logic
│   │   ├── auth_service.ex    # Authentication logic
│   │   ├── token.ex           # JWT generation/validation
│   │   ├── policy.ex          # Permission rules
│   │   └── normalize.ex       # Data transformation
│   │
│   ├── financial/             # Banking & payments context
│   │   ├── schemas/           # Bank, Account, Payment, Transaction
│   │   ├── integrations/      # External bank API clients
│   │   ├── workers/           # Background job workers
│   │   ├── financial_service.ex
│   │   ├── policy.ex
│   │   └── normalize.ex
│   │
│   ├── core/                  # Shared infrastructure
│   │   ├── error.ex           # Canonical error struct
│   │   ├── error_catalog.ex   # Error taxonomy
│   │   ├── error_handler.ex   # Error creation & handling
│   │   ├── service_behavior.ex # Service pattern
│   │   ├── validator.ex       # Core validation logic
│   │   └── cache.ex           # ETS caching
│   │
│   ├── application.ex         # Supervision tree
│   ├── repo.ex                # Database repository
│   └── release.ex             # Release tasks
│
└── ledger_bank_api_web/
    ├── controllers/           # HTTP controllers
    ├── plugs/                 # Authentication, authorization, rate limiting
    ├── adapters/              # Error adapter for HTTP responses
    ├── validation/            # Input validation
    ├── router.ex              # Route definitions
    ├── endpoint.ex            # HTTP endpoint
    ├── logger.ex              # Structured logging
    └── telemetry.ex           # Metrics & monitoring
```

---

## 🛠️ Tech Stack

### Core Technologies
- **Elixir 1.18+** - Functional, concurrent language
- **Phoenix 1.7+** - Web framework
- **Ecto 3.11+** - Database wrapper and query generator
- **PostgreSQL 16+** - Primary database

### Authentication & Security
- **Joken** - JWT token generation and validation
- **Argon2** - Password hashing (OWASP recommended)
- **CORS** - Cross-origin resource sharing
- **Security Headers** - CSP, HSTS, X-Frame-Options, etc.

### Background Jobs
- **Oban 2.17+** - Reliable background job processing
- **Telemetry** - Metrics and monitoring
- **Phoenix.PubSub** - Distributed messaging

### HTTP & Integration
- **Req** - Modern HTTP client for bank API integration
- **Finch** - HTTP client pool
- **Jason** - JSON encoding/decoding
- **Swoosh** - Email delivery

### Development & Testing
- **ExUnit** - Testing framework
- **Mox** - Mocking library
- **Mimic** - Another mocking option
- **Bypass** - HTTP mocking
- **Phoenix LiveDashboard** - Real-time monitoring
- **Credo** - Code analysis (optional)

### DevOps
- **Docker & Docker Compose** - Containerization
- **GitHub Actions** - CI/CD pipeline

---

## 📚 Documentation

Complete documentation is available in the `docs/` folder:

- **[Getting Started](docs/GETTING_STARTED.md)** - Setup and running instructions
- **[API Reference](docs/API_REFERENCE.md)** - Complete endpoint documentation  
- **[Architecture Guide](docs/ARCHITECTURE.md)** - System design and patterns
- **[Developer Guide](docs/DEVELOPER.md)** - Code patterns and workflows
- **[Testing Guide](docs/TESTING_GUIDE.md)** - Testing strategies and examples
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Production deployment options
- **[Cheatsheet](docs/CHEATSHEET.md)** - Quick reference for developers

---

## 🚀 Quick Start

### Prerequisites

- **Elixir** 1.18+ and **Erlang/OTP** 26+
- **PostgreSQL** 16+ (via Docker or local installation)
- **Docker** and **Docker Compose** (recommended)
- **Git**

### Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api
```

#### 2. Install Dependencies

```bash
mix deps.get
```

#### 3. Setup Environment Variables

Create a `.env` file (or export directly):

```bash
# Database Configuration
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASS=postgres
export DB_NAME=ledger_bank_api_dev

# JWT Secret (minimum 32 characters)
export JWT_SECRET="your-super-secret-jwt-key-at-least-32-chars-long-please"

# Phoenix Secret (generate with: mix phx.gen.secret)
export SECRET_KEY_BASE="your-phoenix-secret-key-base-here"

# External Bank API (optional)
export MONZO_CLIENT_ID="your-monzo-client-id"
export MONZO_CLIENT_SECRET="your-monzo-client-secret"
```

#### 4. Start PostgreSQL with Docker

```bash
docker-compose up -d db
```

Wait for PostgreSQL to be ready:

```bash
# Check if PostgreSQL is running
docker-compose ps

# Or use pg_isready
pg_isready -h localhost -p 5432 -U postgres
```

#### 5. Setup Database

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Seed sample data
mix run priv/repo/seeds.exs
```

#### 6. Start the Application

```bash
# Interactive mode with Phoenix server
iex -S mix phx.server

# Or non-interactive mode
mix phx.server
```

The API will be available at **http://localhost:4000**

### Automated Setup (Recommended)

Use the provided setup script for a complete environment:

```bash
./test_setup.sh
```

This script:
- ✅ Starts Docker containers
- ✅ Drops and recreates databases
- ✅ Runs all migrations
- ✅ Seeds sample data
- ✅ Clears cache

### Verify Installation

```bash
# Health check
curl http://localhost:4000/api/health

# Expected response:
# {"status":"ok","timestamp":"2025-10-10T...", "version":"1.0.0","uptime":...}
```

### Sample Credentials

After seeding, you can login with:

**Regular User:**
- Email: `alice@example.com`
- Password: `password123!`

**Admin User:**
- Email: `admin@example.com`
- Password: `admin123!`

---

## 📚 API Documentation

### Base URL

```
http://localhost:4000/api
```

### Authentication

Most endpoints require authentication via JWT Bearer token:

```bash
Authorization: Bearer <your_jwt_token>
```

### API Endpoints

#### Authentication

##### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "alice@example.com",
  "password": "password123!"
}
```

**Response:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "uuid",
      "email": "alice@example.com",
      "full_name": "Alice Example",
      "role": "user",
      "status": "ACTIVE"
    }
  },
  "success": true,
  "timestamp": "2025-10-10T12:00:00Z"
}
```

##### Refresh Token
```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

##### Logout
```http
POST /api/auth/logout
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

##### Get Current User
```http
GET /api/auth/me
Authorization: Bearer <access_token>
```

---

#### User Management

##### List Users (Admin Only)
```http
GET /api/users?page=1&page_size=20&sort=email:asc&status=ACTIVE
Authorization: Bearer <admin_token>
```

**Query Parameters:**
- `page` - Page number (default: 1)
- `page_size` - Items per page (default: 20, max: 100)
- `sort` - Sort field and direction (e.g., `email:asc`, `created_at:desc`)
- `status` - Filter by status (ACTIVE, SUSPENDED, DELETED)
- `role` - Filter by role (user, admin, support)

##### List Users with Keyset Pagination
```http
GET /api/users/keyset?limit=20&cursor={"inserted_at":"2024-01-01T00:00:00Z","id":"uuid"}
Authorization: Bearer <admin_token>
```

##### Get User by ID
```http
GET /api/users/{id}
Authorization: Bearer <admin_token>
```

##### Create User (Public Registration)
```http
POST /api/users
Content-Type: application/json

{
  "email": "newuser@example.com",
  "full_name": "New User",
  "password": "password123!",
  "password_confirmation": "password123!"
}
```

**Note:** Role is automatically set to `user` for public registration.

##### Create User as Admin
```http
POST /api/users/admin
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "email": "newadmin@example.com",
  "full_name": "New Admin",
  "password": "admin-password-123!",
  "password_confirmation": "admin-password-123!",
  "role": "admin"
}
```

##### Update User
```http
PUT /api/users/{id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "full_name": "Updated Name",
  "status": "ACTIVE"
}
```

##### Delete User
```http
DELETE /api/users/{id}
Authorization: Bearer <admin_token>
```

##### Get User Statistics
```http
GET /api/users/stats
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "data": {
    "total_users": 100,
    "active_users": 85,
    "admin_users": 5,
    "suspended_users": 15
  },
  "success": true
}
```

---

#### Profile Management

##### Get Current Profile
```http
GET /api/profile
Authorization: Bearer <access_token>
```

##### Update Profile
```http
PUT /api/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "full_name": "Updated Name"
}
```

##### Change Password
```http
PUT /api/profile/password
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "current_password": "oldpassword",
  "new_password": "newpassword123!",
  "password_confirmation": "newpassword123!"
}
```

---

#### Payment Management

##### Create Payment
```http
POST /api/payments
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "amount": "100.50",
  "direction": "DEBIT",
  "payment_type": "PAYMENT",
  "description": "Coffee shop payment",
  "user_bank_account_id": "uuid"
}
```

**Payment Types:**
- `TRANSFER` - Bank transfer
- `PAYMENT` - General payment
- `DEPOSIT` - Deposit to account
- `WITHDRAWAL` - Withdrawal from account

**Directions:**
- `CREDIT` - Money coming in
- `DEBIT` - Money going out

##### List Payments
```http
GET /api/payments?page=1&page_size=20&direction=DEBIT&status=PENDING
Authorization: Bearer <access_token>
```

##### Get Payment Details
```http
GET /api/payments/{id}
Authorization: Bearer <access_token>
```

##### Process Payment
```http
POST /api/payments/{id}/process
Authorization: Bearer <access_token>
```

##### Get Payment Status
```http
GET /api/payments/{id}/status
Authorization: Bearer <access_token>
```

##### Cancel Payment
```http
DELETE /api/payments/{id}
Authorization: Bearer <access_token>
```

##### Validate Payment (Dry Run)
```http
POST /api/payments/validate
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "amount": "100.50",
  "direction": "DEBIT",
  "payment_type": "PAYMENT",
  "description": "Test payment",
  "user_bank_account_id": "uuid"
}
```

**Response:**
```json
{
  "data": {
    "valid": true,
    "message": "Payment validation successful",
    "payment": {...},
    "account": {...}
  }
}
```

##### Get Payment Statistics
```http
GET /api/payments/stats
Authorization: Bearer <access_token>
```

---

#### Health Checks

##### Basic Health Check
```http
GET /api/health
```

##### Detailed Health Check
```http
GET /api/health/detailed
```

#### Error Discovery

##### List All Problem Types
```http
GET /api/problems
```

**Response:**
```json
{
  "data": {
    "problems": [
      {
        "code": "insufficient_funds",
        "type": "https://api.ledgerbank.com/problems/insufficient_funds",
        "status": 422,
        "title": "Insufficient funds for this transaction",
        "category": "business_rule",
        "retryable": false
      }
    ],
    "categories": {
      "validation": 12,
      "business_rule": 8,
      "external_dependency": 5
    }
  },
  "success": true
}
```

##### Get Problem Details
```http
GET /api/problems/insufficient_funds
```

**Response:**
```json
{
  "data": {
    "code": "insufficient_funds",
    "type": "https://api.ledgerbank.com/problems/insufficient_funds",
    "status": 422,
    "title": "Insufficient funds for this transaction",
    "category": "business_rule",
    "retryable": false,
    "retry_delay_ms": 0,
    "max_retry_attempts": 0,
    "description": "Occurs when attempting to process a payment that exceeds the available account balance",
    "examples": ["Payment amount: $150, Available balance: $100"]
  },
  "success": true
}
```

##### List Problems by Category
```http
GET /api/problems/category/business_rule
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-10-10T12:00:00Z",
  "version": "1.0.0",
  "uptime": 123456,
  "checks": {
    "database": "ok",
    "memory": "ok",
    "disk": "ok"
  }
}
```

##### Readiness Check (for Load Balancers)
```http
GET /api/health/ready
```

##### Liveness Check (for Container Orchestration)
```http
GET /api/health/live
```

---

### Error Responses

All errors follow RFC 9457 Problem Details format:

```json
{
  "type": "https://api.ledgerbank.com/problems/email_already_exists",
  "title": "Email already exists",
  "status": 409,
  "detail": "A user with this email address already exists",
  "instance": "req_1234567890abcdef",
  "code": "email_already_exists",
  "reason": "email_already_exists",
  "category": "conflict",
  "retryable": false,
  "timestamp": "2025-10-10T12:00:00Z",
  "details": {
    "field": "email"
  }
}
```

**Content-Type:** `application/problem+json`

**Retry-After Header:** Included for retryable errors (e.g., `Retry-After: 1000`)

**Common Error Codes:**
- `400` - Validation error
- `401` - Authentication required / Invalid token
- `403` - Insufficient permissions
- `404` - Resource not found
- `409` - Conflict (e.g., duplicate email)
- `422` - Business rule violation
- `429` - Rate limit exceeded
- `500` - Internal server error
- `503` - Service unavailable

---

## 🗄️ Database Schema

### Entity Relationship Diagram

```
┌─────────────┐
│    Users    │
└──────┬──────┘
       │
       │ 1:N
       │
       ├──────────────────────┐
       │                      │
       ↓                      ↓
┌──────────────┐      ┌──────────────────┐
│RefreshTokens │      │UserBankLogins    │
└──────────────┘      └────────┬─────────┘
                               │
                               │ 1:N
                               │
                               ↓
                      ┌──────────────────┐
                      │UserBankAccounts  │
                      └────────┬─────────┘
                               │
                  ┌────────────┼─────────────┐
                  │            │             │
                  │ 1:N        │ 1:N         │ 1:N
                  ↓            ↓             ↓
          ┌──────────────┐ ┌──────────┐ ┌──────────────┐
          │Transactions  │ │UserPayments│ │BankBranches  │
          └──────────────┘ └──────────┘ └───────┬──────┘
                                                 │
                                                 │ N:1
                                                 ↓
                                         ┌──────────────┐
                                         │    Banks     │
                                         └──────────────┘
```

### Core Tables

#### users
Primary table for user authentication and profile data.

```sql
Column            Type              Description
--------------------------------------------------------------
id                uuid              Primary key
email             string            Unique email address
full_name         string            User's full name
status            string            ACTIVE | SUSPENDED | DELETED
role              string            user | admin | support
password_hash     string            Argon2 hashed password
active            boolean           Account active flag
verified          boolean           Email verified flag
suspended         boolean           Account suspended flag
deleted           boolean           Soft delete flag
inserted_at       timestamp         Creation timestamp
updated_at        timestamp         Last update timestamp

Indexes:
- UNIQUE: email
- INDEX: status, role, active, verified, suspended, deleted
- INDEX: inserted_at, updated_at
```

#### banks
Financial institutions available for integration.

```sql
Column              Type              Description
--------------------------------------------------------------
id                  uuid              Primary key
name                string            Bank name (unique)
country             string            2-3 letter country code
code                string            Unique bank code
logo_url            string            Bank logo URL
api_endpoint        string            API endpoint URL
status              string            ACTIVE | INACTIVE
integration_module  string            Elixir module for integration
inserted_at         timestamp         Creation timestamp
updated_at          timestamp         Last update timestamp

Indexes:
- UNIQUE: name, code
- INDEX: country, status
```

#### bank_branches
Physical or virtual branches of banks.

```sql
Column          Type              Description
--------------------------------------------------------------
id              uuid              Primary key
bank_id         uuid              Foreign key → banks
name            string            Branch name
iban            string            IBAN code (unique)
country         string            2-3 letter country code
routing_number  string            9-digit routing number
swift_code      string            SWIFT/BIC code (unique)
inserted_at     timestamp         Creation timestamp
updated_at      timestamp         Last update timestamp

Indexes:
- UNIQUE: iban, swift_code
- INDEX: bank_id, country
- FOREIGN KEY: bank_id → banks.id (ON DELETE CASCADE)
```

#### user_bank_logins
OAuth2 credentials for user's bank connections.

```sql
Column            Type              Description
--------------------------------------------------------------
id                uuid              Primary key
user_id           uuid              Foreign key → users
bank_branch_id    uuid              Foreign key → bank_branches
username          string            Bank username
status            string            ACTIVE | INACTIVE | ERROR
last_sync_at      timestamp         Last synchronization time
sync_frequency    integer           Sync frequency in seconds (300-86400)
access_token      text              OAuth2 access token
refresh_token     text              OAuth2 refresh token
token_expires_at  timestamp         Token expiration time
scope             string            OAuth2 granted scopes
provider_user_id  string            User ID from bank provider
inserted_at       timestamp         Creation timestamp
updated_at        timestamp         Last update timestamp

Indexes:
- UNIQUE: (user_id, bank_branch_id, username)
- INDEX: user_id, bank_branch_id, status
- FOREIGN KEY: user_id → users.id (ON DELETE CASCADE)
- FOREIGN KEY: bank_branch_id → bank_branches.id (ON DELETE CASCADE)
```

#### user_bank_accounts
User's actual bank accounts at financial institutions.

```sql
Column              Type              Description
--------------------------------------------------------------
id                  uuid              Primary key
user_bank_login_id  uuid              Foreign key → user_bank_logins
user_id             uuid              Foreign key → users
currency            string            3-letter currency code (e.g., USD, EUR)
account_type        string            CHECKING | SAVINGS | CREDIT | INVESTMENT
balance             decimal(15,2)     Current account balance
last_four           string            Last 4 digits of account number
account_name        string            Custom account name
status              string            ACTIVE | INACTIVE | CLOSED
last_sync_at        timestamp         Last synchronization time
external_account_id string            External account identifier
inserted_at         timestamp         Creation timestamp
updated_at          timestamp         Last update timestamp

Indexes:
- UNIQUE: external_account_id
- INDEX: user_bank_login_id, account_type, status
- FOREIGN KEY: user_bank_login_id → user_bank_logins.id (ON DELETE CASCADE)
- FOREIGN KEY: user_id → users.id (ON DELETE CASCADE)

Check Constraints:
- balance >= 0 OR account_type = 'CREDIT'
```

#### user_payments
User-initiated payments and transfers.

```sql
Column                Type              Description
--------------------------------------------------------------
id                    uuid              Primary key
user_bank_account_id  uuid              Foreign key → user_bank_accounts
user_id               uuid              Foreign key → users
amount                decimal(15,2)     Payment amount (must be > 0)
direction             string            CREDIT | DEBIT
description           string            Payment description
payment_type          string            DEPOSIT | WITHDRAWAL | TRANSFER | PAYMENT
status                string            PENDING | PROCESSING | COMPLETED | FAILED | CANCELLED
posted_at             timestamp         When payment was posted
external_transaction_id string          External transaction identifier
inserted_at           timestamp         Creation timestamp
updated_at            timestamp         Last update timestamp

Indexes:
- INDEX: user_bank_account_id, amount, payment_type, status, direction
- INDEX: posted_at, external_transaction_id
- FOREIGN KEY: user_bank_account_id → user_bank_accounts.id (ON DELETE CASCADE)
- FOREIGN KEY: user_id → users.id (ON DELETE CASCADE)

Check Constraints:
- amount > 0
```

#### transactions
Completed transactions on user accounts.

```sql
Column        Type              Description
--------------------------------------------------------------
id            uuid              Primary key
account_id    uuid              Foreign key → user_bank_accounts
user_id       uuid              Foreign key → users
description   string            Transaction description
amount        decimal(15,2)     Transaction amount (must be > 0)
direction     string            CREDIT | DEBIT
posted_at     timestamp         When transaction was posted
inserted_at   timestamp         Creation timestamp
updated_at    timestamp         Last update timestamp

Indexes:
- INDEX: account_id, posted_at, amount, direction
- COMPOSITE INDEX: (account_id, posted_at)
- FOREIGN KEY: account_id → user_bank_accounts.id (ON DELETE CASCADE)
- FOREIGN KEY: user_id → users.id (ON DELETE CASCADE)

Check Constraints:
- amount > 0
```

#### refresh_tokens
JWT refresh tokens for secure token rotation.

```sql
Column       Type              Description
--------------------------------------------------------------
id           uuid              Primary key
user_id      uuid              Foreign key → users
jti          string            JWT token identifier (unique)
expires_at   timestamp         Token expiration time
revoked_at   timestamp         Token revocation time (null if active)
inserted_at  timestamp         Creation timestamp
updated_at   timestamp         Last update timestamp

Indexes:
- UNIQUE: jti
- INDEX: user_id, expires_at, revoked_at
- FOREIGN KEY: user_id → users.id (ON DELETE CASCADE)
```

#### oban_jobs
Background job queue (managed by Oban).

See [Oban documentation](https://hexdocs.pm/oban/Oban.html) for schema details.

---

## 🎯 Error Handling System

### Error Architecture

The application implements a **three-layer error handling system**:

1. **Error Catalog** - Central taxonomy of all errors
2. **Error Struct** - Canonical error representation
3. **Error Handler** - Error creation and processing

### Error Categories

```elixir
:validation          # Input validation failures → 400
:not_found          # Resource not found → 404
:authentication     # Authentication failures → 401
:authorization      # Authorization failures → 403
:conflict           # Resource conflicts → 409
:business_rule      # Business logic violations → 422
:external_dependency# External service failures → 503
:system             # Internal system errors → 500
```

### Error Reason Codes

#### Validation Errors (400)
```elixir
:invalid_amount_format
:missing_fields
:invalid_direction
:invalid_email_format
:invalid_password_format
:invalid_uuid_format
:invalid_datetime_format
:invalid_name_format
:invalid_role
:invalid_status
:invalid_payment_type
:invalid_currency_format
:invalid_account_type
```

#### Not Found Errors (404)
```elixir
:user_not_found
:account_not_found
:payment_not_found
:token_not_found
:bank_not_found
```

#### Authentication Errors (401)
```elixir
:invalid_credentials
:invalid_password
:invalid_token
:token_expired
:token_revoked
:invalid_token_type
```

#### Authorization Errors (403)
```elixir
:forbidden
:insufficient_permissions
:unauthorized_access
```

#### Conflict Errors (409)
```elixir
:email_already_exists
:already_processed
:duplicate_transaction
```

#### Business Rule Errors (422)
```elixir
:insufficient_funds
:account_inactive
:daily_limit_exceeded
:amount_exceeds_limit
:negative_amount
:negative_balance
:currency_mismatch
:account_frozen
:account_suspended
```

#### External Dependency Errors (503)
```elixir
:timeout
:service_unavailable
:bank_api_error
:payment_provider_error
```

#### System Errors (500)
```elixir
:internal_server_error
:database_error
:configuration_error
```

### Retry Policy Matrix

| Category | Retryable | Circuit Breaker | Max Retries | Retry Delay |
|----------|-----------|-----------------|-------------|-------------|
| validation | ❌ No | ❌ No | 0 | 0ms |
| not_found | ❌ No | ❌ No | 0 | 0ms |
| authentication | ❌ No | ❌ No | 0 | 0ms |
| authorization | ❌ No | ❌ No | 0 | 0ms |
| conflict | ❌ No | ❌ No | 0 | 0ms |
| business_rule | ❌ No | ❌ No | 0 | 0ms |
| external_dependency | ✅ Yes | ✅ Yes | 3 | 1000ms |
| system | ✅ Yes | ✅ Yes | 2 | 500ms |

### Error Response Format

```json
{
  "error": {
    "type": "unprocessable_entity",
    "message": "Insufficient funds for this transaction",
    "code": 422,
    "reason": "insufficient_funds",
    "details": {
      "account_id": "uuid",
      "available": "50.00",
      "requested": "100.00"
    },
    "timestamp": "2025-10-10T12:00:00Z"
  }
}
```

---

## ⚙️ Background Jobs with Oban

### Queue Configuration

```elixir
queues: [
  banking: 3,        # Bank API calls (rate-limited)
  payments: 2,       # Payment processing (critical)
  notifications: 3,  # Email/SMS notifications
  default: 1         # Miscellaneous tasks
]
```

### Workers

#### PaymentWorker

Processes user payments with comprehensive business rule validation.

**Features:**
- ✅ Comprehensive payment validation
- ✅ Balance updates with transactions
- ✅ Duplicate detection
- ✅ Priority queue support
- ✅ Intelligent retry based on error category
- ✅ Dead letter queue for non-retryable errors

**Usage:**
```elixir
# Schedule payment processing
PaymentWorker.schedule_payment(payment_id)

# Schedule with priority (0-9, 0 = highest)
PaymentWorker.schedule_payment_with_priority(payment_id, 0)

# Schedule with delay
PaymentWorker.schedule_payment_with_delay(payment_id, 60)
```

#### BankSyncWorker

Synchronizes bank data from external APIs.

**Features:**
- ✅ OAuth2 token refresh
- ✅ Account balance synchronization
- ✅ Transaction history fetch
- ✅ Rate limiting respect
- ✅ Retry with exponential backoff
- ✅ Uniqueness constraints (5-minute window)

**Usage:**
```elixir
# Schedule bank sync
BankSyncWorker.schedule_sync(login_id)

# Schedule with delay
BankSyncWorker.schedule_sync_with_delay(login_id, 300)
```

### Retry Strategies

Workers automatically determine retry behavior based on error categories:

```elixir
# Business rule violations → No retry, mark as failed
:insufficient_funds → Dead Letter Queue

# External dependency errors → Retry with backoff
:bank_api_error → 3 retries with exponential backoff

# System errors → Retry with shorter delay
:database_error → 2 retries with 500ms base delay
```

### Monitoring Jobs

```elixir
# Get job status
PaymentWorker.get_payment_job_status(payment_id)

# Cancel scheduled job
PaymentWorker.cancel_payment_job(payment_id)
```

### Phoenix LiveDashboard

Monitor Oban jobs in real-time at:
```
http://localhost:4000/dev/dashboard/oban
```

---

## 🔐 Security Features

### Authentication Security

#### JWT Token Management
- ✅ **Access tokens** (15-minute expiry)
- ✅ **Refresh tokens** (7-day expiry with rotation)
- ✅ **Token revocation** support
- ✅ **JTI (JWT ID)** for unique token identification
- ✅ **Token blacklisting** via database

#### Password Security
- ✅ **Argon2** hashing (OWASP recommended)
- ✅ **Role-based complexity**:
  - Regular users: minimum 8 characters
  - Admin/Support: minimum 15 characters
- ✅ **Password confirmation** required
- ✅ **Current password** verification for changes

#### Constant-Time Authentication
Prevents timing attacks for email enumeration:

```elixir
# SECURITY: Always performs password hashing
# even for non-existent users
@dummy_password_hash Argon2.hash_pwd_salt("dummy_password")

def authenticate_user(email, password) do
  user = get_user_by_email(email) || nil
  password_hash = if user, do: user.password_hash, else: @dummy_password_hash
  
  # Constant time comparison
  password_valid? = Argon2.verify_pass(password, password_hash)
  
  # Check user existence and status AFTER password verification
  # to maintain constant time regardless of account state
end
```

### Authorization

#### Role-Based Access Control (RBAC)
```elixir
Roles:
├── user    - Regular users
├── support - Customer support agents
└── admin   - System administrators
```

#### Policy-Driven Permissions
Pure functions for permission checks:

```elixir
# User operations
Policy.can_update_user?(current_user, target_user, attrs)
Policy.can_delete_user?(current_user, target_user)
Policy.can_list_users?(current_user)

# Financial operations
Policy.can_create_payment?(current_user, payment_attrs)
Policy.can_process_payment?(current_user, payment)
Policy.can_view_account?(current_user, account)
```

### Security Headers

Automatically applied to all responses:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'none'; ...
Strict-Transport-Security: max-age=31536000; includeSubDomains (production only)
```

### Rate Limiting

Configurable rate limiting to prevent abuse:

```elixir
# Default configuration
max_requests: 100 per window
window_size: 60 seconds (1 minute)

# Rate limit headers in responses
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 1633987200
```

### Security Audit Logging

Comprehensive security event tracking:

```elixir
# Logged security events
- Authentication failures
- Authorization failures  
- Rate limit violations
- Suspicious request patterns
- Security policy violations
- Admin actions
```

### Input Validation

#### Multi-Layer Validation
1. **Web Layer** - InputValidator for HTTP inputs
2. **Core Layer** - Core.Validator for data formats
3. **Schema Layer** - Ecto changesets for database constraints
4. **Business Layer** - Business rule validation

#### Security Validations
- ✅ **UUID format** validation
- ✅ **Email format** with null byte rejection
- ✅ **SQL injection** prevention via parameterized queries
- ✅ **XSS prevention** via output escaping
- ✅ **CSRF protection** for session-based auth
- ✅ **Length limits** on all string fields

### Data Integrity

#### Database Constraints
```sql
-- Check constraints
ALTER TABLE users 
  ADD CONSTRAINT status_check 
  CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED'));

ALTER TABLE user_payments
  ADD CONSTRAINT amount_positive_check
  CHECK (amount > 0);

-- Foreign key cascades
ON DELETE CASCADE  -- Automatic cleanup
```

### Sensitive Data Handling

#### Sanitization
```elixir
# Sensitive fields removed from logs
sanitized_fields = [
  :password, :password_hash,
  :access_token, :refresh_token,
  :secret, :private_key, :api_key
]
```

#### Secure Storage
- ✅ Passwords → Argon2 hashed
- ✅ OAuth tokens → Encrypted at rest (recommended)
- ✅ JWT secrets → Environment variables only
- ✅ API keys → Never committed to git

---

## 🧪 Testing

### Test Organization

The test suite is organized by domain and concern:

```
test/
├── ledger_bank_api/
│   ├── accounts/                      # ~2,500 lines of tests
│   │   ├── auth_service_test.exs      # Authentication logic
│   │   ├── constant_time_auth_test.exs # Timing attack prevention
│   │   ├── edge_case_test.exs         # Edge cases & error handling
│   │   ├── normalize_test.exs         # Data transformation
│   │   ├── policy_test.exs            # Permission rules
│   │   ├── user_service_test.exs      # User business logic
│   │   ├── user_service_keyset_test.exs # Keyset pagination
│   │   └── user_service_oban_test.exs  # Background jobs
│   │
│   ├── core/                          # ~700 lines of tests
│   │   ├── cache_test.exs             # Caching logic
│   │   └── error_catalog_financial_test.exs # Error system
│   │
│   └── financial/                     # ~3,000 lines of tests
│       ├── financial_service_test.exs # Financial operations
│       ├── financial_service_validation_test.exs
│       ├── normalize_test.exs         # Financial data transformation
│       ├── payment_business_rules_test.exs # Payment validation
│       ├── policy_test.exs            # Financial permissions
│       └── workers/
│           ├── bank_sync_worker_test.exs
│           ├── payment_worker_test.exs
│           └── priority_execution_test.exs
│
├── ledger_bank_api_web/               # ~6,000 lines of tests
│   ├── controllers/                   # Controller integration tests
│   │   ├── auth_controller_test.exs
│   │   ├── payments_controller_test.exs
│   │   ├── users_controller_test.exs
│   │   ├── profile_controller_test.exs
│   │   ├── authorization_test.exs
│   │   ├── security_user_creation_test.exs
│   │   └── users_controller_keyset_test.exs
│   │
│   ├── plugs/                         # Plug tests
│   │   ├── rate_limit_test.exs
│   │   └── security_headers_test.exs
│   │
│   └── validation/                    # Input validation tests
│       ├── input_validator_test.exs
│       └── input_validator_financial_test.exs
│
└── support/                           # Test helpers & fixtures
    ├── conn_case.ex                   # Controller test setup
    ├── data_case.ex                   # Database test setup
    ├── oban_case.ex                   # Oban test setup
    ├── password_helper.ex             # Test password utilities
    ├── fixtures/
    │   ├── users_fixtures.ex
    │   └── banking_fixtures.ex
    └── mocks/
        └── financial_service_mock.ex
```

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/ledger_bank_api/accounts/user_service_test.exs

# Run specific test
mix test test/ledger_bank_api/accounts/user_service_test.exs:42

# Run tests by pattern
mix test --only auth

# Run tests with warnings as errors (CI mode)
mix test --warnings-as-errors

# Run tests in parallel
mix test --max-cases 4
```

### Test Categories

#### Unit Tests
- ✅ Service business logic
- ✅ Policy functions
- ✅ Normalization functions
- ✅ Validation functions
- ✅ Error handling

#### Integration Tests
- ✅ Controller endpoints
- ✅ Database operations
- ✅ Authentication flow
- ✅ Authorization checks
- ✅ Background jobs

#### Security Tests
- ✅ Constant-time authentication
- ✅ Role-based access control
- ✅ Token validation
- ✅ Rate limiting
- ✅ Input validation

### Test Helpers

#### Fixtures
```elixir
# Create test users
user = UsersFixtures.user_fixture()
admin = UsersFixtures.admin_fixture()

# Create banking data
bank = BankingFixtures.bank_fixture()
account = BankingFixtures.bank_account_fixture(user)
```

#### Mocking
```elixir
# Mock financial service
Mimic.copy(LedgerBankApi.Financial.FinancialService)

Mimic.stub(FinancialService, :process_payment, fn id ->
  {:ok, %{id: id, status: "COMPLETED"}}
end)
```

### Continuous Integration

GitHub Actions workflow (`.github/workflows/ci.yml`):

```yaml
- ✅ Elixir 1.18.4 / OTP 26.2
- ✅ PostgreSQL 16 via Docker
- ✅ Dependency caching
- ✅ Database creation & migrations
- ✅ Test suite execution with --warnings-as-errors
- ✅ Docker image build
```

---

## 🚀 Deployment

### Production Checklist

Before deploying to production:

- [ ] Set strong `JWT_SECRET` (minimum 64 characters)
- [ ] Set secure `SECRET_KEY_BASE` (generate with `mix phx.gen.secret`)
- [ ] Configure `DATABASE_URL` with SSL
- [ ] Set appropriate `POOL_SIZE` (default: 10)
- [ ] Configure external bank API credentials
- [ ] Set `MIX_ENV=prod`
- [ ] Set `PHX_SERVER=true` for standalone deployment
- [ ] Configure logging level (`:info` or `:warning`)
- [ ] Set up database backups
- [ ] Configure SSL/TLS certificates
- [ ] Set up monitoring and alerting
- [ ] Configure rate limiting appropriately
- [ ] Set up log aggregation

### Environment Variables (Production)

```bash
# Application
MIX_ENV=prod
PHX_SERVER=true
PHX_HOST=yourdomain.com
PORT=4000
SECRET_KEY_BASE=<generate-with-mix-phx-gen-secret>

# Database
DATABASE_URL=ecto://user:password@host:5432/database?ssl=true
POOL_SIZE=10

# JWT
JWT_SECRET=<at-least-64-character-secret-key>

# External APIs
MONZO_CLIENT_ID=your-production-client-id
MONZO_CLIENT_SECRET=your-production-client-secret
MONZO_API_URL=https://api.monzo.com

# Oban Queue Configuration (optional)
OBAN_QUEUES=banking:3,payments:2,notifications:3,default:1
```

### Docker Production Deployment

#### 1. Build the Image

   ```bash
# Build production image
docker compose build --pull

# Or manually
docker build -t ledger-bank-api:latest .
```

#### 2. Run with Docker Compose

   ```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f app

# Check health
curl http://localhost:4000/api/health/ready
```

#### 3. Run Migrations

   ```bash
# Inside the container
docker compose exec app bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

# Or with docker-compose entrypoint (automatically runs migrations)
```

### Release Build

Build an Elixir release for production:

   ```bash
# Install dependencies
mix deps.get --only prod

# Compile assets and code
MIX_ENV=prod mix compile

# Build release
MIX_ENV=prod mix release

# The release will be in _build/prod/rel/ledger_bank_api/
```

Run the release:

   ```bash
# Start the server
_build/prod/rel/ledger_bank_api/bin/ledger_bank_api start

# Run migrations
_build/prod/rel/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

# Stop the server
_build/prod/rel/ledger_bank_api/bin/ledger_bank_api stop
```

### Kubernetes Deployment

Example Kubernetes manifests:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-bank-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ledger-bank-api
  template:
    metadata:
      labels:
        app: ledger-bank-api
    spec:
      containers:
      - name: app
        image: ledger-bank-api:latest
   ports:
        - containerPort: 4000
        env:
        - name: PHX_SERVER
          value: "true"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: secret_key_base
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt_secret
        livenessProbe:
          httpGet:
            path: /api/health/live
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health/ready
            port: 4000
          initialDelaySeconds: 10
          periodSeconds: 5

---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ledger-bank-api
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 4000
  selector:
    app: ledger-bank-api
```

### Database Migrations

Always run migrations before deploying new code:

```bash
# Using release task
bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

# Or using mix (development/staging)
mix ecto.migrate
```

### Health Monitoring

Set up health check monitoring:

```bash
# Liveness check (container is alive)
curl http://your-domain/api/health/live

# Readiness check (can accept traffic)
curl http://your-domain/api/health/ready

# Detailed health (database, memory, etc.)
curl http://your-domain/api/health/detailed
```

### Monitoring & Observability

#### Telemetry
Built-in telemetry for:
- HTTP request duration
- Database query performance
- Oban job processing
- Custom business metrics

#### Logging
Structured JSON logging for production:
- Request/response logs with correlation IDs
- Error tracking with stack traces
- Security audit logs
- Business event logs

#### Recommended Tools
- **APM**: AppSignal, New Relic, or Datadog
- **Logging**: Papertrail, Loggly, or ELK Stack
- **Monitoring**: Prometheus + Grafana
- **Error Tracking**: Sentry or Rollbar

---

## 🛠️ Development

### Development Setup

1. **Install Elixir Version Manager (optional)**
   ```bash
   asdf install
   ```

2. **Start Development Server**
```bash
   iex -S mix phx.server
   ```

3. **Access Development Tools**
   - API: http://localhost:4000
   - LiveDashboard: http://localhost:4000/dev/dashboard
   - Sent Emails: http://localhost:4000/dev/mailbox

### Development Commands

```bash
# Database
mix ecto.setup           # Create, migrate, and seed
mix ecto.reset           # Drop, recreate, migrate, and seed
mix ecto.migrate         # Run pending migrations
mix ecto.rollback        # Rollback last migration
mix ecto.gen.migration   # Generate new migration

# Code Quality
mix format               # Format code
mix credo               # Static code analysis (if installed)
mix dialyzer            # Type checking (if installed)

# Testing
mix test                 # Run all tests
mix test.watch          # Watch mode (if installed)
mix test --cover        # With coverage report

# Interactive Development
iex -S mix              # Start IEx with project loaded
iex -S mix phx.server   # Start IEx with Phoenix server

# Routes
mix phx.routes          # Show all routes

# Dependencies
mix deps.get            # Fetch dependencies
mix deps.update --all   # Update all dependencies
mix deps.clean --all    # Clean dependencies
```

### Code Style

This project follows standard Elixir conventions:

```elixir
# Format code automatically
mix format

# Check formatting
mix format --check-formatted
```

### Project Structure Best Practices

1. **Contexts** - Domain-driven organization (Accounts, Financial)
2. **Services** - Business logic layer with standard behavior
3. **Policies** - Pure permission functions
4. **Normalize** - Data transformation layer
5. **Schemas** - Database entities with Ecto
6. **Controllers** - Thin HTTP layer, delegates to services
7. **Plugs** - Reusable HTTP middleware
8. **Workers** - Background job processing

### Adding a New Feature

1. **Create Schema & Migration**
   ```bash
   mix ecto.gen.migration create_feature_name
   ```

2. **Define Schema**
   ```elixir
   # lib/ledger_bank_api/context/schemas/feature.ex
   defmodule LedgerBankApi.Context.Schemas.Feature do
     use Ecto.Schema
     # ...
   end
   ```

3. **Create Service**
   ```elixir
   # lib/ledger_bank_api/context/feature_service.ex
   defmodule LedgerBankApi.Context.FeatureService do
     @behaviour LedgerBankApi.Core.ServiceBehavior
     # ...
   end
   ```

4. **Add Policy (if needed)**
   ```elixir
   # In lib/ledger_bank_api/context/policy.ex
   def can_do_feature?(user, resource), do: ...
   ```

5. **Create Controller**
   ```elixir
   # lib/ledger_bank_api_web/controllers/feature_controller.ex
   defmodule LedgerBankApiWeb.FeatureController do
     use LedgerBankApiWeb.Controllers.BaseController
     # ...
   end
   ```

6. **Add Routes**
   ```elixir
   # lib/ledger_bank_api_web/router.ex
   scope "/api/features" do
     pipe_through [:api, :authenticated]
     # ...
   end
   ```

7. **Write Tests**
   ```elixir
   # test/ledger_bank_api/context/feature_service_test.exs
   # test/ledger_bank_api_web/controllers/feature_controller_test.exs
   ```

---

## 🔮 What I Would Build Next

Having mastered these patterns, here's my learning roadmap:

### **Immediate Next Steps (1-2 weeks)**

1. **GraphQL API** → Rebuild this with Absinthe
   - Compare REST vs GraphQL for complex financial queries
   - Learn N+1 query prevention with Dataloader
   - Schema stitching for microservices

2. **Real Banking Integration** → Connect to Plaid API
   - OAuth2 flow for real bank connections
   - Webhook handling for transaction updates
   - Error handling for external API failures

3. **Frontend Dashboard** → React + TypeScript
   - Consume this API with proper JWT handling
   - Real-time updates via Phoenix Channels/WebSockets
   - Charts for financial data visualization

### **Medium Term (1-2 months)**

4. **Event Sourcing** → Rebuild with Commanded/EventStore
   - Learn CQRS pattern for financial audit trails
   - Compare event-driven vs CRUD
   - Time-travel debugging for payments

5. **Distributed Systems** → Multi-node Elixir cluster
   - Replace ETS cache with Redis (my CacheAdapter makes this easy)
   - Learn clustering with `libcluster`
   - Distributed Oban with Redis queues

6. **Observability** → Add AppSignal or Datadog
   - Custom telemetry events
   - Distributed tracing with correlation IDs
   - Alerting on business metrics (failed payments, auth failures)

### **Advanced Learning (3-6 months)**

7. **Microservices** → Split into Auth, Payments, Accounts services
   - Learn service boundaries and API gateways
   - Distributed transactions / Saga pattern
   - Service mesh with Istio

8. **Machine Learning Integration** → Fraud detection
   - Anomaly detection on payment patterns
   - Real-time scoring with Nx (Elixir ML library)
   - A/B testing for fraud rules

9. **Mobile API** → Add GraphQL subscriptions
   - Real-time balance updates
   - Push notifications for transactions
   - Offline-first mobile patterns

---

## 🤝 Contributing

This is a learning/portfolio project, but contributions are welcome if you're learning too!

### Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`mix test`)
5. Format code (`mix format`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Pull Request Guidelines

- ✅ Include tests for new features
- ✅ Update documentation as needed
- ✅ Follow existing code style
- ✅ Ensure all tests pass
- ✅ Keep commits focused and atomic
- ✅ Write clear commit messages
- ✅ Update CHANGELOG.md (if applicable)

### Code Review Process

1. All PRs require approval from maintainers
2. CI must pass (tests, formatting, etc.)
3. Address review feedback promptly
4. Keep PR scope focused and reasonable

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Built with:
- [Elixir](https://elixir-lang.org/) - Functional, concurrent programming language
- [Phoenix Framework](https://phoenixframework.org/) - Productive web framework
- [Ecto](https://hexdocs.pm/ecto/) - Database wrapper and query generator
- [Oban](https://hexdocs.pm/oban/) - Robust background job processing
- [Joken](https://hexdocs.pm/joken/) - JWT implementation

---

## 📞 Contact & Portfolio

### About the Developer

Hi! I'm Rafael, and I built this project to learn production Elixir patterns. If you're:

- 👔 **Hiring for Elixir/backend roles** → Let's talk about what I learned building this
- 🎓 **Learning Elixir too** → Feel free to ask questions or open issues
- 🔧 **Want to contribute** → PRs welcome! See patterns you'd do differently? Let's discuss!

**Connect with me:**
- 📧 Email: rafarojasv6@gmail.com
- 💼 LinkedIn: [Rafael Rojas](https://linkedin.com/in/rafael-rojas-villegas) *(if applicable)*
- 🐙 GitHub: [@rafaelRojasVi](https://github.com/rafaelRojasVi)
- 🌐 Portfolio: [rafaelrojas.dev](https://rafaelrojas.dev) *(if you have one)*

### Other Projects

Check out my other learning projects:
- 🚧 [Your other Elixir project]
- 🚧 [Your frontend project]
- 🚧 [Your infrastructure project]

---

## 📚 Resources & Inspiration

This project was influenced by:

**Books:**
- *Designing Elixir Systems with OTP* by James Edward Gray II & Bruce A. Tate
- *Programming Phoenix 1.4* by Chris McCord, Bruce Tate, & José Valim

**Blog Posts & Talks:**
- [How Stripe Designs Beautiful APIs](https://stripe.com/blog/api-design)
- [Error Handling in Elixir](https://dockyard.com/blog/2021/07/28/error-handling-in-elixir)
- [Oban Best Practices](https://getoban.pro/docs/pro/best-practices.html)

**Open Source Projects:**
- [Phoenix Framework](https://github.com/phoenixframework/phoenix) - Web framework patterns
- [Oban](https://github.com/sorentwo/oban) - Background job inspiration
- [Plaid Elixir](https://github.com/wfgilman/plaid-elixir) - Banking integration patterns

---

## 📝 Developer Notes

### Why I Made Certain Choices

**Q: Why not use Phoenix.Token instead of Joken?**  
A: I wanted to learn JWT internals and implement token rotation myself. Phoenix.Token is great, but building with Joken taught me about claims validation, signers, and security considerations.

**Q: Why ETS instead of Redis for cache?**  
A: I implemented `CacheAdapter` behavior so switching to Redis is one config change. ETS keeps the project simple to run locally, but the architecture is Redis-ready.

**Q: Why so many test files?**  
A: I wanted to learn different testing strategies:
- Integration tests (full user flows)
- Security tests (timing attacks, injection)
- Performance tests (N+1 queries, concurrent updates)
- Edge case tests (null bytes, boundary conditions)

**Q: Is this production-ready?**  
A: The patterns are production-grade, but you'd need:
- Real banking integration (Plaid, Stripe)
- Distributed cache (Redis)
- Proper secrets management (Vault)
- APM/monitoring (AppSignal, New Relic)
- Rate limiting per user (currently per IP)

---

<div align="center">

**Made with ❤️ using Elixir and Phoenix**

*Built as a learning project • Not for production financial transactions*

[⬆ Back to Top](#ledgerbank-api)

</div>

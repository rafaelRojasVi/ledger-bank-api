# 🧪 Testing Guide

Comprehensive guide to the testing strategy and how to run tests in LedgerBank API.

---

## 📋 Table of Contents

- [Testing Philosophy](#-testing-philosophy)
- [Quick Start](#-quick-start)
- [Test Organization](#-test-organization)
- [Running Tests](#-running-tests)
- [Writing Tests](#-writing-tests)
- [Test Patterns](#-test-patterns)
- [Coverage](#-coverage)
- [CI/CD](#-cicd)

---

## 🎯 Testing Philosophy

### **Test Pyramid**

```
        /\
       /  \
      / UI \ ← 10% (Controller tests)
     /______\
    /        \
   /Integration\ ← 30% (Service + DB tests)
  /____________\
 /              \
/  Unit Tests    \ ← 60% (Policy, Normalize, pure functions)
/________________\
```

### **What I Test**

**✅ Unit Tests** (Fast, No I/O)
- Policy functions (`Policy.can_update_user?`)
- Normalize functions (`Normalize.user_attrs`)
- Validators (`Validator.validate_email`)
- Error catalog (`ErrorCatalog.category_for_reason`)
- Problem Details formatting (`ErrorAdapter.to_problem_details`)

**✅ Integration Tests** (Real Database)
- Service operations with database
- Controller endpoints (HTTP → DB → HTTP)
- Background workers with Oban
- Authentication flows (login → token → protected endpoint)
- Problem Registry endpoints (`/api/problems`)

**✅ Security Tests** (Edge Cases)
- Timing attack prevention
- Null byte injection
- SQL injection via parameterized queries
- XSS prevention
- CSRF token validation

**✅ Performance Tests** (Scalability)
- N+1 query detection
- Concurrent update handling
- Keyset vs offset pagination benchmarks
- Stress testing (1000 jobs, 100 concurrent users)

### **What I Don't Test**

**❌ Don't Test:**
- Ecto query generation (trust the library)
- Phoenix router (trust the framework)
- Third-party libraries (they have their own tests)

**Instead:** Test the integration points and business logic.

---

## 🚀 Quick Start

### **Run All Tests**

```bash
# Run full test suite
mix test

# With coverage report
mix test --cover

# With warnings as errors (CI mode)
mix test --warnings-as-errors

# Fast (parallel execution)
mix test --max-cases 8
```

### **Run Specific Tests**

```bash
# By file
mix test test/ledger_bank_api/accounts/user_service_test.exs

# By line number (specific test)
mix test test/ledger_bank_api/accounts/user_service_test.exs:42

# By pattern (all tests with "authentication" in description)
mix test --only authentication

# By tag
mix test --only integration
mix test --only unit
mix test --exclude slow
```

### **Watch Mode** (Optional)

```bash
# Install mix_test_watch
mix archive.install hex mix_test_watch

# Run in watch mode
mix test.watch

# Watch specific files
mix test.watch test/ledger_bank_api/accounts/
```

---

## 📂 Test Organization

### **Directory Structure**

```
test/
├── ledger_bank_api/
│   ├── accounts/                      # User & auth tests (~2,500 lines)
│   │   ├── schemas/
│   │   │   ├── user_test.exs          # User schema validation
│   │   │   └── refresh_token_test.exs # Token schema validation
│   │   ├── auth_service_test.exs      # Authentication business logic
│   │   ├── constant_time_auth_test.exs # Timing attack prevention
│   │   ├── edge_case_test.exs         # Edge cases & error handling
│   │   ├── normalize_test.exs         # Data transformation
│   │   ├── policy_test.exs            # Permission rules
│   │   ├── token_test.exs             # JWT generation/validation
│   │   ├── user_service_test.exs      # User CRUD operations
│   │   ├── user_service_keyset_test.exs # Keyset pagination
│   │   └── user_service_oban_test.exs # Background job scheduling
│   │
│   ├── core/                          # Core functionality tests (~700 lines)
│   │   ├── cache_test.exs             # ETS cache operations
│   │   ├── error_test.exs             # Error struct & policies
│   │   ├── error_catalog_financial_test.exs # Error taxonomy
│   │   └── validator_test.exs         # Core validation logic
│   │
│   ├── financial/                     # Financial domain tests (~3,000 lines)
│   │   ├── financial_service_test.exs # Financial operations
│   │   ├── financial_service_validation_test.exs # Business rules
│   │   ├── normalize_test.exs         # Financial data transformation
│   │   ├── payment_business_rules_test.exs # Payment validation
│   │   ├── policy_test.exs            # Financial permissions
│   │   └── workers/
│   │       ├── bank_sync_worker_test.exs # Bank sync jobs
│   │       ├── payment_worker_test.exs   # Payment processing
│   │       └── priority_execution_test.exs # Priority queues
│   │
│   └── performance/                   # Performance tests (~7,000 lines)
│       ├── ecto_performance_test.exs  # Query optimization
│       └── oban_stress_test.exs       # Job queue stress tests
│
├── ledger_bank_api_web/               # Web layer tests (~6,000 lines)
│   ├── adapters/
│   │   └── error_adapter_test.exs     # Error → HTTP mapping
│   ├── controllers/
│   │   ├── auth_controller_test.exs   # Authentication endpoints
│   │   ├── integration_flow_test.exs  # ★ 3,796 lines of end-to-end flows
│   │   ├── payments_controller_test.exs # Payment endpoints
│   │   ├── profile_controller_test.exs # Profile management
│   │   ├── users_controller_test.exs   # User management
│   │   ├── authorization_test.exs      # RBAC enforcement
│   │   ├── security_user_creation_test.exs # Security edge cases
│   │   └── users_controller_keyset_test.exs # Keyset pagination
│   ├── plugs/
│   │   ├── authenticate_test.exs      # JWT validation
│   │   ├── authorize_test.exs         # Role-based access
│   │   ├── rate_limit_test.exs        # Rate limiting
│   │   ├── security_audit_test.exs    # Security logging
│   │   └── security_headers_test.exs  # Security headers
│   └── validation/
│       ├── input_validator_test.exs   # Web input validation
│       └── input_validator_financial_test.exs # Financial validation
│
└── support/                           # Test helpers
    ├── conn_case.ex                   # Controller test setup
    ├── data_case.ex                   # Database test setup
    ├── oban_case.ex                   # Oban test setup
    ├── password_helper.ex             # Password utilities for tests
    ├── fixtures/
    │   ├── users_fixtures.ex          # User test data
    │   └── banking_fixtures.ex        # Banking test data
    └── mocks/
        └── financial_service_mock.ex  # Service mocking
```

---

## 🏃 Running Tests

### **Basic Commands**

```bash
# All tests
mix test

# With pretty formatter
mix test --formatter Elixir.ExUnit.Formatter

# Stop on first failure
mix test --max-failures 1

# Show slowest tests
mix test --slowest 10

# Verbose output
mix test --trace

# Seed for reproducibility
mix test --seed 0
```

### **By Category**

```bash
# Authentication tests
mix test test/ledger_bank_api/accounts/auth_service_test.exs

# Financial tests
mix test test/ledger_bank_api/financial/

# Controller tests
mix test test/ledger_bank_api_web/controllers/

# Worker tests
mix test test/ledger_bank_api/financial/workers/

# Security tests
mix test test/ledger_bank_api/accounts/constant_time_auth_test.exs
mix test test/ledger_bank_api_web/controllers/security_user_creation_test.exs

# Performance tests (slower)
mix test test/ledger_bank_api/performance/
```

### **By Tag**

```bash
# Run only unit tests (fast)
@tag :unit
mix test --only unit

# Run only integration tests
@tag :integration  
mix test --only integration

# Skip slow tests
@tag :slow
mix test --exclude slow

# Run only security tests
@tag :security
mix test --only security
```

### **Parallel Execution**

```bash
# Use all CPU cores
mix test --max-cases $(nproc)

# Specific parallelism
mix test --max-cases 4

# Sequential (for debugging)
mix test --max-cases 1
```

---

## ✍️ Writing Tests

### **Test Structure**

Every test file follows this pattern:

```elixir
defmodule LedgerBankApi.FeatureTest do
  use LedgerBankApi.DataCase  # or ConnCase for controllers
  
  alias LedgerBankApi.Feature
  
  describe "function_name/arity" do
    test "what it should do in normal case" do
      # Arrange
      user = create_user()
      
      # Act
      result = Feature.function(user)
      
      # Assert
      assert {:ok, _} = result
    end
    
    test "what it should do when error occurs" do
      # Arrange
      invalid_input = %{}
      
      # Act
      result = Feature.function(invalid_input)
      
      # Assert
      assert {:error, error} = result
      assert error.reason == :missing_fields
    end
  end
end
```

### **Test Cases for DataCase** (Database Tests)

```elixir
defmodule LedgerBankApi.UserServiceTest do
  use LedgerBankApi.DataCase
  
  alias LedgerBankApi.Accounts.UserService
  
  describe "create_user/1" do
    test "creates user with valid attrs" do
      attrs = %{
        email: "test@example.com",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      }
      
      assert {:ok, user} = UserService.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.role == "user"
    end
    
    test "returns error for duplicate email" do
      attrs = %{email: "test@example.com", ...}
      
      # Create first user
      {:ok, _user1} = UserService.create_user(attrs)
      
      # Try to create duplicate
      {:error, error} = UserService.create_user(attrs)
      
      assert error.reason == :email_already_exists
      assert error.code == 409
    end
  end
end
```

### **Test Cases for ConnCase** (Controller Tests)

```elixir
defmodule LedgerBankApiWeb.Controllers.AuthControllerTest do
  use LedgerBankApiWeb.ConnCase
  
  alias LedgerBankApi.Accounts.UserService
  
  describe "POST /api/auth/login" do
    setup do
      {:ok, user} = UserService.create_user(%{
        email: "test@example.com",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      })
      
      %{user: user}
    end
    
    test "returns JWT tokens for valid credentials", %{conn: conn, user: user} do
      conn = post(conn, "/api/auth/login", %{
        email: user.email,
        password: "password123"
      })
      
      assert %{
        "data" => %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "user" => returned_user
        }
      } = json_response(conn, 200)
      
      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert returned_user["id"] == user.id
    end
    
    test "returns 401 for invalid password", %{conn: conn, user: user} do
      conn = post(conn, "/api/auth/login", %{
        email: user.email,
        password: "wrong_password"
      })
      
      assert %{
        "error" => %{
          "reason" => "invalid_credentials",
          "code" => 401
        }
      } = json_response(conn, 401)
    end
  end
end
```

### **Test Cases for ObanCase** (Background Jobs)

```elixir
defmodule LedgerBankApi.Financial.Workers.PaymentWorkerTest do
  use LedgerBankApi.ObanCase
  
  alias LedgerBankApi.Financial.Workers.PaymentWorker
  
  describe "perform/1" do
    test "processes payment successfully" do
      payment = create_payment(%{status: "PENDING"})
      
      # Enqueue job
      assert {:ok, job} = PaymentWorker.schedule_payment(payment.id)
      
      # Worker runs immediately in test mode (Oban config: testing: :inline)
      assert_enqueued worker: PaymentWorker, args: %{payment_id: payment.id}
      
      # Verify side effects
      updated_payment = Repo.get(UserPayment, payment.id)
      assert updated_payment.status == "COMPLETED"
    end
    
    test "emits telemetry on success" do
      payment = create_payment()
      
      # Attach telemetry handler
      :telemetry.attach_many(
        "test-handler",
        [[:ledger_bank_api, :worker, :payment, :success]],
        &handle_event/4,
        nil
      )
      
      # Execute worker
      PaymentWorker.schedule_payment(payment.id)
      
      # Assert telemetry was emitted
      assert_received {:telemetry_event, [:ledger_bank_api, :worker, :payment, :success], _, _}
    end
  end
end
```

---

## 📊 Test Statistics

### **Current Coverage**

| Category | Files | Lines | Coverage |
|----------|-------|-------|----------|
| **Unit Tests** | 15 | ~3,000 | 95%+ |
| **Integration Tests** | 20 | ~8,000 | 90%+ |
| **Controller Tests** | 10 | ~6,000 | 95%+ |
| **Security Tests** | 5 | ~2,000 | 100% |
| **Performance Tests** | 2 | ~7,000 | N/A |
| **Total** | **52** | **~26,000** | **92%+** |

### **Highlight Tests**

**Longest Test File:**
```elixir
# test/ledger_bank_api_web/controllers/integration_flow_test.exs
# 3,796 lines - Complete user journeys from registration to payment processing
```

**Most Complex Test:**
```elixir
# test/ledger_bank_api/accounts/constant_time_auth_test.exs
# Validates that authentication timing doesn't leak information
```

**Best Performance Test:**
```elixir
# test/ledger_bank_api/performance/ecto_performance_test.exs  
# Detects N+1 queries, benchmarks pagination strategies
```

---

## 📝 Test Patterns

### **Pattern 1: Factory Functions**

Instead of copying setup code, use fixtures:

```elixir
# test/support/fixtures/users_fixtures.ex
defmodule LedgerBankApi.UsersFixtures do
  def user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      full_name: "Test User",
      password: "password123",
      password_confirmation: "password123"
    }
    
    attrs = Map.merge(default_attrs, attrs)
    {:ok, user} = LedgerBankApi.Accounts.UserService.create_user(attrs)
    user
  end
  
  def admin_fixture(attrs \\ %{}) do
    user_fixture(Map.put(attrs, :role, "admin"))
  end
end

# In tests:
test "admin can delete users" do
  admin = admin_fixture()
  user = user_fixture()
  
  assert Policy.can_delete_user?(admin, user)
end
```

### **Pattern 2: Setup Blocks**

```elixir
describe "update_user/2" do
  setup do
    user = user_fixture()
    admin = admin_fixture()
    
    %{user: user, admin: admin}
  end
  
  test "admin can update any user", %{user: user, admin: admin} do
    # user and admin available from setup
  end
end

# Or setup with tags:
setup :create_user
setup :create_payment

defp create_user(_context) do
  %{user: user_fixture()}
end
```

### **Pattern 3: Assertions**

```elixir
# Good assertions
assert {:ok, user} = UserService.create_user(attrs)
assert user.email == "test@example.com"

# Error assertions
assert {:error, error} = UserService.create_user(invalid_attrs)
assert error.reason == :missing_fields
assert error.code == 400
assert error.category == :validation

# List assertions
assert [user1, user2] = UserService.list_users()
assert length(users) == 2

# Map assertions
assert %{data: data, pagination: pagination} = result
assert pagination.page == 1
assert pagination.total_count > 0
```

### **Pattern 4: Mocking with Mox**

```elixir
# Define mock in test_helper.exs
Mox.defmock(FinancialServiceMock, for: FinancialServiceBehaviour)

# In test
defmodule PaymentWorkerTest do
  use LedgerBankApi.ObanCase
  
  import Mox
  
  # Allow mocks to be called in tests
  setup :verify_on_exit!
  
  test "calls FinancialService.process_payment" do
    payment_id = "test-id"
    
    # Expect the call
    expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
      {:ok, %{status: "COMPLETED"}}
    end)
    
    # Execute worker
    PaymentWorker.perform(%Oban.Job{args: %{"payment_id" => payment_id}})
    
    # Mox verifies the call happened
  end
end
```

### **Pattern 5: Async Tests**

```elixir
# For tests that don't share data
test "can run in parallel", %{async: true} do
  # Test won't interfere with others
end

# Use in test module
use LedgerBankApi.DataCase, async: true

# ⚠️ Don't use async if:
# - Test modifies global state (ETS tables)
# - Test uses Oban (shared job queue)
# - Test uses cache (shared ETS table)
```

---

## 🧪 Testing Specific Features

### **Testing Authentication**

```elixir
test "login returns JWT tokens" do
  user = user_fixture()
  
  conn = post(conn, "/api/auth/login", %{
    email: user.email,
    password: "password123"
  })
  
  assert %{"data" => %{"access_token" => token}} = json_response(conn, 200)
  
  # Verify token is valid
  assert {:ok, claims} = Token.verify_access_token(token)
  assert claims["sub"] == user.id
end

test "login fails with invalid credentials" do
  user = user_fixture()
  
  conn = post(conn, "/api/auth/login", %{
    email: user.email,
    password: "wrong_password"
  })
  
  assert %{"error" => %{"reason" => "invalid_credentials"}} = json_response(conn, 401)
end

test "constant-time authentication prevents timing attacks" do
  # Test that response times are similar for:
  # - Valid email + wrong password
  # - Invalid email + any password
  
  timings = for _ <- 1..100 do
    start = System.monotonic_time(:microsecond)
    UserService.authenticate_user("fake@example.com", "password")
    System.monotonic_time(:microsecond) - start
  end
  
  avg = Enum.sum(timings) / length(timings)
  std_dev = calculate_std_dev(timings, avg)
  
  # Timing should be consistent (low standard deviation)
  assert std_dev < avg * 0.1  # Within 10%
end
```

### **Testing Background Workers**

```elixir
test "PaymentWorker processes payment" do
  payment = payment_fixture(%{status: "PENDING"})
  
  # Schedule job
  assert {:ok, job} = PaymentWorker.schedule_payment(payment.id)
  
  # In test env, Oban runs inline (testing: :inline)
  # So job is already executed here
  
  # Verify result
  updated_payment = Repo.get!(UserPayment, payment.id)
  assert updated_payment.status == "COMPLETED"
end

test "PaymentWorker retries on external errors" do
  payment = payment_fixture()
  
  # Stub to return retryable error
  expect(FinancialServiceMock, :process_payment, fn _id ->
    {:error, ErrorHandler.business_error(:bank_api_error, %{})}
  end)
  
  # Execute
  assert {:error, error} = PaymentWorker.perform_work(%{"payment_id" => payment.id}, %{})
  
  # Verify it's retryable
  assert Error.should_retry?(error) == true
end

test "PaymentWorker does not retry business errors" do
  payment = payment_fixture()
  
  # Stub to return non-retryable error
  expect(FinancialServiceMock, :process_payment, fn _id ->
    {:error, ErrorHandler.business_error(:insufficient_funds, %{})}
  end)
  
  # Execute
  assert {:error, error} = PaymentWorker.perform_work(%{"payment_id" => payment.id}, %{})
  
  # Verify it's NOT retryable
  assert Error.should_retry?(error) == false
end
```

### **Testing Policies (Pure Functions)**

```elixir
test "admin can update any user" do
  admin = %User{id: "admin-id", role: "admin"}
  user = %User{id: "user-id", role: "user"}
  attrs = %{full_name: "New Name"}
  
  assert Policy.can_update_user?(admin, user, attrs) == true
end

test "users can update their own name" do
  user = %User{id: "user-id", role: "user"}
  attrs = %{full_name: "New Name"}
  
  assert Policy.can_update_user?(user, user, attrs) == true
end

test "users cannot change their own role" do
  user = %User{id: "user-id", role: "user"}
  attrs = %{role: "admin"}
  
  assert Policy.can_update_user?(user, user, attrs) == false
end

# No database, no mocks needed! Fast tests.
```

### **Testing Normalize Functions**

```elixir
test "user_attrs normalizes email" do
  attrs = %{"email" => "  ALICE@EXAMPLE.COM  "}
  
  normalized = Normalize.user_attrs(attrs)
  
  assert normalized["email"] == "alice@example.com"
end

test "user_attrs forces role to user" do
  attrs = %{
    "email" => "test@example.com",
    "full_name" => "Test",
    "role" => "admin"  # Try to inject admin role
  }
  
  normalized = Normalize.user_attrs(attrs)
  
  # Security: role is forced to "user" for public registration
  assert normalized["role"] == "user"
end
```

### **Testing Error Handling**

```elixir
test "ErrorHandler.business_error creates proper Error struct" do
  context = %{account_id: "acc-123", balance: "50.00"}
  
  error = ErrorHandler.business_error(:insufficient_funds, context)
  
  # Verify error structure
  assert error.reason == :insufficient_funds
  assert error.category == :business_rule
  assert error.code == 422
  assert error.type == :unprocessable_entity
  assert error.retryable == false
  
  # Verify context
  assert error.context.account_id == "acc-123"
  
  # Verify telemetry
  assert is_binary(error.correlation_id)
end

test "ErrorCatalog maps reasons to categories" do
  assert ErrorCatalog.category_for_reason(:insufficient_funds) == :business_rule
  assert ErrorCatalog.category_for_reason(:bank_api_error) == :external_dependency
  assert ErrorCatalog.category_for_reason(:invalid_email_format) == :validation
end

test "ErrorAdapter formats RFC 9457 Problem Details" do
  error = %Error{
    type: :unprocessable_entity,
    code: "insufficient_funds",
    reason: :insufficient_funds,
    category: :business_rule,
    message: "Insufficient funds for this transaction",
    context: %{account_id: "acc-123", requested: "100.00", available: "50.00"},
    correlation_id: "req-123",
    timestamp: ~U[2024-01-15 10:30:00Z]
  }
  
  conn = build_conn()
  conn = put_in(conn.assigns[:correlation_id], "req-123")
  
  problem_details = ErrorAdapter.to_problem_details(error, conn)
  
  # RFC 9457 required fields
  assert problem_details.type == "https://api.ledgerbank.com/problems/insufficient_funds"
  assert problem_details.title == "Insufficient funds for this transaction"
  assert problem_details.status == 422
  assert problem_details.detail == "Insufficient funds for this transaction"
  assert problem_details.instance == "req-123"
  
  # Custom extensions
  assert problem_details.code == "insufficient_funds"
  assert problem_details.reason == :insufficient_funds
  assert problem_details.category == :business_rule
  assert problem_details.retryable == false
  assert problem_details.timestamp == ~U[2024-01-15 10:30:00Z]
  
  # Sanitized context
  assert problem_details.details == %{"account_id" => "acc-123", "requested" => "100.00", "available" => "50.00"}
end
```

---

## 🛡️ Security Testing

### **Testing Constant-Time Authentication**

```elixir
# test/ledger_bank_api/accounts/constant_time_auth_test.exs
test "authentication timing does not reveal email existence" do
  # Create known user
  {:ok, user} = create_user(%{email: "known@example.com", password: "password123"})
  
  # Time 100 attempts with non-existent email
  nonexistent_timings = for _ <- 1..100 do
    {time, _result} = :timer.tc(fn ->
      UserService.authenticate_user("nonexistent@example.com", "password123")
    end)
    time
  end
  
  # Time 100 attempts with existing email but wrong password
  wrong_password_timings = for _ <- 1..100 do
    {time, _result} = :timer.tc(fn ->
      UserService.authenticate_user(user.email, "wrong_password")
    end)
    time
  end
  
  # Calculate averages
  avg_nonexistent = Enum.sum(nonexistent_timings) / length(nonexistent_timings)
  avg_wrong_password = Enum.sum(wrong_password_timings) / length(wrong_password_timings)
  
  # Timings should be within 10% of each other
  difference_percent = abs(avg_nonexistent - avg_wrong_password) / avg_nonexistent
  
  assert difference_percent < 0.1, """
  Timing attack possible! Response times differ by #{difference_percent * 100}%
  - Nonexistent email avg: #{avg_nonexistent}μs
  - Wrong password avg: #{avg_wrong_password}μs
  """
end
```

### **Testing Injection Attacks**

```elixir
test "rejects null bytes in email" do
  attrs = %{
    email: "test\0@example.com",  # Null byte
    full_name: "Test",
    password: "password123",
    password_confirmation: "password123"
  }
  
  assert {:error, error} = UserService.create_user(attrs)
  assert error.reason == :invalid_email_format
end

test "SQL injection prevention via parameterized queries" do
  # Try to inject SQL
  email = "'; DROP TABLE users; --"
  
  # Should safely return "user not found", not execute SQL
  assert {:error, error} = UserService.get_user_by_email(email)
  assert error.reason == :user_not_found
  
  # Verify users table still exists
  assert Repo.all(User) |> length() > 0
end
```

---

## ⚡ Performance Testing

### **Testing N+1 Queries**

```elixir
test "list_users avoids N+1 queries" do
  # Create 100 users
  users = for _ <- 1..100, do: user_fixture()
  
  # Count queries
  query_count = count_queries(fn ->
    UserService.list_users(%{pagination: %{page: 1, page_size: 100}})
  end)
  
  # Should be 1 query (SELECT * FROM users), not 100
  assert query_count == 1
end

defp count_queries(fun) do
  ref = make_ref()
  
  :telemetry.attach(
    "query-counter-#{ref}",
    [:ledger_bank_api, :repo, :query],
    fn _event, _measurements, _metadata, acc ->
      send(self(), {:query, acc + 1})
    end,
    0
  )
  
  fun.()
  
  :telemetry.detach("query-counter-#{ref}")
  
  receive do
    {:query, count} -> count
  after
    0 -> 0
  end
end
```

### **Stress Testing Workers**

```elixir
test "handles 1000 concurrent payment jobs" do
  # Create 1000 payments
  payments = for _ <- 1..1000, do: payment_fixture()
  
  # Schedule all at once
  jobs = Enum.map(payments, fn payment ->
    {:ok, job} = PaymentWorker.schedule_payment(payment.id)
    job
  end)
  
  # Wait for completion (with timeout)
  assert wait_for_jobs(jobs, timeout: 60_000)
  
  # Verify all processed
  completed = Repo.all(from p in UserPayment, where: p.status == "COMPLETED")
  assert length(completed) == 1000
end
```

---

## 📈 Coverage Reports

### **Generate Coverage**

```bash
# Run tests with coverage
mix test --cover

# View coverage report
open cover/excoveralls.html  # macOS
xdg-open cover/excoveralls.html  # Linux
start cover/excoveralls.html  # Windows

# Coverage by module
mix test --cover --export-coverage default

# Combine coverage from multiple runs
mix test.coverage
```

### **Coverage Goals**

| Layer | Target | Current | Status |
|-------|--------|---------|--------|
| Services | 95%+ | 96% | ✅ |
| Schemas | 90%+ | 94% | ✅ |
| Controllers | 90%+ | 92% | ✅ |
| Policies | 100% | 100% | ✅ |
| Workers | 90%+ | 91% | ✅ |
| **Overall** | **90%+** | **92%** | ✅ |

**Untested Code** (Intentional):
- Error formatting (mostly delegation to libraries)
- Telemetry emission (tested via integration)
- Docker entrypoint scripts

---

## 🔄 CI/CD Testing

### **GitHub Actions Workflow**

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.4'
          otp-version: '26.2'
      
      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: deps-${{ runner.os }}-${{ hashFiles('**/mix.lock') }}
      
      - run: mix deps.get
      - run: mix ecto.create
      - run: mix ecto.migrate
      
      # Run tests with coverage
      - run: mix test --warnings-as-errors --cover
      
      # Upload coverage (optional)
      - uses: codecov/codecov-action@v3
        with:
          files: ./cover/excoveralls.json
      
      # Build Docker image
      - run: docker compose build --pull
```

### **What CI Tests**

- ✅ All tests pass
- ✅ No compiler warnings
- ✅ Code formatted correctly (`mix format --check-formatted`)
- ✅ Docker image builds successfully
- ✅ Database migrations apply cleanly
- ✅ Coverage above threshold (90%+)

---

## 🎯 Test-Driven Development (TDD)

### **Example: Adding a New Feature**

Let's add "payment cancellation" using TDD:

**Step 1: Write the test first (Red)**

```elixir
# test/ledger_bank_api/financial/financial_service_test.exs
describe "cancel_payment/1" do
  test "cancels pending payment" do
    payment = payment_fixture(%{status: "PENDING"})
    
    assert {:ok, cancelled_payment} = FinancialService.cancel_payment(payment.id)
    assert cancelled_payment.status == "CANCELLED"
  end
  
  test "returns error for already completed payment" do
    payment = payment_fixture(%{status: "COMPLETED"})
    
    assert {:error, error} = FinancialService.cancel_payment(payment.id)
    assert error.reason == :already_processed
  end
end
```

**Step 2: Run tests (they fail)**

```bash
mix test test/ledger_bank_api/financial/financial_service_test.exs:42
# Error: undefined function cancel_payment/1
```

**Step 3: Implement minimal code (Green)**

```elixir
# lib/ledger_bank_api/financial/financial_service.ex
def cancel_payment(payment_id) do
  with {:ok, payment} <- get_user_payment(payment_id),
       :ok <- validate_cancellable_status(payment) do
    payment
    |> UserPayment.changeset(%{status: "CANCELLED"})
    |> Repo.update()
  end
end

defp validate_cancellable_status(%{status: "PENDING"}), do: :ok
defp validate_cancellable_status(payment) do
  {:error, ErrorHandler.business_error(:already_processed, %{
    payment_id: payment.id,
    status: payment.status
  })}
end
```

**Step 4: Run tests (they pass)**

```bash
mix test test/ledger_bank_api/financial/financial_service_test.exs:42
# Green! ✅
```

**Step 5: Refactor (if needed)**

```elixir
# Add to ErrorCatalog if not present
:already_processed => :conflict

# Add policy check
def can_cancel_payment?(user, payment) do
  payment.status == "PENDING" and user.id == payment.user_id
end
```

**Step 6: Add controller test**

```elixir
test "DELETE /api/payments/:id cancels payment", %{conn: conn} do
  user = user_fixture()
  token = generate_token(user)
  payment = payment_fixture(user, %{status: "PENDING"})
  
  conn = conn
  |> put_req_header("authorization", "Bearer #{token}")
  |> delete("/api/payments/#{payment.id}")
  
  assert %{"data" => cancelled} = json_response(conn, 200)
  assert cancelled["status"] == "CANCELLED"
end
```

### **Testing Problem Registry Endpoints**

```elixir
# test/ledger_bank_api_web/controllers/problems_controller_test.exs
describe "GET /api/problems" do
  test "lists all problem types with categories", %{conn: conn} do
    conn = get(conn, ~p"/api/problems")
    
    assert %{"data" => data} = json_response(conn, 200)
    assert is_list(data["problems"])
    assert is_map(data["categories"])
    
    # Verify RFC 9457 compliance
    problem = List.first(data["problems"])
    assert Map.has_key?(problem, "type")
    assert Map.has_key?(problem, "title")
    assert Map.has_key?(problem, "status")
    assert Map.has_key?(problem, "code")
    assert Map.has_key?(problem, "category")
    assert Map.has_key?(problem, "retryable")
  end
end

describe "GET /api/problems/:reason" do
  test "returns detailed problem information", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/insufficient_funds")
    
    assert %{"data" => problem} = json_response(conn, 200)
    assert problem["code"] == "insufficient_funds"
    assert problem["type"] == "https://api.ledgerbank.com/problems/insufficient_funds"
    assert problem["status"] == 422
    assert problem["category"] == "business_rule"
    assert problem["retryable"] == false
    assert is_binary(problem["description"])
    assert is_list(problem["examples"])
  end
  
  test "returns 400 for invalid reason format", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/123invalid")
    
    assert json_response(conn, 400)
    content_type = get_resp_header(conn, "content-type") |> List.first()
    assert content_type == "application/problem+json; charset=utf-8"
  end
  
  test "returns 404 for non-existent reason", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/nonexistent_error")
    
    assert json_response(conn, 404)
    content_type = get_resp_header(conn, "content-type") |> List.first()
    assert content_type == "application/problem+json; charset=utf-8"
  end
end

describe "GET /api/problems/category/:category" do
  test "lists problems by category", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/category/business_rule")
    
    assert %{"data" => data} = json_response(conn, 200)
    assert data["category"] == "business_rule"
    assert is_list(data["problems"])
    
    # All problems should be in the specified category
    for problem <- data["problems"] do
      assert problem["category"] == "business_rule"
    end
  end
  
  test "returns 400 for invalid category format", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/category/123invalid")
    
    assert json_response(conn, 400)
    content_type = get_resp_header(conn, "content-type") |> List.first()
    assert content_type == "application/problem+json; charset=utf-8"
  end
  
  test "returns 404 for non-existent category", %{conn: conn} do
    conn = get(conn, ~p"/api/problems/category/nonexistent_category")
    
    assert json_response(conn, 404)
    content_type = get_resp_header(conn, "content-type") |> List.first()
    assert content_type == "application/problem+json; charset=utf-8"
  end
end
```

---

## 🐛 Debugging Test Failures

### **Common Issues**

**Issue: Tests fail randomly**
```bash
# Symptom: Tests pass alone but fail in suite
mix test test/path/to/test.exs  # ✅ Passes
mix test                         # ❌ Fails

# Cause: Shared state (ETS tables, cache, Oban)
# Fix: Clear state in setup or use ExUnit.Case instead of async: true
```

**Issue: Database errors**
```bash
# Symptom: "table does not exist"
# Fix: Run migrations
MIX_ENV=test mix ecto.migrate

# Or reset database
MIX_ENV=test mix ecto.reset
```

**Issue: Connection timeout**
```bash
# Symptom: "connection timeout"
# Fix: Increase pool size in test.exs
config :ledger_bank_api, LedgerBankApi.Repo,
  pool_size: 20  # Was: 10
```

### **Debugging Techniques**

**1. Use IEx in tests:**
```elixir
test "debug something" do
  user = user_fixture()
  
  require IEx; IEx.pry()  # Breakpoint here
  
  # When test runs, you'll drop into IEx
  # Type `user` to inspect, `continue` to proceed
end
```

**2. Print debugging:**
```elixir
test "debug with IO.inspect" do
  result = UserService.create_user(attrs)
  IO.inspect(result, label: "CREATE RESULT")
  
  # Or use pipe:
  result
  |> IO.inspect(label: "BEFORE ASSERTION")
  |> assert_success()
end
```

**3. Verbose mode:**
```bash
# Show all output
mix test --trace

# Show only failing test output
mix test --max-failures 1
```

---

## 📚 Test Documentation

### **Documenting Test Intent**

```elixir
@moduledoc """
Tests for UserService authentication logic.

Covers:
- User creation with various attribute combinations
- Email uniqueness validation
- Password hashing verification
- Constant-time authentication security
- Token generation and validation
"""

describe "authenticate_user/2" do
  @describetag :authentication
  
  test "returns user for valid credentials" do
    # Given a user exists with known credentials
    user = user_fixture(%{email: "test@example.com", password: "password123"})
    
    # When we authenticate with valid credentials
    result = UserService.authenticate_user("test@example.com", "password123")
    
    # Get the user back
    assert {:ok, authenticated_user} = result
    assert authenticated_user.id == user.id
  end
end
```

---

## 🎓 Learning Resources

### **Testing in Elixir**

**Books:**
- *Testing Elixir* by Andrea Leopardi & Jeffrey Matthias
- *Property-Based Testing with PropEr, Erlang, and Elixir* by Fred Hebert

**Blog Posts:**
- [Testing Phoenix Controllers](https://hexdocs.pm/phoenix/testing_controllers.html)
- [Mocking in Elixir with Mox](https://blog.appsignal.com/2020/03/10/how-to-use-mox-for-testing-in-elixir.html)
- [Testing Oban Workers](https://hexdocs.pm/oban/Oban.Testing.html)

**Videos:**
- ElixirConf talks on testing patterns
- Pragmatic Studio courses on TDD in Elixir

---

## ✅ Pre-Commit Checklist

Before committing code:

```bash
# 1. Format code
mix format

# 2. Run tests
mix test

# 3. Check for warnings
mix compile --warnings-as-errors

# 4. Check coverage (optional)
mix test --cover

# 5. Run specific test for your changes
mix test test/path/to/your_test.exs
```

---

## 🎉 Test Milestones

Track your testing progress:

- [ ] ✅ All existing tests pass
- [ ] ✅ Added tests for new features
- [ ] ✅ Security edge cases covered
- [ ] ✅ Performance tests prevent regressions
- [ ] ✅ Integration tests cover happy paths
- [ ] ✅ Error cases tested exhaustively
- [ ] ✅ CI pipeline passes on every commit
- [ ] ✅ Coverage above 90%

---

<div align="center">

**"Tests are the safety net that lets you refactor confidently."**

*This project has 1000+ tests. That's how I refactored 280 lines without fear.*

</div>


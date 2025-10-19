# ⚡ LedgerBank API Cheatsheet

Quick reference for common tasks and patterns.

---

## 🏃 Quick Commands

### **Setup & Running**

```bash
# First time setup
./test_setup.sh                    # Sets up everything
mix phx.server                     # Start server

# Development
mix deps.get                       # Install dependencies
mix ecto.migrate                   # Run migrations
mix run priv/repo/seeds.exs        # Seed data

# Testing
mix test                           # All tests
mix test --cover                   # With coverage
mix test path/to/test.exs:42       # Specific test

# Database
mix ecto.reset                     # Drop, create, migrate, seed
mix ecto.rollback                  # Rollback last migration
mix ecto.gen.migration name        # Create new migration

# Docker
docker compose up -d               # Start containers
docker compose logs -f web         # View logs
docker compose down                # Stop containers
```

---

## 🌐 API Endpoints

### **Base URL**
```
http://localhost:4000/api
```

### **Quick Test Sequence**

```bash
# 1. Login
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'

# Extract access_token from response, then:

# 2. Get profile
curl http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"

# 3. List users (admin only)
curl "http://localhost:4000/api/users?page=1&page_size=20" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"

# 4. Create payment
curl -X POST http://localhost:4000/api/payments \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount":"100.50",
    "direction":"DEBIT",
    "payment_type":"PAYMENT",
    "description":"Test payment",
    "user_bank_account_id":"UUID_HERE"
  }'
```

---

## 🔐 Authentication Examples

### **Register New User**
```bash
curl -X POST http://localhost:4000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email":"newuser@example.com",
    "full_name":"New User",
    "password":"password123",
    "password_confirmation":"password123"
  }'
```

### **Login & Get Tokens**
```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email":"newuser@example.com",
    "password":"password123"
  }' | jq '.data.access_token'
```

### **Refresh Token**
```bash
curl -X POST http://localhost:4000/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token":"YOUR_REFRESH_TOKEN"
  }'
```

### **Logout**
```bash
curl -X POST http://localhost:4000/api/auth/logout \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token":"YOUR_REFRESH_TOKEN"
  }'
```

---

## 💻 Code Patterns

### **Creating a New Service**

```elixir
defmodule LedgerBankApi.Context.FeatureService do
  @behaviour LedgerBankApi.Core.ServiceBehavior
  
  import Ecto.Query
  require LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Core.{ErrorHandler, ServiceBehavior}
  
  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "feature_service"
  
  def get_feature(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_feature, %{feature_id: id})
    ServiceBehavior.get_operation(Feature, id, :feature_not_found, context)
  end
  
  def create_feature(attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :create_feature, %{})
    ServiceBehavior.create_operation(&Feature.changeset(%Feature{}, &1), attrs, context)
  end
end
```

### **Creating a New Controller**

```elixir
defmodule LedgerBankApiWeb.Controllers.FeatureController do
  use LedgerBankApiWeb.Controllers.BaseController
  
  alias LedgerBankApi.Context.FeatureService
  alias LedgerBankApiWeb.Validation.InputValidator
  
  action_fallback LedgerBankApiWeb.FallbackController
  
  def show(conn, %{"id" => id}) do
    context = build_context(conn, :show_feature)
    
    validate_uuid_and_get(
      conn,
      context,
      id,
      &FeatureService.get_feature/1,
      fn feature ->
        handle_success(conn, feature)
      end
    )
  end
  
  def create(conn, params) do
    context = build_context(conn, :create_feature)
    
    validate_and_execute(
      conn,
      context,
      InputValidator.validate_feature_creation(params),
      &FeatureService.create_feature/1,
      fn feature ->
        conn
        |> put_status(:created)
        |> handle_success(feature)
      end
    )
  end
end
```

### **Creating a New Worker**

```elixir
defmodule LedgerBankApi.Workers.FeatureWorker do
  use LedgerBankApi.Core.WorkerBehavior,
    queue: :default,
    max_attempts: 5,
    tags: ["feature"]
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def worker_name, do: "FeatureWorker"
  
  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def perform_work(%{"feature_id" => id}, context) do
    with {:ok, feature} <- get_feature(id),
         {:ok, result} <- process_feature(feature) do
      {:ok, result}
    end
  end
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def extract_context_from_args(%{"feature_id" => id}) do
    %{feature_id: id}
  end
  
  # Schedule helpers
  def schedule(feature_id, opts \\ []) do
    %{"feature_id" => feature_id}
    |> new(opts)
    |> Oban.insert()
  end
end
```

### **Adding a New Error Reason**

```elixir
# 1. Add to ErrorCatalog
def reason_codes do
  %{
    # ... existing ...
    :feature_not_available => :business_rule  # Add this
  }
end

# 2. Add default message
def default_message_for_reason(reason) do
  case reason do
    # ... existing ...
    :feature_not_available -> "Feature not available for your account"
  end
end

# 3. Use in services
def do_feature(user) do
  if feature_available?(user) do
    {:ok, perform_feature(user)}
  else
    {:error, ErrorHandler.business_error(:feature_not_available, %{user_id: user.id})}
  end
end

# That's it! Automatically gets:
# - HTTP 422 (from :business_rule category)
# - retryable: false
# - telemetry emission
# - correlation ID
```

---

## 🧪 Testing Patterns

### **Unit Test Template**

```elixir
test "function does what it should" do
  # Arrange
  input = %{...}
  
  # Act
  result = Module.function(input)
  
  # Assert
  assert {:ok, output} = result
  assert output.field == expected_value
end
```

### **Controller Test Template**

```elixir
test "POST /endpoint creates resource", %{conn: conn} do
  # Arrange
  user = user_fixture()
  token = generate_token(user)
  params = %{...}
  
  # Act
  conn = conn
  |> put_req_header("authorization", "Bearer #{token}")
  |> post("/api/endpoint", params)
  
  # Assert
  assert %{"data" => data} = json_response(conn, 201)
  assert data["field"] == expected
end
```

### **Worker Test Template**

```elixir
test "worker processes job successfully" do
  # Arrange
  resource = create_resource()
  
  # Act
  assert {:ok, job} = Worker.schedule(resource.id)
  
  # Assert (Oban runs inline in tests)
  updated = Repo.get!(Resource, resource.id)
  assert updated.status == "PROCESSED"
end
```

---

## 🔧 IEx Helpers

### **Interactive Development**

```elixir
# Start IEx with app loaded
iex -S mix

# Useful commands in IEx:

# Reload module after editing
iex> r LedgerBankApi.Accounts.UserService

# Get function documentation
iex> h UserService.create_user

# Find functions
iex> exports UserService

# Test a function
iex> UserService.create_user(%{...})

# Query database
iex> LedgerBankApi.Repo.all(User)

# Clear ETS cache
iex> LedgerBankApi.Core.Cache.clear()

# Get cache stats
iex> LedgerBankApi.Core.Cache.stats()

# Schedule a job
iex> alias LedgerBankApi.Financial.Workers.PaymentWorker
iex> PaymentWorker.schedule_payment("payment-id")

# Check Oban jobs
iex> Oban.check_queue(queue: :payments)
```

---

## 📦 Database Operations

### **Migrations**

```bash
# Create migration
mix ecto.gen.migration add_field_to_table

# Run migrations
mix ecto.migrate

# Rollback
mix ecto.rollback
mix ecto.rollback --step 2      # Rollback 2 migrations
mix ecto.rollback --to 20250101 # Rollback to version

# Migration status
mix ecto.migrations

# Reset (drop + create + migrate + seed)
mix ecto.reset
```

### **Seeding**

```bash
# Run seeds
mix run priv/repo/seeds.exs

# Custom seed file
mix run priv/repo/custom_seeds.exs

# Seed in IEx
iex> Code.eval_file("priv/repo/seeds.exs")
```

### **Database Console**

```bash
# PostgreSQL console
docker compose exec db psql -U postgres -d ledger_bank_api_dev

# Common SQL commands
\dt                # List tables
\d users          # Describe users table
\di               # List indexes
SELECT COUNT(*) FROM users;
SELECT * FROM users LIMIT 5;
```

---

## 🔍 Debugging

### **Viewing Logs**

```bash
# Application logs
tail -f log/dev.log

# Docker logs
docker compose logs -f web

# Oban job logs
# Check Phoenix LiveDashboard at /dev/dashboard
```

### **Debugging in Tests**

```elixir
# Drop into IEx during test
test "debug something" do
  user = user_fixture()
  require IEx; IEx.pry()  # Breakpoint
  # Continue with 'continue' or 'respawn'
end

# Print debugging
test "inspect values" do
  result = do_something()
  IO.inspect(result, label: "RESULT")
end
```

---

## 🚨 Common Issues & Fixes

### **"Port 4000 already in use"**

```bash
# Find process using port
lsof -ti:4000  # macOS/Linux
netstat -ano | findstr :4000  # Windows

# Kill process
kill -9 $(lsof -ti:4000)  # macOS/Linux
```

### **"Database does not exist"**

```bash
mix ecto.create
```

### **"JWT_SECRET not configured"**

```bash
export JWT_SECRET="your-64-character-secret-here"
# Or add to .env file
```

### **"Oban jobs not running"**

```bash
# Check Oban configuration in config/test.exs
config :ledger_bank_api, Oban,
  testing: :inline  # Jobs run immediately in tests

# In dev, check queues are configured
config :ledger_bank_api, Oban,
  queues: [banking: 2, payments: 1]
```

### **Tests fail with "table does not exist"**

```bash
MIX_ENV=test mix ecto.reset
```

---

## 📊 Monitoring

### **Health Checks**

```bash
# Basic health
curl http://localhost:4000/api/health

# Detailed health (includes DB check)
curl http://localhost:4000/api/health/detailed

# Readiness (for load balancers)
curl http://localhost:4000/api/health/ready

# Liveness (for container orchestration)
curl http://localhost:4000/api/health/live
```

### **Error Discovery (Problem Registry)**

```bash
# List all error types
curl http://localhost:4000/api/problems

# Get specific error details
curl http://localhost:4000/api/problems/insufficient_funds

# List errors by category
curl http://localhost:4000/api/problems/category/business_rule
```

### **Phoenix LiveDashboard**

```
http://localhost:4000/dev/dashboard
```

Views:
- Request metrics
- Oban jobs
- ETS tables
- Processes
- Database connections

### **Cache Stats**

```elixir
# In IEx or via endpoint
LedgerBankApi.Core.Cache.stats()
# => %{
#   total_entries: 42,
#   active_entries: 38,
#   expired_entries: 4,
#   total_access_count: 1234,
#   average_access_count: 32.5,
#   adapter: "ets"
# }
```

---

## 🔐 Security

### **Generate Secrets**

```bash
# JWT secret (64 characters)
mix phx.gen.secret 64

# Phoenix secret key base
mix phx.gen.secret

# Random password for testing
openssl rand -base64 32
```

### **Check Security Headers**

```bash
curl -I http://localhost:4000/api/health

# Should see:
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: strict-origin-when-cross-origin
```

---

## 📝 Code Snippets

### **Handle Errors in Services**

```elixir
def operation(params) do
  context = ServiceBehavior.build_context(__MODULE__, :operation, %{})
  
  ServiceBehavior.with_error_handling(context, fn ->
    with {:ok, validated} <- validate(params),
         {:ok, result} <- perform_operation(validated) do
      {:ok, result}
    end
  end)
end
```

### **Add Policy Check**

```elixir
def operation(user, resource) do
  if Policy.can_do_operation?(user, resource) do
    {:ok, do_operation(resource)}
  else
    {:error, ErrorHandler.business_error(:insufficient_permissions, %{
      user_id: user.id,
      resource_id: resource.id
    })}
  end
end
```

### **Schedule Background Job**

```elixir
# In service
def create_payment(attrs) do
  with {:ok, payment} <- insert_payment(attrs) do
    # Schedule async processing
    PaymentWorker.schedule_payment(payment.id)
    {:ok, payment}
  end
end

# With priority (0 = highest)
PaymentWorker.schedule_payment_with_priority(payment.id, 0)

# With delay (seconds)
PaymentWorker.schedule_payment_with_delay(payment.id, 60)
```

### **Use Cache**

```elixir
def get_user(id) do
  cache_key = "user:#{id}"
  
  case Cache.get(cache_key) do
    {:ok, user} -> {:ok, user}
    :not_found ->
      case Repo.get(User, id) do
        nil -> {:error, :not_found}
        user ->
          Cache.put(cache_key, user, ttl: 300)  # 5 minutes
          {:ok, user}
      end
  end
end

# Or use get_or_put
Cache.get_or_put("user:#{id}", fn ->
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end, ttl: 300)
```

---

## 🏗️ Architecture Patterns

### **Service Layer Pattern**

```elixir
# Service implements ServiceBehavior
@behaviour ServiceBehavior

# Build context with correlation ID
context = ServiceBehavior.build_context(__MODULE__, :operation, extra_context)

# Use standard operations
ServiceBehavior.get_operation(Schema, id, :not_found_reason, context)
ServiceBehavior.create_operation(&Schema.changeset(%Schema{}, &1), attrs, context)
ServiceBehavior.update_operation(&Schema.changeset/2, resource, attrs, context)
ServiceBehavior.delete_operation(resource, context)
```

### **Policy Pattern**

```elixir
# Pure functions, no database
def can_do_action?(user, resource) do
  cond do
    user.role == "admin" -> true
    user.id == resource.user_id -> true
    true -> false
  end
end

# Use in services
if Policy.can_do_action?(user, resource) do
  {:ok, do_action(resource)}
else
  {:error, ErrorHandler.business_error(:insufficient_permissions, %{})}
end
```

### **Normalize Pattern**

```elixir
# Pure data transformation
def normalize_attrs(attrs) when is_map(attrs) do
  attrs
  |> Map.take(["field1", "field2"])
  |> normalize_field1()
  |> normalize_field2()
  |> add_defaults()
end

# Use before service calls
def create_resource(attrs) do
  normalized = Normalize.normalize_attrs(attrs)
  Service.create(normalized)
end
```

---

## 🎯 Error Handling

### **Return Error from Service**

```elixir
# Business error
{:error, ErrorHandler.business_error(:insufficient_funds, %{
  account_id: account.id,
  balance: account.balance,
  requested: amount
})}

# Validation error
{:error, ErrorHandler.business_error(:invalid_email_format, %{
  field: "email",
  value: email
})}

# External error (retryable)
{:error, ErrorHandler.retryable_error(:bank_api_error, %{
  service: "monzo",
  endpoint: "/accounts"
})}
```

### **Error Response Format**

```json
{
  "error": {
    "type": "unprocessable_entity",
    "message": "Insufficient funds for this transaction",
    "code": 422,
    "reason": "insufficient_funds",
    "details": {
      "account_id": "uuid",
      "balance": "50.00",
      "requested": "100.00"
    },
    "timestamp": "2025-10-14T12:00:00Z"
  }
}
```

---

## 🔄 Background Jobs

### **Schedule Jobs**

```elixir
# Payment processing
PaymentWorker.schedule_payment(payment_id)

# Bank sync
BankSyncWorker.schedule_sync(login_id)

# With options
Worker.schedule(id, [
  priority: 0,              # 0-9, 0 = highest
  schedule_in: 60,          # Delay in seconds
  max_attempts: 3,          # Override default
  tags: ["urgent"]          # Custom tags
])
```

### **Check Job Status**

```elixir
# Get job status
{:ok, status} = PaymentWorker.get_payment_job_status(payment_id)

# Cancel job
{:ok, :cancelled} = PaymentWorker.cancel_payment_job(payment_id)

# View jobs in LiveDashboard
http://localhost:4000/dev/dashboard/oban
```

---

## 🌐 API Response Formats

### **Success Response**

```json
{
  "data": {...},
  "success": true,
  "timestamp": "2025-10-14T12:00:00Z",
  "correlation_id": "abc123",
  "metadata": {
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_count": 100
    }
  }
}
```

### **Error Response**

```json
{
  "error": {
    "type": "validation_error",
    "message": "Email already exists",
    "code": 400,
    "reason": "email_already_exists",
    "details": {"field": "email"},
    "timestamp": "2025-10-14T12:00:00Z"
  }
}
```

### **List Response**

```json
{
  "data": [...],
  "success": true,
  "timestamp": "2025-10-14T12:00:00Z",
  "metadata": {
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_count": 100,
      "total_pages": 5,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

---

## 🎨 Code Quality

### **Formatting**

```bash
# Format all files
mix format

# Check formatting
mix format --check-formatted

# Format specific files
mix format lib/ledger_bank_api/accounts/*.ex
```

### **Compilation**

```bash
# Compile with warnings
mix compile

# Treat warnings as errors
mix compile --warnings-as-errors

# Clean build
mix clean && mix compile
```

---

## 🐳 Docker

### **Development**

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f

# Restart service
docker compose restart web

# Exec into container
docker compose exec web bash

# Stop services
docker compose down

# Remove volumes (fresh start)
docker compose down -v
```

### **Production Build**

```bash
# Build image
docker build -t ledger-bank-api:latest .

# Run migrations in container
docker compose exec web /app/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

# View container logs
docker logs -f container_id
```

---

## 🎯 Git Workflow

### **Feature Branch**

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes, commit
git add .
git commit -m "Add my feature"

# Push
git push origin feature/my-feature

# Create PR on GitHub
```

### **Commit Message Format**

```
<type>: <subject>

<body>

Types:
- feat: New feature
- fix: Bug fix
- refactor: Code refactoring
- test: Adding tests
- docs: Documentation changes
- chore: Maintenance tasks

Example:
feat: Add payment cancellation endpoint

- Add cancel_payment/1 to FinancialService
- Add DELETE /api/payments/:id route
- Add policy check for cancellation
- Add tests for cancellation flow
```

---

## 📖 Documentation

### **Generate API Docs**

```bash
# Generate OpenAPI spec (if using phoenix_swagger)
mix swagger.generate

# View docs locally
open http://localhost:4000/api/docs
```

### **Module Documentation**

```elixir
@moduledoc """
Brief description of module purpose.

## Usage

    iex> Module.function(arg)
    {:ok, result}

## Examples

    # Create a user
    {:ok, user} = UserService.create_user(%{...})
"""

@doc """
Function documentation.

Returns `{:ok, result}` on success or `{:error, %Error{}}` on failure.

## Examples

    iex> create_user(%{email: "test@example.com"})
    {:ok, %User{}}
"""
```

---

## 🎓 Learning Resources

### **When Stuck**

1. **Check the docs folder:**
   - `docs/ARCHITECTURE_IMPROVEMENTS.md` - Pattern explanations
   - `docs/QUICK_REFERENCE_PATTERNS.md` - Code examples
   - `docs/IMPLEMENTATION_SUMMARY.md` - Feature documentation

2. **Use IEx:**
   ```elixir
   iex> h ModuleName
   iex> h ModuleName.function
   ```

3. **Read tests:**
   - Tests are executable documentation
   - See `test/` directory for examples

4. **External docs:**
   - [Phoenix Guides](https://hexdocs.pm/phoenix/)
   - [Ecto Documentation](https://hexdocs.pm/ecto/)
   - [Oban Guides](https://hexdocs.pm/oban/)

---

## ⚡ Performance Tips

### **Database Query Optimization**

```elixir
# Avoid N+1 queries - use preload
users = Repo.all(User) |> Repo.preload(:refresh_tokens)

# Use indexes
# Migrations should have:
create index(:users, [:email])
create index(:users, [:status, :role])  # Composite index

# Use limit for large datasets
query |> limit(100) |> Repo.all()
```

### **Caching**

```elixir
# Cache expensive operations
def get_user_stats do
  Cache.get_or_put("user_stats", fn ->
    {:ok, compute_expensive_stats()}
  end, ttl: 300)
end

# Clear cache after updates
def update_user(user, attrs) do
  with {:ok, updated} <- Repo.update(User.changeset(user, attrs)) do
    Cache.delete("user:#{user.id}")
    {:ok, updated}
  end
end
```

---

## 🎉 Quick Wins

### **Add New Endpoint in 5 Minutes**

1. **Add route:**
   ```elixir
   # router.ex
   get "/features", FeatureController, :index
   ```

2. **Create controller:**
   ```elixir
   def index(conn, _params) do
     features = FeatureService.list_features()
     handle_success(conn, features)
   end
   ```

3. **Create service:**
   ```elixir
   def list_features do
     Repo.all(Feature)
   end
   ```

4. **Test:**
   ```bash
   curl http://localhost:4000/api/features
   ```

### **Add Background Job in 10 Minutes**

See "Creating a New Worker" pattern above. Copy `PaymentWorker`, change names, done!

---

<div align="center">

**💡 Pro Tip:** Keep this cheatsheet open while developing!

[Back to Main README](../README.md)

</div>


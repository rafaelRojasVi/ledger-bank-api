# 👨‍💻 Developer Guide

Code patterns, conventions, and workflows for contributing to LedgerBank API.

## 🎯 **Code Organization**

### **Directory Structure**

```
lib/ledger_bank_api/
├── accounts/                 # User management domain
│   ├── schemas/             # Ecto schemas
│   ├── user_service.ex      # Business logic
│   ├── auth_service.ex      # Authentication
│   ├── policy.ex            # Authorization rules
│   └── normalize.ex         # Data transformation
├── financial/               # Banking domain
│   ├── schemas/             # Payment, Account schemas
│   ├── financial_service.ex # Business logic
│   ├── workers/             # Background jobs
│   └── integrations/        # External APIs
├── core/                    # Shared infrastructure
│   ├── error_catalog.ex     # Error taxonomy
│   ├── worker_behavior.ex   # Worker pattern
│   ├── schema_helpers.ex    # Validation helpers
│   └── cache_adapter.ex     # Cache abstraction
└── application.ex           # OTP application
```

### **Layer Responsibilities**

| Layer | Responsibility | Examples |
|-------|---------------|----------|
| **Web** | HTTP handling, input validation | Controllers, Plugs, InputValidator |
| **Business** | Domain logic, orchestration | Services, Policies, Normalize |
| **Data** | Persistence, queries | Schemas, Repo, Workers |
| **Infrastructure** | Cross-cutting concerns | Cache, Error handling, Telemetry |

## 🏗️ **Code Patterns**

### **Creating a New Service**

```elixir
defmodule LedgerBankApi.Accounts.UserService do
  @behaviour LedgerBankApi.Core.ServiceBehavior
  
  import Ecto.Query
  require LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Core.{ErrorHandler, ServiceBehavior}
  alias LedgerBankApi.Accounts.{Schemas.User, Policy, Normalize}
  
  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "user_service"
  
  def get_user(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user, %{user_id: id})
    ServiceBehavior.get_operation(User, id, :user_not_found, context)
  end
  
  def create_user(attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :create_user, %{})
    
    ServiceBehavior.with_error_handling(context, fn ->
      with {:ok, normalized_attrs} <- normalize_user_attrs(attrs),
           {:ok, user} <- insert_user(normalized_attrs) do
        {:ok, user}
      end
    end)
  end
  
  def update_user(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user, %{user_id: user.id})
    
    ServiceBehavior.with_error_handling(context, fn ->
      with {:ok, normalized_attrs} <- normalize_user_attrs(attrs),
           {:ok, updated_user} <- update_user_record(user, normalized_attrs) do
        {:ok, updated_user}
      end
    end)
  end
  
  # Private functions
  defp normalize_user_attrs(attrs) do
    {:ok, Normalize.user_attrs(attrs)}
  end
  
  defp insert_user(attrs) do
    changeset = User.changeset(%User{}, attrs)
    ServiceBehavior.create_operation(&User.changeset(%User{}, &1), attrs, context)
  end
  
  defp update_user_record(user, attrs) do
    changeset = User.changeset(user, attrs)
    ServiceBehavior.update_operation(&User.changeset/2, user, attrs, context)
  end
end
```

### **Creating a New Controller**

```elixir
defmodule LedgerBankApiWeb.Controllers.UsersController do
  use LedgerBankApiWeb.Controllers.BaseController
  
  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApiWeb.Validation.InputValidator
  
  action_fallback LedgerBankApiWeb.FallbackController
  
  def show(conn, %{"id" => id}) do
    context = build_context(conn, :show_user)
    
    validate_uuid_and_get(
      conn,
      context,
      id,
      &UserService.get_user/1,
      fn user ->
        handle_success(conn, user)
      end
    )
  end
  
  def create(conn, params) do
    context = build_context(conn, :create_user)
    
    validate_and_execute(
      conn,
      context,
      InputValidator.validate_user_creation(params),
      &UserService.create_user/1,
      fn user ->
        conn
        |> put_status(:created)
        |> handle_success(user)
      end
    )
  end
  
  def update(conn, %{"id" => id} = params) do
    context = build_context(conn, :update_user)
    
    with {:ok, user} <- UserService.get_user(id),
         {:ok, validated_params} <- InputValidator.validate_user_update(params),
         {:ok, updated_user} <- UserService.update_user(user, validated_params) do
      handle_success(conn, updated_user)
    end
  end
end
```

### **Creating a New Worker**

```elixir
defmodule LedgerBankApi.Financial.Workers.PaymentWorker do
  use LedgerBankApi.Core.WorkerBehavior,
    queue: :payments,
    max_attempts: 5,
    priority: 0,
    tags: ["payment", "financial"]
  
  alias LedgerBankApi.Financial.FinancialService
  alias LedgerBankApi.Core.ErrorHandler
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def worker_name, do: "payment_worker"
  
  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def perform_work(%{"payment_id" => payment_id}, context) do
    with {:ok, payment} <- fetch_payment(payment_id, context),
         {:ok, result} <- process_payment(payment, context) do
      {:ok, result}
    end
  end
  
  @impl LedgerBankApi.Core.WorkerBehavior
  def extract_context_from_args(%{"payment_id" => payment_id}) do
    %{payment_id: payment_id}
  end
  
  # Scheduling helpers
  def schedule_payment(payment_id, opts \\ []) do
    %{"payment_id" => payment_id}
    |> new(opts)
    |> Oban.insert()
  end
  
  def schedule_payment_with_priority(payment_id, priority, opts \\ []) do
    schedule_payment(payment_id, Keyword.put(opts, :priority, priority))
  end
  
  def schedule_payment_with_delay(payment_id, delay_seconds, opts \\ []) do
    schedule_at = DateTime.add(DateTime.utc_now(), delay_seconds, :second)
    schedule_payment(payment_id, Keyword.put(opts, :schedule_in, schedule_at))
  end
  
  # Private functions
  defp fetch_payment(payment_id, context) do
    case FinancialService.get_payment(payment_id) do
      {:ok, payment} -> {:ok, payment}
      {:error, :payment_not_found} -> 
        {:error, ErrorHandler.business_error(:payment_not_found, context)}
      {:error, reason} -> 
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end
  
  defp process_payment(payment, context) do
    # Your business logic here
    # Return: {:ok, result} | {:error, %Error{}}
  end
end
```

### **Creating a New Schema**

```elixir
defmodule LedgerBankApi.Financial.Schemas.Payment do
  use LedgerBankApi.Core.SchemaHelpers
  
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "payments" do
    field :amount, :decimal
    field :direction, :string
    field :payment_type, :string
    field :status, :string, default: "PENDING"
    field :description, :string
    field :posted_at, :utc_datetime
    
    belongs_to :user_bank_account, LedgerBankApi.Financial.Schemas.UserBankAccount
    belongs_to :user, LedgerBankApi.Accounts.Schemas.User
    
    timestamps(type: :utc_datetime)
  end
  
  @fields [:amount, :direction, :payment_type, :status, :description, :posted_at, :user_bank_account_id, :user_id]
  @required_fields [:amount, :direction, :payment_type, :user_bank_account_id, :user_id]
  
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_amount_positive(:amount)
    |> validate_direction_field(:direction)
    |> validate_payment_type_field(:payment_type)
    |> validate_status_field(:status)
    |> validate_description_length(:description)
    |> validate_not_future(:posted_at)
    |> foreign_key_constraint(:user_bank_account_id)
    |> foreign_key_constraint(:user_id)
  end
  
  def create_changeset(struct, attrs) do
    struct
    |> changeset(attrs)
    |> put_change(:status, "PENDING")
    |> put_change(:posted_at, DateTime.utc_now())
  end
  
  def update_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:status, :description])
    |> validate_status_field(:status)
    |> validate_description_length(:description)
  end
end
```

## 🧪 **Testing Patterns**

### **Service Tests**

```elixir
defmodule LedgerBankApi.Accounts.UserServiceTest do
  use LedgerBankApi.DataCase, async: true
  
  alias LedgerBankApi.Accounts.{UserService, Schemas.User}
  alias LedgerBankApi.Core.ErrorHandler
  
  describe "create_user/1" do
    test "creates user with valid attributes" do
      attrs = %{
        email: "test@example.com",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      }
      
      assert {:ok, %User{} = user} = UserService.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.full_name == "Test User"
      assert user.role == "user"
      assert user.status == "ACTIVE"
    end
    
    test "returns error with invalid attributes" do
      attrs = %{email: "invalid-email"}
      
      assert {:error, %ErrorHandler{} = error} = UserService.create_user(attrs)
      assert error.reason == :missing_fields
      assert error.category == :validation
    end
    
    test "returns error when email already exists" do
      existing_user = user_fixture()
      attrs = %{
        email: existing_user.email,
        full_name: "Another User",
        password: "password123",
        password_confirmation: "password123"
      }
      
      assert {:error, %ErrorHandler{} = error} = UserService.create_user(attrs)
      assert error.reason == :email_already_exists
      assert error.category == :conflict
    end
  end
end
```

### **Controller Tests**

```elixir
defmodule LedgerBankApiWeb.Controllers.UsersControllerTest do
  use LedgerBankApiWeb.ConnCase, async: true
  
  alias LedgerBankApi.Accounts.Schemas.User
  
  describe "POST /api/users" do
    test "creates user with valid data", %{conn: conn} do
      user_attrs = %{
        email: "test@example.com",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      }
      
      conn = post(conn, ~p"/api/users", user_attrs)
      
      assert %{"data" => data} = json_response(conn, 201)
      assert data["email"] == "test@example.com"
      assert data["full_name"] == "Test User"
      assert data["role"] == "user"
      assert data["status"] == "ACTIVE"
    end
    
    test "returns error with invalid data", %{conn: conn} do
      user_attrs = %{email: "invalid-email"}
      
      conn = post(conn, ~p"/api/users", user_attrs)
      
      assert %{"error" => error} = json_response(conn, 400)
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end
  end
  
  describe "GET /api/users/:id" do
    test "returns user when authenticated as owner", %{conn: conn} do
      user = user_fixture()
      token = generate_token(user)
      
      conn = 
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")
      
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == user.id
      assert data["email"] == user.email
    end
    
    test "returns error when not authenticated", %{conn: conn} do
      user = user_fixture()
      
      conn = get(conn, ~p"/api/users/#{user.id}")
      
      assert %{"error" => error} = json_response(conn, 401)
      assert error["type"] == "unauthorized"
    end
  end
end
```

### **Worker Tests**

```elixir
defmodule LedgerBankApi.Financial.Workers.PaymentWorkerTest do
  use LedgerBankApi.DataCase, async: true
  use Oban.Testing, repo: LedgerBankApi.Repo
  
  alias LedgerBankApi.Financial.{Workers.PaymentWorker, Schemas.Payment}
  
  describe "perform_work/2" do
    test "processes payment successfully" do
      payment = payment_fixture()
      
      assert {:ok, job} = PaymentWorker.schedule_payment(payment.id)
      
      # Oban runs jobs inline in test environment
      assert :ok = perform_job(job, PaymentWorker)
      
      # Verify payment was processed
      updated_payment = Repo.get!(Payment, payment.id)
      assert updated_payment.status == "COMPLETED"
    end
    
    test "handles payment not found" do
      fake_payment_id = Ecto.UUID.generate()
      
      assert {:ok, job} = PaymentWorker.schedule_payment(fake_payment_id)
      
      assert {:error, %ErrorHandler{} = error} = perform_job(job, PaymentWorker)
      assert error.reason == :payment_not_found
    end
  end
end
```

## 🔧 **Development Workflow**

### **Setting Up Development Environment**

```bash
# 1. Clone and setup
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api
./test_setup.sh

# 2. Start development server
mix phx.server

# 3. Run tests
mix test

# 4. Format code
mix format

# 5. Check for warnings
mix compile --warnings-as-errors
```

### **Git Workflow**

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat: add payment cancellation endpoint"

# 3. Push and create PR
git push origin feature/my-feature
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
feat: add payment cancellation endpoint

- Add cancel_payment/1 to FinancialService
- Add DELETE /api/payments/:id route
- Add policy check for cancellation
- Add tests for cancellation flow
```

## 📝 **Code Style Guide**

### **Naming Conventions**

- **Modules:** `LedgerBankApi.Context.ModuleName`
- **Functions:** `snake_case`
- **Variables:** `snake_case`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Private functions:** `defp` with descriptive names

### **Function Organization**

```elixir
defmodule MyModule do
  # 1. Module attributes
  @moduledoc "..."
  @behaviour SomeBehaviour
  
  # 2. Imports and aliases
  import Ecto.Query
  alias MyApp.SomeModule
  
  # 3. Public functions (grouped by purpose)
  def public_function_1, do: ...
  def public_function_2, do: ...
  
  # 4. Private functions (grouped by purpose)
  defp private_function_1, do: ...
  defp private_function_2, do: ...
end
```

### **Documentation Standards**

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
def create_user(attrs) do
  # Implementation
end
```

## 🐛 **Debugging**

### **IEx Helpers**

```elixir
# Start IEx with app loaded
iex -S mix

# Useful commands
iex> h UserService.create_user  # Get help
iex> r UserService             # Reload module
iex> LedgerBankApi.Repo.all(User)  # Query database
iex> LedgerBankApi.Core.Cache.stats()  # Check cache
```

### **Common Debugging Techniques**

```elixir
# 1. Add logging
require Logger
Logger.info("Processing payment", %{payment_id: payment.id})

# 2. Use IEx.pry for debugging
def process_payment(payment) do
  require IEx; IEx.pry()  # Breakpoint
  # Continue with 'continue' or 'respawn'
end

# 3. Inspect values
IO.inspect(payment, label: "PAYMENT")

# 4. Check database state
LedgerBankApi.Repo.all(Payment) |> IO.inspect()
```

## 🚀 **Performance Tips**

### **Database Queries**

```elixir
# Good: Use preload to avoid N+1 queries
users = Repo.all(User) |> Repo.preload(:refresh_tokens)

# Good: Use indexes
create index(:users, [:email])
create index(:users, [:status, :role])  # Composite index

# Good: Use limit for large datasets
query |> limit(100) |> Repo.all()

# Good: Use keyset pagination
query |> where([u], u.id > ^cursor) |> limit(20)
```

### **Caching**

```elixir
# Good: Cache expensive operations
def get_user_stats do
  Cache.get_or_put("user_stats", fn ->
    {:ok, compute_expensive_stats()}
  end, ttl: 300)
end

# Good: Clear cache after updates
def update_user(user, attrs) do
  with {:ok, updated} <- Repo.update(User.changeset(user, attrs)) do
    Cache.delete("user:#{user.id}")
    {:ok, updated}
  end
end
```

## 🔍 **Code Review Checklist**

### **Before Submitting PR**

- [ ] All tests pass (`mix test`)
- [ ] Code is formatted (`mix format`)
- [ ] No compiler warnings (`mix compile --warnings-as-errors`)
- [ ] Added tests for new functionality
- [ ] Updated documentation if needed
- [ ] Follows naming conventions
- [ ] Uses appropriate error handling
- [ ] No hardcoded values (use config)
- [ ] Proper logging for debugging

### **Review Focus Areas**

- **Architecture:** Does it follow clean architecture principles?
- **Error Handling:** Uses ErrorCatalog and proper error types?
- **Testing:** Adequate test coverage and quality?
- **Performance:** Any obvious performance issues?
- **Security:** Proper input validation and authorization?
- **Documentation:** Clear and helpful documentation?

---

**Happy coding! 🚀**

defmodule LedgerBankApiWeb.Router do
  @moduledoc """
  Router for the bank API with proper authentication and authorization.
  """

  use LedgerBankApiWeb, :router
  import Phoenix.LiveDashboard.Router

  # Suppress false positive warnings for Absinthe.Plug modules
  # The compiler incorrectly looks for these in the LedgerBankApiWeb namespace
  @compile {:no_warn_undefined,
            [LedgerBankApiWeb.Absinthe.Plug, LedgerBankApiWeb.Absinthe.Plug.GraphiQL]}

  pipeline :api do
    plug(:accepts, ["json"])
    # Add distributed tracing for observability
    plug(LedgerBankApiWeb.Plugs.Tracing)
    # Add request size limits for DoS protection
    plug(LedgerBankApiWeb.Plugs.RequestSizeLimit)
    # Add CORS support for cross-origin requests
    plug(LedgerBankApiWeb.Plugs.Cors)
    # Add API versioning support
    plug(LedgerBankApiWeb.Plugs.ApiVersion)
    # Add security headers to all API endpoints
    plug(LedgerBankApiWeb.Plugs.SecurityHeaders)
    # Add security audit logging
    plug(LedgerBankApiWeb.Plugs.SecurityAudit)
    # Add rate limiting to all API endpoints (disabled in test environment)
    if Mix.env() != :test do
      plug(LedgerBankApiWeb.Plugs.RateLimit, max_requests: 100, window_size: 60_000)
    end
  end

  # Minimal browser pipeline for LiveDashboard only (dev/test)
  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
  end

  pipeline :authenticated do
    plug(LedgerBankApiWeb.Plugs.Authenticate)
  end

  pipeline :admin_only do
    plug(LedgerBankApiWeb.Plugs.Authorize, roles: ["admin"])
  end

  pipeline :admin_or_support do
    plug(LedgerBankApiWeb.Plugs.Authorize, roles: ["admin", "support"])
  end

  pipeline :user_or_admin do
    plug(LedgerBankApiWeb.Plugs.Authorize, roles: ["admin", "user", "support"], allow_self: true)
  end

  # Versioned API routes (current and v1)
  scope "/api/v1", LedgerBankApiWeb do
    pipe_through(:api)

    # Health check endpoints (public)
    get("/health", HealthController, :index)
    get("/health/detailed", HealthController, :detailed)
    get("/health/ready", HealthController, :ready)
    get("/health/live", HealthController, :live)

    # Prometheus metrics endpoints (public)
    get("/metrics", Controllers.MetricsController, :index)
    get("/metrics/health", Controllers.MetricsController, :health)

    # API Documentation endpoints (public)
    get("/docs", ApiDocsController, :swagger_ui)
    get("/docs/openapi.json", ApiDocsController, :openapi_spec)

    # Error catalog registry endpoints (public)
    get("/problems", Controllers.ProblemsController, :index)
    get("/problems/:reason", Controllers.ProblemsController, :show)
    get("/problems/category/:category", Controllers.ProblemsController, :category)

    # Webhook endpoints (public, but require signature verification)
    get("/webhooks", Controllers.WebhooksController, :index)
    post("/webhooks/:provider", Controllers.WebhooksController, :handle_webhook)
    post("/webhooks/payments/status", Controllers.WebhooksController, :handle_payment_status)
    post("/webhooks/banks/sync", Controllers.WebhooksController, :handle_account_sync)
    post("/webhooks/fraud/detection", Controllers.WebhooksController, :handle_fraud_detection)

    # GraphQL endpoints
    forward("/graphql", Absinthe.Plug,
      schema: LedgerBankApiWeb.Schema,
      context: &LedgerBankApiWeb.Context.build_context/1
    )

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: LedgerBankApiWeb.Schema,
      context: &LedgerBankApiWeb.Context.build_context/1,
      interface: :simple
    )

    # Authentication endpoints (public)
    post("/auth/login", Controllers.AuthController, :login)
    post("/auth/refresh", Controllers.AuthController, :refresh)
    post("/auth/logout", Controllers.AuthController, :logout)

    # Protected authentication endpoints
    scope "/auth" do
      pipe_through(:authenticated)

      post("/logout-all", Controllers.AuthController, :logout_all)
      get("/me", Controllers.AuthController, :me)
      get("/validate", Controllers.AuthController, :validate)
    end

    # User management endpoints with proper authorization
    scope "/users" do
      # Public user creation (registration) - role forced to "user"
      post("/", Controllers.UsersController, :create)

      # Admin-only user management
      pipe_through([:authenticated, :admin_only])

      post("/admin", Controllers.UsersController, :create_as_admin)
      get("/", Controllers.UsersController, :index)
      get("/keyset", Controllers.UsersController, :index_keyset)
      get("/stats", Controllers.UsersController, :stats)
      get("/:id", Controllers.UsersController, :show)
      put("/:id", Controllers.UsersController, :update)
      delete("/:id", Controllers.UsersController, :delete)
    end

    # User profile management (users can manage their own profile)
    scope "/profile" do
      pipe_through([:authenticated, :user_or_admin])

      get("/", Controllers.UsersController, :show_profile)
      put("/", Controllers.UsersController, :update_profile)
      put("/password", Controllers.UsersController, :update_password)
    end

    # Financial endpoints (payments, accounts, transactions)
    scope "/payments" do
      pipe_through([:authenticated, :user_or_admin])

      post("/", Controllers.PaymentsController, :create)
      get("/", Controllers.PaymentsController, :index)
      get("/stats", Controllers.PaymentsController, :stats)
      post("/validate", Controllers.PaymentsController, :validate)
      get("/:id", Controllers.PaymentsController, :show)
      post("/:id/process", Controllers.PaymentsController, :process)
      get("/:id/status", Controllers.PaymentsController, :status)
      delete("/:id", Controllers.PaymentsController, :delete)
    end
  end

  # Legacy API routes (backward compatibility - defaults to v1)
  scope "/api", LedgerBankApiWeb do
    pipe_through(:api)

    # Health check endpoints (public)
    get("/health", HealthController, :index)
    get("/health/detailed", HealthController, :detailed)
    get("/health/ready", HealthController, :ready)
    get("/health/live", HealthController, :live)

    # Prometheus metrics endpoints (public)
    get("/metrics", Controllers.MetricsController, :index)
    get("/metrics/health", Controllers.MetricsController, :health)

    # API Documentation endpoints (public)
    get("/docs", ApiDocsController, :swagger_ui)
    get("/docs/openapi.json", ApiDocsController, :openapi_spec)

    # Error catalog registry endpoints (public)
    get("/problems", Controllers.ProblemsController, :index)
    get("/problems/:reason", Controllers.ProblemsController, :show)
    get("/problems/category/:category", Controllers.ProblemsController, :category)

    # Webhook endpoints (public, but require signature verification)
    get("/webhooks", Controllers.WebhooksController, :index)
    post("/webhooks/:provider", Controllers.WebhooksController, :handle_webhook)
    post("/webhooks/payments/status", Controllers.WebhooksController, :handle_payment_status)
    post("/webhooks/banks/sync", Controllers.WebhooksController, :handle_account_sync)
    post("/webhooks/fraud/detection", Controllers.WebhooksController, :handle_fraud_detection)

    # Authentication endpoints (public)
    post("/auth/login", Controllers.AuthController, :login)
    post("/auth/refresh", Controllers.AuthController, :refresh)
    post("/auth/logout", Controllers.AuthController, :logout)

    # Protected authentication endpoints
    scope "/auth" do
      pipe_through(:authenticated)

      post("/logout-all", Controllers.AuthController, :logout_all)
      get("/me", Controllers.AuthController, :me)
      get("/validate", Controllers.AuthController, :validate)
    end

    # User management endpoints with proper authorization
    scope "/users" do
      # Public user creation (registration) - role forced to "user"
      post("/", Controllers.UsersController, :create)

      # Admin-only user management
      pipe_through([:authenticated, :admin_only])

      post("/admin", Controllers.UsersController, :create_as_admin)
      get("/", Controllers.UsersController, :index)
      get("/keyset", Controllers.UsersController, :index_keyset)
      get("/stats", Controllers.UsersController, :stats)
      get("/:id", Controllers.UsersController, :show)
      put("/:id", Controllers.UsersController, :update)
      delete("/:id", Controllers.UsersController, :delete)
    end

    # User profile management (users can manage their own profile)
    scope "/profile" do
      pipe_through([:authenticated, :user_or_admin])

      get("/", Controllers.UsersController, :show_profile)
      put("/", Controllers.UsersController, :update_profile)
      put("/password", Controllers.UsersController, :update_password)
    end

    # Financial endpoints (payments, accounts, transactions)
    scope "/payments" do
      pipe_through([:authenticated, :user_or_admin])

      post("/", Controllers.PaymentsController, :create)
      get("/", Controllers.PaymentsController, :index)
      get("/stats", Controllers.PaymentsController, :stats)
      post("/validate", Controllers.PaymentsController, :validate)
      get("/:id", Controllers.PaymentsController, :show)
      post("/:id/process", Controllers.PaymentsController, :process)
      get("/:id/status", Controllers.PaymentsController, :status)
      delete("/:id", Controllers.PaymentsController, :delete)
    end
  end

  # Enable LiveDashboard in development and test
  if Mix.env() in [:dev, :test] do
    scope "/" do
      pipe_through(:browser)

      live_dashboard("/dashboard",
        metrics: LedgerBankApiWeb.Telemetry,
        ecto_repos: [LedgerBankApi.Repo]
      )
    end
  end
end

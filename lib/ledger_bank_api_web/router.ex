defmodule LedgerBankApiWeb.Router do
  @moduledoc """
  Router for the bank API with proper authentication and authorization.
  """

  use LedgerBankApiWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :api do
    plug :accepts, ["json"]
    # Add security headers to all API endpoints
    plug LedgerBankApiWeb.Plugs.SecurityHeaders
    # Add security audit logging
    plug LedgerBankApiWeb.Plugs.SecurityAudit
    # Add rate limiting to all API endpoints (disabled in test environment)
    if Mix.env() != :test do
      plug LedgerBankApiWeb.Plugs.RateLimit, max_requests: 100, window_size: 60_000
    end
  end

  # Minimal browser pipeline for LiveDashboard only (dev/test)
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
  end

  pipeline :authenticated do
    plug LedgerBankApiWeb.Plugs.Authenticate
  end

  pipeline :admin_only do
    plug LedgerBankApiWeb.Plugs.Authorize, roles: ["admin"]
  end

  pipeline :admin_or_support do
    plug LedgerBankApiWeb.Plugs.Authorize, roles: ["admin", "support"]
  end

  pipeline :user_or_admin do
    plug LedgerBankApiWeb.Plugs.Authorize, roles: ["admin", "user", "support"], allow_self: true
  end

  scope "/api", LedgerBankApiWeb do
    pipe_through :api

    # Health check endpoints (public)
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :detailed
    get "/health/ready", HealthController, :ready
    get "/health/live", HealthController, :live

    # API Documentation endpoints (public) - TODO: Fix controller compilation
    # get "/docs", Controllers.ApiDocsController, :swagger_ui
    # get "/docs/openapi.json", Controllers.ApiDocsController, :openapi_spec

    # Authentication endpoints (public)
    post "/auth/login", Controllers.AuthController, :login
    post "/auth/refresh", Controllers.AuthController, :refresh
    post "/auth/logout", Controllers.AuthController, :logout

    # Protected authentication endpoints
    scope "/auth" do
      pipe_through :authenticated

      post "/logout-all", Controllers.AuthController, :logout_all
      get "/me", Controllers.AuthController, :me
      get "/validate", Controllers.AuthController, :validate
    end

    # User management endpoints with proper authorization
    scope "/users" do
      # Public user creation (registration) - role forced to "user"
      post "/", Controllers.UsersController, :create

      # Admin-only user management
      pipe_through [:authenticated, :admin_only]

      post "/admin", Controllers.UsersController, :create_as_admin
      get "/", Controllers.UsersController, :index
      get "/keyset", Controllers.UsersController, :index_keyset
      get "/stats", Controllers.UsersController, :stats
      get "/:id", Controllers.UsersController, :show
      put "/:id", Controllers.UsersController, :update
      delete "/:id", Controllers.UsersController, :delete
    end

    # User profile management (users can manage their own profile)
    scope "/profile" do
      pipe_through [:authenticated, :user_or_admin]

      get "/", Controllers.UsersController, :show_profile
      put "/", Controllers.UsersController, :update_profile
      put "/password", Controllers.UsersController, :update_password
    end

    # Financial endpoints (payments, accounts, transactions)
    scope "/payments" do
      pipe_through [:authenticated, :user_or_admin]

      post "/", Controllers.PaymentsController, :create
      get "/", Controllers.PaymentsController, :index
      get "/stats", Controllers.PaymentsController, :stats
      post "/validate", Controllers.PaymentsController, :validate
      get "/:id", Controllers.PaymentsController, :show
      post "/:id/process", Controllers.PaymentsController, :process
      get "/:id/status", Controllers.PaymentsController, :status
      delete "/:id", Controllers.PaymentsController, :delete
    end
  end

  # Enable LiveDashboard in development and test
  if Mix.env() in [:dev, :test] do
    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: LedgerBankApiWeb.Telemetry,
        ecto_repos: [LedgerBankApi.Repo]
    end
  end
end

defmodule LedgerBankApiWeb.Router do
  @moduledoc """
  Optimized router with auto-generated routes and better organization.
  Provides consistent routing patterns and eliminates route duplication.
  """

  use LedgerBankApiWeb, :router

  # Pipeline definitions
  pipeline :api do
    plug :accepts, ["json"]
    plug LedgerBankApiWeb.Plugs.RateLimit
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug LedgerBankApiWeb.Plugs.RateLimit
    plug LedgerBankApiWeb.Plugs.Authenticate
  end

  pipeline :public do
    plug :accepts, ["json"]
  end

    # Public endpoints (no authentication required)
  scope "/api", LedgerBankApiWeb do
    pipe_through :public

    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :detailed
    get "/health/ready", HealthController, :ready

    # Handle unsupported HTTP methods for health endpoints
    put "/health", HealthController, :method_not_allowed
    post "/health", HealthController, :method_not_allowed
    delete "/health", HealthController, :method_not_allowed
    patch "/health", HealthController, :method_not_allowed

    put "/health/detailed", HealthController, :method_not_allowed
    post "/health/detailed", HealthController, :method_not_allowed
    delete "/health/detailed", HealthController, :method_not_allowed
    patch "/health/detailed", HealthController, :method_not_allowed

    put "/health/ready", HealthController, :method_not_allowed
    post "/health/ready", HealthController, :method_not_allowed
    delete "/health/ready", HealthController, :method_not_allowed
    patch "/health/ready", HealthController, :method_not_allowed
  end

  # Authentication endpoints (no authentication required)
  scope "/api/auth", LedgerBankApiWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/refresh", AuthController, :refresh
  end

  # Protected API endpoints (authentication required)
  scope "/api", LedgerBankApiWeb do
    pipe_through :auth

    # User profile
    get "/me", AuthController, :me
    post "/logout", AuthController, :logout

    # Auto-generated resource routes
    # Users (admin only)
    scope "/users" do
      get "/", UsersController, :index
      get "/:id", UsersController, :show
      put "/:id", UsersController, :update
      delete "/:id", UsersController, :delete
      post "/:id/suspend", UsersController, :suspend
      post "/:id/activate", UsersController, :activate
      get "/role/:role", UsersController, :list_by_role
    end

    # User bank logins
    scope "/user-bank-logins" do
      get "/", UserBankLoginsController, :index
      get "/:id", UserBankLoginsController, :show
      post "/", UserBankLoginsController, :create
      put "/:id", UserBankLoginsController, :update
      delete "/:id", UserBankLoginsController, :delete
      post "/:id/sync", UserBankLoginsController, :sync
    end

    # Banking endpoints (accounts)
    scope "/accounts" do
      get "/", BankingController, :index
      get "/:id", BankingController, :show
      post "/", BankingController, :create
      put "/:id", BankingController, :update
      delete "/:id", BankingController, :delete
    end

    # Payments
    scope "/payments" do
      get "/", PaymentsController, :index
      get "/:id", PaymentsController, :show
      post "/", PaymentsController, :create
      put "/:id", PaymentsController, :update
      delete "/:id", PaymentsController, :delete
      post "/:id/process", PaymentsController, :process
      get "/account/:account_id", PaymentsController, :list_for_account
    end

    # Custom banking endpoints
    scope "/accounts" do
      get "/:id/transactions", BankingController, :transactions
      get "/:id/balances", BankingController, :balances
      get "/:id/payments", BankingController, :payments
    end

    # Bank sync endpoint
    post "/sync/:login_id", BankingController, :sync
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ledger_bank_api, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: LedgerBankApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Catch-all route for 404 errors
  match :*, "/*path", LedgerBankApiWeb.ErrorController, :not_found
end

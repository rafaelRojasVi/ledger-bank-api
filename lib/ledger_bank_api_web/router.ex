defmodule LedgerBankApiWeb.Router do
  @moduledoc """
  Main router using optimized V2 controllers for better performance and maintainability.
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
  end

  # Authentication endpoints (no authentication required)
  scope "/api/auth", LedgerBankApiWeb do
    pipe_through :api

    post "/register", AuthControllerV2, :register
    post "/login", AuthControllerV2, :login
    post "/refresh", AuthControllerV2, :refresh
  end

  # Protected API endpoints (authentication required)
  scope "/api", LedgerBankApiWeb do
    pipe_through :auth

    # User profile
    get "/me", AuthControllerV2, :me
    post "/logout", AuthControllerV2, :logout

    # User management (admin only)
    scope "/users" do
      get "/", UsersControllerV2, :index
      get "/:id", UsersControllerV2, :show
      put "/:id", UsersControllerV2, :update
      delete "/:id", UsersControllerV2, :delete
      post "/:id/suspend", UsersControllerV2, :suspend
      post "/:id/activate", UsersControllerV2, :activate
      get "/role/:role", UsersControllerV2, :list_by_role
    end

    # User bank logins
    scope "/user-bank-logins" do
      get "/", UserBankLoginsControllerV2, :index
      get "/:id", UserBankLoginsControllerV2, :show
      post "/", UserBankLoginsControllerV2, :create
      put "/:id", UserBankLoginsControllerV2, :update
      delete "/:id", UserBankLoginsControllerV2, :delete
      post "/:id/sync", UserBankLoginsControllerV2, :sync
    end

    # Banking endpoints
    scope "/accounts" do
      get "/", BankingControllerV2, :index
      get "/:id", BankingControllerV2, :show
      get "/:id/transactions", BankingControllerV2, :transactions
      get "/:id/balances", BankingControllerV2, :balances
      get "/:id/payments", BankingControllerV2, :payments
    end

    # Payments
    scope "/payments" do
      get "/", PaymentsControllerV2, :index
      get "/:id", PaymentsControllerV2, :show
      post "/", PaymentsControllerV2, :create
      put "/:id", PaymentsControllerV2, :update
      delete "/:id", PaymentsControllerV2, :delete
      post "/:id/process", PaymentsControllerV2, :process
      get "/account/:account_id", PaymentsControllerV2, :list_for_account
    end

    # Bank sync endpoint
    post "/sync/:login_id", BankingControllerV2, :sync
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
end

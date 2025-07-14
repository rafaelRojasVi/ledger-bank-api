defmodule LedgerBankApiWeb.Router do
  use LedgerBankApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    # plug LedgerBankApiWeb.Plugs.RateLimit
    # plug LedgerBankApiWeb.Plugs.ClientAuth
  end

  pipeline :public do
    plug :accepts, ["json"]
  end

  # Public health check endpoint (no authentication required)
  scope "/api", LedgerBankApiWeb do
    pipe_through :public

    get "/health", HealthController, :index
  end

  # Banking API endpoints (like Teller.io)
  scope "/api", LedgerBankApiWeb do
    pipe_through :api

    # Account endpoints
    get "/accounts", BankingController, :index
    get "/accounts/:id", BankingController, :show
    get "/accounts/:id/transactions", BankingController, :transactions
    get "/accounts/:id/balances", BankingController, :balances
    get "/accounts/:id/payments", BankingController, :payments

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
end

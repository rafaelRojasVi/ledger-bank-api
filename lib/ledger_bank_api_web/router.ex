defmodule LedgerBankApiWeb.Router do
  use LedgerBankApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug LedgerBankApiWeb.Plugs.ClientAuth
  end

  scope "/api", LedgerBankApiWeb do
    pipe_through :api

    resources "/accounts", AccountController, only: [:index, :show]
    get "/accounts/:id/transactions", TransactionController, :index

    # 👇 NEW — live fan-out endpoint
    get "/enrollments/:id/live_snapshot", SnapshotController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ledger_bank_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: LedgerBankApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

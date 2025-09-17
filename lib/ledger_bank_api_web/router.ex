defmodule LedgerBankApiWeb.Router do
  @moduledoc """
  Simple router for the bank API.
  """

  use LedgerBankApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LedgerBankApiWeb do
    pipe_through :api

    # Health check
    get "/health", HealthController, :index

    # Authentication endpoints
    post "/auth/login", Controllers.AuthController, :login
    post "/auth/refresh", Controllers.AuthController, :refresh
    post "/auth/logout", Controllers.AuthController, :logout
    post "/auth/logout-all", Controllers.AuthController, :logout_all
    get "/auth/me", Controllers.AuthController, :me
    get "/auth/validate", Controllers.AuthController, :validate

    # User management endpoints
    get "/users", Controllers.UsersController, :index
    get "/users/stats", Controllers.UsersController, :stats
    get "/users/:id", Controllers.UsersController, :show
    post "/users", Controllers.UsersController, :create
    put "/users/:id", Controllers.UsersController, :update
    delete "/users/:id", Controllers.UsersController, :delete
  end
end

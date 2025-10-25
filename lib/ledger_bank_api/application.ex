defmodule LedgerBankApi.Application do
  @moduledoc """
  The main application module for LedgerBankApi.
  Starts the supervision tree, including Repo, Endpoint, Oban, and other core services.
  """

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications

  use Application

  @impl true
  def start(_type, _args) do
    # Fail fast if JWT secret is missing or weak
    LedgerBankApi.Accounts.Token.ensure_jwt_secret!()

    # Validate financial configuration before starting
    case LedgerBankApi.Core.FinancialConfig.validate_configuration() do
      :ok ->
        require Logger
        Logger.info("Financial configuration validated successfully")

      {:error, reason} ->
        require Logger
        Logger.error("Financial configuration validation failed: #{reason}")
        raise "Configuration validation failed: #{reason}"
    end

    base_children = [
      LedgerBankApiWeb.Telemetry,
      LedgerBankApi.Repo,
      {Phoenix.PubSub, name: LedgerBankApi.PubSub},
      {Finch, name: LedgerBankApi.Finch},
      {Task.Supervisor, name: LedgerBankApi.TaskSupervisor},
      {Oban, Application.fetch_env!(:ledger_bank_api, Oban)}
    ]

    # Initialize cache adapter
    case LedgerBankApi.Core.Cache.init() do
      :ok ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("Failed to initialize cache adapter: #{inspect(reason)}")
        raise "Cache initialization failed: #{inspect(reason)}"
    end

    # Initialize rate limiting table
    LedgerBankApiWeb.Plugs.RateLimit.ensure_table_exists()

    # Initialize circuit breakers (disabled for now due to configuration issues)
    # case LedgerBankApi.Core.CircuitBreaker.init_default_breakers() do
    #   :ok -> :ok
    #   {:error, reason} ->
    #     require Logger
    #     Logger.error("Failed to initialize circuit breakers: #{inspect(reason)}")
    #     raise "Circuit breaker initialization failed: #{inspect(reason)}"
    # end

    http_child =
      if Application.get_env(:ledger_bank_api, LedgerBankApiWeb.Endpoint)[:server] do
        [LedgerBankApiWeb.Endpoint]
      else
        []
      end

    children = base_children ++ http_child

    opts = [strategy: :one_for_one, name: LedgerBankApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Callback for application config changes.
  """
  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LedgerBankApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

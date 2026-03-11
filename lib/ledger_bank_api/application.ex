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
        require Logger
        adapter_name = Application.get_env(:ledger_bank_api, :cache_adapter) |> inspect()
        Logger.info("Cache adapter initialized: #{adapter_name}")

      {:error, reason} ->
        require Logger
        Logger.error("Failed to initialize cache adapter: #{inspect(reason)}")
        # For Redis adapter, log warning but don't crash if Redis is unavailable
        # Application can still run with degraded cache performance
        adapter = Application.get_env(:ledger_bank_api, :cache_adapter)
        if adapter == LedgerBankApi.Core.Cache.RedisAdapter do
          Logger.warning("Redis cache adapter failed to initialize. Application will continue but caching will be unavailable.")
        else
          raise "Cache initialization failed: #{inspect(reason)}"
        end
    end

    # Initialize rate limiting table
    LedgerBankApiWeb.Plugs.RateLimit.ensure_table_exists()

    # Initialize circuit breakers (optional, controlled by config)
    if Application.get_env(:ledger_bank_api, :enable_circuit_breaker, true) do
      case LedgerBankApi.Core.CircuitBreaker.init_default_breakers() do
        :ok ->
          require Logger
          Logger.info("Circuit breakers initialized successfully")

        {:error, reason} ->
          require Logger
          Logger.warning("Failed to initialize circuit breakers: #{inspect(reason)}. Continuing without circuit breaker protection.")
      end
    end

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

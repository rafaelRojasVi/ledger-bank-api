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
    base_children = [
      LedgerBankApiWeb.Telemetry,
      LedgerBankApi.Repo,
      {Phoenix.PubSub, name: LedgerBankApi.PubSub},
      {Finch, name: LedgerBankApi.Finch},
      {Task.Supervisor, name: LedgerBankApi.TaskSupervisor},
      {Oban, Application.fetch_env!(:ledger_bank_api, Oban)}
    ]

    # Initialize cache table
    case :ets.new(:ledger_cache, [:set, :public, :named_table]) do
      :ledger_cache -> :ok
      {:error, reason} ->
        require Logger
        Logger.error("Failed to create cache table: #{inspect(reason)}")
        raise "Cache table creation failed: #{inspect(reason)}"
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

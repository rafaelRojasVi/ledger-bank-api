defmodule LedgerBankApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LedgerBankApiWeb.Telemetry,
      LedgerBankApi.Repo,
      {DNSCluster, query: Application.get_env(:ledger_bank_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LedgerBankApi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LedgerBankApi.Finch},
      {Task.Supervisor, name: LedgerBankApi.TaskSupervisor},
      # Start a worker by calling: LedgerBankApi.Worker.start_link(arg)
      # {LedgerBankApi.Worker, arg},
      # Start to serve requests, typically the last entry
      LedgerBankApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LedgerBankApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LedgerBankApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

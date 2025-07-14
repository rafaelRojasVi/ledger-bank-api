defmodule LedgerBankApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LedgerBankApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

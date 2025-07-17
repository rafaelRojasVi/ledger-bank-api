defmodule LedgerBankApi.Workers.BankSyncWorker do
  @moduledoc """
  Oban worker for syncing user bank logins with external bank systems.
  Enqueues background jobs to fetch and update account data for a given login.
  """
  use Oban.Worker, queue: :banking

  @impl Oban.Worker
  @doc """
  Performs the sync operation for the given login_id.
  """
  def perform(%Oban.Job{args: %{"login_id" => login_id}}) do
    IO.puts("[Stub] Would sync user login: #{login_id}")
    :ok
  end
end

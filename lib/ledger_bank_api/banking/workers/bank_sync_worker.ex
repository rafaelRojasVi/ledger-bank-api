defmodule LedgerBankApi.Workers.BankSyncWorker do
  use Oban.Worker, queue: :banking

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"login_id" => login_id}}) do
    IO.puts("[Stub] Would sync user login: #{login_id}")
    :ok
  end
end

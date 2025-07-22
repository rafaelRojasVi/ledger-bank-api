defmodule LedgerBankApi.Workers.BankSyncWorker do
  use Oban.Worker, queue: :banking
  require Logger
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @impl Oban.Worker
  @doc """
  Performs bank sync for a given login_id, with centralized error handling.
  """
  def perform(%Oban.Job{args: %{"login_id" => login_id}}) do
    context = %{worker: __MODULE__, login_id: login_id}

    ErrorHandler.with_error_handling(fn ->
      LedgerBankApi.Banking.UserBankLogins.sync_login(login_id)
    end, context)
  end
end

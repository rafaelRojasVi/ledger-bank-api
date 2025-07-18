defmodule LedgerBankApi.Workers.BankSyncWorker do
  use Oban.Worker, queue: :banking
  require Logger
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"login_id" => login_id}}) do
    context = %{worker: __MODULE__, login_id: login_id}

    ErrorHandler.with_error_handling(fn ->
      login =
        Repo.get!(UserBankLogin, login_id)
        |> Repo.preload(bank_branch: :bank)

      integration_mod = login.bank_branch.bank.integration_module |> String.to_existing_atom()

      case integration_mod.fetch_accounts(%{access_token: login.encrypted_password}) do
        {:ok, accounts} ->
          Logger.info("Fetched accounts: #{inspect(accounts)}")
          :ok
        {:error, reason} ->
          raise "Failed to fetch accounts: #{inspect(reason)}"
      end
    end, context)
  end
end

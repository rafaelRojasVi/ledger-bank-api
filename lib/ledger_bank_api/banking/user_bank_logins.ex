defmodule LedgerBankApi.Banking.UserBankLogins do
  @moduledoc "Business logic for user bank logins."
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Workers.BankSyncWorker
  use LedgerBankApi.CrudHelpers, schema: UserBankLogin

  def create_user_bank_login(attrs) do
    changeset = UserBankLogin.changeset(%UserBankLogin{}, attrs)

    case Repo.insert(changeset) do
      {:ok, login} ->
        Oban.insert(BankSyncWorker.new(%{"login_id" => login.id}, queue: :banking))
        {:ok, login}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Synchronize a bank login by id (used by BankSyncWorker)
  def sync_login(login_id) do
    login =
      Repo.get!(LedgerBankApi.Banking.Schemas.UserBankLogin, login_id)
      |> Repo.preload(bank_branch: :bank)

    integration_mod = login.bank_branch.bank.integration_module |> String.to_existing_atom()

    case integration_mod.fetch_accounts(%{access_token: login.encrypted_password}) do
      {:ok, accounts} ->
        require Logger
        Logger.info("Fetched accounts: #{inspect(accounts)}")
        :ok
      {:error, reason} ->
        raise "Failed to fetch accounts: #{inspect(reason)}"
    end
  end
end

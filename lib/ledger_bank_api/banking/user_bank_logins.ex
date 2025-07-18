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
end

defmodule LedgerBankApi.Banking.UserBankLogins do
  @moduledoc "Business logic for user bank logins."
  import Ecto.Query, warn: false
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Workers.BankSyncWorker
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  use LedgerBankApi.CrudHelpers, schema: UserBankLogin

  def create_user_bank_login(attrs) do
    context = %{action: :create_user_bank_login, user_id: attrs["user_id"]}

    ErrorHandler.with_error_handling(fn ->
      changeset = UserBankLogin.changeset(%UserBankLogin{}, attrs)

      case Repo.insert(changeset) do
        {:ok, login} ->
          # Queue the sync job
          Oban.insert(BankSyncWorker.new(%{"login_id" => login.id}, queue: :banking))
          login
        {:error, changeset} ->
          {:error, changeset}
      end
    end, context)
  end

  # Synchronize a bank login by id (used by BankSyncWorker)
  def sync_login(login_id) do
    context = %{action: :sync_login, login_id: login_id}

    ErrorHandler.with_error_handling(fn ->
      login =
        Repo.get!(UserBankLogin, login_id)
        |> Repo.preload(bank_branch: :bank)

      integration_mod = login.bank_branch.bank.integration_module |> String.to_existing_atom()

      case integration_mod.fetch_accounts(%{access_token: login.encrypted_password}) do
        {:ok, accounts} ->
          require Logger
          Logger.info("Fetched accounts for login #{login_id}: #{length(accounts)} accounts")
          # TODO: Process and store the accounts
          :ok
        {:error, reason} ->
          {:error, "Failed to fetch accounts: #{inspect(reason)}"}
      end
    end, context)
  end

  @doc """
  List user bank logins with advanced filtering, pagination, and sorting.
  """
  def list_with_filters(_pagination, _filters, _sorting, user_id, _user_filter) do
    # For now, just return all logins for the user
    # In a real implementation, you might want to apply filters
    UserBankLogin
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  @doc """
  Get user bank login with preloads.
  """
  def get_with_preloads!(id, preloads) do
    UserBankLogin
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end
end

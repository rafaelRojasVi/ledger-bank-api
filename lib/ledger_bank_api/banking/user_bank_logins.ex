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
          {:ok, login}
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

      case get_integration_module(login.bank_branch.bank.integration_module) do
        {:ok, integration_mod} ->
          case integration_mod.fetch_accounts(%{access_token: login.encrypted_password}) do
            {:ok, accounts} ->
              require Logger
              Logger.info("Fetched accounts for login #{login_id}: #{length(accounts)} accounts")

              # Process and store the accounts
              Repo.transaction(fn ->
                Enum.each(accounts, fn account_data ->
                  # Map external account data to our schema
                  account_attrs = %{
                    user_bank_login_id: login.id,
                    currency: account_data["currency"] || "USD",
                    account_type: account_data["type"] || "CHECKING",
                    balance: Decimal.new(account_data["balance"] || "0"),
                    last_four: account_data["last4"] || "",
                    account_name: account_data["name"] || "Account",
                    status: "ACTIVE",
                    external_account_id: account_data["id"]
                  }

                  # Create or update the account
                  case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankAccount,
                                  external_account_id: account_data["id"]) do
                    nil ->
                      # Create new account
                      %LedgerBankApi.Banking.Schemas.UserBankAccount{}
                      |> LedgerBankApi.Banking.Schemas.UserBankAccount.changeset(account_attrs)
                      |> Repo.insert!()
                    existing_account ->
                      # Update existing account
                      existing_account
                      |> LedgerBankApi.Banking.Schemas.UserBankAccount.changeset(account_attrs)
                      |> Repo.update!()
                  end
                end)

                # Update login status and last_sync_at
                login
                |> Ecto.Changeset.change(%{
                  status: "ACTIVE",
                  last_sync_at: DateTime.utc_now()
                })
                |> Repo.update!()
              end)

              :ok
            {:error, reason} ->
              # Update login status to ERROR
              login
              |> Ecto.Changeset.change(%{
                status: "ERROR",
                last_sync_at: DateTime.utc_now()
              })
              |> Repo.update!()

              {:error, "Failed to fetch accounts: #{inspect(reason)}"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Safely converts integration module string to atom with error handling.
  Returns {:ok, module} or {:error, reason}.
  """
  defp get_integration_module(integration_module_string) do
    case integration_module_string do
      nil ->
        {:error, :missing_integration_module}
      module_string when is_binary(module_string) ->
        try do
          {:ok, String.to_existing_atom(module_string)}
        rescue
          ArgumentError ->
            {:error, :invalid_integration_module}
        end
      _ ->
        {:error, :invalid_integration_module_type}
    end
  end

  alias LedgerBankApi.Helpers.QueryHelpers

  @doc """
  Lists user bank logins with advanced filtering, pagination, and sorting.
  Returns {:ok, %{data: list, pagination: map}} or {:error, reason}.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    context = %{action: :list_with_filters, user_id: user_id, user_filter: user_filter}

    ErrorHandler.with_error_handling(fn ->
      QueryHelpers.list_with_filters(
        UserBankLogin,
        pagination,
        filters,
        sorting,
        user_id,
        user_filter,
        allowed_sort_fields: ["username", "status", "created_at", "updated_at"],
        field_mappings: %{
          "status" => :status,
          "username" => :username
        }
      )
    end, context)
  end

  @doc """
  Updates a user bank login with validation.
  Returns {:ok, login} or {:error, reason}.
  """
  def update_user_bank_login(login, attrs) do
    context = %{action: :update_user_bank_login, login_id: login.id}

    ErrorHandler.with_error_handling(fn ->
      login
      |> UserBankLogin.changeset(attrs)
      |> Repo.update()
    end, context)
  end

  @doc """
  Deletes a user bank login with validation.
  Returns {:ok, login} or {:error, reason}.
  """
  def delete_user_bank_login(login) do
    context = %{action: :delete_user_bank_login, login_id: login.id}

    ErrorHandler.with_error_handling(fn ->
      Repo.delete(login)
    end, context)
  end

  @doc """
  Gets a user bank login by ID with preloads.
  Returns {:ok, login} or {:error, reason}.
  """
  def get_user_bank_login_with_preloads!(id, preloads) do
    context = %{action: :get_user_bank_login_with_preloads, id: id, preloads: preloads}

    ErrorHandler.with_error_handling(fn ->
      UserBankLogin
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    end, context)
  end

  @doc """
  Gets user bank logins by user ID with filtering.
  Returns {:ok, list} or {:error, reason}.
  """
  def get_logins_by_user(user_id, filters \\ %{}) do
    context = %{action: :get_logins_by_user, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      query = UserBankLogin
      |> where([l], l.user_id == ^user_id)

      # Apply filters
      query = case filters do
        %{status: status} when not is_nil(status) ->
          where(query, [l], l.status == ^status)
        _ -> query
      end

      query = case filters do
        %{bank_branch_id: bank_branch_id} when not is_nil(bank_branch_id) ->
          where(query, [l], l.bank_branch_id == ^bank_branch_id)
        _ -> query
      end

      query = case filters do
        %{active_only: true} ->
          where(query, [l], l.status == "ACTIVE")
        _ -> query
      end

      query
      |> order_by([l], desc: l.updated_at)
      |> Repo.all()
    end, context)
  end

  @doc """
  Updates the status of a user bank login.
  Returns {:ok, login} or {:error, reason}.
  """
  def update_login_status(login, status) do
    context = %{action: :update_login_status, login_id: login.id, status: status}

    ErrorHandler.with_error_handling(fn ->
      login
      |> Ecto.Changeset.change(%{status: status})
      |> Repo.update()
    end, context)
  end

  @doc """
  Checks if a user bank login is active and valid.
  Returns {:ok, boolean} or {:error, reason}.
  """
  def is_login_valid?(login) do
    context = %{action: :is_login_valid, login_id: login.id}

    ErrorHandler.with_error_handling(fn ->
      is_valid = case login do
        %{status: "ACTIVE", last_sync_at: last_sync_at} when not is_nil(last_sync_at) ->
          # Check if last sync was within 24 hours
          hours_since_sync = DateTime.diff(DateTime.utc_now(), last_sync_at, :hour)
          hours_since_sync < 24
        _ ->
          false
      end
      {:ok, is_valid}
    end, context)
  end
end

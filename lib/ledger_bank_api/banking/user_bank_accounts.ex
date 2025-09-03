defmodule LedgerBankApi.Banking.UserBankAccounts do
  @moduledoc """
  Enhanced business logic for user bank accounts with advanced querying, optimization, and authorization.
  Provides Ecto.Query-based operations for better performance and flexibility.
  All functions return standardized {:ok, data} or {:error, reason} patterns.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler


  use LedgerBankApi.CrudHelpers, schema: UserBankAccount

  alias LedgerBankApi.Helpers.QueryHelpers

  @doc """
  Lists user bank accounts with advanced filtering, pagination, and sorting.
  Returns {:ok, %{data: list, pagination: map}} or {:error, reason}.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    context = %{action: :list_with_filters, user_id: user_id, user_filter: user_filter}

    ErrorHandler.with_error_handling(fn ->
      QueryHelpers.list_with_filters(
        UserBankAccount,
        pagination,
        filters,
        sorting,
        user_id,
        user_filter,
        allowed_sort_fields: ["balance", "account_name", "created_at", "updated_at"],
        field_mappings: %{
          "status" => :status,
          "account_type" => :account_type,
          "currency" => :currency,
          "last_four" => :last_four
        },
        join_assoc: :user_bank_login
      )
    end, context)
  end



  @doc """
  Gets user bank account with preloads and user filtering for authorization.
  Returns {:ok, account} or {:error, reason}.
  """
  def get_with_preloads_and_user!(id, preloads, user_id) do
    context = %{action: :get_with_preloads_and_user, id: id, preloads: preloads, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      case get_account_with_ownership_check(id, user_id) do
        {:ok, account} ->
          account
          |> Repo.preload(preloads)
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Gets an account with ownership validation.
  Returns {:ok, account} or {:error, :forbidden}.
  """
  def get_account_with_ownership_check(account_id, user_id) do
    case Repo.get(UserBankAccount, account_id) do
      nil ->
        {:error, :not_found}
      account ->
        account
        |> Repo.preload(user_bank_login: [])
        |> validate_account_ownership(user_id)
    end
  end

  @doc """
  Lists accounts for a specific user with optimized querying and authorization.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_for_user(user_id, opts \\ []) do
    context = %{action: :list_for_user, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      UserBankAccount
      |> join(:inner, [a], l in assoc(a, :user_bank_login))
      |> where([a, l], l.user_id == ^user_id)
      |> preload([a, l], user_bank_login: {l, bank_branch: :bank})
      |> apply_list_opts(opts)
      |> Repo.all()
    end, context)
  end

  @doc """
  Gets account balance with caching support and authorization.
  Returns {:ok, balance} or {:error, reason}.
  """
  def get_account_balance(account_id, user_id) do
    context = %{action: :get_account_balance, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # First check if user owns this account
      case get_with_preloads_and_user!(account_id, [], user_id) do
        {:ok, %{data: account}} -> {:ok, account.balance}
        {:error, %{error: %{type: :not_found}}} -> {:error, :account_not_found}
        error -> error
      end
    end, context)
  end

  @doc """
  Updates account balance atomically with authorization and validation.
  Returns {:ok, updated_count} or {:error, reason}.
  """
  def update_balance(account_id, new_balance, user_id) do
    context = %{action: :update_balance, account_id: account_id, new_balance: new_balance, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate user owns the account
      with {:ok, _account} <- get_with_preloads_and_user!(account_id, [], user_id),
           {:ok, _} <- validate_balance_update(new_balance) do

        result = Repo.update_all(
          from(a in UserBankAccount, where: a.id == ^account_id),
          set: [balance: new_balance, updated_at: DateTime.utc_now()]
        )

        # Invalidate cache
        LedgerBankApi.Cache.invalidate_account_balance(account_id)

        {:ok, result}
      end
    end, context)
  end

  @doc """
  Creates a user bank account with authorization and business rule validation.
  Returns {:ok, account} or {:error, reason}.
  """
  def create_user_bank_account(attrs, user_id) do
    context = %{action: :create_user_bank_account, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate that the user owns the bank login
      with {:ok, _login} <- validate_bank_login_ownership(attrs["user_bank_login_id"], user_id),
           {:ok, _} <- validate_account_creation_rules(attrs) do

        %UserBankAccount{}
        |> UserBankAccount.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, account} ->
            # Invalidate user accounts cache
            LedgerBankApi.Cache.invalidate_user_accounts(user_id)
            {:ok, account}
          error -> error
        end
      end
    end, context)
  end

  @doc """
  Updates a user bank account with authorization and validation.
  Returns {:ok, account} or {:error, reason}.
  """
  def update_user_bank_account(account_id, attrs, user_id) do
    context = %{action: :update_user_bank_account, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      with {:ok, account} <- get_with_preloads_and_user!(account_id, [], user_id),
           {:ok, _} <- validate_account_update_rules(attrs, account) do

        account
        |> UserBankAccount.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_account} ->
            # Invalidate caches
            LedgerBankApi.Cache.invalidate_account_balance(account_id)
            LedgerBankApi.Cache.invalidate_user_accounts(user_id)
            {:ok, updated_account}
          error -> error
        end
      end
    end, context)
  end

  @doc """
  Deletes a user bank account with authorization and dependency checks.
  Returns {:ok, account} or {:error, reason}.
  """
  def delete_user_bank_account(account_id, user_id) do
    context = %{action: :delete_user_bank_account, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      with {:ok, account} <- get_with_preloads_and_user!(account_id, [], user_id),
           {:ok, _} <- validate_account_deletion_rules(account) do

        Repo.delete(account)
        |> case do
          {:ok, deleted_account} ->
            # Invalidate caches
            LedgerBankApi.Cache.invalidate_account_balance(account_id)
            LedgerBankApi.Cache.invalidate_user_accounts(user_id)
            {:ok, deleted_account}
          error -> error
        end
      end
    end, context)
  end

  # Private helper functions

  defp apply_list_opts(query, opts) do
    Enum.reduce(opts, query, fn {key, value}, acc ->
      case key do
        :preload -> Repo.preload(acc, value)
        :where -> where(acc, ^value)
        :order_by -> order_by(acc, ^value)
        _ -> acc
      end
    end)
  end

  defp validate_balance_update(balance) when is_struct(balance, Decimal) do
    if Decimal.lt?(balance, Decimal.new(0)) do
      {:error, :negative_balance}
    else
      {:ok, :valid_balance}
    end
  end

  defp validate_balance_update(_), do: {:error, :invalid_balance_format}

  defp validate_bank_login_ownership(login_id, user_id) do
    case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankLogin, id: login_id, user_id: user_id) do
      nil -> {:error, :unauthorized}
      login -> {:ok, login}
    end
  end

  defp validate_account_ownership(account, user_id) do
    case account.user_bank_login do
      %{user_id: ^user_id} -> {:ok, account}
      _ -> {:error, :forbidden}
    end
  end

  defp validate_account_creation_rules(attrs) do
    # Validate required fields
    required_fields = ["user_bank_login_id", "currency", "account_type"]
    missing_fields = Enum.filter(required_fields, fn field ->
      is_nil(attrs[field]) or attrs[field] == ""
    end)

    if Enum.empty?(missing_fields) do
      {:ok, :valid_creation}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  defp validate_account_update_rules(attrs, _account) do
    # Prevent updating critical fields
    restricted_fields = ["user_bank_login_id", "external_account_id"]
    restricted_updates = Enum.filter(restricted_fields, fn field ->
      Map.has_key?(attrs, field)
    end)

    if Enum.empty?(restricted_updates) do
      {:ok, :valid_update}
    else
      {:error, {:restricted_fields, restricted_updates}}
    end
  end

  defp validate_account_deletion_rules(account) do
    # Check if account has pending payments
    pending_payments = Repo.aggregate(
      from(p in LedgerBankApi.Banking.Schemas.UserPayment,
          where: p.user_bank_account_id == ^account.id and p.status == "PENDING"),
      :count
    )

    if pending_payments > 0 do
      {:error, :has_pending_payments}
    else
      {:ok, :can_delete}
    end
  end
end

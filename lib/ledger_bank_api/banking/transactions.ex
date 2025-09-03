defmodule LedgerBankApi.Banking.Transactions do
  @moduledoc """
  Enhanced business logic for transactions with standardized return patterns.
  All functions return {:ok, data} or {:error, reason}.
  """
  import Ecto.Query
  alias LedgerBankApi.Banking.Schemas.Transaction
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  use LedgerBankApi.CrudHelpers, schema: Transaction

  alias LedgerBankApi.Helpers.QueryHelpers

  @doc """
  Lists transactions for a specific account with ownership validation.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_for_account(account_id, user_id, _opts \\ []) do
    context = %{action: :list_for_account, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate account ownership first
      case validate_account_ownership(account_id, user_id) do
        {:ok, _account} ->
          Transaction
          |> where([t], t.account_id == ^account_id)
          |> order_by([t], desc: t.posted_at)
          |> Repo.all()
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Lists transactions with advanced filtering, pagination, and sorting.
  Returns {:ok, %{data: list, pagination: map}} or {:error, reason}.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    context = %{action: :list_with_filters, user_id: user_id, user_filter: user_filter}

    ErrorHandler.with_error_handling(fn ->
      QueryHelpers.list_with_filters(
        Transaction,
        pagination,
        filters,
        sorting,
        user_id,
        user_filter,
        allowed_sort_fields: ["amount", "description", "posted_at", "created_at"],
        field_mappings: %{
          "amount" => :amount,
          "description" => :description,
          "direction" => :direction
        },
        join_assoc: :user_bank_account
      )
    end, context)
  end



  @doc """
  Creates a transaction with validation.
  Returns {:ok, transaction} or {:error, reason}.
  """
  def create_transaction(attrs) do
    context = %{action: :create_transaction, account_id: attrs["account_id"]}

    ErrorHandler.with_error_handling(fn ->
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()
    end, context)
  end

  @doc """
  Updates a transaction with ownership validation.
  Returns {:ok, transaction} or {:error, reason}.
  """
  def update_transaction(transaction, attrs, user_id) do
    context = %{action: :update_transaction, transaction_id: transaction.id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate account ownership first
      case validate_account_ownership(transaction.account_id, user_id) do
        {:ok, _account} ->
          transaction
          |> Transaction.changeset(attrs)
          |> Repo.update()
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Deletes a transaction with ownership validation.
  Returns {:ok, transaction} or {:error, reason}.
  """
  def delete_transaction(transaction, user_id) do
    context = %{action: :delete_transaction, transaction_id: transaction.id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate account ownership first
      case validate_account_ownership(transaction.account_id, user_id) do
        {:ok, _account} ->
          Repo.delete(transaction)
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Gets a transaction by ID with preloads.
  Returns {:ok, transaction} or {:error, reason}.
  """
  def get_transaction_with_preloads!(id, preloads) do
    context = %{action: :get_transaction_with_preloads, id: id, preloads: preloads}

    ErrorHandler.with_error_handling(fn ->
      Transaction
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    end, context)
  end

  @doc """
  Gets transactions by account with ownership validation and advanced filtering.
  Returns {:ok, list} or {:error, reason}.
  """
  def get_transactions_by_account(account_id, user_id, filters \\ %{}) do
    context = %{action: :get_transactions_by_account, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      # Validate account ownership first
      case validate_account_ownership(account_id, user_id) do
        {:ok, _account} ->
          query = Transaction
          |> where([t], t.account_id == ^account_id)

          # Apply filters
          query = case filters do
            %{date_from: date_from} when not is_nil(date_from) ->
              where(query, [t], t.posted_at >= ^date_from)
            _ -> query
          end

          query = case filters do
            %{date_to: date_to} when not is_nil(date_to) ->
              where(query, [t], t.posted_at <= ^date_to)
            _ -> query
          end

          query = case filters do
            %{amount_min: amount_min} when not is_nil(amount_min) ->
              where(query, [t], t.amount >= ^amount_min)
            _ -> query
          end

          query = case filters do
            %{amount_max: amount_max} when not is_nil(amount_max) ->
              where(query, [t], t.amount <= ^amount_max)
            _ -> query
          end

          query = case filters do
            %{direction: direction} when not is_nil(direction) ->
              where(query, [t], t.direction == ^direction)
            _ -> query
          end

        query
        |> order_by([t], desc: t.posted_at)
        |> Repo.all()
      {:error, reason} ->
        {:error, reason}
      end
    end, context)
  end

  # Private helper functions

  defp validate_account_ownership(account_id, user_id) do
    case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankAccount, id: account_id) do
      nil -> {:error, :account_not_found}
      account ->
        # Check if user owns this account through the bank login
        case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankLogin,
                        id: account.user_bank_login_id, user_id: user_id) do
          nil -> {:error, :forbidden}
          _ -> {:ok, account}
        end
    end
  end
end

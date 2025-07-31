defmodule LedgerBankApi.Banking.UserBankAccounts do
  @moduledoc """
  Enhanced business logic for user bank accounts with advanced querying and optimization.
  Provides Ecto.Query-based operations for better performance and flexibility.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: UserBankAccount

  @doc """
  List user bank accounts with advanced filtering, pagination, and sorting.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    UserBankAccount
    |> apply_user_filter(user_id, user_filter)
    |> apply_filters(filters)
    |> apply_sorting(sorting)
    |> apply_pagination(pagination)
    |> Repo.all()
  end

  @doc """
  Get user bank account with preloads for optimized queries.
  """
  def get_with_preloads!(id, preloads) do
    UserBankAccount
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end

  @doc """
  Get user bank account with preloads and user filtering.
  """
  def get_with_preloads_and_user!(id, preloads, user_id) do
    UserBankAccount
    |> join(:inner, [a], l in assoc(a, :user_bank_login))
    |> where([a, l], a.id == ^id and l.user_id == ^user_id)
    |> preload([a, l], user_bank_login: {l, bank_branch: :bank})
    |> Repo.one!()
    |> Repo.preload(preloads)
  end

  @doc """
  List accounts for a specific user with optimized querying.
  """
  def list_for_user(user_id, opts \\ []) do
    UserBankAccount
    |> join(:inner, [a], l in assoc(a, :user_bank_login))
    |> where([a, l], l.user_id == ^user_id)
    |> preload([a, l], user_bank_login: {l, bank_branch: :bank})
    |> apply_list_opts(opts)
    |> Repo.all()
  end

  @doc """
  Get account balance with caching support.
  """
  def get_account_balance(account_id) do
    # TODO: Implement caching with Cachex or similar
    case Repo.get(UserBankAccount, account_id) do
      nil -> {:error, :not_found}
      account -> {:ok, account.balance}
    end
  end

  @doc """
  Update account balance atomically.
  """
  def update_balance(account_id, new_balance) do
    Repo.update_all(
      from(a in UserBankAccount, where: a.id == ^account_id),
      set: [balance: new_balance, updated_at: DateTime.utc_now()]
    )
  end

  # Private helper functions

  defp apply_user_filter(query, _user_id, nil), do: query
  defp apply_user_filter(query, user_id, :user_id) do
    query
    |> join(:inner, [a], l in assoc(a, :user_bank_login))
    |> where([a, l], l.user_id == ^user_id)
  end
  defp apply_user_filter(query, _user_id, filter_fun) when is_function(filter_fun, 2) do
    # For complex filtering, we'll need to handle this differently
    # This is a placeholder for custom filter functions
    query
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        "status" -> where(acc, [a], a.status == ^value)
        "account_type" -> where(acc, [a], a.account_type == ^value)
        "currency" -> where(acc, [a], a.currency == ^value)
        "last_four" -> where(acc, [a], a.last_four == ^value)
        _ -> acc
      end
    end)
  end

  defp apply_sorting(query, %{sort_by: field, sort_order: order}) do
    direction = if order == "asc", do: :asc, else: :desc

    case field do
      "balance" -> order_by(query, [a], [{^direction, a.balance}])
      "account_name" -> order_by(query, [a], [{^direction, a.account_name}])
      "created_at" -> order_by(query, [a], [{^direction, a.inserted_at}])
      "updated_at" -> order_by(query, [a], [{^direction, a.updated_at}])
      _ -> order_by(query, [a], [{^direction, a.inserted_at}])
    end
  end

  defp apply_pagination(query, %{page: page, per_page: per_page}) do
    offset = (page - 1) * per_page
    query
    |> limit(^per_page)
    |> offset(^offset)
  end

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
end

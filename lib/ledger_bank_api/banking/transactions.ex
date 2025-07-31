defmodule LedgerBankApi.Banking.Transactions do
  @moduledoc "Business logic for transactions."
  import Ecto.Query
  alias LedgerBankApi.Banking.Schemas.Transaction
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: Transaction

  def list_for_account(account_id, _opts \\ []) do
    Transaction
    |> where([t], t.account_id == ^account_id)
    |> Repo.all()
  end

  @doc """
  List transactions with advanced filtering, pagination, and sorting.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    import Ecto.Query
    alias LedgerBankApi.Banking.Behaviours.{Paginated, Sortable}

    # Start with base query
    query = from t in Transaction

    # Apply user filter if provided
    query = if user_filter do
      from t in query, where: field(t, ^String.to_atom(user_filter)) == ^user_id
    else
      query
    end

    # Apply filters
    query = apply_filters(query, filters)

    # Apply sorting
    query = Sortable.apply_sorting(query, sorting)

    # Apply pagination
    offset = Paginated.calculate_offset(pagination.page, pagination.per_page)
    query = from t in query, limit: ^pagination.per_page, offset: ^offset

    # Execute query
    Repo.all(query)
  end

  defp apply_filters(query, filters) do
    import Ecto.Query

    Enum.reduce(filters, query, fn {key, value}, acc ->
      case {key, value} do
        {:date_from, date} ->
          from t in acc, where: t.posted_at >= ^date
        {:date_to, date} ->
          from t in acc, where: t.posted_at <= ^date
        {:amount_min, amount} ->
          from t in acc, where: t.amount >= ^amount
        {:amount_max, amount} ->
          from t in acc, where: t.amount <= ^amount
        {:description, description} ->
          from t in acc, where: ilike(t.description, ^"%#{description}%")
        {:status, status} ->
          from t in acc, where: t.status == ^status
        _ ->
          acc
      end
    end)
  end

  @doc """
  Get transaction with preloads.
  """
  def get_with_preloads!(id, preloads) do
    Transaction
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end
end

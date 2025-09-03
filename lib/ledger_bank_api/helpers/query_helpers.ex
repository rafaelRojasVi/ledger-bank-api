defmodule LedgerBankApi.Helpers.QueryHelpers do
  @moduledoc """
  Simple query helpers for common database operations.
  """

  import Ecto.Query

  @doc """
  Builds a query with user filtering applied.
  """
  def build_user_filtered_query(schema, user_id, user_filter, join_assoc \\ nil) do
    case {user_filter, join_assoc} do
      {nil, nil} ->
        schema
      {nil, assoc} when not is_nil(assoc) ->
        schema
        |> join(:inner, [s], j in assoc(s, ^assoc))
        |> distinct([s], s.id)
      {:user_id, nil} ->
        schema
        |> where([s], s.user_id == ^user_id)
      {:user_id, assoc} ->
        schema
        |> join(:inner, [s], j in assoc(s, ^assoc))
        |> where([s, j], j.user_id == ^user_id)
        |> distinct([s], s.id)
      {:user_bank_account, nil} ->
        # Handle user_bank_account filter without join_assoc
        # This means we need to join through user_bank_account to get to user_bank_login.user_id
        schema
        |> join(:inner, [s], a in assoc(s, :user_bank_account))
        |> join(:inner, [s, a], l in assoc(a, :user_bank_login))
        |> where([s, a, l], l.user_id == ^user_id)
        |> distinct([s], s.id)
      {:user_bank_account, assoc} ->
        # Handle user_bank_account filter with join_assoc
        schema
        |> join(:inner, [s], j in assoc(s, ^assoc))
        |> join(:inner, [s, j], a in assoc(j, :user_bank_account))
        |> join(:inner, [s, j, a], l in assoc(a, :user_bank_login))
        |> where([s, j, a, l], l.user_id == ^user_id)
        |> distinct([s], s.id)
      _ ->
        # Default case for any other user_filter values
        schema
    end
  end

  @doc """
  Applies filters to a query.
  """
  def apply_filters(query, filters, field_mappings \\ %{}) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      if is_nil(value) or value == "" do
        acc
      else
        case {key, value} do
          {:date_from, date} ->
            where(acc, [q], q.posted_at >= ^date)
          {:date_to, date} ->
            where(acc, [q], q.posted_at <= ^date)
          {:amount_min, amount} ->
            where(acc, [q], q.amount >= ^amount)
          {:amount_max, amount} ->
            where(acc, [q], q.amount <= ^amount)
          {:description, description} ->
            where(acc, [q], ilike(q.description, ^"%#{description}%"))
          _ ->
            # Convert key to atom if it's a string, otherwise use as is
            field_key = if is_binary(key), do: String.to_existing_atom(key), else: key
            field = Map.get(field_mappings, key, field_key)
            where(acc, [q], field(q, ^field) == ^value)
        end
      end
    end)
  end

  @doc """
  Applies sorting to a query.
  """
  def apply_sorting(query, %{sort_by: field, sort_order: order}, allowed_fields) do
    if field in allowed_fields do
      direction = if order == "asc", do: :asc, else: :desc
      # Convert field to atom if it's a string, otherwise use as is
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field
      order_by(query, [q], [{^direction, field(q, ^field_atom)}])
    else
      query
    end
  end

  @doc """
  Standard list with filters implementation.
  """
  def list_with_filters(schema, pagination, filters, sorting, user_id, user_filter, opts \\ []) do
    allowed_sort_fields = Keyword.get(opts, :allowed_sort_fields, [])
    field_mappings = Keyword.get(opts, :field_mappings, %{})
    join_assoc = Keyword.get(opts, :join_assoc)

    query = schema
    |> build_user_filtered_query(user_id, user_filter, join_assoc)
    |> apply_filters(filters, field_mappings)
    |> apply_sorting(sorting, allowed_sort_fields)

    # Apply pagination
    page = Map.get(pagination, :page, 1)
    page_size = Map.get(pagination, :page_size, 20)
    offset = (page - 1) * page_size

    results = query
    |> limit(^page_size)
    |> offset(^offset)
    |> LedgerBankApi.Repo.all()

    total_count = query |> LedgerBankApi.Repo.aggregate(:count)

    {:ok, %{
      data: results,
      pagination: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: ceil(total_count / page_size)
      }
    }}
  end

  @doc """
  Gets a record with preloads.
  """
  def get_with_preloads!(schema, id, preloads) do
    schema
    |> LedgerBankApi.Repo.get!(id)
    |> LedgerBankApi.Repo.preload(preloads)
    |> then(&{:ok, &1})
  end

  @doc """
  Builds a query with joins and preloads.
  """
  def build_query_with_joins(schema, joins, preloads \\ []) do
    query = schema

    # Apply joins
    query = Enum.reduce(joins, query, fn {join_type, assoc, conditions}, acc ->
      acc
      |> join(join_type, [s], j in assoc(s, ^assoc))
      |> then(fn q ->
        if conditions do
          Enum.reduce(conditions, q, fn {field, value}, query_acc ->
            where(query_acc, [s, j], field(j, ^field) == ^value)
          end)
        else
          q
        end
      end)
    end)

    # Apply preloads
    if Enum.empty?(preloads) do
      query
    else
      LedgerBankApi.Repo.preload(query, preloads)
    end
  end

  @doc """
  Builds a query with dynamic where conditions.
  """
  def build_dynamic_query(schema, conditions) do
    Enum.reduce(conditions, schema, fn {field, operator, value}, acc ->
      case operator do
        :eq -> where(acc, [s], field(s, ^field) == ^value)
        :ne -> where(acc, [s], field(s, ^field) != ^value)
        :gt -> where(acc, [s], field(s, ^field) > ^value)
        :gte -> where(acc, [s], field(s, ^field) >= ^value)
        :lt -> where(acc, [s], field(s, ^field) < ^value)
        :lte -> where(acc, [s], field(s, ^field) <= ^value)
        :like -> where(acc, [s], like(field(s, ^field), ^"%#{value}%"))
        :ilike -> where(acc, [s], ilike(field(s, ^field), ^"%#{value}%"))
        :in -> where(acc, [s], field(s, ^field) in ^value)
        :not_in -> where(acc, [s], field(s, ^field) not in ^value)
        :is_nil -> where(acc, [s], is_nil(field(s, ^field)))
        :not_is_nil -> where(acc, [s], not is_nil(field(s, ^field)))
        _ -> acc
      end
    end)
  end

  @doc """
  Executes a query with pagination and returns results with metadata.
  """
  def execute_paginated_query(query, page, page_size) do
    total_count = LedgerBankApi.Repo.aggregate(query, :count)
    offset = (page - 1) * page_size

    results = query
    |> limit(^page_size)
    |> offset(^offset)
    |> LedgerBankApi.Repo.all()

    {:ok, %{
      data: results,
      pagination: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: ceil(total_count / page_size),
        has_next: page < ceil(total_count / page_size),
        has_prev: page > 1
      }
    }}
  end
end

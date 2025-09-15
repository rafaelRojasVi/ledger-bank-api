defmodule LedgerBankApi.Database do
  @moduledoc """
  Consolidated database operations and query helpers.
  Combines functionality from query_helpers, crud_helpers, and other database utilities.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import LedgerBankApi.Database.Macros

  # ============================================================================
  # ENHANCED CRUD OPERATIONS WITH ERROR HANDLING
  # ============================================================================

  @doc """
  Get a record by ID with error handling.
  """
  def get_with_error_handling(queryable, id) do
    with_error_handling(:get_record, %{queryable: queryable, id: id}, do:
      case Repo.get(queryable, id) do
        nil -> {:error, :not_found}
        record -> {:ok, record}
      end
    )
  end

  @doc """
  Create a record with error handling.
  """
  def create_with_error_handling(queryable, attrs) do
    with_error_handling(:create_record, %{queryable: queryable, attrs: attrs}, do:
      struct(queryable, %{})
      |> queryable.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Update a record with error handling.
  """
  def update_with_error_handling(record, attrs) do
    with_error_handling(:update_record, %{id: record.id, attrs: attrs}, do:
      record
      |> record.__struct__.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a record with error handling.
  """
  def delete_with_error_handling(record) do
    with_error_handling(:delete_record, %{id: record.id}, do:
      Repo.delete(record)
    )
  end

  @doc """
  List records with options and error handling.
  """
  def list_with_error_handling(queryable, opts \\ []) do
    with_error_handling(:list_records, %{queryable: queryable, opts: opts}, do:
      queryable
      |> apply_filters(opts[:filters])
      |> apply_sorting(opts[:sort])
      |> apply_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  # ============================================================================
  # CRUD MACROS
  # ============================================================================


  def get(queryable, id) do
    with_error_handling(:get_record, %{queryable: queryable, id: id}, do:
      case Repo.get(queryable, id) do
        nil -> {:error, :not_found}
        record -> {:ok, record}
      end
    )
  end

  def get!(queryable, id) do
    with_error_handling(:get_record_bang, %{queryable: queryable, id: id}, do:
      Repo.get!(queryable, id)
    )
  end

  def get_by(queryable, clauses) do
    with_error_handling(:get_by_record, %{queryable: queryable, clauses: clauses}, do:
      case Repo.get_by(queryable, clauses) do
        nil -> {:error, :not_found}
        record -> {:ok, record}
      end
    )
  end

  def get_by!(queryable, clauses) do
    with_error_handling(:get_by_record_bang, %{queryable: queryable, clauses: clauses}, do:
      Repo.get_by!(queryable, clauses)
    )
  end

  def list(queryable) do
    with_error_handling(:list_records, %{queryable: queryable}, do:
      Repo.all(queryable)
    )
  end

  def list(queryable, opts) do
    with_error_handling(:list_records_with_opts, %{queryable: queryable, opts: opts}, do:
      queryable
      |> apply_filters(opts[:filters])
      |> apply_sorting(opts[:sort])
      |> apply_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  def create(changeset) do
    with_error_handling(:create_record, %{changeset: changeset}, do:
      Repo.insert(changeset)
    )
  end

  def update(changeset) do
    with_error_handling(:update_record, %{changeset: changeset}, do:
      Repo.update(changeset)
    )
  end

  def delete(record) do
    with_error_handling(:delete_record, %{record: record}, do:
      Repo.delete(record)
    )
  end

  def delete_all(queryable) do
    with_error_handling(:delete_all_records, %{queryable: queryable}) do
      {count, _} = Repo.delete_all(queryable)
      count
    end
  end


  @doc """
  Apply filters to a query.
  """
  def apply_filters(query, nil), do: query
  def apply_filters(query, []), do: query
  def apply_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn {field, value}, acc ->
      case field do
        :status when is_binary(value) ->
          where(acc, [r], r.status == ^value)
        :user_id when is_binary(value) ->
          where(acc, [r], r.user_id == ^value)
        :bank_id when is_binary(value) ->
          where(acc, [r], r.bank_id == ^value)
        :account_id when is_binary(value) ->
          where(acc, [r], r.account_id == ^value)
        :user_bank_account_id when is_binary(value) ->
          where(acc, [r], r.user_bank_account_id == ^value)
        :bank_branch_id when is_binary(value) ->
          where(acc, [r], r.bank_branch_id == ^value)
        :user_bank_login_id when is_binary(value) ->
          where(acc, [r], r.user_bank_login_id == ^value)
        :created_at_start when is_binary(value) ->
          where(acc, [r], r.inserted_at >= ^value)
        :created_at_end when is_binary(value) ->
          where(acc, [r], r.inserted_at <= ^value)
        :updated_at_start when is_binary(value) ->
          where(acc, [r], r.updated_at >= ^value)
        :updated_at_end when is_binary(value) ->
          where(acc, [r], r.updated_at <= ^value)
        _ ->
          acc
      end
    end)
  end

  @doc """
  Apply sorting to a query.
  """
  def apply_sorting(query, nil), do: query
  def apply_sorting(query, []), do: query
  def apply_sorting(query, sort) when is_list(sort) do
    Enum.reduce(sort, query, fn {field, direction}, acc ->
      case direction do
        :asc -> order_by(acc, [r], asc: field(r, ^field))
        :desc -> order_by(acc, [r], desc: field(r, ^field))
        _ -> acc
      end
    end)
  end

  @doc """
  Apply pagination to a query.
  """
  def apply_pagination(query, nil), do: query
  def apply_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size
    query
    |> limit(^page_size)
    |> offset(^offset)
  end

  @doc """
  Get paginated results with metadata.
  """
  def paginate(query, pagination) do
    page = pagination[:page] || 1
    page_size = pagination[:page_size] || 20

    # Get total count
    total_count = Repo.aggregate(query, :count)

    # Get paginated results
    offset_value = (page - 1) * page_size
    results = query
    |> limit(^page_size)
    |> offset(^offset_value)
    |> Repo.all()

    # Calculate pagination metadata
    total_pages = ceil(total_count / page_size)
    has_next = page < total_pages
    has_prev = page > 1

    pagination_meta = %{
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages,
      has_next: has_next,
      has_prev: has_prev
    }

    {:ok, %{
      data: results,
      pagination: pagination_meta
    }}
  end

  @doc """
  Get records with preloads.
  """
  def get_with_preloads(queryable, id, preloads) do
    with_error_handling(:get_with_preloads, %{queryable: queryable, id: id, preloads: preloads}, do:
      case Repo.get(queryable, id) do
        nil -> {:error, :not_found}
        record -> {:ok, Repo.preload(record, preloads)}
      end
    )
  end

  def get_with_preloads!(queryable, id, preloads) do
    with_error_handling(:get_with_preloads_bang, %{queryable: queryable, id: id, preloads: preloads}, do:
      queryable
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    )
  end

  @doc """
  Get records with preloads and user filtering.
  """
  def get_with_preloads_and_user!(queryable, id, preloads, user_id) do
    with_error_handling(:get_with_preloads_and_user_bang, %{queryable: queryable, id: id, preloads: preloads, user_id: user_id}, do:
      queryable
      |> where([r], r.user_id == ^user_id)
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    )
  end

  @doc """
  List records with preloads.
  """
  def list_with_preloads(queryable, preloads) do
    with_error_handling(:list_with_preloads, %{queryable: queryable, preloads: preloads}, do:
      queryable
      |> Repo.all()
      |> Repo.preload(preloads)
    )
  end

  @doc """
  List records with preloads and filters.
  """
  def list_with_preloads(queryable, preloads, opts) do
    with_error_handling(:list_with_preloads_and_opts, %{queryable: queryable, preloads: preloads, opts: opts}, do:
      queryable
      |> apply_filters(opts[:filters])
      |> apply_sorting(opts[:sort])
      |> apply_pagination(opts[:pagination])
      |> Repo.all()
      |> Repo.preload(preloads)
    )
  end

  @doc """
  Transaction wrapper for database operations.
  """
  def transaction(fun) do
    with_error_handling(:transaction, %{}, do:
      Repo.transaction(fun)
    )
  end

  @doc """
  Rollback a transaction.
  """
  def rollback(reason) do
    with_error_handling(:rollback, %{reason: reason}, do:
      Repo.rollback(reason)
    )
  end
end

defmodule LedgerBankApi.Banking.Pagination do
  @moduledoc """
  Provides pagination utilities for banking context functions, including query pagination, total count, and paginated response formatting.
  """

  require Ecto.Query

  @doc """
  Applies pagination to an Ecto query.
  """
  def apply_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query
    |> Ecto.Query.limit(^page_size)
    |> Ecto.Query.offset(^offset)
  end

  @doc """
  Gets total count for a query without pagination.
  """
  def get_total_count(query, repo \\ LedgerBankApi.Repo) do
    query
    |> Ecto.Query.exclude(:order_by)
    |> Ecto.Query.exclude(:preload)
    |> repo.aggregate(:count)
  end

  @doc """
  Executes a paginated query and returns data with metadata.
  """
  def execute_paginated_query(query, pagination_params, repo \\ LedgerBankApi.Repo) do
    total_count = get_total_count(query, repo)
    paginated_query = apply_pagination(query, pagination_params)
    data = repo.all(paginated_query)

    metadata = LedgerBankApi.Behaviours.Paginated.build_pagination_metadata(
      pagination_params.page,
      pagination_params.page_size,
      total_count
    )

    %{
      data: data,
      pagination: metadata
    }
  end
end

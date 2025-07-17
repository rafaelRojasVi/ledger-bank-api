defmodule LedgerBankApi.Behaviours.Paginated do
  @moduledoc """
  Behaviour and utility functions for modules that support pagination.
  Provides extraction, validation, and struct creation for pagination parameters in API requests.
  """

  @callback handle_paginated_data(any(), map(), keyword()) :: any()
  @callback extract_pagination_params(map()) :: map()
  @callback validate_pagination_params(map()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Extracts pagination parameters from request params with sensible defaults.
  """
  def extract_pagination_params(params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "20") |> String.to_integer()

    %{page: page, page_size: page_size}
  end

  @doc """
  Validates pagination parameters and returns normalized values.
  """
  def validate_pagination_params(%{page: page, page_size: page_size}) do
    cond do
      page < 1 ->
        {:error, "Page must be greater than 0"}
      page_size < 1 ->
        {:error, "Page size must be greater than 0"}
      page_size > 100 ->
        {:error, "Page size cannot exceed 100"}
      true ->
        {:ok, %{page: page, page_size: page_size}}
    end
  end

  @doc """
  Calculates offset from page and page_size.
  """
  def calculate_offset(page, page_size) do
    (page - 1) * page_size
  end

  @doc """
  Builds pagination metadata for response.
  """
  def build_pagination_metadata(page, page_size, total_count) do
    total_pages = ceil(total_count / page_size)

    %{
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end

  @doc """
  Creates a pagination struct for easy handling.
  """
  def create_pagination_struct(params) do
    case validate_pagination_params(extract_pagination_params(params)) do
      {:ok, validated_params} -> {:ok, struct(LedgerBankApi.Behaviours.PaginationParams, validated_params)}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule LedgerBankApi.Behaviours.PaginationParams do
  @moduledoc """
  Struct for pagination parameters.
  """
  defstruct [:page, :page_size]

  @type t :: %__MODULE__{
    page: integer(),
    page_size: integer()
  }
end

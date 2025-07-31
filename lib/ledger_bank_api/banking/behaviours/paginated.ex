defmodule LedgerBankApi.Banking.Behaviours.Paginated do
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
    per_page = Map.get(params, "page_size", "20") |> String.to_integer()

    %{page: page, per_page: per_page}
  end

  @doc """
  Validates pagination parameters and returns normalized values.
  """
  def validate_pagination_params(%{page: page, per_page: per_page}) do
    cond do
      page < 1 ->
        {:error, "Page must be greater than 0"}
      per_page < 1 ->
        {:error, "Page size must be greater than 0"}
      per_page > 100 ->
        {:error, "Page size cannot exceed 100"}
      true ->
        {:ok, %{page: page, per_page: per_page}}
    end
  end

  @doc """
  Calculates offset from page and per_page.
  """
  def calculate_offset(page, per_page) do
    (page - 1) * per_page
  end

  @doc """
  Builds pagination metadata for response.
  """
  def build_pagination_metadata(page, per_page, total_count) do
    total_pages = ceil(total_count / per_page)

    %{
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end

  @doc """
  Generic helper for struct creation/validation from params, validation function, and struct module.
  """
  def create_struct(params, validate_fun, struct_mod) do
    case validate_fun.(params) do
      {:ok, validated_params} -> {:ok, struct(struct_mod, validated_params)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a pagination struct for easy handling.
  """
  def create_pagination_struct(params) do
    create_struct(extract_pagination_params(params), &validate_pagination_params/1, LedgerBankApi.Banking.Behaviours.PaginationParams)
  end
end

defmodule LedgerBankApi.Banking.Behaviours.PaginationParams do
  @moduledoc """
  Struct for pagination parameters.
  """
  defstruct [:page, :page_size]

  @type t :: %__MODULE__{
    page: integer(),
    page_size: integer()
  }
end

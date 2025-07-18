defmodule LedgerBankApi.Banking.Behaviours.Sortable do
  @moduledoc """
  Behaviour and utility functions for modules that support sorting.
  Provides extraction, validation, and struct creation for sort parameters in API requests.
  """

  require Ecto.Query

  @callback handle_sorted_data(any(), map(), keyword()) :: any()
  @callback extract_sort_params(map()) :: map()
  @callback validate_sort_params(map(), list()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Extracts sort parameters from request params.
  """
  def extract_sort_params(params) do
    %{
      sort_by: Map.get(params, "sort_by", "posted_at"),
      sort_order: Map.get(params, "sort_order", "desc")
    }
  end

  @doc """
  Validates sort parameters against allowed fields and orders.
  """
  def validate_sort_params(%{sort_by: sort_by, sort_order: sort_order}, allowed_fields) do
    cond do
      sort_by not in allowed_fields ->
        {:error, "Invalid sort field. Allowed: #{Enum.join(allowed_fields, ", ")}"}
      sort_order not in ["asc", "desc"] ->
        {:error, "Sort order must be 'asc' or 'desc'"}
      true ->
        {:ok, %{sort_by: sort_by, sort_order: sort_order}}
    end
  end

  @doc """
  Applies sorting to an Ecto query.
  """
  def apply_sorting(query, %{sort_by: field, sort_order: order}) do
    direction = if order == "asc", do: :asc, else: :desc

    case field do
      "posted_at" -> Ecto.Query.order_by(query, [q], [{^direction, q.posted_at}])
      "amount" -> Ecto.Query.order_by(query, [q], [{^direction, q.amount}])
      "description" -> Ecto.Query.order_by(query, [q], [{^direction, q.description}])
      "created_at" -> Ecto.Query.order_by(query, [q], [{^direction, q.inserted_at}])
      _ -> query
    end
  end

  @doc """
  Creates a sort struct for easy handling.
  """
  def create_sort_struct(params, allowed_fields) do
    case validate_sort_params(extract_sort_params(params), allowed_fields) do
      {:ok, validated_params} -> {:ok, struct(LedgerBankApi.Banking.Behaviours.SortParams, validated_params)}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule LedgerBankApi.Banking.Behaviours.SortParams do
  @moduledoc """
  Struct for sort parameters.
  """
  defstruct [:sort_by, :sort_order]

  @type t :: %__MODULE__{
    sort_by: String.t(),
    sort_order: String.t()
  }
end

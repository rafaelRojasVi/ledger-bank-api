defmodule LedgerBankApi.Banking.Behaviours.Filterable do
  @moduledoc """
  Behaviour and utility functions for modules that support filtering.
  Provides extraction, validation, and struct creation for filter parameters in API requests.
  """

  @callback handle_filtered_data(any(), map(), keyword()) :: any()
  @callback extract_filter_params(map()) :: map()
  @callback validate_filter_params(map()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Extracts filter parameters from request params.
  """
  def extract_filter_params(params) do
    %{
      date_from: Map.get(params, "date_from"),
      date_to: Map.get(params, "date_to"),
      amount_min: Map.get(params, "amount_min"),
      amount_max: Map.get(params, "amount_max"),
      description: Map.get(params, "description"),
      status: Map.get(params, "status")
    }
  end

  @doc """
  Validates filter parameters and returns normalized values.
  """
  def validate_filter_params(filters) do
    # Remove nil values and validate date ranges
    valid_filters = filters
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()

    case validate_date_range(valid_filters) do
      {:ok, validated_filters} -> {:ok, validated_filters}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_date_range(%{date_from: from, date_to: to} = filters) do
    case {parse_date(from), parse_date(to)} do
      {{:ok, from_date}, {:ok, to_date}} ->
        if DateTime.compare(from_date, to_date) == :gt do
          {:error, "Date from must be before date to"}
        else
          {:ok, Map.put(filters, :date_from, from_date)}
          |> then(fn {:ok, f} -> {:ok, Map.put(f, :date_to, to_date)} end)
        end
      {{:error, _}, _} ->
        {:error, "Invalid date_from format"}
      {_, {:error, _}} ->
        {:error, "Invalid date_to format"}
    end
  end

  defp validate_date_range(filters), do: {:ok, filters}

  defp parse_date(nil), do: {:ok, nil}
  defp parse_date(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Invalid date format"}
    end
  end

  @doc """
  Creates a filter struct for easy handling.
  """
  def create_filter_struct(params) do
    case validate_filter_params(extract_filter_params(params)) do
      {:ok, validated_params} -> {:ok, struct(LedgerBankApi.Banking.Behaviours.FilterParams, validated_params)}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule LedgerBankApi.Banking.Behaviours.FilterParams do
  @moduledoc """
  Struct for filter parameters.
  """
  defstruct [:date_from, :date_to, :amount_min, :amount_max, :description, :status]

  @type t :: %__MODULE__{
    date_from: DateTime.t() | nil,
    date_to: DateTime.t() | nil,
    amount_min: Decimal.t() | nil,
    amount_max: Decimal.t() | nil,
    description: String.t() | nil,
    status: String.t() | nil
  }
end

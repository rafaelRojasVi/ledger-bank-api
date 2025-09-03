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
      date_from: Map.get(params, "start_date"),
      date_to: Map.get(params, "end_date"),
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
      {:ok, validated_filters} ->
        case validate_amount_range(validated_filters) do
          {:ok, validated_amounts} -> {:ok, validated_amounts}
          {:error, reason} -> {:error, reason}
        end
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

  defp validate_date_range(%{date_from: from} = filters) do
    case parse_date(from) do
      {:ok, from_date} ->
        {:ok, Map.put(filters, :date_from, from_date)}
      {:error, _} ->
        {:error, "Invalid date_from format"}
    end
  end

  defp validate_date_range(%{date_to: to} = filters) do
    case parse_date(to) do
      {:ok, to_date} ->
        {:ok, Map.put(filters, :date_to, to_date)}
      {:error, _} ->
        {:error, "Invalid date_to format"}
    end
  end

  defp validate_date_range(filters), do: {:ok, filters}

  defp validate_amount_range(%{amount_min: min, amount_max: max} = filters) do
    case {parse_amount(min), parse_amount(max)} do
      {{:ok, min_amount}, {:ok, max_amount}} ->
        if Decimal.compare(min_amount, max_amount) == :gt do
          {:error, "Amount min must be less than or equal to amount max"}
        else
          {:ok, Map.put(filters, :amount_min, min_amount)}
          |> then(fn {:ok, f} -> {:ok, Map.put(f, :amount_max, max_amount)} end)
        end
      {{:error, _}, _} ->
        {:error, "Invalid amount_min format"}
      {_, {:error, _}} ->
        {:error, "Invalid amount_max format"}
    end
  end

  defp validate_amount_range(%{amount_min: min} = filters) do
    case parse_amount(min) do
      {:ok, min_amount} ->
        {:ok, Map.put(filters, :amount_min, min_amount)}
      {:error, _} ->
        {:error, "Invalid amount_min format"}
    end
  end

  defp validate_amount_range(%{amount_max: max} = filters) do
    case parse_amount(max) do
      {:ok, max_amount} ->
        {:ok, Map.put(filters, :amount_max, max_amount)}
      {:error, _} ->
        {:error, "Invalid amount_max format"}
    end
  end

  defp validate_amount_range(filters), do: {:ok, filters}

  defp parse_amount(nil), do: {:ok, nil}
  defp parse_amount(amount_string) when is_binary(amount_string) do
    case Decimal.parse(amount_string) do
      {decimal, _remainder} -> {:ok, decimal}
      :error -> {:error, "Invalid amount format"}
    end
  end
  defp parse_amount(_), do: {:error, "Invalid amount format"}

  defp parse_date(nil), do: {:ok, nil}
  defp parse_date(date_string) do
    # Try parsing as ISO8601 datetime first
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ ->
        # Try parsing as date and convert to datetime
        case Date.from_iso8601(date_string) do
          {:ok, date} ->
            case DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
              {:ok, datetime} -> {:ok, datetime}
              _ -> {:error, "Invalid date format"}
            end
          _ -> {:error, "Invalid date format"}
        end
    end
  end

  alias LedgerBankApi.Banking.Behaviours.SharedBehaviours

  @doc """
  Creates a filter struct for easy handling.
  """
  def create_filter_struct(params) do
    SharedBehaviours.create_struct(extract_filter_params(params), &validate_filter_params/1, LedgerBankApi.Banking.Behaviours.FilterParams)
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

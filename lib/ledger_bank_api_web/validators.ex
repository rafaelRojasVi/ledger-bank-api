defmodule LedgerBankApiWeb.Validators do
  @moduledoc """
  Input validation for API endpoints.
  Provides comprehensive validation with detailed error messages.
  """

  require Logger

  @doc """
  Validates UUID format.
  """
  def validate_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> {:ok, uuid}
      :error -> {:error, "Invalid UUID format"}
    end
  end

  def validate_uuid(_), do: {:error, "UUID must be a string"}

  @doc """
  Validates pagination parameters.
  """
  def validate_pagination(params) do
    page = parse_integer(params["page"], 1)
    per_page = parse_integer(params["per_page"], 20)

    cond do
      page < 1 ->
        {:error, "Page must be greater than 0"}

      per_page < 1 ->
        {:error, "Per page must be greater than 0"}

      per_page > 100 ->
        {:error, "Per page cannot exceed 100"}

      true ->
        {:ok, %{page: page, per_page: per_page}}
    end
  end

  @doc """
  Validates date range parameters.
  """
  def validate_date_range(params) do
    from_date = parse_datetime(params["from_date"])
    to_date = parse_datetime(params["to_date"])

    case {from_date, to_date} do
      {{:ok, from}, {:ok, to}} when from > to ->
        {:error, "From date must be before to date"}

      {{:ok, from}, {:ok, to}} ->
        {:ok, %{from_date: from, to_date: to}}

      {{:error, reason}, _} ->
        {:error, "Invalid from_date: #{reason}"}

      {_, {:error, reason}} ->
        {:error, "Invalid to_date: #{reason}"}
    end
  end

  @doc """
  Validates account filters.
  """
  def validate_account_filters(params) do
    user_id = validate_uuid(params["user_id"])
    institution = validate_string(params["institution"], "institution")

    case {user_id, institution} do
      {{:ok, uid}, {:ok, inst}} ->
        {:ok, %{user_id: uid, institution: inst}}

      {{:error, reason}, _} ->
        {:error, reason}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Validates transaction filters.
  """
  def validate_transaction_filters(params) do
    account_id = validate_uuid(params["account_id"])
    date_range = validate_date_range(params)
    order_by = validate_order_by(params["order_by"])

    case {account_id, date_range, order_by} do
      {{:ok, aid}, {:ok, dr}, {:ok, ob}} ->
        {:ok, Map.merge(dr, %{account_id: aid, order_by: ob})}

      {{:error, reason}, _, _} ->
        {:error, reason}

      {_, {:error, reason}, _} ->
        {:error, reason}

      {_, _, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Validates enrollment ID for live snapshots.
  """
  def validate_enrollment_id(enrollment_id) do
    case validate_uuid(enrollment_id) do
      {:ok, _} -> {:ok, enrollment_id}
      {:error, reason} -> {:error, "Invalid enrollment ID: #{reason}"}
    end
  end

  @doc """
  Sanitizes and validates string inputs.
  """
  def validate_string(value, field_name) when is_binary(value) do
    sanitized = String.trim(value)

    cond do
      String.length(sanitized) == 0 ->
        {:error, "#{field_name} cannot be empty"}

      String.length(sanitized) > 255 ->
        {:error, "#{field_name} cannot exceed 255 characters"}

      true ->
        {:ok, sanitized}
    end
  end

  def validate_string(nil, _), do: {:ok, nil}
  def validate_string(_, field_name), do: {:error, "#{field_name} must be a string"}

  @doc """
  Validates order by parameter.
  """
  def validate_order_by(order_by) when is_binary(order_by) do
    case String.downcase(order_by) do
      "asc" -> {:ok, :asc}
      "desc" -> {:ok, :desc}
      _ -> {:error, "Order by must be 'asc' or 'desc'"}
    end
  end

  def validate_order_by(nil), do: {:ok, :desc}
  def validate_order_by(_), do: {:error, "Order by must be a string"}

  # Private helper functions

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(_, default), do: default

  defp parse_datetime(nil), do: {:ok, nil}
  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, _} -> {:error, "Invalid date format. Use ISO8601 format"}
    end
  end

  defp parse_datetime(_), do: {:error, "Date must be a string"}
end

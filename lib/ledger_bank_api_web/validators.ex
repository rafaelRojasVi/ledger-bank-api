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
end

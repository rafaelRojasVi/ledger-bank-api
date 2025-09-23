defmodule LedgerBankApi.Core.Validator do
  @moduledoc """
  Centralized validation module for the LedgerBankApi application.

  This module provides core validation functions that return simple error reasons.
  These reasons are then converted to proper Error structs by ErrorHandler.

  ## Architecture Role

  - **Purpose**: Core validation logic that can be reused across the application
  - **Returns**: Simple error reasons (atoms) like `:invalid_uuid_format`, `:missing_fields`
  - **Used by**: InputValidator (web layer), UserService (business layer)
  - **Error conversion**: InputValidator converts these reasons to ErrorHandler.business_error calls

  ## Usage

      # Direct usage in business logic
      case Validator.validate_uuid(user_id) do
        :ok -> proceed_with_operation()
        {:error, reason} -> {:error, ErrorHandler.business_error(reason, context)}
      end

      # Used by InputValidator for web layer validation
      InputValidator.validate_user_id(user_id)  # internally uses Validator.validate_uuid
  """

  @doc """
  Validates UUID format.

  Returns :ok for valid UUIDs, {:error, reason} for invalid ones.
  """
  def validate_uuid(nil), do: {:error, :missing_fields}
  def validate_uuid(""), do: {:error, :missing_fields}
  def validate_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _uuid} -> :ok
      :error -> {:error, :invalid_uuid_format}
    end
  end
  def validate_uuid(_), do: {:error, :invalid_uuid_format}

  @doc """
  Validates email format using the same regex as User schema.

  Returns :ok for valid emails, {:error, reason} for invalid ones.
  """
  def validate_email(nil), do: {:error, :missing_fields}
  def validate_email(""), do: {:error, :missing_fields}
  def validate_email(email) when is_binary(email) do
    # Use the same regex as User schema for consistency
    case Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email) do
      true -> :ok
      false -> {:error, :invalid_email_format}
    end
  end
  def validate_email(_), do: {:error, :invalid_email_format}

  @doc """
  Validates email format with security consideration.

  For security reasons, invalid email formats return :user_not_found
  instead of :invalid_email_format to prevent email enumeration attacks.
  """
  def validate_email_secure(nil), do: {:error, :user_not_found}
  def validate_email_secure(""), do: {:error, :user_not_found}
  def validate_email_secure(email) when is_binary(email) do
    case Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email) do
      true -> :ok
      false -> {:error, :user_not_found}
    end
  end
  def validate_email_secure(_), do: {:error, :user_not_found}

  @doc """
  Validates password presence and type.

  Returns :ok for valid passwords, {:error, reason} for invalid ones.
  """
  def validate_password(nil), do: {:error, :invalid_credentials}
  def validate_password(""), do: {:error, :invalid_credentials}
  def validate_password(password) when is_binary(password), do: :ok
  def validate_password(_), do: {:error, :invalid_credentials}

  @doc """
  Validates datetime format and ensures it's in the future.

  Returns :ok for valid future datetimes, {:error, reason} for invalid ones.
  """
  def validate_future_datetime(nil), do: {:error, :missing_fields}
  def validate_future_datetime(datetime) when is_struct(datetime, DateTime) do
    if DateTime.compare(DateTime.utc_now(), datetime) == :lt do
      :ok
    else
      {:error, :invalid_datetime_format}
    end
  end
  def validate_future_datetime(_), do: {:error, :invalid_datetime_format}

  @doc """
  Validates that a value is not nil or empty.

  Returns :ok for non-empty values, {:error, reason} for empty ones.
  """
  def validate_required(nil), do: {:error, :missing_fields}
  def validate_required(""), do: {:error, :missing_fields}
  def validate_required(value) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, :missing_fields}
    else
      :ok
    end
  end
  def validate_required(_), do: :ok

  @doc """
  Validates multiple fields using a list of validation functions.

  Returns :ok if all validations pass, {:error, reason} for the first failure.
  """
  def validate_all(validations) when is_list(validations) do
    Enum.reduce_while(validations, :ok, fn validation, _acc ->
      case validation do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Validates a map of fields using corresponding validation functions.

  Returns :ok if all validations pass, {:error, reason} for the first failure.
  """
  def validate_fields(fields, validations) when is_map(fields) and is_map(validations) do
    Enum.reduce_while(validations, :ok, fn {field, validator}, _acc ->
      value = Map.get(fields, field)
      case validator.(value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end

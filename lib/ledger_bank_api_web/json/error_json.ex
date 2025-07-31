defmodule LedgerBankApiWeb.ErrorJSON do
  @moduledoc """
  Error JSON templates for Phoenix error handling.
  """

  # Phoenix expects these specific function names for status codes
  def error_400(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "validation_error",
        message: "Validation failed",
        code: 400,
        details: %{reason: reason}
      }
    }
  end

  def error_401(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "unauthorized",
        message: "Unauthorized access",
        code: 401,
        details: %{reason: reason}
      }
    }
  end

  def error_404(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "not_found",
        message: "Resource not found",
        code: 404,
        details: %{reason: reason}
      }
    }
  end

  def error_409(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "conflict",
        message: "Constraint violation: users_email_index",
        code: 409,
        details: %{reason: reason}
      }
    }
  end

  def error_500(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "internal_server_error",
        message: "An unexpected error occurred",
        code: 500,
        details: %{reason: reason}
      }
    }
  end

  # Fallback error function
  def error(%{conn: _conn, reason: reason}) do
    %{
      error: %{
        type: "internal_server_error",
        message: "An unexpected error occurred",
        code: 500,
        details: %{reason: reason}
      }
    }
  end

  # Phoenix expects these function names for status codes (without "error_" prefix)
  def unquote(:"500")(%{reason: reason}) do
    error_500(%{conn: nil, reason: reason})
  end

  def unquote(:"404")(%{reason: reason}) do
    error_404(%{conn: nil, reason: reason})
  end

  def unquote(:"401")(%{reason: reason}) do
    error_401(%{conn: nil, reason: reason})
  end

  def unquote(:"400")(%{reason: reason}) do
    error_400(%{conn: nil, reason: reason})
  end

  def unquote(:"409")(%{reason: reason}) do
    error_409(%{conn: nil, reason: reason})
  end

end

defmodule LedgerBankApiWeb.ErrorJSON do
  @moduledoc """
  Fallback error handling for Phoenix when the custom ErrorAdapter doesn't handle the error.

  This module provides JSON error responses for standard HTTP status codes
  when the application's custom error handling system doesn't catch the error.
  """

  # If you want to use a Phoenix status, we recommend adding the "catch-all"
  # `:internal_server_error` below. For now, we just return the connection
  # to be handled by the custom error handling system.

  def render("500.json", %{conn: _conn}) do
    # Fallback error handler for unexpected 500 errors
    # Custom error handling should prevent this in normal operation
    %{
      error: %{
        type: "internal_server_error",
        reason: "An unexpected error occurred",
        message: "Please try again later",
        code: 500,
        timestamp: DateTime.utc_now()
      }
    }
  end

  def render("404.json", %{conn: _conn}) do
    %{
      error: %{
        type: "not_found",
        reason: "resource_not_found",
        message: "The requested resource was not found",
        code: 404,
        timestamp: DateTime.utc_now()
      }
    }
  end

  def render("400.json", %{conn: _conn}) do
    %{
      error: %{
        type: "bad_request",
        reason: "invalid_request",
        message: "The request was invalid",
        code: 400,
        timestamp: DateTime.utc_now()
      }
    }
  end

  def render("401.json", %{conn: _conn}) do
    %{
      error: %{
        type: "unauthorized",
        reason: "authentication_required",
        message: "Authentication is required",
        code: 401,
        timestamp: DateTime.utc_now()
      }
    }
  end

  def render("403.json", %{conn: _conn}) do
    %{
      error: %{
        type: "forbidden",
        reason: "access_denied",
        message: "Access denied",
        code: 403,
        timestamp: DateTime.utc_now()
      }
    }
  end

  def render("422.json", %{conn: _conn}) do
    %{
      error: %{
        type: "unprocessable_entity",
        reason: "validation_failed",
        message: "The request could not be processed",
        code: 422,
        timestamp: DateTime.utc_now()
      }
    }
  end

  # By default, Phoenix returns the status message from template
  # names. For example, "404.json" becomes "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

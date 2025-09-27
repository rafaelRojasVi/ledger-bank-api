defmodule LedgerBankApiWeb.FallbackController do
  @moduledoc """
  Fallback controller for handling errors in a centralized way.

  This controller eliminates the need for repetitive error handling in individual
  controller actions by providing a single point for error translation.
  """

  use LedgerBankApiWeb, :controller
  alias LedgerBankApiWeb.Adapters.ErrorAdapter
  alias LedgerBankApi.Core.Error

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    context = %{
      source: "fallback_controller",
      action: :changeset_error,
      correlation_id: conn.assigns[:correlation_id]
    }

    ErrorAdapter.handle_changeset_error(conn, changeset, context)
  end

  def call(conn, {:error, %Error{} = error}) do
    # Add correlation ID to error context if not present
    error_with_correlation = if is_nil(error.correlation_id) do
      %{error | correlation_id: conn.assigns[:correlation_id]}
    else
      error
    end

    ErrorAdapter.handle_error(conn, error_with_correlation)
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    context = %{
      source: "fallback_controller",
      action: :generic_error,
      correlation_id: conn.assigns[:correlation_id],
      reason: reason
    }

    ErrorAdapter.handle_generic_error(conn, reason, context)
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    context = %{
      source: "fallback_controller",
      action: :generic_error,
      correlation_id: conn.assigns[:correlation_id],
      message: reason
    }

    ErrorAdapter.handle_generic_error(conn, :internal_server_error, context)
  end

  def call(conn, {:error, reason}) do
    context = %{
      source: "fallback_controller",
      action: :unexpected_error,
      correlation_id: conn.assigns[:correlation_id],
      original_error: inspect(reason)
    }

    ErrorAdapter.handle_generic_error(conn, :internal_server_error, context)
  end

  def call(conn, result) do
    require Logger
    Logger.warning("FallbackController called with non-error result", %{
      result: inspect(result),
      correlation_id: conn.assigns[:correlation_id]
    })

    context = %{
      source: "fallback_controller",
      action: :unexpected_result,
      correlation_id: conn.assigns[:correlation_id],
      result: inspect(result)
    }

    ErrorAdapter.handle_generic_error(conn, :internal_server_error, context)
  end
end

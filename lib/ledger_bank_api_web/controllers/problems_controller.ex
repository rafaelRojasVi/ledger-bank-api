defmodule LedgerBankApiWeb.Controllers.ProblemsController do
  @moduledoc """
  Controller for exposing error catalog registry.

  Provides RFC 9457 Problem Details registry endpoint that allows clients
  to discover and understand all possible error types the API can return.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Core.ErrorCatalog

  @doc """
  GET /api/problems

  Returns the complete error catalog registry in RFC 9457 Problem Details format.
  This endpoint allows clients to discover all possible error types and their metadata.
  """
  def index(conn, _params) do
    problems =
      ErrorCatalog.reason_codes()
      |> Enum.map(fn {reason, category} ->
        %{
          code: reason,
          type: "https://api.ledgerbank.com/problems/#{reason}",
          status: ErrorCatalog.http_status_for_category(category),
          title: ErrorCatalog.default_message_for_reason(reason),
          category: category,
          retryable: should_retry_for_category?(category),
          retry_delay_ms: retry_delay_for_category(category),
          max_retry_attempts: max_retry_attempts_for_category(category)
        }
      end)
      |> Enum.sort_by(fn problem -> problem.code end)

    # Add metadata about the catalog
    metadata = %{
      total_errors: length(problems),
      categories: ErrorCatalog.categories(),
      api_version: "v1",
      last_updated: DateTime.utc_now()
    }

    handle_success(conn, problems, metadata)
  end

  @doc """
  GET /api/problems/:reason

  Returns detailed information about a specific error reason.
  """
  def show(conn, %{"reason" => reason}) do
    try do
      reason_atom = String.to_existing_atom(reason)

      if ErrorCatalog.valid_reason?(reason_atom) do
        category = ErrorCatalog.category_for_reason(reason_atom)

        problem = %{
          code: reason_atom,
          type: "https://api.ledgerbank.com/problems/#{reason_atom}",
          status: ErrorCatalog.http_status_for_category(category),
          title: ErrorCatalog.default_message_for_reason(reason_atom),
          category: category,
          retryable: should_retry_for_category?(category),
          retry_delay_ms: retry_delay_for_category(category),
          max_retry_attempts: max_retry_attempts_for_category(category),
          description: get_error_description(reason_atom),
          examples: get_error_examples(reason_atom)
        }

        handle_success(conn, problem)
      else
        context = build_context(conn, :get_error_reason, %{reason: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:invalid_reason_format, context)
        handle_error(conn, error)
      end
    rescue
      ArgumentError ->
        context = build_context(conn, :get_error_reason, %{reason: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:invalid_reason_format, context)
        handle_error(conn, error)
    end
  end

  @doc """
  GET /api/problems/category/:category

  Returns all error reasons for a specific category.
  """
  def category(conn, %{"category" => category}) do
    try do
      category_atom = String.to_existing_atom(category)

      if category_atom in ErrorCatalog.categories() do
        reasons = ErrorCatalog.reasons_for_category(category_atom)

        problems =
          reasons
          |> Enum.map(fn reason ->
            %{
              code: reason,
              type: "https://api.ledgerbank.com/problems/#{reason}",
              status: ErrorCatalog.http_status_for_category(category_atom),
              title: ErrorCatalog.default_message_for_reason(reason),
              category: category_atom,
              retryable: should_retry_for_category?(category_atom),
              retry_delay_ms: retry_delay_for_category(category_atom),
              max_retry_attempts: max_retry_attempts_for_category(category_atom)
            }
          end)
          |> Enum.sort_by(fn problem -> problem.code end)

        metadata = %{
          category: category_atom,
          total_errors: length(problems),
          http_status: ErrorCatalog.http_status_for_category(category_atom)
        }

        handle_success(conn, problems, metadata)
      else
        context = build_context(conn, :get_error_category, %{category: category})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:invalid_category, context)
        handle_error(conn, error)
      end
    rescue
      ArgumentError ->
        context = build_context(conn, :get_error_category, %{category: category})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:invalid_category_format, context)
        handle_error(conn, error)
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp should_retry_for_category?(category) do
    case category do
      :external_dependency -> true
      :system -> true
      _ -> false
    end
  end

  defp retry_delay_for_category(category) do
    case category do
      :external_dependency -> 1000
      :system -> 500
      _ -> 0
    end
  end

  defp max_retry_attempts_for_category(category) do
    case category do
      :external_dependency -> 3
      :system -> 2
      _ -> 0
    end
  end

  defp get_error_description(reason) do
    # Add more detailed descriptions for specific error reasons
    case reason do
      :insufficient_funds ->
        "The account does not have enough balance to complete the requested transaction."

      :daily_limit_exceeded ->
        "The payment amount would exceed the daily transaction limit for this account."

      :invalid_amount_format ->
        "The provided amount is not in a valid format or contains invalid characters."

      :account_not_found ->
        "No account exists with the provided identifier."

      _ ->
        "See the error catalog documentation for more details about this error type."
    end
  end

  defp get_error_examples(reason) do
    # Provide example error responses for common error types
    case reason do
      :insufficient_funds ->
        [
          %{
            amount: 100.00,
            available_balance: 75.50,
            requested_currency: "USD"
          }
        ]

      :daily_limit_exceeded ->
        [
          %{
            requested_amount: 5000.00,
            daily_limit: 2500.00,
            remaining_limit: 0.00
          }
        ]

      :invalid_amount_format ->
        [
          %{
            provided_value: "abc",
            expected_format: "decimal number (e.g., 100.50)"
          }
        ]

      _ ->
        []
    end
  end
end

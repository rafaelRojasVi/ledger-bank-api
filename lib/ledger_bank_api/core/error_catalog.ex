defmodule LedgerBankApi.Core.ErrorCatalog do
  @moduledoc """
  Error catalog defining the canonical error taxonomy for the LedgerBankApi application.

  This module serves as the single source of truth for error reason codes, categories,
  and their expected behavior. Treat changes to this catalog like API changes.

  ## Error Categories

  - `:validation` - Input validation failures (400)
  - `:not_found` - Resource not found (404)
  - `:authentication` - Authentication failures (401)
  - `:authorization` - Authorization failures (403)
  - `:conflict` - Resource conflicts (409)
  - `:business_rule` - Business logic violations (422)
  - `:external_dependency` - External service failures (503)
  - `:system` - Internal system errors (500)

  ## Policy Matrix

  | Category | Retryable | Circuit Breaker | Max Retries | Retry Delay |
  |----------|-----------|-----------------|-------------|-------------|
  | validation | No | No | 0 | 0ms |
  | not_found | No | No | 0 | 0ms |
  | authentication | No | No | 0 | 0ms |
  | authorization | No | No | 0 | 0ms |
  | conflict | No | No | 0 | 0ms |
  | business_rule | No | No | 0 | 0ms |
  | external_dependency | Yes | Yes | 3 | 1000ms |
  | system | Yes | Yes | 2 | 500ms |
  """

  @doc """
  Error reason codes and their categories.

  This is the central mapping that defines how each error reason is categorized.
  Categories drive HTTP status codes, retry behavior, and telemetry.

  ## Adding New Errors

  1. Add the reason to this map with appropriate category
  2. Add default message in `default_message_for_reason/1`
  3. Update tests in `error_catalog_test.exs`
  4. Document the error in API documentation

  ## Categories Guide

  - `:validation` - Input format/type errors (400) - No retry
  - `:business_rule` - Domain logic violations (422) - No retry
  - `:external_dependency` - Third-party service failures (503) - Retry 3x
  - `:system` - Internal infrastructure errors (500) - Retry 2x
  """
  def reason_codes do
    %{
      # ========================================================================
      # VALIDATION ERRORS (400) - Input format/type issues
      # ========================================================================
      :invalid_amount_format => :validation,
      :missing_fields => :validation,
      :invalid_direction => :validation,
      :invalid_email_format => :validation,
      :invalid_password_format => :validation,
      :invalid_uuid_format => :validation,
      :invalid_datetime_format => :validation,
      :invalid_name_format => :validation,
      :invalid_role => :validation,
      :invalid_status => :validation,
      :invalid_payment_type => :validation,
      :invalid_currency_format => :validation,
      :invalid_account_type => :validation,
      :invalid_description_format => :validation,
      :invalid_account_name_format => :validation,
      :amount_too_small => :validation,
      :account_frozen => :business_rule,
      :account_suspended => :business_rule,
      :description_required => :validation,
      :description_too_long => :validation,
      :webhook_processing_failed => :validation,
      :unauthorized_access => :authorization,

      # Not found errors
      :user_not_found => :not_found,
      :account_not_found => :not_found,
      :payment_not_found => :not_found,
      :token_not_found => :not_found,
      :bank_not_found => :not_found,

      # Authentication errors
      :invalid_credentials => :authentication,
      :invalid_password => :authentication,
      :invalid_token => :authentication,
      :token_expired => :authentication,
      :token_revoked => :authentication,
      :invalid_token_type => :authentication,
      :invalid_refresh_token_format => :authentication,
      :invalid_issuer => :authentication,
      :invalid_audience => :authentication,
      :token_not_yet_valid => :authentication,
      :missing_required_claims => :authentication,
      :unauthorized => :authentication,

      # Authorization errors
      :forbidden => :authorization,
      :insufficient_permissions => :authorization,

      # Conflict errors
      :email_already_exists => :conflict,
      :already_processed => :conflict,
      :duplicate_transaction => :conflict,

      # Business rule errors
      :insufficient_funds => :business_rule,
      :account_inactive => :business_rule,
      :daily_limit_exceeded => :business_rule,
      :amount_exceeds_limit => :business_rule,
      :negative_amount => :business_rule,
      :negative_balance => :business_rule,
      :currency_mismatch => :business_rule,

      # External dependency errors
      :timeout => :external_dependency,
      :service_unavailable => :external_dependency,
      :bank_api_error => :external_dependency,
      :payment_provider_error => :external_dependency,

      # System errors
      :internal_server_error => :system,
      :database_error => :system,
      :configuration_error => :system,

      # Additional error reasons for problems endpoint
      :invalid_reason_format => :validation,
      :invalid_category => :validation,
      :invalid_category_format => :validation
    }
  end

  @doc """
  Get category for a reason code.
  """
  def category_for_reason(reason) do
    Map.get(reason_codes(), reason, :system)
  end

  @doc """
  Get all reason codes for a category.
  """
  def reasons_for_category(category) do
    reason_codes()
    |> Enum.filter(fn {_reason, cat} -> cat == category end)
    |> Enum.map(fn {reason, _cat} -> reason end)
  end

  @doc """
  Check if a reason code exists in the catalog.
  """
  def valid_reason?(reason) do
    Map.has_key?(reason_codes(), reason)
  end

  @doc """
  Get all available categories.
  """
  def categories do
    [
      :validation,
      :not_found,
      :authentication,
      :authorization,
      :conflict,
      :business_rule,
      :external_dependency,
      :system
    ]
  end

  @doc """
  Get HTTP status code for a category.
  """
  def http_status_for_category(category) do
    case category do
      :validation -> 400
      :not_found -> 404
      :authentication -> 401
      :authorization -> 403
      :conflict -> 409
      :business_rule -> 422
      :external_dependency -> 503
      :system -> 500
    end
  end

  @doc """
  Get error type for a category (for backward compatibility).
  """
  def error_type_for_category(category) do
    case category do
      :validation -> :validation_error
      :not_found -> :not_found
      :authentication -> :unauthorized
      :authorization -> :forbidden
      :conflict -> :conflict
      :business_rule -> :unprocessable_entity
      :external_dependency -> :service_unavailable
      :system -> :internal_server_error
    end
  end

  @doc """
  Get default error message for a reason.
  """
  def default_message_for_reason(reason) do
    case reason do
      # Validation errors
      :invalid_amount_format -> "Invalid amount format"
      :missing_fields -> "Required fields are missing"
      :invalid_direction -> "Invalid payment direction"
      :invalid_email_format -> "Invalid email format"
      :invalid_password_format -> "Invalid password format"
      :invalid_uuid_format -> "Invalid UUID format"
      :invalid_datetime_format -> "Invalid datetime format"
      :invalid_name_format -> "Invalid name format"
      :invalid_role -> "Invalid role"
      :invalid_status -> "Invalid status"
      :invalid_payment_type -> "Invalid payment type"
      :invalid_currency_format -> "Invalid currency format"
      :invalid_account_type -> "Invalid account type"
      :invalid_description_format -> "Invalid description format"
      :invalid_account_name_format -> "Invalid account name format"
      :amount_too_small -> "Amount is too small"
      :account_frozen -> "Account is frozen"
      :account_suspended -> "Account is suspended"
      :description_required -> "Description is required"
      :description_too_long -> "Description is too long"
      :webhook_processing_failed -> "Webhook processing failed"
      :unauthorized_access -> "Unauthorized access to account"
      # Not found errors
      :user_not_found -> "User not found"
      :account_not_found -> "Account not found"
      :payment_not_found -> "Payment not found"
      :token_not_found -> "Token not found"
      :bank_not_found -> "Bank not found"
      # Authentication errors
      :invalid_credentials -> "Invalid credentials"
      :invalid_password -> "Invalid password"
      :invalid_token -> "Invalid token"
      :token_expired -> "Token has expired"
      :token_revoked -> "Token has been revoked"
      :invalid_token_type -> "Invalid token type"
      :invalid_refresh_token_format -> "Invalid refresh token format"
      :invalid_issuer -> "Invalid token issuer"
      :invalid_audience -> "Invalid token audience"
      :token_not_yet_valid -> "Token not yet valid"
      :missing_required_claims -> "Missing required token claims"
      :unauthorized -> "Unauthorized access"
      # Authorization errors
      :forbidden -> "Access forbidden"
      :insufficient_permissions -> "Insufficient permissions"
      # Conflict errors
      :email_already_exists -> "Email already exists"
      :already_processed -> "Resource has already been processed"
      :duplicate_transaction -> "Duplicate transaction"
      # Business rule errors
      :insufficient_funds -> "Insufficient funds for this transaction"
      :account_inactive -> "Account is inactive"
      :daily_limit_exceeded -> "Daily payment limit exceeded"
      :amount_exceeds_limit -> "Payment amount exceeds single transaction limit"
      :negative_amount -> "Payment amount cannot be negative"
      :negative_balance -> "Account balance cannot be negative"
      :currency_mismatch -> "Payment currency does not match account currency"
      # External dependency errors
      :timeout -> "Request timeout"
      :service_unavailable -> "Service temporarily unavailable"
      :bank_api_error -> "Bank API error"
      :payment_provider_error -> "Payment provider error"
      # System errors
      :internal_server_error -> "An unexpected error occurred"
      :database_error -> "Database error"
      :configuration_error -> "Configuration error"
      # Additional error reasons for problems endpoint
      :invalid_reason_format -> "Invalid error reason format"
      :invalid_category -> "Invalid error category"
      :invalid_category_format -> "Invalid error category format"
      _ -> "An unexpected error occurred"
    end
  end
end

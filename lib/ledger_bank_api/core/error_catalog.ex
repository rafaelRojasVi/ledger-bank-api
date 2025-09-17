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
  """
  def reason_codes do
    %{
      # Validation errors
      :invalid_amount_format => :validation,
      :missing_fields => :validation,
      :invalid_direction => :validation,
      :invalid_email_format => :validation,
      :invalid_password_format => :validation,

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
      :invalid_issuer => :authentication,
      :invalid_audience => :authentication,
      :token_not_yet_valid => :authentication,
      :missing_required_claims => :authentication,

      # Authorization errors
      :forbidden => :authorization,
      :unauthorized_access => :authorization,
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

      # External dependency errors
      :timeout => :external_dependency,
      :service_unavailable => :external_dependency,
      :bank_api_error => :external_dependency,
      :payment_provider_error => :external_dependency,

      # System errors
      :internal_server_error => :system,
      :database_error => :system,
      :configuration_error => :system
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
    [:validation, :not_found, :authentication, :authorization, :conflict, :business_rule, :external_dependency, :system]
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
end

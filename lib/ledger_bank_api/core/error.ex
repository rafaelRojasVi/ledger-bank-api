defmodule LedgerBankApi.Core.Error do
  @moduledoc """
  Core error handling module for the LedgerBankApi application.

  This module provides the canonical ErrorResponse struct and core error handling functionality.
  """

  defstruct [:type, :message, :code, :reason, :context, :timestamp, :category, :correlation_id, :source, :retryable, :circuit_breaker]

  @type t :: %__MODULE__{
    type: atom(),
    message: String.t(),
    code: integer(),
    reason: atom(),
    context: map(),
    timestamp: DateTime.t(),
    category: atom(),
    correlation_id: String.t() | nil,
    source: String.t() | nil,
    retryable: boolean(),
    circuit_breaker: boolean()
  }

  @doc """
  Creates a new ErrorResponse with the given parameters.
  """
  def new(type, message, code, reason, context \\ %{}, opts \\ []) do
    category = Keyword.get(opts, :category, infer_category_from_type(type))
    correlation_id = Keyword.get(opts, :correlation_id)
    source = Keyword.get(opts, :source)
    retryable = Keyword.get(opts, :retryable, infer_retryable_from_category(category))
    circuit_breaker = Keyword.get(opts, :circuit_breaker, infer_circuit_breaker_from_category(category))

    %__MODULE__{
      type: type,
      message: message,
      code: code,
      reason: reason,
      context: context,
      timestamp: DateTime.utc_now(),
      category: category,
      correlation_id: correlation_id,
      source: source,
      retryable: retryable,
      circuit_breaker: circuit_breaker
    }
  end

  @doc """
  Converts ErrorResponse to a map suitable for JSON serialization.
  Strips sensitive information from context for client responses.
  """
  def to_client_map(%__MODULE__{} = error) do
    %{
      error: %{
        type: error.type,
        message: error.message,
        code: error.code,
        reason: error.reason,
        details: sanitize_context(error.context),
        timestamp: error.timestamp
      }
    }
  end

  @doc """
  Converts ErrorResponse to a map for internal logging (includes all context).
  """
  def to_log_map(%__MODULE__{} = error) do
    %{
      error_type: error.type,
      error_message: error.message,
      error_code: error.code,
      error_reason: error.reason,
      context: error.context,
      timestamp: error.timestamp
    }
  end

  # Private helper to sanitize context for client responses
  defp sanitize_context(context) when is_map(context) do
    context
    |> Map.drop([:password, :password_hash, :access_token, :refresh_token, :secret, :private_key, :api_key])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert atom keys to strings for JSON serialization
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      Map.put(acc, string_key, value)
    end)
  end

  defp sanitize_context(context), do: context

  # ============================================================================
  # ERROR CATEGORY AND POLICY INFERENCE
  # ============================================================================

  # Infer error category from error type
  defp infer_category_from_type(type) do
    case type do
      :validation_error -> :validation
      :not_found -> :not_found
      :unauthorized -> :authentication
      :forbidden -> :authorization
      :conflict -> :conflict
      :unprocessable_entity -> :business_rule
      :service_unavailable -> :external_dependency
      :timeout -> :external_dependency
      :internal_server_error -> :system
      _ -> :system
    end
  end

  # Infer retryable status from category
  defp infer_retryable_from_category(category) do
    case category do
      :external_dependency -> true
      :system -> true
      _ -> false
    end
  end

  # Infer circuit breaker status from category
  defp infer_circuit_breaker_from_category(category) do
    case category do
      :external_dependency -> true
      :system -> true
      _ -> false
    end
  end

  # ============================================================================
  # POLICY FUNCTIONS
  # ============================================================================

  @doc """
  Check if an error should trigger a retry.
  """
  def should_retry?(%__MODULE__{retryable: true, category: category}) do
    case category do
      :external_dependency -> true
      :system -> true
      _ -> false
    end
  end
  def should_retry?(_), do: false

  @doc """
  Check if an error should trigger circuit breaker.
  """
  def should_circuit_break?(%__MODULE__{circuit_breaker: true, category: category}) do
    case category do
      :external_dependency -> true
      :system -> true
      _ -> false
    end
  end
  def should_circuit_break?(_), do: false

  @doc """
  Get retry delay in milliseconds based on error category.
  """
  def retry_delay(%__MODULE__{category: :external_dependency}), do: 1000
  def retry_delay(%__MODULE__{category: :system}), do: 500
  def retry_delay(_), do: 0

  @doc """
  Get maximum retry attempts based on error category.
  """
  def max_retry_attempts(%__MODULE__{category: :external_dependency}), do: 3
  def max_retry_attempts(%__MODULE__{category: :system}), do: 2
  def max_retry_attempts(_), do: 0

  @doc """
  Generate a correlation ID for error tracking.
  """
  def generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @doc """
  Emit telemetry event for error tracking.
  """
  def emit_telemetry(%__MODULE__{} = error) do
    :telemetry.execute(
      [:ledger_bank_api, :error, :created],
      %{count: 1},
      %{
        error_type: error.type,
        error_reason: error.reason,
        error_category: error.category,
        correlation_id: error.correlation_id,
        source: error.source,
        retryable: error.retryable,
        circuit_breaker: error.circuit_breaker,
        timestamp: error.timestamp
      }
    )
  end
end

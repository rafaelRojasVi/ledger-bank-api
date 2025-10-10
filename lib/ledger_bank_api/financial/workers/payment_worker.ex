defmodule LedgerBankApi.Financial.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.

  Uses pure domain error handling with canonical Error structs.
  All errors are returned as {:error, %Error{}} tuples with proper categorization.

  ## Configuration
  - Queue: `:payments`
  - Max attempts: 5
  - Timeout: 5 minutes
  - Backoff: Exponential with custom error-based delays
  - Uniqueness: 60 seconds period on payment_id
  """
  use Oban.Worker,
    queue: :payments,
    max_attempts: 5,
    priority: 0,
    tags: ["payment", "financial"]
  require Logger
  import Ecto.Query, warn: false
  alias LedgerBankApi.Core.{Error, ErrorHandler}
  alias LedgerBankApi.Repo

  @impl Oban.Worker
  @doc """
  Performs the payment processing for a given payment_id.
  Returns :ok on success or {:error, %Error{}} on failure.
  """
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}} = job) do
    start_time = System.monotonic_time(:millisecond)
    correlation_id = Error.generate_correlation_id()
    context = %{
      worker: __MODULE__,
      payment_id: payment_id,
      job_id: job.id,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      correlation_id: correlation_id
    }

    Logger.info("Starting payment processing", context)

    result = with {:ok, _payment} <- fetch_payment(payment_id, context),
                  {:ok, _result} <- process_payment(payment_id, context) do
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("Payment processed successfully", Map.put(context, :duration_ms, duration))

      # Emit success telemetry
      emit_telemetry(:success, duration, context)
      :ok
    else
      {:error, %Error{} = error} ->
        duration = System.monotonic_time(:millisecond) - start_time
        log_error(error, Map.put(context, :duration_ms, duration))

        # Emit failure telemetry
        emit_telemetry(:failure, duration, Map.put(context, :error_reason, error.reason))

        handle_worker_error(error, context)
    end

    result
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  # ============================================================================
  # PRIVATE DOMAIN FUNCTIONS
  # ============================================================================

  defp fetch_payment(payment_id, context) do
    try do
      financial_service = Application.get_env(:ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialService)
      case financial_service.get_user_payment(payment_id) do
        {:ok, payment} -> {:ok, payment}
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} when is_atom(reason) ->
          {:error, ErrorHandler.business_error(reason, Map.put(context, :source, "payment_worker"))}
        {:error, reason} when is_binary(reason) ->
          {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :original_message, reason), :source, "payment_worker"))}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :exception, inspect(error)), :source, "payment_worker"))}
    end
  end

  defp process_payment(payment_id, context) do
    try do
      financial_service = Application.get_env(:ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialService)
      case financial_service.process_payment(payment_id) do
        {:ok, result} -> {:ok, result}
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} when is_atom(reason) ->
          {:error, ErrorHandler.business_error(reason, Map.put(context, :source, "payment_worker"))}
        {:error, reason} when is_binary(reason) ->
          {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :original_message, reason), :source, "payment_worker"))}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :exception, inspect(error)), :source, "payment_worker"))}
    end
  end

  # ============================================================================
  # ERROR HANDLING
  # ============================================================================

  defp log_error(%Error{} = error, context) do
    Logger.error("Payment processing failed",
      Map.merge(Error.to_log_map(error), context)
    )
  end

  defp handle_worker_error(%Error{} = error, context) do
    # Enhanced financial error handling with specific retry logic
    retry_decision = determine_retry_strategy(error, context)

    case retry_decision do
      {:retry, retry_info} ->
        # Log retry decision with financial-specific details
        Logger.info("Payment worker will retry", Map.merge(%{
          error_reason: error.reason,
          error_category: error.category,
          retryable: error.retryable,
          current_attempt: context.attempt,
          max_job_attempts: context.max_attempts,
          retry_strategy: retry_info.strategy,
          retry_delay: retry_info.delay,
          retry_reason: retry_info.reason
        }, retry_info.metadata || %{}))

      {:dead_letter, dlq_info} ->
        # Log non-retryable error with dead letter queue details
        Logger.warning("Payment worker will not retry - sending to dead letter queue", Map.merge(%{
          error_reason: error.reason,
          error_category: error.category,
          retryable: error.retryable,
          dlq_reason: dlq_info.reason,
          dlq_action: dlq_info.action
        }, dlq_info.metadata || %{}))

        # Handle dead letter queue actions
        handle_dead_letter_queue(error, context, dlq_info)

        # Emit dead-letter queue telemetry
        emit_dead_letter_telemetry(error, context)
    end

    # Return the canonical error - Oban will handle retries based on the error
    {:error, error}
  end

  @doc false
  def backoff(%Oban.Job{attempt: attempt, args: %{"error_reason" => reason}}) do
    # Financial-specific backoff based on error reason
    base_delay = case reason do
      # Business rule errors - no retry needed, but if retried, use short delay
      "insufficient_funds" -> 5000
      "daily_limit_exceeded" -> 5000
      "amount_exceeds_limit" -> 5000
      "account_inactive" -> 5000
      "duplicate_transaction" -> 5000
      "already_processed" -> 5000

      # System errors - retry with longer delays
      "internal_server_error" -> 2000
      "service_unavailable" -> 3000
      "timeout" -> 2000

      # External dependency errors - retry with moderate delays
      "external_dependency" -> 1000
      "network_error" -> 1500

      # Validation errors - no retry needed
      "validation_error" -> 1000
      "bad_request" -> 1000

      # Default
      _ -> 1000
    end

    # Exponential backoff with jitter: base_delay * 2^(attempt - 1) + random(0, base_delay/2)
    jitter = :rand.uniform(trunc(base_delay / 2))
    trunc(base_delay * :math.pow(2, attempt - 1)) + jitter
  end

  def backoff(%Oban.Job{attempt: attempt, args: %{"error_category" => category}}) do
    # Custom backoff based on error category
    base_delay = case category do
      "external_dependency" -> 1000  # 1 second for external deps
      "system" -> 500               # 500ms for system errors
      "business_rule" -> 2000       # 2 seconds for business rules
      "conflict" -> 1000            # 1 second for conflicts
      "validation" -> 500           # 500ms for validation errors
      _ -> 1000
    end

    # Exponential backoff: base_delay * 2^(attempt - 1)
    trunc(base_delay * :math.pow(2, attempt - 1))
  end

  def backoff(%Oban.Job{attempt: attempt}) do
    # Default exponential backoff
    trunc(1000 * :math.pow(2, attempt - 1))
  end

  @doc """
  Schedule a payment processing job.
  """
  def schedule_payment(payment_id, opts \\ []) when is_binary(payment_id) do
    %{"payment_id" => payment_id}
    |> new(opts)
    |> Oban.insert()
  end

  @doc """
  Schedule a payment processing job with delay.
  """
  def schedule_payment_with_delay(payment_id, delay_seconds, opts \\ [])
      when is_binary(payment_id) and is_integer(delay_seconds) and delay_seconds > 0 do
    %{"payment_id" => payment_id}
    |> new(Keyword.merge(opts, [schedule_in: delay_seconds]))
    |> Oban.insert()
  end

  @doc """
  Schedule a payment processing job with priority.
  Priority range: 0-9 (0 = highest priority, 9 = lowest priority)
  """
  def schedule_payment_with_priority(payment_id, priority, opts \\ [])
      when is_binary(payment_id) and is_integer(priority) and priority >= 0 and priority <= 9 do
    %{"payment_id" => payment_id}
    |> new(Keyword.merge(opts, [
      priority: priority,
      unique: [period: 60, fields: [:args], keys: [:payment_id]]
    ]))
    |> Oban.insert()
  end

  @doc """
  Schedule a payment processing job with custom retry configuration.
  """
  def schedule_payment_with_retry_config(payment_id, retry_config, opts \\ [])
      when is_binary(payment_id) and is_map(retry_config) do
    %{"payment_id" => payment_id}
    |> new(Keyword.merge(opts, [
      max_attempts: Map.get(retry_config, :max_attempts, 5),
      unique: [period: 60, fields: [:args], keys: [:payment_id]]
    ]))
    |> Oban.insert()
  end

  @doc """
  Schedule a payment processing job with error context for better retry handling.
  """
  def schedule_payment_with_error_context(payment_id, error_context, opts \\ [])
      when is_binary(payment_id) and is_map(error_context) do
    %{"payment_id" => payment_id}
    |> Map.merge(error_context)
    |> new(Keyword.merge(opts, [
      unique: [period: 60, fields: [:args], keys: [:payment_id]]
    ]))
    |> Oban.insert()
  end

  @doc """
  Cancel a scheduled payment processing job.
  """
  def cancel_payment_job(payment_id) when is_binary(payment_id) do
    # Find and cancel the job
    case Oban.Job
         |> where([j], j.args["payment_id"] == ^payment_id and j.state in ["available", "scheduled"])
         |> Repo.one() do
      nil -> {:error, :job_not_found}
      job ->
        case Oban.cancel_job(job) do
          {:ok, _} -> {:ok, :cancelled}
          error -> error
        end
    end
  end

  @doc """
  Get the status of a payment processing job.
  """
  def get_payment_job_status(payment_id) when is_binary(payment_id) do
    case Oban.Job
         |> where([j], j.args["payment_id"] == ^payment_id)
         |> order_by([j], desc: j.inserted_at)
         |> limit(1)
         |> Repo.one() do
      nil -> {:error, :job_not_found}
      job -> {:ok, %{
        id: job.id,
        state: job.state,
        attempt: job.attempt,
        max_attempts: job.max_attempts,
        inserted_at: job.inserted_at,
        scheduled_at: job.scheduled_at,
        attempted_at: job.attempted_at,
        completed_at: job.completed_at,
        errors: job.errors
      }}
    end
  end

  # ============================================================================
  # RETRY STRATEGY AND DEAD LETTER QUEUE
  # ============================================================================

  defp determine_retry_strategy(%Error{} = error, context) do
    # Financial-specific retry strategy based on error type and context
    case {error.reason, error.category, context.attempt, context.max_attempts} do
      # Business rule errors - generally not retryable
      {reason, :business_rule, _, _} when reason in [
        :insufficient_funds, :daily_limit_exceeded, :amount_exceeds_limit,
        :account_inactive, :duplicate_transaction, :already_processed
      ] ->
        {:dead_letter, %{
          reason: "business_rule_violation",
          action: "mark_payment_failed",
          metadata: %{error_reason: reason, category: :business_rule}
        }}

      # Validation errors - not retryable
      {_, :validation, _, _} ->
        {:dead_letter, %{
          reason: "validation_error",
          action: "mark_payment_failed",
          metadata: %{category: :validation}
        }}

      # Conflict errors - not retryable
      {_, :conflict, _, _} ->
        {:dead_letter, %{
          reason: "conflict_error",
          action: "mark_payment_failed",
          metadata: %{category: :conflict}
        }}

      # System errors - retry with exponential backoff
      {_, :system, attempt, max_attempts} when attempt < max_attempts ->
        {:retry, %{
          strategy: "exponential_backoff",
          delay: calculate_retry_delay(attempt, :system),
          reason: "system_error_retryable",
          metadata: %{attempt: attempt, max_attempts: max_attempts}
        }}

      # External dependency errors - retry with longer delays
      {_, :external_dependency, attempt, max_attempts} when attempt < max_attempts ->
        {:retry, %{
          strategy: "exponential_backoff_with_jitter",
          delay: calculate_retry_delay(attempt, :external_dependency),
          reason: "external_dependency_retryable",
          metadata: %{attempt: attempt, max_attempts: max_attempts}
        }}

      # Max attempts reached - send to dead letter queue
      {_, _, attempt, max_attempts} when attempt >= max_attempts ->
        {:dead_letter, %{
          reason: "max_attempts_exceeded",
          action: "mark_payment_failed",
          metadata: %{attempt: attempt, max_attempts: max_attempts}
        }}

      # Default case - retry if retryable
      _ ->
        if Error.should_retry?(error) do
          {:retry, %{
            strategy: "default_exponential_backoff",
            delay: calculate_retry_delay(context.attempt, :default),
            reason: "default_retryable_error",
            metadata: %{attempt: context.attempt}
          }}
        else
          {:dead_letter, %{
            reason: "non_retryable_error",
            action: "mark_payment_failed",
            metadata: %{error_reason: error.reason, category: error.category}
          }}
        end
    end
  end

  defp calculate_retry_delay(attempt, error_type) do
    base_delay = case error_type do
      :system -> 2000
      :external_dependency -> 3000
      :default -> 1000
    end

    # Exponential backoff with jitter
    jitter = :rand.uniform(trunc(base_delay / 2))
    trunc(base_delay * :math.pow(2, attempt - 1)) + jitter
  end

  defp handle_dead_letter_queue(%Error{} = error, context, dlq_info) do
    # Handle different dead letter queue actions
    case dlq_info.action do
      "mark_payment_failed" ->
        mark_payment_as_failed(context.payment_id, error, context)

      "notify_admin" ->
        notify_admin_of_failed_payment(context.payment_id, error, context)

      "schedule_manual_review" ->
        schedule_manual_review(context.payment_id, error, context)

      _ ->
        Logger.warning("Unknown dead letter queue action", %{
          action: dlq_info.action,
          payment_id: context.payment_id,
          error_reason: error.reason
        })
    end
  end

  defp mark_payment_as_failed(payment_id, error, context) do
    try do
      # Update payment status to FAILED with error details
      _financial_service = Application.get_env(:ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialService)

      # This would typically call a method to mark payment as failed
      # For now, we'll log the action
      Logger.info("Marking payment as failed", %{
        payment_id: payment_id,
        error_reason: error.reason,
        error_category: error.category,
        correlation_id: context.correlation_id
      })

      # In a real implementation, you would call:
      # financial_service.mark_payment_failed(payment_id, error)

    rescue
      e ->
        Logger.error("Failed to mark payment as failed", %{
          payment_id: payment_id,
          error: inspect(e),
          correlation_id: context.correlation_id
        })
    end
  end

  defp notify_admin_of_failed_payment(payment_id, error, context) do
    # In a real implementation, this would send notifications to admins
    Logger.warning("Admin notification: Payment failed", %{
      payment_id: payment_id,
      error_reason: error.reason,
      error_category: error.category,
      correlation_id: context.correlation_id,
      action: "admin_notification_required"
    })
  end

  defp schedule_manual_review(payment_id, error, context) do
    # In a real implementation, this would create a manual review task
    Logger.info("Scheduling manual review for payment", %{
      payment_id: payment_id,
      error_reason: error.reason,
      error_category: error.category,
      correlation_id: context.correlation_id,
      action: "manual_review_scheduled"
    })
  end

  # ============================================================================
  # TELEMETRY
  # ============================================================================

  defp emit_telemetry(status, duration, context) do
    base_metadata = %{
      worker: "PaymentWorker",
      payment_id: context.payment_id,
      job_id: context.job_id,
      attempt: context.attempt,
      correlation_id: context.correlation_id
    }

    # Add error_reason if present in context
    metadata = if Map.has_key?(context, :error_reason) do
      Map.put(base_metadata, :error_reason, context.error_reason)
    else
      base_metadata
    end

    :telemetry.execute(
      [:ledger_bank_api, :worker, :payment, status],
      %{duration: duration, count: 1},
      metadata
    )
  end

  defp emit_dead_letter_telemetry(error, context) do
    :telemetry.execute(
      [:ledger_bank_api, :worker, :dead_letter],
      %{count: 1},
      %{
        worker: "PaymentWorker",
        payment_id: context.payment_id,
        job_id: context.job_id,
        error_reason: error.reason,
        error_category: error.category,
        correlation_id: context.correlation_id
      }
    )
  end
end

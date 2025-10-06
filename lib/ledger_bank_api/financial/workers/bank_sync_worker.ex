defmodule LedgerBankApi.Financial.Workers.BankSyncWorker do
  @moduledoc """
  Oban worker for synchronizing bank data in the background.

  Uses pure domain error handling with canonical Error structs.
  All errors are returned as {:error, %Error{}} tuples with proper categorization.
  Retry logic is driven by error categories, not ad-hoc type checking.

  ## Configuration
  - Queue: `:banking`
  - Max attempts: 5
  - Timeout: 10 minutes (bank API calls can be slow)
  - Backoff: Exponential with custom error-based delays
  - Uniqueness: 300 seconds period on login_id
  """
  use Oban.Worker,
    queue: :banking,
    max_attempts: 5,
    priority: 0,
    tags: ["banking", "sync"]
  require Logger
  alias LedgerBankApi.Core.{Error, ErrorHandler}

  @impl Oban.Worker
  @doc """
  Performs bank sync for a given login_id.
  Returns :ok on success or {:error, %Error{}} on failure.
  Retry decisions are made based on error categories.
  """
  def perform(%Oban.Job{args: %{"login_id" => login_id}} = job) do
    start_time = System.monotonic_time(:millisecond)
    correlation_id = Error.generate_correlation_id()
    context = %{
      worker: __MODULE__,
      login_id: login_id,
      job_id: job.id,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      correlation_id: correlation_id
    }

    Logger.info("Starting bank sync", context)

    result = with {:ok, _result} <- sync_bank_login(login_id, context) do
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("Bank sync completed successfully", Map.put(context, :duration_ms, duration))

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
  def timeout(_job), do: :timer.minutes(10)

  # ============================================================================
  # PRIVATE DOMAIN FUNCTIONS
  # ============================================================================

  defp sync_bank_login(login_id, context) do
    try do
      financial_service = Application.get_env(:ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialService)
      case financial_service.sync_login(login_id) do
        {:ok, result} -> {:ok, result}
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} when is_atom(reason) ->
          {:error, ErrorHandler.business_error(reason, Map.put(context, :source, "bank_sync_worker"))}
        {:error, reason} when is_binary(reason) ->
          {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :original_message, reason), :source, "bank_sync_worker"))}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:internal_server_error, Map.put(Map.put(context, :exception, inspect(error)), :source, "bank_sync_worker"))}
    end
  end

  # ============================================================================
  # ERROR HANDLING
  # ============================================================================

  defp log_error(%Error{} = error, context) do
    Logger.error("Bank sync failed",
      Map.merge(Error.to_log_map(error), context)
    )
  end

  defp handle_worker_error(%Error{} = error, context) do
    # Use policy functions to determine retry behavior
    if Error.should_retry?(error) do
      # Log retry decision with policy details
      Logger.info("Bank sync worker will retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable,
        max_attempts: Error.max_retry_attempts(error),
        retry_delay: Error.retry_delay(error),
        circuit_breaker: Error.should_circuit_break?(error),
        current_attempt: context.attempt,
        max_job_attempts: context.max_attempts
      })
    else
      # Log non-retryable error
      Logger.warning("Bank sync worker will not retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable
      })

      # Emit dead-letter queue telemetry for non-retryable errors
      emit_dead_letter_telemetry(error, context)
    end

    # Return the canonical error - Oban will handle retries based on the error
    {:error, error}
  end

  @doc false
  def backoff(%Oban.Job{attempt: attempt, args: %{"error_category" => category}}) do
    # Custom backoff based on error category
    base_delay = case category do
      "external_dependency" -> 1000  # 1 second for external deps
      "system" -> 500               # 500ms for system errors
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
  Schedule a bank sync job with uniqueness constraint.
  Prevents duplicate sync jobs for the same login within 5 minutes.
  """
  def schedule_sync(login_id, opts \\ []) when is_binary(login_id) do
    %{"login_id" => login_id}
    |> new(Keyword.merge(opts, [
      unique: [period: 300, fields: [:args], keys: [:login_id]]
    ]))
    |> Oban.insert()
  end

  @doc """
  Schedule a bank sync job with delay.
  """
  def schedule_sync_with_delay(login_id, delay_seconds, opts \\ [])
      when is_binary(login_id) and is_integer(delay_seconds) and delay_seconds > 0 do
    schedule_in = DateTime.add(DateTime.utc_now(), delay_seconds, :second)

    %{"login_id" => login_id}
    |> new(Keyword.merge(opts, [
      schedule_in: schedule_in,
      unique: [period: 300, fields: [:args], keys: [:login_id]]
    ]))
    |> Oban.insert()
  end

  # ============================================================================
  # TELEMETRY
  # ============================================================================

  defp emit_telemetry(status, duration, context) do
    base_metadata = %{
      worker: "BankSyncWorker",
      login_id: context.login_id,
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
      [:ledger_bank_api, :worker, :bank_sync, status],
      %{duration: duration, count: 1},
      metadata
    )
  end

  defp emit_dead_letter_telemetry(error, context) do
    :telemetry.execute(
      [:ledger_bank_api, :worker, :dead_letter],
      %{count: 1},
      %{
        worker: "BankSyncWorker",
        login_id: context.login_id,
        job_id: context.job_id,
        error_reason: error.reason,
        error_category: error.category,
        correlation_id: context.correlation_id
      }
    )
  end
end

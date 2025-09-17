defmodule LedgerBankApi.Financial.Workers.BankSyncWorker do
  @moduledoc """
  Oban worker for synchronizing bank data in the background.

  Uses pure domain error handling with canonical Error structs.
  All errors are returned as {:error, %Error{}} tuples with proper categorization.
  Retry logic is driven by error categories, not ad-hoc type checking.
  """
  use Oban.Worker, queue: :banking
  require Logger
  alias LedgerBankApi.Core.{Error, ErrorHandler}

  @impl Oban.Worker
  @doc """
  Performs bank sync for a given login_id.
  Returns :ok on success or {:error, %Error{}} on failure.
  Retry decisions are made based on error categories.
  """
  def perform(%Oban.Job{args: %{"login_id" => login_id}} = job) do
    correlation_id = Error.generate_correlation_id()
    context = %{
      worker: __MODULE__,
      login_id: login_id,
      job_id: job.id,
      attempt: job.attempt,
      correlation_id: correlation_id
    }

    Logger.info("Starting bank sync", context)

    with {:ok, _result} <- sync_bank_login(login_id, context) do
      Logger.info("Bank sync completed successfully", context)
      :ok
    else
      {:error, %Error{} = error} ->
        log_error(error, context)
        handle_worker_error(error, context)
    end
  end

  # ============================================================================
  # PRIVATE DOMAIN FUNCTIONS
  # ============================================================================

  defp sync_bank_login(login_id, context) do
    try do
      case LedgerBankApi.Financial.FinancialService.sync_login(login_id) do
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

  defp handle_worker_error(%Error{} = error, _context) do
    # Use policy functions to determine retry behavior
    if Error.should_retry?(error) do
      # Log retry decision with policy details
      Logger.info("Bank sync worker will retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable,
        max_attempts: Error.max_retry_attempts(error),
        retry_delay: Error.retry_delay(error),
        circuit_breaker: Error.should_circuit_break?(error)
      })
    else
      # Log non-retryable error
      Logger.warning("Bank sync worker will not retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable
      })
    end

    # Return the canonical error - Oban will handle retries based on the error
    {:error, error}
  end

  @doc """
  Schedule a bank sync job.
  """
  def schedule_sync(login_id, opts \\ []) when is_binary(login_id) do
    %{"login_id" => login_id}
    |> new(opts)
    |> Oban.insert()
  end

  @doc """
  Schedule a bank sync job with delay.
  """
  def schedule_sync_with_delay(login_id, delay_seconds, opts \\ [])
      when is_binary(login_id) and is_integer(delay_seconds) and delay_seconds > 0 do
    schedule_in = DateTime.add(DateTime.utc_now(), delay_seconds, :second)

    %{"login_id" => login_id}
    |> new(Keyword.merge(opts, [schedule_in: schedule_in]))
    |> Oban.insert()
  end
end

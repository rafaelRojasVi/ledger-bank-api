defmodule LedgerBankApi.Financial.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.

  Uses pure domain error handling with canonical Error structs.
  All errors are returned as {:error, %Error{}} tuples with proper categorization.
  """
  use Oban.Worker, queue: :payments
  require Logger
  alias LedgerBankApi.Core.{Error, ErrorHandler}

  @impl Oban.Worker
  @doc """
  Performs the payment processing for a given payment_id.
  Returns :ok on success or {:error, %Error{}} on failure.
  """
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}} = job) do
    correlation_id = Error.generate_correlation_id()
    context = %{
      worker: __MODULE__,
      payment_id: payment_id,
      job_id: job.id,
      attempt: job.attempt,
      correlation_id: correlation_id
    }

    Logger.info("Starting payment processing", context)

    with {:ok, _payment} <- fetch_payment(payment_id, context),
         {:ok, _result} <- process_payment(payment_id, context) do
      Logger.info("Payment processed successfully", context)
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

  defp fetch_payment(payment_id, context) do
    try do
      case LedgerBankApi.Financial.FinancialService.get_user_payment(payment_id) do
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
      case LedgerBankApi.Financial.FinancialService.process_payment(payment_id) do
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

  defp handle_worker_error(%Error{} = error, _context) do
    # Use policy functions to determine retry behavior
    if Error.should_retry?(error) do
      # Log retry decision with policy details
      Logger.info("Payment worker will retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable,
        max_attempts: Error.max_retry_attempts(error),
        retry_delay: Error.retry_delay(error),
        circuit_breaker: Error.should_circuit_break?(error)
      })
    else
      # Log non-retryable error
      Logger.warning("Payment worker will not retry", %{
        error_reason: error.reason,
        error_category: error.category,
        retryable: error.retryable
      })
    end

    # Return the canonical error - Oban will handle retries based on the error
    {:error, error}
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
    schedule_in = DateTime.add(DateTime.utc_now(), delay_seconds, :second)

    %{"payment_id" => payment_id}
    |> new(Keyword.merge(opts, [schedule_in: schedule_in]))
    |> Oban.insert()
  end

  @doc """
  Schedule a payment processing job with priority.
  """
  def schedule_payment_with_priority(payment_id, priority, opts \\ [])
      when is_binary(payment_id) and is_integer(priority) and priority >= 0 and priority <= 10 do
    %{"payment_id" => payment_id}
    |> new(Keyword.merge(opts, [priority: priority]))
    |> Oban.insert()
  end
end

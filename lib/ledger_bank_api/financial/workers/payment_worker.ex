defmodule LedgerBankApi.Financial.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.

  Uses WorkerBehavior for standardized error handling, telemetry, and retry logic.

  ## Configuration
  - Queue: `:payments`
  - Max attempts: 5
  - Timeout: 5 minutes
  - Backoff: Exponential with custom error-based delays
  - Uniqueness: 60 seconds period on payment_id
  """
  use LedgerBankApi.Core.WorkerBehavior,
    queue: :payments,
    max_attempts: 5,
    priority: 0,
    tags: ["payment", "financial"]

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo

  @impl LedgerBankApi.Core.WorkerBehavior
  def worker_name, do: "PaymentWorker"

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  @impl LedgerBankApi.Core.WorkerBehavior
  @doc """
  Performs the payment processing for a given payment_id.
  Returns {:ok, result} or {:error, %Error{}}.
  """
  def perform_work(%{"payment_id" => payment_id}, context) do
    with {:ok, _payment} <- fetch_payment(payment_id, context),
         {:ok, result} <- process_payment(payment_id, context) do
      {:ok, result}
    end
  end

  # Extract payment_id into context for logging
  @impl LedgerBankApi.Core.WorkerBehavior
  def extract_context_from_args(%{"payment_id" => payment_id}) do
    %{payment_id: payment_id}
  end

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
  # FINANCIAL-SPECIFIC ERROR HANDLING (Enhanced DLQ Logic)
  # ============================================================================
  # Note: Basic retry logic is handled by WorkerBehavior
  # This section provides financial-specific dead letter queue actions

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
end

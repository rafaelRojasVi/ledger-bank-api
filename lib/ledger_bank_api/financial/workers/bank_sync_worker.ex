defmodule LedgerBankApi.Financial.Workers.BankSyncWorker do
  @moduledoc """
  Oban worker for synchronizing bank data in the background.

  Uses WorkerBehavior for standardized error handling, telemetry, and retry logic.

  ## Configuration
  - Queue: `:banking`
  - Max attempts: 5
  - Timeout: 10 minutes (bank API calls can be slow)
  - Backoff: Exponential with custom error-based delays
  - Uniqueness: 300 seconds period on login_id
  """
  use LedgerBankApi.Core.WorkerBehavior,
    queue: :banking,
    max_attempts: 5,
    priority: 0,
    tags: ["banking", "sync"]

  @impl LedgerBankApi.Core.WorkerBehavior
  def worker_name, do: "BankSyncWorker"

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)

  @impl LedgerBankApi.Core.WorkerBehavior
  @doc """
  Performs bank sync for a given login_id.
  Returns {:ok, result} or {:error, %Error{}}.
  """
  def perform_work(%{"login_id" => login_id}, context) do
    sync_bank_login(login_id, context)
  end

  # Extract login_id into context for logging
  @impl LedgerBankApi.Core.WorkerBehavior
  def extract_context_from_args(%{"login_id" => login_id}) do
    %{login_id: login_id}
  end

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
    %{"login_id" => login_id}
    |> new(Keyword.merge(opts, [
      schedule_in: delay_seconds,
      unique: [period: 300, fields: [:args], keys: [:login_id]]
    ]))
    |> Oban.insert()
  end

end

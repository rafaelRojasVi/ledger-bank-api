defmodule LedgerBankApi.Workers.BankSyncWorker do
  @moduledoc """
  Oban worker for synchronizing bank data in the background.
  Handles bank login synchronization with comprehensive error handling and retry logic.
  """
  use Oban.Worker, queue: :banking
  require Logger
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @impl Oban.Worker
  @doc """
  Performs bank sync for a given login_id, with centralized error handling and retry logic.
  """
  def perform(%Oban.Job{args: %{"login_id" => login_id}} = job) do
    context = %{worker: __MODULE__, login_id: login_id, attempt: job.attempt}

    Logger.info("Starting bank sync for login_id: #{login_id} (attempt #{job.attempt})")

    result = ErrorHandler.with_error_handling(fn ->
      LedgerBankApi.Banking.sync_login(login_id)
    end, context)

    case result do
      {:ok, _} ->
        Logger.info("Bank sync completed successfully for login_id: #{login_id}")
        :ok
      {:error, reason} ->
        Logger.error("Bank sync failed for login_id: #{login_id}, reason: #{inspect(reason)}")

        # Retry for certain types of errors
        case reason do
          %{error: %{type: :service_unavailable}} ->
            # Retry for service unavailable errors
            {:error, reason}
          %{error: %{type: :timeout}} ->
            # Retry for timeout errors
            {:error, reason}
          _ ->
            # Don't retry for other errors
            {:error, reason}
        end
    end
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

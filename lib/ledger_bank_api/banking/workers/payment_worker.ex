defmodule LedgerBankApi.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.
  Handles payment processing logic for a given payment_id, with centralized error handling.
  """
  use Oban.Worker, queue: :payments
  require Logger
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @impl Oban.Worker
  @doc """
  Performs the payment processing for a given payment_id, with error handling.
  """
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    context = %{worker: __MODULE__, payment_id: payment_id}

    Logger.info("Starting payment processing for payment_id: #{payment_id}")

    # Validate payment exists before processing
    case LedgerBankApi.Banking.get_user_payment(payment_id) do
      {:ok, _payment} ->
        result = ErrorHandler.with_error_handling(fn ->
          LedgerBankApi.Banking.process_payment(payment_id)
        end, context)

        case result do
          {:ok, _} ->
            Logger.info("Payment processed successfully for payment_id: #{payment_id}")
            :ok
          {:error, reason} ->
            Logger.error("Payment processing failed for payment_id: #{payment_id}, reason: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, :not_found} ->
        Logger.error("Payment not found for payment_id: #{payment_id}")
        {:error, :not_found}
      {:error, reason} ->
        Logger.error("Failed to fetch payment for payment_id: #{payment_id}, reason: #{inspect(reason)}")
        {:error, reason}
    end
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

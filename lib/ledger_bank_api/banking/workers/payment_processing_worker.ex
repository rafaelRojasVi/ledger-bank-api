defmodule LedgerBankApi.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.
  Handles payment processing logic for a given payment_id, with centralized error handling.
  """
  use Oban.Worker, queue: :payments
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @impl Oban.Worker
  @doc """
  Performs the payment processing for the given payment_id, with error handling.
  """
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    context = %{worker: __MODULE__, payment_id: payment_id}
    ErrorHandler.with_error_handling(fn ->
      IO.puts("[Stub] Would process payment: #{payment_id}")
      :ok
    end, context)
  end
end

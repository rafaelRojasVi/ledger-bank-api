defmodule LedgerBankApi.Workers.PaymentWorker do
  @moduledoc """
  Oban worker for processing user payments in the background.
  Handles payment processing logic for a given payment_id.
  """
  use Oban.Worker, queue: :payments

  @impl Oban.Worker
  @doc """
  Performs the payment processing for the given payment_id.
  """
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    IO.puts("[Stub] Would process payment: #{payment_id}")
    :ok
  end
end

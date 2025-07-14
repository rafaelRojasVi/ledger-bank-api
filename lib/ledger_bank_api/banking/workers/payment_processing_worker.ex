defmodule LedgerBankApi.Workers.PaymentWorker do
  use Oban.Worker, queue: :payments

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    IO.puts("[Stub] Would process payment: #{payment_id}")
    :ok
  end
end

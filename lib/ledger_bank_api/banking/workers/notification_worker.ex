defmodule LedgerBankApi.Workers.NotificationWorker do
  use Oban.Worker, queue: :notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    IO.inspect(args, label: "[Stub] Would deliver notification with args")
    :ok
  end
end

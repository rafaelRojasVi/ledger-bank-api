defmodule LedgerBankApi.Workers.NotificationWorker do
  @moduledoc """
  Oban worker for delivering notifications to users.
  Enqueues background jobs to send notifications based on provided arguments.
  """
  use Oban.Worker, queue: :notifications

  @impl Oban.Worker
  @doc """
  Performs the notification delivery with the given arguments.
  """
  def perform(%Oban.Job{args: args}) do
    IO.inspect(args, label: "[Stub] Would deliver notification with args")
    :ok
  end
end

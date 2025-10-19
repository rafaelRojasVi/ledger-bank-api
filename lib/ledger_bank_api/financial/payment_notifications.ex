defmodule LedgerBankApi.Financial.PaymentNotifications do
  @moduledoc """
  Service for broadcasting real-time payment notifications via WebSocket.

  Handles publishing payment status updates, balance changes, and other
  financial events to connected clients.
  """

  require Logger

  @doc """
  Broadcast payment status update to user's WebSocket channel.
  """
  def broadcast_payment_status_change(payment) do
    user_id = payment.user_id
    topic = "payment_updates:#{user_id}"

    payload = %{
      payment_id: payment.id,
      status: payment.status,
      amount: payment.amount,
      direction: payment.direction,
      description: payment.description,
      updated_at: payment.updated_at,
      timestamp: DateTime.utc_now()
    }

    Logger.info("Broadcasting payment status change for payment #{payment.id} to user #{user_id}")

    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "payment_status_changed",
      payload: payload
    })

    # Also broadcast to specific payment channel for subscribers
    payment_topic = "payment:#{payment.id}"
    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, payment_topic, %Phoenix.Socket.Broadcast{
      topic: payment_topic,
      event: "payment_updated",
      payload: payload
    })
  end

  @doc """
  Broadcast balance update to user's WebSocket channel.
  """
  def broadcast_balance_change(account) do
    user_id = account.user_id
    topic = "balance_updates:#{user_id}"

    payload = %{
      account_id: account.id,
      account_name: account.account_name,
      balance: account.balance,
      currency: account.currency,
      updated_at: account.updated_at,
      timestamp: DateTime.utc_now()
    }

    Logger.info("Broadcasting balance change for account #{account.id} to user #{user_id}")

    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "balance_changed",
      payload: payload
    })
  end

  @doc """
  Broadcast payment creation notification.
  """
  def broadcast_payment_created(payment) do
    user_id = payment.user_id
    topic = "payment_updates:#{user_id}"

    payload = %{
      payment_id: payment.id,
      status: payment.status,
      amount: payment.amount,
      direction: payment.direction,
      description: payment.description,
      created_at: payment.inserted_at,
      timestamp: DateTime.utc_now(),
      event_type: "payment_created"
    }

    Logger.info("Broadcasting payment created for payment #{payment.id} to user #{user_id}")

    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "payment_created",
      payload: payload
    })
  end

  @doc """
  Broadcast payment failure notification.
  """
  def broadcast_payment_failed(payment, error_reason) do
    user_id = payment.user_id
    topic = "payment_updates:#{user_id}"

    payload = %{
      payment_id: payment.id,
      status: payment.status,
      amount: payment.amount,
      direction: payment.direction,
      description: payment.description,
      error_reason: error_reason,
      failed_at: DateTime.utc_now(),
      timestamp: DateTime.utc_now(),
      event_type: "payment_failed"
    }

    Logger.warning("Broadcasting payment failure for payment #{payment.id} to user #{user_id}: #{error_reason}")

    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "payment_failed",
      payload: payload
    })
  end

  @doc """
  Broadcast system maintenance notification to all connected users.
  """
  def broadcast_maintenance_notification(message, scheduled_time \\ nil) do
    payload = %{
      message: message,
      scheduled_time: scheduled_time,
      timestamp: DateTime.utc_now(),
      event_type: "system_maintenance"
    }

    Logger.info("Broadcasting system maintenance notification: #{message}")

    # Broadcast to all users (in a real system, you might want to target specific user groups)
    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, "system_notifications", %Phoenix.Socket.Broadcast{
      topic: "system_notifications",
      event: "maintenance_notification",
      payload: payload
    })
  end

  @doc """
  Broadcast account sync notification.
  """
  def broadcast_account_sync(user_id, accounts_synced) do
    topic = "payment_updates:#{user_id}"

    payload = %{
      accounts_synced: accounts_synced,
      sync_completed_at: DateTime.utc_now(),
      timestamp: DateTime.utc_now(),
      event_type: "account_sync_completed"
    }

    Logger.info("Broadcasting account sync completion for user #{user_id}: #{accounts_synced} accounts synced")

    Phoenix.PubSub.broadcast(LedgerBankApi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "account_sync_completed",
      payload: payload
    })
  end
end

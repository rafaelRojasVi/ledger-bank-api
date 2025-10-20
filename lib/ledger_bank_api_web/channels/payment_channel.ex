defmodule LedgerBankApiWeb.PaymentChannel do
  @moduledoc """
  Phoenix Channel for real-time payment notifications.

  Handles WebSocket connections for payment status updates,
  transaction notifications, and real-time account balance changes.
  """

  use Phoenix.Channel
  require Logger

  # Join channel with authentication
  def join("payment:" <> user_id, _payload, socket) do
    case authenticate_user(socket, user_id) do
      {:ok, user} ->
        Logger.info("User #{user.id} joined payment channel")

        # Subscribe to user-specific payment events
        Phoenix.PubSub.subscribe(LedgerBankApi.PubSub, "payment_updates:#{user_id}")

        # Send initial connection confirmation
        push(socket, "payment_connected", %{
          user_id: user_id,
          timestamp: DateTime.utc_now(),
          message: "Connected to payment notifications"
        })

        {:ok, socket}

      {:error, _reason} ->
        Logger.warning("Unauthorized attempt to join payment channel for user #{user_id}")
        {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle payment status update requests
  def handle_in("payment_status", %{"payment_id" => payment_id}, socket) do
    _user_id = get_user_id_from_socket(socket)

    case LedgerBankApi.Financial.FinancialService.get_user_payment(payment_id) do
      {:ok, payment} ->
        push(socket, "payment_status_update", %{
          payment_id: payment_id,
          status: payment.status,
          amount: payment.amount,
          direction: payment.direction,
          updated_at: payment.updated_at,
          timestamp: DateTime.utc_now()
        })

        {:noreply, socket}

      {:error, _reason} ->
        push(socket, "payment_error", %{
          payment_id: payment_id,
          error: "Payment not found or access denied",
          timestamp: DateTime.utc_now()
        })

        {:noreply, socket}
    end
  end

  # Handle real-time balance requests
  def handle_in("balance_request", %{"account_id" => account_id}, socket) do
    _user_id = get_user_id_from_socket(socket)

    case LedgerBankApi.Financial.FinancialService.get_user_bank_account(account_id) do
      {:ok, balance} ->
        push(socket, "balance_update", %{
          account_id: account_id,
          balance: balance.amount,
          currency: balance.currency,
          last_updated: balance.updated_at,
          timestamp: DateTime.utc_now()
        })

        {:noreply, socket}

      {:error, _reason} ->
        push(socket, "balance_error", %{
          account_id: account_id,
          error: "Account not found or access denied",
          timestamp: DateTime.utc_now()
        })

        {:noreply, socket}
    end
  end

  # Handle subscription to specific payment updates
  def handle_in("subscribe_payment", %{"payment_id" => payment_id}, socket) do
    _user_id = get_user_id_from_socket(socket)

    # Subscribe to specific payment updates
    Phoenix.PubSub.subscribe(LedgerBankApi.PubSub, "payment:#{payment_id}")

    push(socket, "subscription_confirmed", %{
      payment_id: payment_id,
      message: "Subscribed to payment updates",
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle ping for connection health
  def handle_in("ping", _payload, socket) do
    push(socket, "pong", %{
      timestamp: DateTime.utc_now(),
      server_time: System.system_time(:millisecond)
    })

    {:noreply, socket}
  end

  # Handle incoming payment notifications from PubSub
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "payment_updates:" <> _user_id,
          event: "payment_status_changed",
          payload: payload
        },
        socket
      ) do
    push(socket, "payment_notification", payload)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "payment:" <> _payment_id,
          event: "payment_updated",
          payload: payload
        },
        socket
      ) do
    push(socket, "payment_update", payload)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "balance_updates:" <> _user_id,
          event: "balance_changed",
          payload: payload
        },
        socket
      ) do
    push(socket, "balance_notification", payload)
    {:noreply, socket}
  end

  # Clean up subscriptions on disconnect
  def terminate(reason, socket) do
    user_id = get_user_id_from_socket(socket)

    Logger.info("User #{user_id} disconnected from payment channel. Reason: #{inspect(reason)}")

    # Unsubscribe from all payment-related topics
    Phoenix.PubSub.unsubscribe(LedgerBankApi.PubSub, "payment_updates:#{user_id}")
    Phoenix.PubSub.unsubscribe(LedgerBankApi.PubSub, "balance_updates:#{user_id}")

    :ok
  end

  # Private helper functions

  defp authenticate_user(socket, user_id) do
    case socket.assigns[:current_user] do
      %{id: ^user_id} = user -> {:ok, user}
      _ -> {:error, :unauthorized}
    end
  end

  defp get_user_id_from_socket(socket) do
    socket.assigns[:current_user].id
  end
end

defmodule LedgerBankApiWeb.Controllers.WebhooksController do
  @moduledoc """
  Webhook controller for handling external service notifications.

  Supports webhooks from payment processors, bank APIs, and other
  external services for real-time event notifications.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  require Logger


  @doc """
  Handle incoming webhook from external services.

  POST /api/webhooks/:provider
  """
  def handle_webhook(conn, %{"provider" => provider} = params) do
    context = build_context(conn, :handle_webhook, %{provider: provider})

    # Validate webhook signature if required
    case verify_webhook_signature(conn, provider) do
      :ok ->
        process_webhook(conn, provider, params, context)

      {:error, reason} ->
        Logger.warning("Webhook signature verification failed for #{provider}: #{inspect(reason)}")
        context = build_context(conn, :handle_webhook, %{provider: provider, error: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:unauthorized, context)
        handle_error(conn, error)
    end
  end

  @doc """
  Handle payment status webhook from payment processor.

  POST /api/webhooks/payments/status
  """
  def handle_payment_status(conn, params) do
    _context = build_context(conn, :handle_payment_status)

    with {:ok, validated_params} <- validate_payment_webhook_params(params),
         {:ok, payment} <- process_payment_status_update(validated_params) do

      # Broadcast real-time notification
      LedgerBankApi.Financial.PaymentNotifications.broadcast_payment_status_change(payment)

      Logger.info("Payment status webhook processed successfully for payment #{payment.id}")

      handle_success(conn, %{
        message: "Payment status updated successfully",
        payment_id: payment.id,
        status: payment.status,
        timestamp: DateTime.utc_now()
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("Payment status webhook validation failed: #{inspect(changeset.errors)}")
        context = build_context(conn, :handle_payment_status, %{errors: changeset.errors})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:validation_error, Map.put(context, :changeset, changeset))
        handle_error(conn, error)

      {:error, reason} ->
        Logger.error("Payment status webhook processing failed: #{inspect(reason)}")
        context = build_context(conn, :handle_payment_status, %{error: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:webhook_processing_failed, context)
        handle_error(conn, error)
    end
  end

  @doc """
  Handle account sync webhook from bank API.

  POST /api/webhooks/banks/sync
  """
  def handle_account_sync(conn, params) do
    _context = build_context(conn, :handle_account_sync)

    with {:ok, validated_params} <- validate_account_sync_webhook_params(params),
         {:ok, sync_result} <- process_account_sync(validated_params) do

      # Broadcast real-time notification
      LedgerBankApi.Financial.PaymentNotifications.broadcast_account_sync(
        sync_result.user_id,
        sync_result.accounts_synced
      )

      Logger.info("Account sync webhook processed successfully for user #{sync_result.user_id}")

      handle_success(conn, %{
        message: "Account sync completed successfully",
        user_id: sync_result.user_id,
        accounts_synced: sync_result.accounts_synced,
        timestamp: DateTime.utc_now()
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("Account sync webhook validation failed: #{inspect(changeset.errors)}")
        context = build_context(conn, :handle_account_sync, %{errors: changeset.errors})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:validation_error, Map.put(context, :changeset, changeset))
        handle_error(conn, error)

      {:error, reason} ->
        Logger.error("Account sync webhook processing failed: #{inspect(reason)}")
        context = build_context(conn, :handle_account_sync, %{error: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:webhook_processing_failed, context)
        handle_error(conn, error)
    end
  end

  @doc """
  Handle fraud detection webhook.

  POST /api/webhooks/fraud/detection
  """
  def handle_fraud_detection(conn, params) do
    _context = build_context(conn, :handle_fraud_detection)

    with {:ok, validated_params} <- validate_fraud_webhook_params(params),
         {:ok, fraud_result} <- process_fraud_detection(validated_params) do

      Logger.warning("Fraud detection webhook processed: #{fraud_result.severity} for payment #{fraud_result.payment_id}")

      handle_success(conn, %{
        message: "Fraud detection processed successfully",
        payment_id: fraud_result.payment_id,
        severity: fraud_result.severity,
        action_taken: fraud_result.action_taken,
        timestamp: DateTime.utc_now()
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("Fraud detection webhook validation failed: #{inspect(changeset.errors)}")
        context = build_context(conn, :handle_fraud_detection, %{errors: changeset.errors})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:validation_error, Map.put(context, :changeset, changeset))
        handle_error(conn, error)

      {:error, reason} ->
        Logger.error("Fraud detection webhook processing failed: #{inspect(reason)}")
        context = build_context(conn, :handle_fraud_detection, %{error: reason})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:webhook_processing_failed, context)
        handle_error(conn, error)
    end
  end

  @doc """
  List webhook endpoints and their configurations.

  GET /api/webhooks
  """
  def index(conn, _params) do
    _context = build_context(conn, :list_webhooks)

    webhook_endpoints = [
      %{
        endpoint: "/api/webhooks/payments/status",
        method: "POST",
        description: "Payment status updates from payment processor",
        required_headers: ["x-webhook-signature"],
        example_payload: %{
          payment_id: "pay_1234567890",
          status: "completed",
          amount: 10000,
          currency: "GBP",
          timestamp: "2024-01-15T10:30:00Z"
        }
      },
      %{
        endpoint: "/api/webhooks/banks/sync",
        method: "POST",
        description: "Account synchronization from bank API",
        required_headers: ["x-webhook-signature"],
        example_payload: %{
          user_id: "user_1234567890",
          bank_id: "bank_123",
          accounts_synced: 2,
          sync_timestamp: "2024-01-15T10:30:00Z"
        }
      },
      %{
        endpoint: "/api/webhooks/fraud/detection",
        method: "POST",
        description: "Fraud detection alerts",
        required_headers: ["x-webhook-signature"],
        example_payload: %{
          payment_id: "pay_1234567890",
          severity: "high",
          risk_score: 0.95,
          detection_reason: "unusual_transaction_pattern",
          recommended_action: "block"
        }
      }
    ]

    handle_success(conn, %{
      webhooks: webhook_endpoints,
      total_count: length(webhook_endpoints),
      documentation_url: "https://docs.ledgerbank.com/webhooks"
    })
  end

  # Private helper functions

  defp validate_payment_webhook_params(params) do
    required_fields = ["payment_id", "status", "amount"]

    case validate_required_fields(params, required_fields) do
      :ok -> {:ok, params}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_account_sync_webhook_params(params) do
    required_fields = ["user_id", "bank_id", "accounts_synced"]

    case validate_required_fields(params, required_fields) do
      :ok -> {:ok, params}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_fraud_webhook_params(params) do
    required_fields = ["payment_id", "severity", "risk_score"]

    case validate_required_fields(params, required_fields) do
      :ok -> {:ok, params}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_fields(params, required_fields) do
    missing_fields = Enum.reject(required_fields, &Map.has_key?(params, &1))

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp verify_webhook_signature(conn, provider) do
    signature = get_req_header(conn, "x-webhook-signature") |> List.first()
    body = conn.assigns[:raw_body] || ""

    case provider do
      "payments" ->
        verify_payment_webhook_signature(signature, body)

      "banks" ->
        verify_bank_webhook_signature(signature, body)

      "fraud" ->
        verify_fraud_webhook_signature(signature, body)

      _ ->
        Logger.warning("Unknown webhook provider: #{provider}")
        {:error, :unknown_provider}
    end
  end

  defp verify_payment_webhook_signature(signature, body) when is_binary(signature) do
    secret = System.get_env("PAYMENT_WEBHOOK_SECRET")
    expected_signature = "sha256=" <> :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(signature, expected_signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp verify_payment_webhook_signature(_signature, _body) do
    {:error, :missing_signature}
  end

  defp verify_bank_webhook_signature(signature, body) when is_binary(signature) do
    secret = System.get_env("BANK_WEBHOOK_SECRET")
    expected_signature = "sha256=" <> :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(signature, expected_signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp verify_bank_webhook_signature(_signature, _body) do
    {:error, :missing_signature}
  end

  defp verify_fraud_webhook_signature(signature, body) when is_binary(signature) do
    secret = System.get_env("FRAUD_WEBHOOK_SECRET")
    expected_signature = "sha256=" <> :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(signature, expected_signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp verify_fraud_webhook_signature(_signature, _body) do
    {:error, :missing_signature}
  end

  defp process_webhook(conn, provider, params, _context) do
    case provider do
      "payments" ->
        handle_payment_status(conn, params)

      "banks" ->
        handle_account_sync(conn, params)

      "fraud" ->
        handle_fraud_detection(conn, params)

      _ ->
        Logger.warning("Unknown webhook provider: #{provider}")
        context = build_context(conn, :handle_webhook, %{provider: provider})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:unknown_webhook_provider, context)
        handle_error(conn, error)
    end
  end

  defp process_payment_status_update(params) do
    # This would integrate with your payment service
    # For now, return a mock success
    {:ok, %{
      id: params["payment_id"],
      status: params["status"],
      amount: params["amount"],
      direction: params["direction"] || "outbound",
      user_id: "user_123"  # This would come from the payment record
    }}
  end

  defp process_account_sync(params) do
    # This would integrate with your bank sync service
    # For now, return a mock success
    {:ok, %{
      user_id: params["user_id"],
      accounts_synced: params["accounts_synced"],
      sync_timestamp: params["sync_timestamp"]
    }}
  end

  defp process_fraud_detection(params) do
    # This would integrate with your fraud detection service
    # For now, return a mock success
    {:ok, %{
      payment_id: params["payment_id"],
      severity: params["severity"],
      action_taken: params["recommended_action"]
    }}
  end
end

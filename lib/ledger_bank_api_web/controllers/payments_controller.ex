defmodule LedgerBankApiWeb.PaymentsController do
  @moduledoc """
  Optimized payments controller using base controller patterns.
  Provides payment management and processing operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.ResponseHelpers

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler



  # Custom payment actions
  def process(conn, %{"id" => payment_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :process, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      {:ok, payment} = LedgerBankApi.Banking.get_user_payment(payment_id)
      # Ensure user can only process payments from their accounts
      # Preload the user_bank_login association to access user_id
      {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(payment.user_bank_account_id)
      if account.user_bank_login.user_id != user_id do
        raise "Unauthorized access to payment"
      end

      # Queue the payment processing job
      Oban.insert(%Oban.Job{
        queue: :payments,
        worker: "LedgerBankApi.Workers.PaymentWorker",
        args: %{"payment_id" => payment_id}
      })

      job_response("payment_processing", payment_id)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(202)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end

  def list_for_account(conn, %{"account_id" => account_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :list_for_account, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      # Verify the account belongs to the user
      # Preload the user_bank_login association to access user_id
      {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(account_id)
      if account.user_bank_login.user_id != user_id do
        raise "Unauthorized access to account"
      end

      LedgerBankApi.Banking.list_user_payments_for_account(account_id)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end



end

defmodule LedgerBankApiWeb.PaymentsController do
  @moduledoc """
  Optimized payments controller using base controller patterns.
  Provides payment management and processing operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController, except: [action: 2]
  import LedgerBankApiWeb.ResponseHelpers
  require LedgerBankApi.Helpers.AuthorizationHelpers

  alias LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler



  # Standard CRUD operations for payments with user filtering
  crud_operations(
    Context,
    LedgerBankApi.Banking.Schemas.UserPayment,
    "payment",
    user_filter: :user_id,
    authorization: :user_ownership,
    allowed_sort_fields: ["id", "amount", "direction", "description", "payment_type", "status", "posted_at", "external_transaction_id", "inserted_at", "updated_at"],
    default_sort_field: "inserted_at"
  )

  def index(conn, params) do
    user_id = conn.assigns.current_user_id
    # Fetch payments using the context (mimic macro logic, but explicit for debugging)
    payments = LedgerBankApi.Banking.UserPayments.list_with_filters(%{}, %{}, %{}, user_id, nil)
    IO.inspect(payments, label: "DEBUG: payments from context")
    rendered = Enum.map(payments, &LedgerBankApiWeb.JSON.PaymentJSON.format/1)
    IO.inspect(rendered, label: "DEBUG: rendered payments")
    json(conn, %{data: rendered})
  end

  # Custom payment actions
  def process(conn, %{"id" => payment_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :process, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      payment = Context.get_user_payment!(payment_id)
      # Ensure user can only process payments from their accounts
      # Preload the user_bank_login association to access user_id
      account = Context.get_user_bank_account_with_preloads!(payment.user_bank_account_id, [:user_bank_login])
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
      account = Context.get_user_bank_account_with_preloads!(account_id, [:user_bank_login])
      if account.user_bank_login.user_id != user_id do
        raise "Unauthorized access to account"
      end

      Context.list_payments_for_user_bank_account(account_id)
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

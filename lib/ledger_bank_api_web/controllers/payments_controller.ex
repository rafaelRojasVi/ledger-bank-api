defmodule LedgerBankApiWeb.PaymentsControllerV2 do
  @moduledoc """
  Optimized payments controller using base controller patterns.
  Provides payment management and processing operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController
  import LedgerBankApiWeb.JSON.BaseJSON

  alias LedgerBankApi.Banking.Context

  # Standard CRUD operations for payments with custom user filtering
  crud_operations(
    Context,
    LedgerBankApi.Banking.Schemas.UserPayment,
    "payment",
    user_filter: &filter_payments_by_user/2,
    authorization: :user_ownership
  )

  # Custom payment actions
  async_action :process do
    payment = Context.get_user_payment!(params["id"])
    # Ensure user can only process payments from their accounts
    account = Context.get_user_bank_account!(payment.user_bank_account_id)
    if account.user_bank_login.user_id != user_id do
      raise "Unauthorized access to payment"
    end

    # Queue the payment processing job
    Oban.insert(%Oban.Job{
      queue: :payments,
      worker: "LedgerBankApi.Workers.PaymentWorker",
      args: %{"payment_id" => params["id"]}
    })

    format_job_response("payment_processing", params["id"])
  end

  action :list_for_account do
    # Verify the account belongs to the user
    account = Context.get_user_bank_account!(params["account_id"])
    if account.user_bank_login.user_id != user_id do
      raise "Unauthorized access to account"
    end

    Context.list_payments_for_user_bank_account(params["account_id"])
  end

  # Override create to add account ownership validation
  def create(conn, %{"payment" => payment_params}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :create_payment, user_id: user_id}

    # Verify the account belongs to the user
    account_id = payment_params["user_bank_account_id"]
    account = Context.get_user_bank_account!(account_id)
    if account.user_bank_login.user_id != user_id do
      conn
      |> put_status(403)
      |> json(%{
        error: %{
          type: :forbidden,
          message: "Unauthorized access to account",
          code: 403
        }
      })
    else
      case ErrorHandler.with_error_handling(fn ->
        Context.create_user_payment(payment_params)
      end, context) do
        {:ok, response} ->
          conn
          |> put_status(201)
          |> render(:show, %{payment: response.data})
        {:error, error_response} ->
          {status, response} = ErrorHandler.handle_error(error_response, context, [])
          conn |> put_status(status) |> json(response)
      end
    end
  end

  # Private helper functions

  defp filter_payments_by_user(payments, user_id) do
    # Get user's bank accounts first
    user_accounts = Context.list_user_bank_accounts()
    |> Enum.filter(fn account ->
      account.user_bank_login.user_id == user_id
    end)
    |> Enum.map(fn account -> account.id end)

    # Get payments for user's accounts
    Enum.filter(payments, fn payment ->
      payment.user_bank_account_id in user_accounts
    end)
  end
end

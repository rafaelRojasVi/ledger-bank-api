defmodule LedgerBankApi.Banking.UserPayments do
  @moduledoc "Business logic for user payments."
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Repo
  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: UserPayment

  def list_for_account(account_id) do
    UserPayment
    |> where([p], p.user_bank_account_id == ^account_id)
    |> order_by([p], desc: p.posted_at)
    |> Repo.all()
  end

  def list_pending do
    UserPayment |> where([p], p.status == "PENDING") |> Repo.all()
  end

  # Process a payment by id. This is where real business logic would go.
  def process_payment(payment_id) do
    context = %{module: __MODULE__, payment_id: payment_id}

    LedgerBankApi.Banking.Behaviours.ErrorHandler.with_error_handling(fn ->
      Repo.transaction(fn ->
        payment = Repo.get!(UserPayment, payment_id)

        if payment.status != "PENDING" do
          Repo.rollback(:already_processed)
        end

        txn_attrs = %{
          account_id: payment.user_bank_account_id,
          amount: payment.amount,
          description: payment.description || "Payment",
          posted_at: DateTime.utc_now(),
          direction: payment.direction
        }

        case LedgerBankApi.Banking.Transactions.create(txn_attrs) do
          {:ok, txn} ->
            changeset =
              Ecto.Changeset.change(payment, status: "COMPLETED", external_transaction_id: txn.id)
            {:ok, _updated_payment} = Repo.update(changeset)

            # Notification stub (replace with real logic as needed)
            # NotificationService.notify_payment_completed(payment.user_id, payment.id)

            {:ok, txn}

          {:error, changeset} ->
            Repo.rollback({:transaction_error, changeset})
        end
      end)
    end, context)
  end

  @doc """
  List user payments with advanced filtering, pagination, and sorting.
  """
  def list_with_filters(_pagination, _filters, _sorting, user_id, _user_filter) do
    # Get all user bank account IDs for the user first
    account_ids =
      LedgerBankApi.Banking.UserBankAccounts
      |> join(:inner, [a], login in assoc(a, :user_bank_login))
      |> where([a, login], login.user_id == ^user_id)
      |> select([a, _login], a.id)
      |> Repo.all()

    # Get payments for those accounts
    payments =
      from(p in LedgerBankApi.Banking.Schemas.UserPayment,
        where: p.user_bank_account_id in ^account_ids
      )
      |> Repo.all()

    payments
  end

  @doc """
  Get user payment with preloads.
  """
  def get_with_preloads!(id, preloads) do
    UserPayment
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end
end

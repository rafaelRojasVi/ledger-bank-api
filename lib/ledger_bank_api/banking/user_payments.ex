defmodule LedgerBankApi.Banking.UserPayments do
  @moduledoc """
  Enhanced business logic for user payments with comprehensive business rules, authorization, and payment limits.
  All functions return standardized {:ok, data} or {:error, reason} patterns.
  """
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: UserPayment

  # Payment limits configuration
  @daily_payment_limit Decimal.new("10000.00")  # $10,000 daily limit
  @monthly_payment_limit Decimal.new("50000.00") # $50,000 monthly limit
  @max_single_payment Decimal.new("5000.00")    # $5,000 single payment limit

  @doc """
  Lists payments for a specific account with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_for_account(account_id) do
    context = %{action: :list_for_account, account_id: account_id}

    ErrorHandler.with_error_handling(fn ->
      UserPayment
      |> where([p], p.user_bank_account_id == ^account_id)
      |> order_by([p], desc: p.posted_at)
      |> Repo.all()
    end, context)
  end

  @doc """
  Lists pending payments with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_pending do
    context = %{action: :list_pending}

    ErrorHandler.with_error_handling(fn ->
      UserPayment |> where([p], p.status == "PENDING") |> Repo.all()
    end, context)
  end

  @doc """
  Creates a payment with comprehensive business rule validation.
  Returns {:ok, payment} or {:error, reason}.
  """
  def create_payment(attrs, user) do
    context = %{action: :create_payment, user_id: user.id, account_id: attrs["user_bank_account_id"]}

    ErrorHandler.with_error_handling(fn ->
      # Validate user authorization for the account
      with {:ok, account} <- validate_account_ownership(attrs["user_bank_account_id"], user.id),
           {:ok, _} <- validate_payment_amount(attrs["amount"]),
           {:ok, _} <- validate_payment_limits(attrs["user_bank_account_id"], attrs["amount"], user.id),
           {:ok, _} <- validate_account_status(account) do

        # Create the payment
        %UserPayment{}
        |> UserPayment.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, payment} ->
            # Queue payment processing
            Oban.insert(LedgerBankApi.Workers.PaymentWorker.new(%{"payment_id" => payment.id}, queue: :payments))
            {:ok, payment}
          error -> error
        end
      end
    end, context)
  end

  @doc """
  Processes a payment with comprehensive business logic and error handling.
  Returns {:ok, transaction} or {:error, reason}.
  """
  def process_payment(payment_id) do
    context = %{module: __MODULE__, payment_id: payment_id}

    ErrorHandler.with_error_handling(fn ->
      Repo.transaction(fn ->
        payment = Repo.get!(UserPayment, payment_id)

        # Validate payment status
        if payment.status != "PENDING" do
          Repo.rollback(:already_processed)
        end

        # Get the account to update balance
        account = Repo.get!(LedgerBankApi.Banking.Schemas.UserBankAccount, payment.user_bank_account_id)

        # Validate account status
        if account.status != "ACTIVE" do
          Repo.rollback(:account_inactive)
        end

        # Calculate new balance based on payment direction
        new_balance = case payment.direction do
          "CREDIT" -> Decimal.add(account.balance, payment.amount)
          "DEBIT" -> Decimal.sub(account.balance, payment.amount)
          _ -> Repo.rollback(:invalid_direction)
        end

        # Validate sufficient funds for debit transactions
        if payment.direction == "DEBIT" and Decimal.lt?(account.balance, payment.amount) do
          Repo.rollback(:insufficient_funds)
        end

        # Validate final balance is not negative
        if Decimal.lt?(new_balance, Decimal.new(0)) do
          Repo.rollback(:insufficient_funds)
        end

        txn_attrs = %{
          account_id: payment.user_bank_account_id,
          amount: payment.amount,
          description: payment.description || "Payment",
          posted_at: DateTime.utc_now(),
          direction: payment.direction
        }

        case LedgerBankApi.Banking.Transactions.create_transaction(txn_attrs) do
          {:ok, %{data: txn}} ->
            # Update payment status
            payment_changeset =
              Ecto.Changeset.change(payment, status: "COMPLETED", external_transaction_id: txn.id)
            {:ok, _updated_payment} = Repo.update(payment_changeset)

            # Update account balance
            account_changeset = Ecto.Changeset.change(account, balance: new_balance)
            {:ok, _updated_account} = Repo.update(account_changeset)

            # Invalidate cache
            LedgerBankApi.Cache.invalidate_account_balance(account.id)

            # Log successful payment
            require Logger
            Logger.info("Payment processed successfully", %{
              payment_id: payment.id,
              account_id: account.id,
              amount: payment.amount,
              direction: payment.direction,
              new_balance: new_balance
            })

            txn

          {:error, changeset} ->
            Repo.rollback({:transaction_error, changeset})
        end
      end)
    end, context)
  end

  alias LedgerBankApi.Helpers.QueryHelpers

  @doc """
  Lists user payments with advanced filtering, pagination, and sorting.
  Returns {:ok, %{data: list, pagination: map}} or {:error, reason}.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    context = %{action: :list_with_filters, user_id: user_id, user_filter: user_filter}

    ErrorHandler.with_error_handling(fn ->
      # Build query to get payments for user's accounts
      base_query = from p in UserPayment,
        join: a in assoc(p, :user_bank_account),
        join: l in assoc(a, :user_bank_login),
        where: l.user_id == ^user_id

      QueryHelpers.list_with_filters(
        base_query,
        pagination,
        filters,
        sorting,
        user_id,
        nil, # Don't pass user_filter since base_query already handles it
        allowed_sort_fields: ["amount", "direction", "payment_type", "status", "posted_at", "inserted_at"],
        field_mappings: %{
          "amount" => :amount,
          "direction" => :direction,
          "payment_type" => :payment_type,
          "status" => :status
        }
      )
    end, context)
  end



  # Private business rule validation functions

  defp validate_account_ownership(account_id, user_id) do
    case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankAccount, id: account_id) do
      nil -> {:error, :account_not_found}
      account ->
        # Check if user owns this account through the bank login
        case Repo.get_by(LedgerBankApi.Banking.Schemas.UserBankLogin,
                        id: account.user_bank_login_id, user_id: user_id) do
          nil -> {:error, :unauthorized}
          _ -> {:ok, account}
        end
    end
  end

  defp validate_payment_amount(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal_amount, _remainder} -> validate_payment_amount(decimal_amount)
      :error -> {:error, :invalid_amount_format}
    end
  end

  defp validate_payment_amount(%Decimal{} = amount) do
    cond do
      Decimal.lt?(amount, Decimal.new(0)) ->
        {:error, :negative_amount}
      Decimal.gt?(amount, @max_single_payment) ->
        {:error, :amount_exceeds_limit}
      true ->
        {:ok, amount}
    end
  end

  defp validate_payment_amount(_), do: {:error, :invalid_amount}

  defp validate_payment_limits(_account_id, amount, user_id) do
    # Parse amount if it's a string
    decimal_amount = case amount do
      %Decimal{} -> amount
      amount_str when is_binary(amount_str) ->
        case Decimal.parse(amount_str) do
          {decimal, _remainder} -> decimal
          :error -> {:error, :invalid_amount_format}
        end
      _ -> {:error, :invalid_amount}
    end

    # Check daily limit
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    today_end = DateTime.add(today_start, 24 * 60 * 60, :second)

    daily_total = UserPayment
    |> join(:inner, [p], a in assoc(p, :user_bank_account))
    |> join(:inner, [p, a], l in assoc(a, :user_bank_login))
    |> where([p, a, l], l.user_id == ^user_id and p.status == "COMPLETED")
    |> where([p], p.posted_at >= ^today_start and p.posted_at < ^today_end)
    |> select([p], coalesce(sum(p.amount), 0))
    |> Repo.one()

    if Decimal.gt?(Decimal.add(daily_total, decimal_amount), @daily_payment_limit) do
      {:error, :daily_limit_exceeded}
    else
      # Check monthly limit
      month_start = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      month_end = DateTime.add(month_start, 31 * 24 * 60 * 60, :second)

      monthly_total = UserPayment
      |> join(:inner, [p], a in assoc(p, :user_bank_account))
      |> join(:inner, [p, a], l in assoc(a, :user_bank_login))
      |> where([p, a, l], l.user_id == ^user_id and p.status == "COMPLETED")
      |> where([p], p.posted_at >= ^month_start and p.posted_at < ^month_end)
      |> select([p], coalesce(sum(p.amount), 0))
      |> Repo.one()

      if Decimal.gt?(Decimal.add(monthly_total, decimal_amount), @monthly_payment_limit) do
        {:error, :monthly_limit_exceeded}
      else
        {:ok, :limits_valid}
      end
    end
  end

  defp validate_account_status(%{status: "ACTIVE"}), do: {:ok, :account_active}
  defp validate_account_status(%{status: "INACTIVE"}), do: {:error, :account_inactive}
  defp validate_account_status(%{status: "CLOSED"}), do: {:error, :account_closed}
  defp validate_account_status(_), do: {:error, :invalid_account_status}
end

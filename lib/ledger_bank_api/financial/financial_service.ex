defmodule LedgerBankApi.Financial.FinancialService do
  @moduledoc """
  Financial service module for handling financial operations.

  This module provides business logic for financial operations including
  bank synchronization, payment processing, and account management.
  """

  @behaviour LedgerBankApi.Financial.FinancialServiceBehaviour
  @behaviour LedgerBankApi.Core.ServiceBehavior

  import Ecto.Query, warn: false
  require LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Core.{ErrorHandler, ServiceBehavior}

  alias LedgerBankApi.Financial.Schemas.{
    Bank,
    BankBranch,
    UserBankAccount,
    UserBankLogin,
    Transaction,
    UserPayment
  }

  # ============================================================================
  # SERVICE BEHAVIOR IMPLEMENTATION
  # ============================================================================

  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "financial_service"

  # ============================================================================
  # BANK OPERATIONS
  # ============================================================================

  @doc """
  Get a bank by ID.
  """
  def get_bank(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_bank, %{bank_id: id})

    ServiceBehavior.with_standard_error_handling(context, :bank_not_found, fn ->
      ServiceBehavior.get_operation(Bank, id, :bank_not_found, context)
    end)
  end

  @doc """
  List all banks.
  """
  def list_banks(opts \\ []) do
    Bank
    |> apply_bank_filters(opts[:filters])
    |> apply_bank_sorting(opts[:sort])
    |> apply_bank_pagination(opts[:pagination])
    |> Repo.all()
  end

  @doc """
  List active banks.
  """
  def list_active_banks do
    Bank
    |> where([b], b.status == "ACTIVE")
    |> Repo.all()
  end

  @doc """
  Create a new bank.
  """
  def create_bank(attrs) do
    %Bank{}
    |> Bank.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a bank.
  """
  def update_bank(bank, attrs) do
    bank
    |> Bank.update_changeset(attrs)
    |> Repo.update()
  end

  # ============================================================================
  # BANK BRANCH OPERATIONS
  # ============================================================================

  @doc """
  Get a bank branch by ID.
  """
  def get_bank_branch(id) do
    case Repo.get(BankBranch, id) do
      nil ->
        {:error,
         ErrorHandler.business_error(:account_not_found, %{
           resource: "bank_branch",
           id: id,
           source: "financial_service"
         })}

      branch ->
        {:ok, branch}
    end
  end

  @doc """
  List bank branches for a bank.
  """
  def list_bank_branches(bank_id) do
    BankBranch
    |> where([bb], bb.bank_id == ^bank_id)
    |> Repo.all()
  end

  @doc """
  Create a new bank branch.
  """
  def create_bank_branch(attrs) do
    %BankBranch{}
    |> BankBranch.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # USER BANK ACCOUNT OPERATIONS
  # ============================================================================

  @doc """
  Get a user bank account by ID.
  """
  def get_user_bank_account(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user_bank_account, %{account_id: id})

    ServiceBehavior.with_standard_error_handling(context, :account_not_found, fn ->
      ServiceBehavior.get_operation(UserBankAccount, id, :account_not_found, context)
    end)
  end

  @doc """
  List user bank accounts for a user.
  """
  def list_user_bank_accounts(user_id) do
    UserBankAccount
    |> where([uba], uba.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Create a new user bank account.
  """
  def create_user_bank_account(attrs) do
    %UserBankAccount{}
    |> UserBankAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update user bank account balance.
  """
  def update_account_balance(account, new_balance) do
    account
    |> UserBankAccount.balance_changeset(%{
      balance: new_balance,
      last_sync_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # ============================================================================
  # USER BANK LOGIN OPERATIONS
  # ============================================================================

  @doc """
  Get a user bank login by ID.
  """
  @impl true
  def get_user_bank_login(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user_bank_login, %{login_id: id})

    ServiceBehavior.with_standard_error_handling(context, :account_not_found, fn ->
      ServiceBehavior.get_operation(UserBankLogin, id, :account_not_found, context)
    end)
  end

  @doc """
  List user bank logins for a user.
  """
  def list_user_bank_logins(user_id) do
    UserBankLogin
    |> where([ubl], ubl.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Create a new user bank login.
  """
  def create_user_bank_login(attrs) do
    %UserBankLogin{}
    |> UserBankLogin.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update user bank login tokens.
  """
  def update_login_tokens(login, attrs) do
    login
    |> UserBankLogin.token_changeset(attrs)
    |> Repo.update()
  end

  # ============================================================================
  # TRANSACTION OPERATIONS
  # ============================================================================

  @doc """
  Get a transaction by ID.
  """
  def get_transaction(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_transaction, %{transaction_id: id})

    ServiceBehavior.with_standard_error_handling(context, :account_not_found, fn ->
      ServiceBehavior.get_operation(Transaction, id, :account_not_found, context)
    end)
  end

  @doc """
  List transactions for a user bank account.
  """
  def list_transactions(account_id, opts \\ []) do
    Transaction
    |> where([t], t.account_id == ^account_id)
    |> apply_transaction_filters(opts[:filters])
    |> apply_transaction_sorting(opts[:sort])
    |> apply_transaction_pagination(opts[:pagination])
    |> Repo.all()
  end

  @doc """
  Create a new transaction.
  """
  def create_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # USER PAYMENT OPERATIONS
  # ============================================================================

  @doc """
  Get a user payment by ID.
  """
  @impl true
  def get_user_payment(payment_id) do
    context =
      ServiceBehavior.build_context(__MODULE__, :get_user_payment, %{payment_id: payment_id})

    ServiceBehavior.with_standard_error_handling(context, :payment_not_found, fn ->
      ServiceBehavior.get_operation(UserPayment, payment_id, :payment_not_found, context)
    end)
  end

  @doc """
  List user payments for a user.
  """
  def list_user_payments(user_id, opts \\ []) do
    base_query =
      UserPayment
      |> where([up], up.user_id == ^user_id)
      |> apply_payment_filters(opts[:filters])
      |> apply_payment_sorting(opts[:sort])

    # Get total count for pagination
    total_count = base_query |> Repo.aggregate(:count)

    # Apply pagination and get results
    paginated_query = apply_payment_pagination(base_query, opts[:pagination])
    payments = Repo.all(paginated_query)

    # Build pagination metadata
    pagination =
      case opts[:pagination] do
        %{page: page, page_size: page_size} ->
          %{
            page: page,
            page_size: page_size,
            total_count: total_count,
            total_pages: ceil(total_count / page_size),
            has_next: page * page_size < total_count,
            has_prev: page > 1
          }

        _ ->
          %{
            page: 1,
            page_size: total_count,
            total_count: total_count,
            total_pages: 1,
            has_next: false,
            has_prev: false
          }
      end

    {payments, pagination}
  end

  @doc """
  Create a new user payment with basic business rule validation.
  """
  def create_user_payment(attrs) do
    context =
      ServiceBehavior.build_context(__MODULE__, :create_user_payment, %{user_id: attrs[:user_id]})

    ServiceBehavior.with_standard_error_handling(context, :validation_error, fn ->
      with {:ok, account} <- get_user_bank_account(attrs[:user_bank_account_id]),
           :ok <- validate_account_active(account),
           :ok <- validate_amount_limits_at_creation(attrs),
           {:ok, payment} <-
             ServiceBehavior.create_operation(
               &UserPayment.changeset(%UserPayment{}, &1),
               attrs,
               context
             ) do
        {:ok, payment}
      end
    end)
  end

  @doc """
  Process a user payment with comprehensive business rule validation.
  """
  @impl true
  def process_payment(payment_id) do
    context =
      ServiceBehavior.build_context(__MODULE__, :process_payment, %{payment_id: payment_id})

    ServiceBehavior.with_standard_error_handling(context, :payment_processing_failed, fn ->
      with {:ok, payment} <- get_user_payment(payment_id),
           {:ok, account} <- get_user_bank_account(payment.user_bank_account_id),
           :ok <- validate_payment_status(payment),
           :ok <- validate_account_active(account),
           :ok <- validate_amount_limits(payment),
           :ok <- validate_sufficient_funds(payment, account),
           :ok <- validate_daily_limits(payment, account),
           :ok <- check_duplicate_transaction(payment),
           {:ok, updated_payment} <- execute_payment_processing(payment, account) do
        {:ok, updated_payment}
      end
    end)
  end

  # ============================================================================
  # BANK SYNCHRONIZATION
  # ============================================================================

  @doc """
  Synchronizes bank login data with external bank API.
  """
  @impl true
  def sync_login(login_id) do
    context = ServiceBehavior.build_context(__MODULE__, :sync_login, %{login_id: login_id})

    ServiceBehavior.with_standard_error_handling(context, :sync_failed, fn ->
      with {:ok, login} <- get_user_bank_login(login_id),
           {:ok, _updated_login} <- execute_sync(login) do
        {:ok, %{status: "synced", login_id: login_id, synced_at: DateTime.utc_now()}}
      end
    end)
  end

  # ============================================================================
  # PUBLIC BUSINESS RULE VALIDATION FUNCTIONS
  # ============================================================================

  @doc """
  Validates if an account is active and can process payments.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_account_active(account) do
    case account.status do
      "ACTIVE" ->
        :ok

      _ ->
        {:error,
         ErrorHandler.business_error(:account_inactive, %{
           account_id: account.id,
           status: account.status
         })}
    end
  end

  @doc """
  Validates if there are sufficient funds for a payment.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_sufficient_funds(payment, account) do
    # Only validate for DEBIT payments (money going out)
    case payment.direction do
      "DEBIT" ->
        if Decimal.gt?(account.balance, payment.amount) or
             Decimal.eq?(account.balance, payment.amount) do
          :ok
        else
          {:error,
           ErrorHandler.business_error(:insufficient_funds, %{
             payment_id: payment.id,
             payment_amount: payment.amount,
             account_balance: account.balance,
             shortfall: Decimal.sub(payment.amount, account.balance)
           })}
        end

      "CREDIT" ->
        :ok

      _ ->
        {:error, ErrorHandler.business_error(:invalid_direction, %{direction: payment.direction})}
    end
  end

  @doc """
  Validates if a payment would exceed daily spending limits.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_daily_limits(payment, account) do
    # Check daily spending limits for DEBIT payments
    case payment.direction do
      "DEBIT" ->
        daily_limit = get_daily_limit_for_account(account)
        daily_spent = calculate_daily_spent(account, DateTime.utc_now())

        if Decimal.gt?(Decimal.add(daily_spent, payment.amount), daily_limit) do
          {:error,
           ErrorHandler.business_error(:daily_limit_exceeded, %{
             payment_id: payment.id,
             payment_amount: payment.amount,
             daily_spent: daily_spent,
             daily_limit: daily_limit,
             account_id: account.id
           })}
        else
          :ok
        end

      "CREDIT" ->
        :ok

      _ ->
        {:error, ErrorHandler.business_error(:invalid_direction, %{direction: payment.direction})}
    end
  end

  @doc """
  Validates if a payment amount exceeds single transaction limits.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_amount_limits(payment) do
    # Check single transaction limits
    max_single_transaction = get_max_single_transaction_limit()

    if Decimal.gt?(payment.amount, max_single_transaction) do
      {:error,
       ErrorHandler.business_error(:amount_exceeds_limit, %{
         payment_id: payment.id,
         payment_amount: payment.amount,
         max_limit: max_single_transaction
       })}
    else
      :ok
    end
  end

  @doc """
  Checks for duplicate transactions within a time window.
  Returns :ok or {:error, %Error{}}.
  """
  def check_duplicate_transaction(payment) do
    # Check for duplicate transactions based on amount, description, and time window
    # Only check for duplicates within the last 5 minutes
    duplicate_window_minutes = 5

    query =
      from(up in UserPayment,
        where: up.user_id == ^payment.user_id,
        where: up.amount == ^payment.amount,
        where: up.description == ^payment.description,
        where: up.direction == ^payment.direction,
        where: up.id != ^payment.id,
        # Only check completed payments
        where: up.status == "COMPLETED",
        where: up.posted_at > ago(^duplicate_window_minutes, "minute")
      )

    case Repo.one(query) do
      nil ->
        :ok

      _duplicate ->
        {:error,
         ErrorHandler.business_error(:duplicate_transaction, %{
           payment_id: payment.id,
           amount: payment.amount,
           description: payment.description
         })}
    end
  end

  @doc """
  Validates if a payment status allows processing.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_payment_status(payment) do
    case payment.status do
      "PENDING" ->
        :ok

      _ ->
        {:error,
         ErrorHandler.business_error(:already_processed, %{
           payment_id: payment.id,
           current_status: payment.status
         })}
    end
  end

  @doc """
  Validates if an account has sufficient balance for a given amount.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_account_balance(account, amount) do
    if Decimal.gt?(account.balance, amount) or Decimal.eq?(account.balance, amount) do
      :ok
    else
      {:error,
       ErrorHandler.business_error(:insufficient_funds, %{
         account_id: account.id,
         required_amount: amount,
         account_balance: account.balance,
         shortfall: Decimal.sub(amount, account.balance)
       })}
    end
  end

  @doc """
  Validates if a user can make payments from an account.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_user_account_access(user, account) do
    if user.id == account.user_id do
      :ok
    else
      {:error,
       ErrorHandler.business_error(:unauthorized_access, %{
         user_id: user.id,
         account_id: account.id,
         account_user_id: account.user_id
       })}
    end
  end

  @doc """
  Validates if a payment amount is within acceptable range.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_payment_amount_range(amount) do
    min_amount = Decimal.new("0.01")
    max_amount = get_max_single_transaction_limit()

    cond do
      Decimal.lt?(amount, min_amount) ->
        {:error,
         ErrorHandler.business_error(:amount_too_small, %{
           amount: amount,
           min_amount: min_amount
         })}

      Decimal.gt?(amount, max_amount) ->
        {:error,
         ErrorHandler.business_error(:amount_exceeds_limit, %{
           amount: amount,
           max_amount: max_amount
         })}

      true ->
        :ok
    end
  end

  @doc """
  Validates if an account is not frozen or suspended.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_account_not_frozen(account) do
    case account.status do
      "FROZEN" ->
        {:error, ErrorHandler.business_error(:account_frozen, %{account_id: account.id})}

      "SUSPENDED" ->
        {:error, ErrorHandler.business_error(:account_suspended, %{account_id: account.id})}

      _ ->
        :ok
    end
  end

  @doc """
  Validates if a payment description meets requirements.
  Returns :ok or {:error, %Error{}}.
  """
  def validate_payment_description(description) do
    cond do
      is_nil(description) or description == "" ->
        {:error, ErrorHandler.business_error(:description_required, %{})}

      String.length(description) > 255 ->
        {:error,
         ErrorHandler.business_error(:description_too_long, %{
           description: description,
           max_length: 255
         })}

      true ->
        :ok
    end
  end

  # ============================================================================
  # BATCH VALIDATION FUNCTIONS
  # ============================================================================

  @doc """
  Performs comprehensive validation for a payment before processing.
  Returns :ok or {:error, %Error{}} with the first validation error found.
  """
  def validate_payment_comprehensive(payment, account, user) do
    validations = [
      fn -> validate_payment_status(payment) end,
      fn -> validate_account_active(account) end,
      fn -> validate_account_not_frozen(account) end,
      fn -> validate_user_account_access(user, account) end,
      fn -> validate_payment_amount_range(payment.amount) end,
      fn -> validate_payment_description(payment.description) end,
      fn -> validate_sufficient_funds(payment, account) end,
      fn -> validate_daily_limits(payment, account) end,
      fn -> validate_amount_limits(payment) end,
      fn -> check_duplicate_transaction(payment) end
    ]

    Enum.reduce_while(validations, :ok, fn validation, _acc ->
      case validation.() do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  @doc """
  Performs basic validation for a payment (without duplicate check).
  Returns :ok or {:error, %Error{}} with the first validation error found.
  """
  def validate_payment_basic(payment, account, user) do
    validations = [
      fn -> validate_payment_status(payment) end,
      fn -> validate_account_active(account) end,
      fn -> validate_account_not_frozen(account) end,
      fn -> validate_user_account_access(user, account) end,
      fn -> validate_payment_amount_range(payment.amount) end,
      fn -> validate_payment_description(payment.description) end,
      fn -> validate_sufficient_funds(payment, account) end,
      fn -> validate_daily_limits(payment, account) end,
      fn -> validate_amount_limits(payment) end
    ]

    Enum.reduce_while(validations, :ok, fn validation, _acc ->
      case validation.() do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  # ============================================================================
  # FINANCIAL HEALTH CHECK FUNCTIONS
  # ============================================================================

  @doc """
  Checks the financial health of an account.
  Returns a map with health indicators.
  """
  def check_account_financial_health(account) do
    daily_limit = get_daily_limit_for_account(account)
    daily_spent = calculate_daily_spent(account, DateTime.utc_now())
    daily_remaining = Decimal.sub(daily_limit, daily_spent)

    %{
      account_id: account.id,
      balance: account.balance,
      status: account.status,
      daily_limit: daily_limit,
      daily_spent: daily_spent,
      daily_remaining: daily_remaining,
      daily_utilization_percent: calculate_utilization_percent(daily_spent, daily_limit),
      is_healthy: account.status == "ACTIVE" and Decimal.gt?(account.balance, Decimal.new("0")),
      can_make_payments:
        account.status == "ACTIVE" and Decimal.gt?(daily_remaining, Decimal.new("0"))
    }
  end

  @doc """
  Checks the financial health of a user across all their accounts.
  Returns a map with aggregated health indicators.
  """
  def check_user_financial_health(user_id) do
    accounts = list_user_bank_accounts(user_id)

    total_balance =
      Enum.reduce(accounts, Decimal.new("0"), fn account, acc ->
        Decimal.add(acc, account.balance)
      end)

    active_accounts = Enum.filter(accounts, fn account -> account.status == "ACTIVE" end)
    frozen_accounts = Enum.filter(accounts, fn account -> account.status == "FROZEN" end)
    suspended_accounts = Enum.filter(accounts, fn account -> account.status == "SUSPENDED" end)

    %{
      user_id: user_id,
      total_balance: total_balance,
      total_accounts: length(accounts),
      active_accounts: length(active_accounts),
      frozen_accounts: length(frozen_accounts),
      suspended_accounts: length(suspended_accounts),
      is_healthy: length(active_accounts) > 0 and Decimal.gt?(total_balance, Decimal.new("0")),
      can_make_payments: length(active_accounts) > 0
    }
  end

  # ============================================================================
  # PAYMENT PROCESSING HELPER FUNCTIONS
  # ============================================================================

  # Private functions now delegate to public validation functions
  # Note: These are now public functions, so we don't need private wrappers

  defp validate_amount_limits_at_creation(attrs) do
    # Check single transaction limits at creation time
    max_single_transaction = get_max_single_transaction_limit()

    if Decimal.gt?(attrs[:amount], max_single_transaction) do
      {:error,
       ErrorHandler.business_error(:amount_exceeds_limit, %{
         payment_amount: attrs[:amount],
         max_limit: max_single_transaction
       })}
    else
      :ok
    end
  end

  defp execute_payment_processing(payment, account) do
    # Execute payment processing with account balance update
    Repo.transaction(fn ->
      # Update account balance for DEBIT payments
      _updated_account =
        case payment.direction do
          "DEBIT" ->
            new_balance = Decimal.sub(account.balance, payment.amount)

            account
            |> UserBankAccount.balance_changeset(%{balance: new_balance})
            |> Repo.update!()

          "CREDIT" ->
            new_balance = Decimal.add(account.balance, payment.amount)

            account
            |> UserBankAccount.balance_changeset(%{balance: new_balance})
            |> Repo.update!()

          _ ->
            account
        end

      # Update payment status
      updated_payment =
        payment
        |> UserPayment.changeset(%{status: "COMPLETED", posted_at: DateTime.utc_now()})
        |> Repo.update!()

      # Create transaction record
      transaction_attrs = %{
        amount: payment.amount,
        direction: payment.direction,
        description: payment.description,
        posted_at: DateTime.utc_now(),
        account_id: account.id,
        user_id: payment.user_id
      }

      %Transaction{}
      |> Transaction.changeset(transaction_attrs)
      |> Repo.insert!()

      updated_payment
    end)
  end

  defp execute_sync(login) do
    # Simple sync logic - in real implementation, this would call external APIs
    # For now, just update the last_sync_at timestamp
    login
    |> UserBankLogin.update_changeset(%{last_sync_at: DateTime.utc_now()})
    |> Repo.update()
  end

  # ============================================================================
  # BUSINESS RULE HELPER FUNCTIONS
  # ============================================================================

  defp get_daily_limit_for_account(account) do
    # In a real implementation, this would come from account settings or user preferences
    # For now, return a default daily limit based on account type
    case account.account_type do
      "CHECKING" -> Decimal.new("1000.00")
      "SAVINGS" -> Decimal.new("500.00")
      "CREDIT" -> Decimal.new("2000.00")
      "INVESTMENT" -> Decimal.new("5000.00")
      _ -> Decimal.new("1000.00")
    end
  end

  defp get_max_single_transaction_limit do
    # In a real implementation, this would come from configuration or account settings
    Decimal.new("10000.00")
  end

  defp calculate_daily_spent(account, _date) do
    # Calculate total amount spent today for DEBIT payments
    start_of_day = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(Date.utc_today(), ~T[23:59:59], "Etc/UTC")

    query =
      from(up in UserPayment,
        where: up.user_bank_account_id == ^account.id,
        where: up.direction == "DEBIT",
        where: up.status == "COMPLETED",
        where: up.posted_at >= ^start_of_day,
        where: up.posted_at <= ^end_of_day,
        select: sum(up.amount)
      )

    case Repo.one(query) do
      nil -> Decimal.new("0")
      total -> total
    end
  end

  defp calculate_utilization_percent(spent, limit) do
    if Decimal.eq?(limit, Decimal.new("0")) do
      0.0
    else
      utilization = Decimal.div(spent, limit)
      Decimal.to_float(Decimal.mult(utilization, Decimal.new("100")))
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  # Bank filters
  defp apply_bank_filters(query, nil), do: query
  defp apply_bank_filters(query, []), do: query

  defp apply_bank_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn {field, value}, acc ->
      case field do
        :status when is_binary(value) ->
          where(acc, [b], b.status == ^value)

        :country when is_binary(value) ->
          where(acc, [b], b.country == ^value)

        _ ->
          acc
      end
    end)
  end

  defp apply_bank_sorting(query, nil), do: query
  defp apply_bank_sorting(query, []), do: query

  defp apply_bank_sorting(query, sort) when is_list(sort) do
    Enum.reduce(sort, query, fn {field, direction}, acc ->
      case direction do
        :asc -> order_by(acc, [b], asc: field(b, ^field))
        :desc -> order_by(acc, [b], desc: field(b, ^field))
        _ -> acc
      end
    end)
  end

  defp apply_bank_pagination(query, nil), do: query

  defp apply_bank_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query
    |> limit(^page_size)
    |> offset(^offset)
  end

  # Transaction filters
  defp apply_transaction_filters(query, nil), do: query
  defp apply_transaction_filters(query, []), do: query

  defp apply_transaction_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn {field, value}, acc ->
      case field do
        :direction when is_binary(value) ->
          where(acc, [t], t.direction == ^value)

        :date_from when is_binary(value) ->
          where(acc, [t], t.posted_at >= ^value)

        :date_to when is_binary(value) ->
          where(acc, [t], t.posted_at <= ^value)

        _ ->
          acc
      end
    end)
  end

  defp apply_transaction_sorting(query, nil), do: query
  defp apply_transaction_sorting(query, []), do: query

  defp apply_transaction_sorting(query, sort) when is_list(sort) do
    Enum.reduce(sort, query, fn {field, direction}, acc ->
      case direction do
        :asc -> order_by(acc, [t], asc: field(t, ^field))
        :desc -> order_by(acc, [t], desc: field(t, ^field))
        _ -> acc
      end
    end)
  end

  defp apply_transaction_pagination(query, nil), do: query

  defp apply_transaction_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query
    |> limit(^page_size)
    |> offset(^offset)
  end

  # Payment filters
  defp apply_payment_filters(query, nil), do: query
  defp apply_payment_filters(query, []), do: query

  defp apply_payment_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn {field, value}, acc ->
      case field do
        :status when is_binary(value) ->
          where(acc, [up], up.status == ^value)

        :payment_type when is_binary(value) ->
          where(acc, [up], up.payment_type == ^value)

        :direction when is_binary(value) ->
          where(acc, [up], up.direction == ^value)

        _ ->
          acc
      end
    end)
  end

  defp apply_payment_sorting(query, nil), do: query
  defp apply_payment_sorting(query, []), do: query

  defp apply_payment_sorting(query, %{field: field, direction: direction}) do
    case direction do
      :asc -> order_by(query, [up], asc: field(up, ^field))
      :desc -> order_by(query, [up], desc: field(up, ^field))
      _ -> query
    end
  end

  defp apply_payment_sorting(query, sort) when is_list(sort) do
    Enum.reduce(sort, query, fn {field, direction}, acc ->
      case direction do
        :asc -> order_by(acc, [up], asc: field(up, ^field))
        :desc -> order_by(acc, [up], desc: field(up, ^field))
        _ -> acc
      end
    end)
  end

  defp apply_payment_pagination(query, nil), do: query

  defp apply_payment_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query
    |> limit(^page_size)
    |> offset(^offset)
  end
end

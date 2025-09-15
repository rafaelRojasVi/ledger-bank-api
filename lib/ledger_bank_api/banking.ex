defmodule LedgerBankApi.Banking do
  @moduledoc """
  Consolidated banking business logic.
  Combines functionality from all banking modules.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import LedgerBankApi.Database.Macros

  # Schemas
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Banking.Schemas.Transaction

  # Generate query operations for all schemas
  use_query_operations(Bank, b)
  use_query_operations(BankBranch, bb)
  use_query_operations(UserBankLogin, ubl)
  use_query_operations(UserBankAccount, uba)
  use_query_operations(UserPayment, up)
  use_query_operations(Transaction, t)

  # ============================================================================
  # BANK MANAGEMENT
  # ============================================================================

  @doc """
  List all banks with optional filters.
  """
  def list_banks(opts \\ []) do
    with_error_handling(:list_banks, %{opts: opts}, do:
      Bank
      |> apply_bank_filters(opts[:filters])
      |> apply_bank_sorting(opts[:sort])
      |> apply_bank_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  @doc """
  Get a bank by ID.
  """
  def get_bank(id) do
    with_error_handling(:get_bank, %{id: id}, do:
      case Repo.get(Bank, id) do
        nil -> {:error, :not_found}
        bank -> {:ok, bank}
      end
    )
  end

  @doc """
  Create a new bank.
  """
  def create_bank(attrs) do
    with_error_handling(:create_bank, %{attrs: attrs}, do:
      %Bank{}
      |> Bank.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Update a bank.
  """
  def update_bank(bank, attrs) do
    with_error_handling(:update_bank, %{id: bank.id, attrs: attrs}, do:
      bank
      |> Bank.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a bank.
  """
  def delete_bank(bank) do
    with_error_handling(:delete_bank, %{id: bank.id}, do:
      Repo.delete(bank)
    )
  end

  @doc """
  List active banks.
  """
  def list_active_banks do
    with_error_handling(:list_active_banks, %{}, do:
      Bank
      |> where([b], b.status == "ACTIVE")
      |> Repo.all()
    )
  end

  @doc """
  Get bank by code.
  """
  def get_bank_by_code(code) do
    with_error_handling(:get_bank_by_code, %{code: code}, do:
      case Repo.get_by(Bank, code: code) do
        nil -> {:error, :not_found}
        bank -> {:ok, bank}
      end
    )
  end

  @doc """
  List banks by country.
  """
  def list_banks_by_country(country) do
    with_error_handling(:list_banks_by_country, %{country: country}, do:
      Bank
      |> where([b], b.country == ^country)
      |> Repo.all()
    )
  end


  # ============================================================================
  # BANK BRANCH MANAGEMENT
  # ============================================================================

  @doc """
  List bank branches with optional filters.
  """
  def list_bank_branches(opts \\ []) do
    with_error_handling(:list_bank_branches, %{opts: opts}, do:
      BankBranch
      |> apply_bank_branch_filters(opts[:filters])
      |> apply_bank_branch_sorting(opts[:sort])
      |> apply_bank_branch_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  @doc """
  Get a bank branch by ID.
  """
  def get_bank_branch(id) do
    with_error_handling(:get_bank_branch, %{id: id}, do:
      case Repo.get(BankBranch, id) do
        nil -> {:error, :not_found}
        branch -> {:ok, branch}
      end
    )
  end

  @doc """
  Create a new bank branch.
  """
  def create_bank_branch(attrs) do
    with_error_handling(:create_bank_branch, %{attrs: attrs}, do:
      %BankBranch{}
      |> BankBranch.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Update a bank branch.
  """
  def update_bank_branch(branch, attrs) do
    with_error_handling(:update_bank_branch, %{id: branch.id, attrs: attrs}, do:
      branch
      |> BankBranch.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a bank branch.
  """
  def delete_bank_branch(branch) do
    with_error_handling(:delete_bank_branch, %{id: branch.id}, do:
      Repo.delete(branch)
    )
  end

  @doc """
  List bank branches by bank ID.
  """
  def list_bank_branches_by_bank(bank_id) do
    with_error_handling(:list_bank_branches_by_bank, %{bank_id: bank_id}, do:
      BankBranch
      |> where([bb], bb.bank_id == ^bank_id)
      |> preload([:bank, :user_bank_logins])
      |> Repo.all()
    )
  end

  @doc """
  List bank branches by country.
  """
  def list_bank_branches_by_country(country) do
    with_error_handling(:list_bank_branches_by_country, %{country: country}, do:
      BankBranch
      |> where([bb], bb.country == ^country)
      |> preload(:bank)
      |> Repo.all()
    )
  end

  @doc """
  Get bank branch by IBAN.
  """
  def get_bank_branch_by_iban(iban) do
    with_error_handling(:get_bank_branch_by_iban, %{iban: iban}, do:
      case Repo.get_by(BankBranch, iban: iban) do
        nil -> {:error, :not_found}
        branch -> {:ok, Repo.preload(branch, :bank)}
      end
    )
  end

  # ============================================================================
  # USER BANK LOGIN MANAGEMENT
  # ============================================================================

  @doc """
  List user bank logins with optional filters.
  """
  def list_user_bank_logins(opts \\ []) do
    with_error_handling(:list_user_bank_logins, %{opts: opts}, do:
      UserBankLogin
      |> apply_user_bank_login_filters(opts[:filters])
      |> apply_user_bank_login_sorting(opts[:sort])
      |> apply_user_bank_login_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  @doc """
  Get a user bank login by ID.
  """
  def get_user_bank_login(id) do
    with_error_handling(:get_user_bank_login, %{id: id}, do:
      case Repo.get(UserBankLogin, id) do
        nil -> {:error, :not_found}
        login -> {:ok, login}
      end
    )
  end

  @doc """
  Create a new user bank login.
  """
  def create_user_bank_login(attrs) do
    with_error_handling(:create_user_bank_login, %{attrs: attrs}, do:
      %UserBankLogin{}
      |> UserBankLogin.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Update a user bank login.
  """
  def update_user_bank_login(login, attrs) do
    with_error_handling(:update_user_bank_login, %{id: login.id, attrs: attrs}, do:
      login
      |> UserBankLogin.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a user bank login.
  """
  def delete_user_bank_login(login) do
    with_error_handling(:delete_user_bank_login, %{id: login.id}, do:
      Repo.delete(login)
    )
  end

  @doc """
  Get user bank logins by user ID.
  """
  def get_user_bank_logins_by_user(user_id, filters \\ %{}) do
    with_error_handling(:get_user_bank_logins_by_user, %{user_id: user_id, filters: filters}, do:
      UserBankLogin
      |> where([l], l.user_id == ^user_id)
      |> apply_user_bank_login_filters(filters)
      |> preload([:bank_branch, :user_bank_accounts])
      |> order_by([l], desc: l.updated_at)
      |> Repo.all()
    )
  end

  @doc """
  Update user bank login status.
  """
  def update_user_bank_login_status(login, status) do
    with_error_handling(:update_user_bank_login_status, %{login_id: login.id, status: status}, do:
      login
      |> Ecto.Changeset.change(%{status: status})
      |> Repo.update()
    )
  end

  @doc """
  Check if user bank login is valid.
  """
  def is_user_bank_login_valid?(login) do
    with_error_handling(:is_user_bank_login_valid, %{login_id: login.id}, do:
      case login do
        %{status: "ACTIVE", last_sync_at: last_sync_at} when not is_nil(last_sync_at) ->
          # Check if last sync was within 24 hours
          hours_since_sync = DateTime.diff(DateTime.utc_now(), last_sync_at, :hour)
          hours_since_sync < 24
        _ ->
          false
      end
    )
  end

  # ============================================================================
  # USER BANK ACCOUNT MANAGEMENT
  # ============================================================================

  @doc """
  List user bank accounts with optional filters.
  """
  def list_user_bank_accounts(opts \\ []) do
    with_error_handling(:list_user_bank_accounts, %{opts: opts}, do:
      UserBankAccount
      |> apply_user_bank_account_filters(opts[:filters])
      |> apply_user_bank_account_sorting(opts[:sort])
      |> apply_user_bank_account_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  @doc """
  Get a user bank account by ID.
  """
  def get_user_bank_account(id) do
    with_error_handling(:get_user_bank_account, %{id: id}, do:
      case Repo.get(UserBankAccount, id) do
        nil -> {:error, :not_found}
        account -> {:ok, account}
      end
    )
  end

  @doc """
  Create a new user bank account.
  """
  def create_user_bank_account(attrs) do
    with_error_handling(:create_user_bank_account, %{attrs: attrs}, do:
      %UserBankAccount{}
      |> UserBankAccount.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Update a user bank account.
  """
  def update_user_bank_account(account, attrs) do
    with_error_handling(:update_user_bank_account, %{id: account.id, attrs: attrs}, do:
      account
      |> UserBankAccount.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a user bank account.
  """
  def delete_user_bank_account(account) do
    with_error_handling(:delete_user_bank_account, %{id: account.id}, do:
      Repo.delete(account)
    )
  end

  @doc """
  Get user bank account with preloads.
  """
  def get_user_bank_account_with_preloads(id, preloads) do
    with_error_handling(:get_user_bank_account_with_preloads, %{id: id, preloads: preloads}, do:
      UserBankAccount
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    )
  end

  @doc """
  Get user bank account with preloads and user validation.
  """
  def get_user_bank_account_with_preloads_and_user(id, preloads, user_id) do
    with_error_handling(:get_user_bank_account_with_preloads_and_user, %{id: id, preloads: preloads, user_id: user_id}, do:
      case get_user_bank_account_with_ownership_check(id, user_id) do
        {:ok, account} ->
          account
          |> Repo.preload(preloads)
        {:error, reason} ->
          {:error, reason}
      end
    )
  end

  @doc """
  Get account with ownership validation.
  """
  def get_user_bank_account_with_ownership_check(account_id, user_id) do
    case Repo.get(UserBankAccount, account_id) do
      nil ->
        {:error, :not_found}
      account ->
        account
        |> Repo.preload(user_bank_login: [])
        |> validate_account_ownership(user_id)
    end
  end

  @doc """
  Update account balance.
  """
  def update_user_bank_account_balance(account_id, new_balance, user_id) do
    with_error_handling(:update_user_bank_account_balance, %{account_id: account_id, new_balance: new_balance, user_id: user_id}, do:
      # Validate user owns the account
      with {:ok, _account} <- get_user_bank_account_with_preloads_and_user(account_id, [], user_id),
           {:ok, _} <- validate_balance_update(new_balance) do

        result = Repo.update_all(
          from(a in UserBankAccount, where: a.id == ^account_id),
          set: [balance: new_balance, updated_at: DateTime.utc_now()]
        )

        # Invalidate cache
        LedgerBankApi.Cache.invalidate_account_balance(account_id)

        {:ok, result}
      end
    )
  end

  # Private helper functions for user bank accounts

  defp validate_account_ownership(account, user_id) do
    case account.user_bank_login do
      %{user_id: ^user_id} -> {:ok, account}
      _ -> {:error, :forbidden}
    end
  end

  defp validate_balance_update(balance) when is_struct(balance, Decimal) do
    if Decimal.lt?(balance, Decimal.new(0)) do
      {:error, :negative_balance}
    else
      {:ok, :valid_balance}
    end
  end

  defp validate_balance_update(_), do: {:error, :invalid_balance_format}

  @doc """
  Get account balance.
  """
  def get_account_balance(account_id, user_id) do
    with_error_handling(:get_account_balance, %{account_id: account_id, user_id: user_id}, do:
      case get_user_bank_account(account_id) do
        {:ok, account} ->
          # Check if user owns this account through the bank login
          case Repo.get_by(UserBankLogin, id: account.user_bank_login_id, user_id: user_id) do
            nil -> {:error, :unauthorized}
            _ -> {:ok, account.balance}
          end
        {:error, :not_found} -> {:error, ErrorHandler.business_error(:account_not_found, %{account_id: account_id})}
        error -> error
      end
    )
  end

  @doc """
  List user bank accounts for a specific user.
  """
  def list_user_bank_accounts_for_user(user_id, opts \\ []) do
    with_error_handling(:list_user_bank_accounts_for_user, %{user_id: user_id}, do:
      UserBankAccount
      |> join(:inner, [a], l in assoc(a, :user_bank_login))
      |> where([a, l], l.user_id == ^user_id)
      |> preload([a, l], [
        :user_payments,
        :transactions,
        user_bank_login: {l, [bank_branch: :bank]}
      ])
      |> apply_list_opts(opts)
      |> Repo.all()
    )
  end

  defp apply_list_opts(query, opts) do
    Enum.reduce(opts, query, fn {key, value}, acc ->
      case key do
        :preload -> Repo.preload(acc, value)
        :where -> where(acc, ^value)
        :order_by -> order_by(acc, ^value)
        _ -> acc
      end
    end)
  end

  # ============================================================================
  # USER PAYMENT MANAGEMENT
  # ============================================================================

  @doc """
  List user payments with optional filters.
  """
  def list_user_payments(opts \\ []) do
    context = %{action: :list_user_payments, opts: opts}
    ErrorHandler.with_error_handling(fn ->
      UserPayment
      |> apply_user_payment_filters(opts[:filters])
      |> apply_user_payment_sorting(opts[:sort])
      |> apply_user_payment_pagination(opts[:pagination])
      |> Repo.all()
    end, context)
  end

  @doc """
  Get a user payment by ID.
  """
  def get_user_payment(id) do
    context = %{action: :get_user_payment, id: id}
    ErrorHandler.with_error_handling(fn ->
      case Repo.get(UserPayment, id) do
        nil -> {:error, :not_found}
        payment -> {:ok, payment}
      end
    end, context)
  end

  @doc """
  Get a user payment by ID with user authorization.
  """
  def get_user_payment_with_auth(id, user_id) do
    context = %{action: :get_user_payment_with_auth, id: id, user_id: user_id}
    ErrorHandler.with_error_handling(fn ->
      case Repo.get(UserPayment, id) do
        nil -> {:error, :not_found}
        payment ->
          if payment.user_id == user_id do
            {:ok, payment}
          else
            {:error, :forbidden}
          end
      end
    end, context)
  end

  @doc """
  Create a new user payment.
  """
  def create_user_payment(attrs) do
    context = %{action: :create_user_payment, attrs: attrs}
    ErrorHandler.with_error_handling(fn ->
      %UserPayment{}
      |> UserPayment.changeset(attrs)
      |> Repo.insert()
    end, context)
  end

  @doc """
  Update a user payment.
  """
  def update_user_payment(payment, attrs) do
    context = %{action: :update_user_payment, payment: payment, attrs: attrs}
    ErrorHandler.with_error_handling(fn ->
      payment
      |> UserPayment.changeset(attrs)
      |> Repo.update()
    end, context)
  end

  @doc """
  Delete a user payment.
  """
  def delete_user_payment(payment) do
    context = %{action: :delete_user_payment, payment: payment}
    ErrorHandler.with_error_handling(fn ->
      Repo.delete(payment)
    end, context)
  end

  @doc """
  List payments for a specific account.
  """
  def list_user_payments_for_account(account_id) do
    context = %{action: :list_user_payments_for_account, account_id: account_id}
    ErrorHandler.with_error_handling(fn ->
      UserPayment
      |> where([p], p.user_bank_account_id == ^account_id)
      |> order_by([p], desc: p.posted_at)
      |> Repo.all()
    end, context)
  end

  @doc """
  List pending payments.
  """
  def list_pending_user_payments do
    context = %{action: :list_pending_user_payments}
    ErrorHandler.with_error_handling(fn ->
      UserPayment |> where([p], p.status == "PENDING") |> Repo.all()
    end, context)
  end

  @doc """
  Get user payment with preloads.
  """
  def get_user_payment_with_preloads(id, preloads) do
    context = %{action: :get_user_payment_with_preloads, id: id, preloads: preloads}
    ErrorHandler.with_error_handling(fn ->
      UserPayment
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    end, context)
  end

  # ============================================================================
  # TRANSACTION MANAGEMENT
  # ============================================================================

  @doc """
  List transactions with optional filters.
  """
  def list_transactions(opts \\ []) do
    context = %{action: :list_transactions, opts: opts}
    ErrorHandler.with_error_handling(fn ->
      Transaction
      |> apply_transaction_filters(opts[:filters])
      |> apply_transaction_sorting(opts[:sort])
      |> apply_transaction_pagination(opts[:pagination])
      |> Repo.all()
    end, context)
  end

  @doc """
  Get a transaction by ID.
  """
  def get_transaction(id) do
    context = %{action: :get_transaction, id: id}
    ErrorHandler.with_error_handling(fn ->
      case Repo.get(Transaction, id) do
        nil -> {:error, :not_found}
        transaction -> {:ok, transaction}
      end
    end, context)
  end

  @doc """
  Get a transaction by ID with user authorization.
  """
  def get_transaction_with_auth(id, user_id) do
    context = %{action: :get_transaction_with_auth, id: id, user_id: user_id}
    ErrorHandler.with_error_handling(fn ->
      case Repo.get(Transaction, id) do
        nil -> {:error, :not_found}
        transaction ->
          if transaction.user_id == user_id do
            {:ok, transaction}
          else
            {:error, :forbidden}
          end
      end
    end, context)
  end

  @doc """
  Create a new transaction.
  """
  def create_transaction(attrs) do
    context = %{action: :create_transaction, attrs: attrs}
    ErrorHandler.with_error_handling(fn ->
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()
    end, context)
  end

  @doc """
  Update a transaction.
  """
  def update_transaction(transaction, attrs) do
    context = %{action: :update_transaction, transaction: transaction, attrs: attrs}
    ErrorHandler.with_error_handling(fn ->
      transaction
      |> Transaction.changeset(attrs)
      |> Repo.update()
    end, context)
  end

  @doc """
  Delete a transaction.
  """
  def delete_transaction(transaction) do
    context = %{action: :delete_transaction, transaction: transaction}
    ErrorHandler.with_error_handling(fn ->
      Repo.delete(transaction)
    end, context)
  end

  @doc """
  List transactions for a specific account.
  """
  def list_transactions_for_account(account_id) do
    context = %{action: :list_transactions_for_account, account_id: account_id}
    ErrorHandler.with_error_handling(fn ->
      Transaction
      |> where([t], t.account_id == ^account_id)
      |> preload([:user_bank_account, :user])
      |> order_by([t], desc: t.posted_at)
      |> Repo.all()
    end, context)
  end

  @doc """
  List transactions by date range.
  """
  def list_transactions_by_date_range(start_date, end_date) do
    context = %{action: :list_transactions_by_date_range, start_date: start_date, end_date: end_date}
    ErrorHandler.with_error_handling(fn ->
      Transaction
      |> where([t], t.posted_at >= ^start_date and t.posted_at <= ^end_date)
      |> order_by([t], desc: t.posted_at)
      |> Repo.all()
    end, context)
  end

  @doc """
  Get transaction with preloads.
  """
  def get_transaction_with_preloads(id, preloads) do
    context = %{action: :get_transaction_with_preloads, id: id, preloads: preloads}
    ErrorHandler.with_error_handling(fn ->
      Transaction
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    end, context)
  end

  @doc """
  Get transaction summary for account.
  """
  def get_transaction_summary_for_account(account_id) do
    context = %{action: :get_transaction_summary_for_account, account_id: account_id}
    ErrorHandler.with_error_handling(fn ->
      # Get total credits
      total_credits = Repo.aggregate(
        from(t in Transaction, where: t.account_id == ^account_id and t.direction == "CREDIT"),
        :sum,
        :amount
      ) || Decimal.new(0)

      # Get total debits
      total_debits = Repo.aggregate(
        from(t in Transaction, where: t.account_id == ^account_id and t.direction == "DEBIT"),
        :sum,
        :amount
      ) || Decimal.new(0)

      # Get transaction count
      transaction_count = Repo.aggregate(
        from(t in Transaction, where: t.account_id == ^account_id),
        :count
      )

      {:ok, %{
        total_credits: total_credits,
        total_debits: total_debits,
        net_amount: Decimal.sub(total_credits, total_debits),
        transaction_count: transaction_count
      }}
    end, context)
  end

  # ============================================================================
  # WORKER FUNCTIONS
  # ============================================================================

  @doc """
  Synchronize a bank login by id (used by BankSyncWorker).
  """
  def sync_login(login_id) do
    context = %{action: :sync_login, login_id: login_id}
    ErrorHandler.with_error_handling(fn ->
      login =
        UserBankLogin
        |> Repo.get!(login_id)
        |> Repo.preload(bank_branch: :bank)

        case get_integration_module(login.bank_branch.bank.integration_module) do
          {:ok, integration_mod} ->
            # Check if access token is valid and refresh if needed
            with {:ok, valid_login} <- ensure_valid_tokens(login, integration_mod),
                 {:ok, accounts} <- integration_mod.fetch_accounts(%{access_token: valid_login.access_token}) do
              require Logger
              Logger.info("Fetched accounts for login #{login_id}: #{length(accounts)} accounts")

              # Process and store the accounts
              Repo.transaction(fn ->
                Enum.each(accounts, fn account_data ->
                  # Map external account data to our schema
                  account_attrs = %{
                    user_bank_login_id: login.id,
                    user_id: login.user_id,
                    currency: account_data["currency"] || "USD",
                    account_type: account_data["type"] || "CHECKING",
                    balance: Decimal.new(account_data["balance"] || "0"),
                    last_four: account_data["last4"] || "",
                    account_name: account_data["name"] || "Account",
                    status: "ACTIVE",
                    external_account_id: account_data["id"]
                  }

                  # Create or update the account
                  case Repo.get_by(UserBankAccount, external_account_id: account_data["id"]) do
                    nil ->
                      # Create new account
                      %UserBankAccount{}
                      |> UserBankAccount.changeset(account_attrs)
                      |> Repo.insert!()
                    existing_account ->
                      # Update existing account
                      existing_account
                      |> UserBankAccount.changeset(account_attrs)
                      |> Repo.update!()
                  end
                end)

                # Update login status and last_sync_at
                login
                |> Ecto.Changeset.change(%{
                  status: "ACTIVE",
                  last_sync_at: DateTime.utc_now()
                })
                |> Repo.update!()
              end)

              :ok
            else
              {:error, reason} ->
              # Update login status to ERROR
              login
              |> Ecto.Changeset.change(%{
                status: "ERROR",
                last_sync_at: DateTime.utc_now()
              })
              |> Repo.update!()

              {:error, "Failed to fetch accounts: #{inspect(reason)}"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Process a payment with comprehensive business logic and error handling.
  """
  def process_payment(payment_id) do
    context = %{action: :process_payment, payment_id: payment_id}
    ErrorHandler.with_error_handling(fn ->
      Repo.transaction(fn ->
        payment = Repo.get!(UserPayment, payment_id)

        # Validate payment status
        if payment.status != "PENDING" do
          Repo.rollback(ErrorHandler.business_error(:conflict, "Payment has already been processed", :already_processed, %{payment_id: payment.id, status: payment.status}))
        end

        # Get the account to update balance
        account = Repo.get!(UserBankAccount, payment.user_bank_account_id)

        # Validate account status
        if account.status != "ACTIVE" do
          Repo.rollback(ErrorHandler.business_error(:account_inactive, %{account_id: account.id, status: account.status}))
        end

        # Calculate new balance based on payment direction
        new_balance = case payment.direction do
          "CREDIT" -> Decimal.add(account.balance, payment.amount)
          "DEBIT" -> Decimal.sub(account.balance, payment.amount)
          _ -> Repo.rollback(ErrorHandler.business_error(:validation_error, "Invalid payment direction", :invalid_direction, %{payment_id: payment.id, direction: payment.direction}))
        end

        # Validate sufficient funds for debit transactions
        if payment.direction == "DEBIT" and Decimal.lt?(account.balance, payment.amount) do
          Repo.rollback(ErrorHandler.business_error(:insufficient_funds, %{account_id: account.id, available: account.balance, requested: payment.amount}))
        end

        # Validate final balance is not negative (except for credit accounts)
        if Decimal.lt?(new_balance, Decimal.new(0)) and account.account_type != "CREDIT" do
          Repo.rollback(ErrorHandler.business_error(:insufficient_funds, %{account_id: account.id, available: account.balance, requested: payment.amount}))
        end

        # Get user_id from the account
        account_with_user = Repo.preload(account, user_bank_login: :user)
        user_id = account_with_user.user_bank_login.user_id

        txn_attrs = %{
          account_id: payment.user_bank_account_id,
          user_id: user_id,
          amount: payment.amount,
          description: payment.description || "Payment",
          posted_at: DateTime.utc_now(),
          direction: payment.direction
        }

        case create_transaction(txn_attrs) do
          {:ok, txn} ->
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

  # Private helper functions for workers

  defp ensure_valid_tokens(login, integration_mod) do
    case UserBankLogin.token_valid?(login) do
      true ->
        {:ok, login}
      false ->
        case UserBankLogin.needs_token_refresh?(login) do
          true ->
            refresh_oauth2_tokens(login, integration_mod)
          false ->
            {:error, :token_expired}
        end
    end
  end

  defp refresh_oauth2_tokens(login, integration_mod) do
    case integration_mod.refresh_token(%{refresh_token: login.refresh_token}) do
      {:ok, %{access_token: new_access_token, refresh_token: new_refresh_token}} ->
        # Update login with new tokens
        expires_at = DateTime.add(DateTime.utc_now(), 3600, :second) # 1 hour from now

        token_attrs = %{
          access_token: new_access_token,
          refresh_token: new_refresh_token,
          token_expires_at: expires_at
        }

        case UserBankLogin.token_changeset(login, token_attrs) |> Repo.update() do
          {:ok, updated_login} -> {:ok, updated_login}
          {:error, changeset} -> {:error, changeset}
        end
      {:error, reason} ->
        # Mark login as error if refresh fails
        UserBankLogin.update_changeset(login, %{status: "ERROR"}) |> Repo.update()
        {:error, reason}
    end
  end

  defp get_integration_module(integration_module_string) do
    case integration_module_string do
      nil ->
        {:error, :missing_integration_module}
      module_string when is_binary(module_string) ->
        try do
          module_atom = String.to_existing_atom(module_string)
          # Verify the module exists and implements the BankApiClient behaviour
          if Code.ensure_loaded?(module_atom) and function_exported?(module_atom, :__behaviour__, 1) do
            behaviours = module_atom.__behaviour__(:callbacks)
            if LedgerBankApi.Banking.BankApiClient in behaviours do
              {:ok, module_atom}
            else
              {:error, :invalid_integration_module}
            end
          else
            {:error, :invalid_integration_module}
          end
        rescue
          ArgumentError ->
            {:error, :invalid_integration_module}
        end
      _ ->
        {:error, :invalid_integration_module_type}
    end
  end

end

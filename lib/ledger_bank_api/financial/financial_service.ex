defmodule LedgerBankApi.Financial.FinancialService do
  @moduledoc """
  Financial service module for handling financial operations.

  This module provides business logic for financial operations including
  bank synchronization, payment processing, and account management.
  """

  @behaviour LedgerBankApi.Financial.FinancialServiceBehaviour

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Core.ErrorHandler
  alias LedgerBankApi.Financial.Schemas.{
    Bank, BankBranch, UserBankAccount, UserBankLogin, Transaction, UserPayment
  }

  # ============================================================================
  # BANK OPERATIONS
  # ============================================================================

  @doc """
  Get a bank by ID.
  """
  def get_bank(id) do
    case Repo.get(Bank, id) do
      nil -> {:error, ErrorHandler.business_error(:bank_not_found, %{resource: "bank", id: id, source: "financial_service"})}
      bank -> {:ok, bank}
    end
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
      nil -> {:error, ErrorHandler.business_error(:account_not_found, %{resource: "bank_branch", id: id, source: "financial_service"})}
      branch -> {:ok, branch}
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
    case Repo.get(UserBankAccount, id) do
      nil -> {:error, ErrorHandler.business_error(:account_not_found, %{resource: "user_bank_account", id: id, source: "financial_service"})}
      account -> {:ok, account}
    end
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
    |> UserBankAccount.balance_changeset(%{balance: new_balance, last_sync_at: DateTime.utc_now()})
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
    case Repo.get(UserBankLogin, id) do
      nil -> {:error, ErrorHandler.business_error(:account_not_found, %{resource: "user_bank_login", id: id, source: "financial_service"})}
      login -> {:ok, login}
    end
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
    case Repo.get(Transaction, id) do
      nil -> {:error, ErrorHandler.business_error(:account_not_found, %{resource: "transaction", id: id, source: "financial_service"})}
      transaction -> {:ok, transaction}
    end
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
    case Repo.get(UserPayment, payment_id) do
      nil -> {:error, ErrorHandler.business_error(:payment_not_found, %{resource: "payment", id: payment_id, source: "financial_service"})}
      payment -> {:ok, payment}
    end
  end

  @doc """
  List user payments for a user.
  """
  def list_user_payments(user_id, opts \\ []) do
    UserPayment
    |> where([up], up.user_id == ^user_id)
    |> apply_payment_filters(opts[:filters])
    |> apply_payment_sorting(opts[:sort])
    |> apply_payment_pagination(opts[:pagination])
    |> Repo.all()
  end

  @doc """
  Create a new user payment.
  """
  def create_user_payment(attrs) do
    %UserPayment{}
    |> UserPayment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Process a user payment.
  """
  @impl true
  def process_payment(payment_id) do
    case get_user_payment(payment_id) do
      {:ok, payment} ->
        # Simple payment processing logic
        # In a real implementation, this would integrate with payment providers
        case payment.status do
          "PENDING" ->
            # Simulate payment processing
            payment
            |> UserPayment.changeset(%{status: "COMPLETED", posted_at: DateTime.utc_now()})
            |> Repo.update()
          _ ->
            {:error, ErrorHandler.business_error(:already_processed, %{payment_id: payment_id, source: "financial_service"})}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  # ============================================================================
  # BANK SYNCHRONIZATION
  # ============================================================================


  @doc """
  Synchronizes bank login data with external bank API.
  """
  @impl true
  def sync_login(login_id) do
    case get_user_bank_login(login_id) do
      {:ok, login} ->
        # Simple sync logic - in real implementation, this would call external APIs
        # For now, just update the last_sync_at timestamp
        login
        |> UserBankLogin.update_changeset(%{last_sync_at: DateTime.utc_now()})
        |> Repo.update()
        |> case do
          {:ok, _updated_login} ->
            {:ok, %{status: "synced", login_id: login_id, synced_at: DateTime.utc_now()}}
          {:error, changeset} ->
            {:error, changeset}
        end
      {:error, error} ->
        {:error, error}
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
        _ ->
          acc
      end
    end)
  end

  defp apply_payment_sorting(query, nil), do: query
  defp apply_payment_sorting(query, []), do: query
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

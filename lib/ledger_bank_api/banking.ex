defmodule LedgerBankApi.Banking do
  @moduledoc """
  The Banking context - real banking API structure.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo

  alias LedgerBankApi.Banking.{
    Bank, BankBranch, UserBankLogin, UserBankAccount, UserPayment, Transaction
  }
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Banking.Pagination

  # --- Bank Functions ---
  def list_banks, do: Repo.all(Bank)
  def get_bank!(id), do: Repo.get!(Bank, id)
  def create_bank(attrs \\ %{}), do: %Bank{} |> Bank.changeset(attrs) |> Repo.insert()

  # --- Bank Branch Functions ---
  def list_bank_branches, do: Repo.all(BankBranch)
  def get_bank_branch!(id), do: Repo.get!(BankBranch, id)
  def create_bank_branch(attrs \\ %{}), do: %BankBranch{} |> BankBranch.changeset(attrs) |> Repo.insert()

  # --- User Bank Login Functions ---
  def list_user_bank_logins, do: Repo.all(UserBankLogin)
  def get_user_bank_login!(id), do: Repo.get!(UserBankLogin, id)
  def create_user_bank_login(attrs \\ %{}), do: %UserBankLogin{} |> UserBankLogin.changeset(attrs) |> Repo.insert()
  def update_user_bank_login(%UserBankLogin{} = login, attrs), do: login |> UserBankLogin.changeset(attrs) |> Repo.update()

  # --- User Bank Account Functions ---
  @doc """
  Returns all user bank accounts with all associations preloaded.
  """
  def list_user_bank_accounts do
    Repo.all(from a in UserBankAccount, preload: [user_bank_login: [bank_branch: :bank]])
  end

  def get_user_bank_account!(id), do: Repo.get!(UserBankAccount, id) |> Repo.preload(user_bank_login: [bank_branch: :bank])
  def get_user_bank_account_by_external_id(external_id), do: Repo.get_by(UserBankAccount, external_account_id: external_id)
  def create_user_bank_account(attrs \\ %{}), do: %UserBankAccount{} |> UserBankAccount.changeset(attrs) |> Repo.insert()
  def update_user_bank_account(%UserBankAccount{} = account, attrs), do: account |> UserBankAccount.changeset(attrs) |> Repo.update()

  # --- User Payments ---
  def list_payments_for_user_bank_account(account_id) do
    UserPayment
    |> where(user_bank_account_id: ^account_id)
    |> order_by([p], desc: p.posted_at)
    |> Repo.all()
  end

  def list_user_payments(opts \\ []) do
    UserPayment
    |> maybe_filter_by_status(opts[:status])
    |> maybe_filter_by_user_account(opts[:user_bank_account_id])
    |> Repo.all()
  end

  def get_user_payment!(id), do: Repo.get!(UserPayment, id)
  def create_user_payment(attrs \\ %{}), do: %UserPayment{} |> UserPayment.changeset(attrs) |> Repo.insert()
  def update_user_payment(%UserPayment{} = payment, attrs), do: payment |> UserPayment.changeset(attrs) |> Repo.update()
  def list_pending_payments, do: UserPayment |> where(status: "PENDING") |> Repo.all()

  # --- Transactions ---
  def list_transactions_for_user_bank_account(account_id, opts \\ []) do
    pagination_params = Keyword.get(opts, :pagination, %{page: 1, page_size: 20})
    filter_params = Keyword.get(opts, :filters, %{})
    sort_params = Keyword.get(opts, :sorting, %{sort_by: "posted_at", sort_order: "desc"})

    Transaction
    |> where(account_id: ^account_id)
    |> apply_filters(filter_params)
    |> apply_sorting(sort_params)
    |> Pagination.execute_paginated_query(pagination_params)
  end

  defp apply_filters(query, %{date_from: from, date_to: to} = filters) when not is_nil(from) and not is_nil(to) do
    query
    |> where([t], t.posted_at >= ^from and t.posted_at <= ^to)
    |> apply_filters(Map.delete(filters, :date_from) |> Map.delete(:date_to))
  end

  defp apply_filters(query, %{date_from: from} = filters) when not is_nil(from) do
    query
    |> where([t], t.posted_at >= ^from)
    |> apply_filters(Map.delete(filters, :date_from))
  end

  defp apply_filters(query, %{date_to: to} = filters) when not is_nil(to) do
    query
    |> where([t], t.posted_at <= ^to)
    |> apply_filters(Map.delete(filters, :date_to))
  end

  defp apply_filters(query, %{amount_min: min} = filters) when not is_nil(min) do
    query
    |> where([t], t.amount >= ^min)
    |> apply_filters(Map.delete(filters, :amount_min))
  end

  defp apply_filters(query, %{amount_max: max} = filters) when not is_nil(max) do
    query
    |> where([t], t.amount <= ^max)
    |> apply_filters(Map.delete(filters, :amount_max))
  end

  defp apply_filters(query, %{description: desc} = filters) when not is_nil(desc) do
    query
    |> where([t], ilike(t.description, ^"%#{desc}%"))
    |> apply_filters(Map.delete(filters, :description))
  end

  defp apply_filters(query, _filters), do: query

  defp apply_sorting(query, %{sort_by: field, sort_order: order}) do
    direction = if order == "asc", do: :asc, else: :desc

    case field do
      "posted_at" -> order_by(query, [t], [{^direction, t.posted_at}])
      "amount" -> order_by(query, [t], [{^direction, t.amount}])
      "description" -> order_by(query, [t], [{^direction, t.description}])
      _ -> order_by(query, [t], [{^direction, t.posted_at}])
    end
  end

  def get_transaction!(id), do: Repo.get!(Transaction, id)
  def create_transaction(attrs \\ %{}), do: %Transaction{} |> Transaction.changeset(attrs) |> Repo.insert()
  def update_transaction(%Transaction{} = transaction, attrs), do: transaction |> Transaction.changeset(attrs) |> Repo.update()
  def delete_transaction(%Transaction{} = transaction), do: Repo.delete(transaction)

  # --- User Functions ---
  def get_user!(id), do: Repo.get!(User, id)
  def create_user(attrs \\ %{}), do: %User{} |> User.changeset(attrs) |> Repo.insert()

  # --- Private Helpers ---
  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, status: ^status)
  defp maybe_filter_by_user_account(query, nil), do: query
  defp maybe_filter_by_user_account(query, account_id), do: where(query, user_bank_account_id: ^account_id)
end

defmodule LedgerBankApiWeb.BankingControllerV2 do
  @moduledoc """
  Optimized banking controller using base controller patterns.
  Provides account management, transactions, and banking operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController
  import LedgerBankApiWeb.JSON.BaseJSON

  alias LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Behaviours.{Paginated, Filterable, Sortable, ErrorHandler}

  # Implement behaviours for pagination, filtering, and sorting
  @behaviour Paginated
  @behaviour Filterable
  @behaviour Sortable
  @behaviour ErrorHandler

  # Standard CRUD operations for user bank accounts
  crud_operations(
    Context,
    LedgerBankApi.Banking.Schemas.UserBankAccount,
    "user_bank_account",
    user_filter: &filter_accounts_by_user/2,
    authorization: :user_ownership
  )

  # Custom banking actions
  action :transactions do
    account = Context.get_user_bank_account!(params["id"])
    # Ensure user can only access their own accounts
    if account.user_bank_login.user_id != user_id do
      raise "Unauthorized access to account"
    end

    # Handle pagination, filtering, and sorting
    with {:ok, pagination_params} <- validate_pagination_params(extract_pagination_params(params)),
         {:ok, filter_params} <- validate_filter_params(extract_filter_params(params)),
         {:ok, sort_params} <- validate_sort_params(extract_sort_params(params), ["posted_at", "amount", "description"]) do

      transactions = Context.list_transactions_for_user_bank_account(account.id)
      %{transactions: transactions, account: account}
    else
      {:error, reason} ->
        raise "Validation error: #{reason}"
    end
  end

  action :balances do
    account = Context.get_user_bank_account!(params["id"])
    # Ensure user can only access their own accounts
    if account.user_bank_login.user_id != user_id do
      raise "Unauthorized access to account"
    end
    %{account: account}
  end

  action :payments do
    account = Context.get_user_bank_account!(params["id"])
    # Ensure user can only access their own accounts
    if account.user_bank_login.user_id != user_id do
      raise "Unauthorized access to account"
    end

    payments = Context.list_payments_for_user_bank_account(account.id)
    %{payments: payments, account: account}
  end

  async_action :sync do
    # Verify the login belongs to the user
    login = Context.get_user_bank_login!(params["login_id"])
    if login.user_id != user_id do
      raise "Unauthorized access to bank login"
    end

    # Queue the sync job
    Oban.insert(%Oban.Job{
      queue: :banking,
      worker: "LedgerBankApi.Workers.BankSyncWorker",
      args: %{"login_id" => params["login_id"]}
    })

    format_job_response("bank_sync", params["login_id"])
  end

  # Behaviour implementations
  @impl Paginated
  def extract_pagination_params(params), do: Paginated.extract_pagination_params(params)
  @impl Paginated
  def validate_pagination_params(params), do: Paginated.validate_pagination_params(params)
  @impl Paginated
  def handle_paginated_data(data, pagination, opts), do: {data, pagination, opts}

  @impl Filterable
  def extract_filter_params(params), do: Filterable.extract_filter_params(params)
  @impl Filterable
  def validate_filter_params(params), do: Filterable.validate_filter_params(params)
  @impl Filterable
  def handle_filtered_data(data, filters, opts), do: {data, filters, opts}

  @impl Sortable
  def extract_sort_params(params), do: Sortable.extract_sort_params(params)
  @impl Sortable
  def validate_sort_params(params, allowed_fields), do: Sortable.validate_sort_params(params, allowed_fields)
  @impl Sortable
  def handle_sorted_data(data, sorting, opts), do: {data, sorting, opts}

  @impl ErrorHandler
  def handle_error(error, context, _opts) do
    case error do
      %{error: error_details} ->
        status_code = ErrorHandler.error_types()[error_details.type] || 500
        {status_code, error}
      _ ->
        error_response = ErrorHandler.handle_common_error(error, context)
        status_code = ErrorHandler.error_types()[error_response.error.type] || 500
        {status_code, error_response}
    end
  end

  @impl ErrorHandler
  def format_error(error, opts), do: ErrorHandler.handle_common_error(error, opts)
  @impl ErrorHandler
  def log_error(error, opts), do: ErrorHandler.log_error(error, opts)

  # Private helper functions

  defp filter_accounts_by_user(accounts, user_id) do
    Enum.filter(accounts, fn account ->
      account.user_bank_login.user_id == user_id
    end)
  end
end

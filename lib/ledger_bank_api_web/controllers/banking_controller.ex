defmodule LedgerBankApiWeb.BankingController do
  use LedgerBankApiWeb, :controller
  require Logger

  @behaviour LedgerBankApi.Behaviours.Paginated
  @behaviour LedgerBankApi.Behaviours.Filterable
  @behaviour LedgerBankApi.Behaviours.Sortable
  @behaviour LedgerBankApi.Behaviours.ErrorHandler

  alias LedgerBankApi.Banking
  alias LedgerBankApi.Behaviours.{Paginated, Filterable, Sortable, ErrorHandler}

  @impl Paginated
  def extract_pagination_params(params) do
    Paginated.extract_pagination_params(params)
  end

  @impl Paginated
  def validate_pagination_params(params) do
    Paginated.validate_pagination_params(params)
  end

  @impl Filterable
  def extract_filter_params(params) do
    Filterable.extract_filter_params(params)
  end

  @impl Filterable
  def validate_filter_params(params) do
    Filterable.validate_filter_params(params)
  end

  @impl Filterable
  def handle_filtered_data(data, filters, opts) do
    {data, filters, opts}
  end

  @impl Paginated
  def handle_paginated_data(data, pagination, opts) do
    {data, pagination, opts}
  end

  @impl Sortable
  def extract_sort_params(params) do
    Sortable.extract_sort_params(params)
  end

  @impl Sortable
  def validate_sort_params(params, allowed_fields) do
    Sortable.validate_sort_params(params, allowed_fields)
  end

  @impl Sortable
  def handle_sorted_data(data, sorting, opts) do
    {data, sorting, opts}
  end

  @impl ErrorHandler
  def handle_error(error, context, _opts) do
    case error do
      %{error: error_details} ->
        # Already formatted error response
        status_code = ErrorHandler.error_types()[error_details.type] || 500
        {status_code, error}
      _ ->
        # Raw error, format it
        error_response = ErrorHandler.handle_common_error(error, context)
        status_code = ErrorHandler.error_types()[error_response.error.type] || 500
        {status_code, error_response}
    end
  end

  @impl ErrorHandler
  def format_error(error, opts) do
    ErrorHandler.handle_common_error(error, opts)
  end

  @impl ErrorHandler
  def log_error(error, opts) do
    ErrorHandler.log_error(error, opts)
  end

  @doc """
  List all bank accounts (public, no user filtering).
  """
  def index(conn, _params) do
    case ErrorHandler.with_error_handling(fn -> Banking.list_user_bank_accounts() end, %{action: :list_accounts}) do
      {:ok, response} -> render(conn, :index, accounts: response.data)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, %{action: :list_accounts}, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Get account details (public).
  """
  def show(conn, %{"id" => account_id}) do
    case ErrorHandler.with_error_handling(fn -> Banking.get_user_bank_account!(account_id) end, %{action: :get_account, account_id: account_id}) do
      {:ok, response} -> render(conn, :show, account: response.data)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, %{action: :get_account, account_id: account_id}, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Get account transactions (public) with pagination, filtering, and sorting.
  """
  def transactions(conn, %{"id" => account_id} = params) do
    context = %{action: :get_transactions, account_id: account_id}

    case ErrorHandler.with_error_handling(fn ->
      with {:ok, pagination_params} <- validate_pagination_params(extract_pagination_params(params)),
           {:ok, filter_params} <- validate_filter_params(extract_filter_params(params)),
           {:ok, sort_params} <- validate_sort_params(extract_sort_params(params), ["posted_at", "amount", "description"]),
           account when not is_nil(account) <- Banking.get_user_bank_account!(account_id),
           result <- Banking.list_transactions_for_user_bank_account(
             account_id,
             pagination: pagination_params,
             filters: filter_params,
             sorting: sort_params
           ) do
        {account, result}
      else
        nil -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end, context) do
      {:ok, response} ->
        {account, result} = response.data
        render(conn, :transactions, result: result, account: account)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Get account balances (public).
  """
  def balances(conn, %{"id" => account_id}) do
    case ErrorHandler.with_error_handling(fn -> Banking.get_user_bank_account!(account_id) end, %{action: :get_balances, account_id: account_id}) do
      {:ok, response} -> render(conn, :balances, account: response.data)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, %{action: :get_balances, account_id: account_id}, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Get account payments (public).
  """
  def payments(conn, %{"id" => account_id}) do
    case ErrorHandler.with_error_handling(fn ->
      account = Banking.get_user_bank_account!(account_id)
      payments = Banking.list_payments_for_user_bank_account(account_id)
      {account, payments}
    end, %{action: :get_payments, account_id: account_id}) do
      {:ok, response} ->
        {account, payments} = response.data
        render(conn, :payments, payments: payments, account: account)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, %{action: :get_payments, account_id: account_id}, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Sync bank data for a specific login (public).
  """
  def sync(conn, %{"login_id" => login_id}) do
    case ErrorHandler.with_error_handling(fn ->
      Oban.insert(%Oban.Job{
        queue: :banking,
        worker: "LedgerBankApi.Workers.BankSyncWorker",
        args: %{"user_bank_login_id" => login_id}
      })

      %{
        message: "Bank sync initiated",
        login_id: login_id,
        status: "queued"
      }
    end, %{action: :sync_bank, login_id: login_id}) do
      {:ok, response} ->
        conn |> put_status(202) |> json(response.data)
      {:error, error_response} ->
        {status, response} = handle_error(error_response, %{action: :sync_bank, login_id: login_id}, [])
        conn |> put_status(status) |> json(response)
    end
  end
end

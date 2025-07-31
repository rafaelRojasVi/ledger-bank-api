defmodule LedgerBankApiWeb.BankingController do
  @moduledoc """
  Optimized banking controller using enhanced base controller patterns.
  Provides account management, transactions, and banking operations with advanced querying.
  """

  use LedgerBankApiWeb, :controller

  import LedgerBankApiWeb.ResponseHelpers
  require LedgerBankApi.Helpers.AuthorizationHelpers

  alias LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Behaviours.{Paginated, Filterable, Sortable, ErrorHandler}
  alias LedgerBankApi.Workers.BankSyncWorker



  # Custom CRUD operations for user bank accounts with indirect user relationship
  def index(conn, params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :list_user_bank_accounts, user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
      # Handle pagination, filtering, and sorting
      with {:ok, pagination_params} <- Paginated.validate_pagination_params(Paginated.extract_pagination_params(params)),
           {:ok, filter_params} <- Filterable.validate_filter_params(Filterable.extract_filter_params(params)) do

        # Extract and validate sort params with correct default for user bank accounts
        sort_params = %{
          sort_by: Map.get(params, "sort_by", "created_at"),
          sort_order: Map.get(params, "sort_order", "desc")
        }

        with {:ok, validated_sort_params} <- Sortable.validate_sort_params(sort_params, ["balance", "account_name", "created_at", "updated_at"]) do
          accounts = Context.list_user_bank_accounts_with_filters(pagination_params, filter_params, validated_sort_params, user_id, :user_id)

          # Preload associations needed for JSON rendering
          LedgerBankApi.Repo.preload(accounts, [user_bank_login: [bank_branch: :bank]])
        else
          {:error, reason} ->
            {:error, %{type: :validation_error, message: reason}}
        end
      else
        {:error, reason} ->
          {:error, %{type: :validation_error, message: reason}}
      end
    end, context) do
      {:ok, response} ->
        render(conn, :index, %{user_bank_account: response.data})
      {:error, error_response} ->
        handle_error_response(conn, error_response, context)
    end
  end

  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :get_user_bank_account, user_id: user_id, resource_id: id}

    case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          # Get account first, then check authorization
          account = Context.get_user_bank_account_with_preloads!(id, [user_bank_login: [bank_branch: :bank]])

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            account
          end
      end
    end, context) do
      {:ok, response} ->
        render(conn, :show, %{account: response.data})
      {:error, error_response} ->
        handle_error_response(conn, error_response, context)
    end
  end

  # Custom banking actions
  def transactions(conn, %{"id" => account_id} = params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :transactions, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(account_id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          account = Context.get_user_bank_account_with_preloads!(account_id, [user_bank_login: [bank_branch: :bank]])

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            # Handle pagination, filtering, and sorting
            with {:ok, pagination_params} <- Paginated.validate_pagination_params(Paginated.extract_pagination_params(params)),
                 {:ok, filter_params} <- Filterable.validate_filter_params(Filterable.extract_filter_params(params)),
                 {:ok, sort_params} <- Sortable.validate_sort_params(Sortable.extract_sort_params(params), ["posted_at", "amount", "description"]) do

              transactions = Context.list_transactions_with_filters(pagination_params, filter_params, sort_params, account_id, "account_id")
              %{transactions: transactions, account: account}
            else
              {:error, reason} ->
                {:error, %{type: :validation_error, message: reason}}
            end
          end
      end
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> render("transactions.json", transactions: response.data.transactions, account: response.data.account)
      {:error, error_response} ->
        handle_error_response(conn, error_response, context)
    end
  end

  def balances(conn, %{"id" => account_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :balances, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(account_id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          account = Context.get_user_bank_account_with_preloads!(account_id, [user_bank_login: [bank_branch: :bank]])

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            %{account: account}
          end
      end
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> render("balances.json", account: response.data.account)
      {:error, error_response} ->
        handle_error_response(conn, error_response, context)
    end
  end

  def payments(conn, %{"id" => account_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :payments, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(account_id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          account = Context.get_user_bank_account_with_preloads!(account_id, [user_bank_login: [bank_branch: :bank]])

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            payments = Context.list_payments_for_user_bank_account(account_id)

            %{payments: payments, account: account}
          end
      end
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> render("payments.json", payments: response.data.payments, account: response.data.account)
      {:error, error_response} ->
        handle_error_response(conn, error_response, context)
    end
  end

    def sync(conn, %{"login_id" => login_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :sync, user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(login_id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          # Verify the login belongs to the user
          login = Context.get_user_bank_login_with_preloads!(login_id, [:user])

          if login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to bank login"}}
          else
            # Queue the sync job
            job = BankSyncWorker.new(%{"login_id" => login_id}, queue: :banking)

            case Oban.insert(job) do
              {:ok, _inserted_job} -> job_response("bank_sync", login_id)
              {:error, reason} -> {:error, reason}
            end
          end
      end
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(202)
        |> json(response.data)
             {:error, error_response} ->
         handle_error_response(conn, error_response, context)
     end
   end

  # Error handling helper
  defp handle_error_response(conn, error_response, context) do
    response = ErrorHandler.handle_common_error(error_response, context)
    status_code = get_error_status_code(response)
    conn |> put_status(status_code) |> json(response)
  end

  defp get_error_status_code(%{error: %{type: type}}) do
    case type do
      :validation_error -> 400
      :not_found -> 404
      :unauthorized -> 401
      :forbidden -> 403
      :conflict -> 409
      :unprocessable_entity -> 422
      _ -> 500
    end
  end
  defp get_error_status_code(_), do: 500
end

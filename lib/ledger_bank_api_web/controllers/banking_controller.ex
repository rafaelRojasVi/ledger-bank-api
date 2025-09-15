defmodule LedgerBankApiWeb.BankingController do
  @moduledoc """
  Optimized banking controller using enhanced base controller patterns.
  Provides account management, transactions, and banking operations with advanced querying.
  """

  use LedgerBankApiWeb, :controller

  import LedgerBankApiWeb.ResponseHelpers

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  alias LedgerBankApi.Workers.BankSyncWorker



  # Custom CRUD operations for user bank accounts with indirect user relationship
  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :list_user_bank_accounts, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      accounts = LedgerBankApi.Banking.list_user_bank_accounts_for_user(user_id)
      # Preload associations needed for JSON rendering
      LedgerBankApi.Repo.preload(accounts, [user_bank_login: [bank_branch: :bank]])
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
          {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(id)

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
  def transactions(conn, %{"id" => account_id} = _params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :transactions, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      # Validate UUID format first
      case Ecto.UUID.cast(account_id) do
        :error -> {:error, %{type: :not_found, message: "Invalid UUID format"}}
        {:ok, _uuid} ->
          {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(account_id)

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            transactions = LedgerBankApi.Banking.list_transactions_for_account(account_id)
            %{transactions: transactions, account: account}
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
          {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(account_id)

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
          {:ok, account} = LedgerBankApi.Banking.get_user_bank_account(account_id)

          # Ensure user can only access their own accounts
          if account.user_bank_login.user_id != user_id do
            {:error, %{type: :forbidden, message: "Unauthorized access to account"}}
          else
            payments = LedgerBankApi.Banking.list_user_payments_for_account(account_id)

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
          {:ok, login} = LedgerBankApi.Banking.get_user_bank_login(login_id)

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

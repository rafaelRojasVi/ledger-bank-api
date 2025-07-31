defmodule LedgerBankApiWeb.UserBankLoginsController do
  @moduledoc """
  Optimized user bank logins controller using base controller patterns.
  Provides bank login management and sync operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController, except: [action: 2]
  import LedgerBankApiWeb.ResponseHelpers
  require LedgerBankApi.Helpers.AuthorizationHelpers

  alias LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  # Standard CRUD operations for user bank logins
  crud_operations(
    Context,
    LedgerBankApi.Banking.Schemas.UserBankLogin,
    "user_bank_login",
    user_filter: :user_id,
    user_field: :user_id,
    authorization: :user_ownership
  )

  # Custom sync action
  def sync(conn, %{"id" => login_id}) do
    user_id = conn.assigns.current_user_id
    context = %{action: :sync, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      login = Context.get_user_bank_login!(login_id)
      # Ensure user can only sync their own logins
      if login.user_id != user_id do
        raise "Unauthorized access to bank login"
      end

      # Queue the sync job
      Oban.insert(%Oban.Job{
        queue: :banking,
        worker: "LedgerBankApi.Workers.BankSyncWorker",
        args: %{"login_id" => login_id}
      })

      job_response("bank_sync", login_id)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(202)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end
end

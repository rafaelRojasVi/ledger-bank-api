defmodule LedgerBankApiWeb.UserBankLoginsControllerV2 do
  @moduledoc """
  Optimized user bank logins controller using base controller patterns.
  Provides bank login management and sync operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController
  import LedgerBankApiWeb.JSON.BaseJSON

  alias LedgerBankApi.Banking.Context

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
  async_action :sync do
    login = Context.get_user_bank_login!(params["id"])
    # Ensure user can only sync their own logins
    if login.user_id != user_id do
      raise "Unauthorized access to bank login"
    end

    # Queue the sync job
    Oban.insert(%Oban.Job{
      queue: :banking,
      worker: "LedgerBankApi.Workers.BankSyncWorker",
      args: %{"login_id" => params["id"]}
    })

    format_job_response("bank_sync", params["id"])
  end
end

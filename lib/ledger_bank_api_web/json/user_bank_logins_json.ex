defmodule LedgerBankApiWeb.JSON.UserBankLoginJSON do
  @moduledoc """
  JSON formatting for user bank login data.
  """

  @doc """
  Format user bank login data consistently.
  """
  def format(login) do
    %{
      id: login.id,
      username: login.username,
      status: login.status,
      last_sync_at: login.last_sync_at,
      sync_frequency: login.sync_frequency,
      bank_branch: LedgerBankApiWeb.JSON.BankBranchJSON.format(login.bank_branch),
      created_at: login.inserted_at,
      updated_at: login.updated_at
    }
  end
end

defmodule LedgerBankApiWeb.UserBankLoginsJSON do
  @moduledoc """
  Optimized user bank logins JSON view using base JSON patterns.
  Provides standardized response formatting for user bank login endpoints.
  """

  import LedgerBankApiWeb.JSON.BaseJSON

  @doc """
  Renders a list of user bank logins.
  """
  def index(%{user_bank_login: logins}) do
    list_response(logins, :user_bank_login)
  end

  @doc """
  Renders a single user bank login.
  """
  def show(%{user_bank_login: login}) do
    show_response(login, :user_bank_login)
  end
end

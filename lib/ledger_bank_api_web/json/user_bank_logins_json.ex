defmodule LedgerBankApiWeb.UserBankLoginsJSONV2 do
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

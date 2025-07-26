defmodule LedgerBankApiWeb.UsersJSONV2 do
  @moduledoc """
  Optimized users JSON view using base JSON patterns.
  Provides standardized response formatting for user endpoints.
  """

  import LedgerBankApiWeb.JSON.BaseJSON

  @doc """
  Renders a list of users.
  """
  def index(%{user: users}) do
    list_response(users, :user)
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    show_response(user, :user)
  end
end

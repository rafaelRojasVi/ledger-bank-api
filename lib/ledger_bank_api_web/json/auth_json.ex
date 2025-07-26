defmodule LedgerBankApiWeb.AuthJSON do
  @moduledoc """
  Optimized auth JSON view using base JSON patterns.
  Provides standardized response formatting for authentication endpoints.
  """

  import LedgerBankApiWeb.JSON.BaseJSON

  @doc """
  Renders authentication response with tokens.
  """
  def auth_response(user, access_token, refresh_token, message) do
    format_auth_response(user, access_token, refresh_token, message)
  end

  @doc """
  Renders logout response.
  """
  def logout_response do
    format_logout_response()
  end

  @doc """
  Renders profile response.
  """
  def profile_response(user) do
    show_response(user, :user)
  end

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

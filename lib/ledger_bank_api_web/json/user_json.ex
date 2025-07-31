defmodule LedgerBankApiWeb.JSON.UserJSON do
  @moduledoc """
  JSON formatting for user data.
  """

  @doc """
  Format user data consistently across all endpoints.
  """
  def format(user) do
    %{
      id: user.id,
      email: user.email,
      full_name: user.full_name,
      role: user.role,
      status: user.status,
      created_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  @doc """
  Format authentication response with tokens.
  """
  def format_auth_response(user, access_token, refresh_token, message) do
    %{
      data: %{
        user: format(user),
        access_token: access_token,
        refresh_token: refresh_token
      },
      message: message
    }
  end

  @doc """
  Format logout response.
  """
  def format_logout_response do
    %{
      message: "Logout successful",
      data: %{}
    }
  end
end

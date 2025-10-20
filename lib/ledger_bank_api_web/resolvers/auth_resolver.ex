defmodule LedgerBankApiWeb.Resolvers.AuthResolver do
  @moduledoc """
  GraphQL resolvers for authentication operations.
  """

  require Logger

  alias LedgerBankApi.Accounts.AuthService

  def login(%{email: email, password: password}, _resolution) do
    case AuthService.login_user(email, password) do
      {:ok, %{user: user, access_token: access_token, refresh_token: refresh_token}} ->
        {:ok,
         %{
           success: true,
           access_token: access_token,
           refresh_token: refresh_token,
           expires_in: nil,
           user: user,
           errors: []
         }}

      {:error, reason} ->
        {:ok,
         %{
           success: false,
           access_token: nil,
           refresh_token: nil,
           expires_in: nil,
           user: nil,
           errors: [reason]
         }}
    end
  end

  def refresh(%{refresh_token: refresh_token}, _resolution) do
    case AuthService.refresh_access_token(refresh_token) do
      {:ok, %{access_token: access_token, refresh_token: new_refresh_token}} ->
        {:ok,
         %{
           success: true,
           access_token: access_token,
           refresh_token: new_refresh_token,
           expires_in: nil,
           user: nil,
           errors: []
         }}

      {:error, reason} ->
        {:ok,
         %{
           success: false,
           access_token: nil,
           refresh_token: nil,
           expires_in: nil,
           user: nil,
           errors: [reason]
         }}
    end
  end
end

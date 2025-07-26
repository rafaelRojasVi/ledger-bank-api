defmodule LedgerBankApiWeb.AuthControllerV2 do
  @moduledoc """
  Optimized auth controller using base controller patterns.
  Provides authentication and user profile operations.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController
  import LedgerBankApiWeb.JSON.BaseJSON

  alias LedgerBankApi.Users.Context

  @doc """
  Register a new user.
  """
  def register(conn, %{"user" => user_params}) do
    context = %{action: :register, email: user_params["email"]}

    case ErrorHandler.with_error_handling(fn ->
      Context.create_user(user_params)
    end, context) do
      {:ok, response} ->
        user = response.data
        {:ok, access_token} = LedgerBankApi.Auth.JWT.generate_access_token(user)
        {:ok, refresh_token} = LedgerBankApi.Auth.JWT.generate_refresh_token(user)
        {:ok, _db_token} = Context.store_refresh_token(user, refresh_token)

        conn
        |> put_status(201)
        |> json(format_auth_response(user, access_token, refresh_token, "User registered successfully"))

      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Login user with email and password.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    context = %{action: :login, email: email}

    case ErrorHandler.with_error_handling(fn ->
      Context.login_user(email, password)
    end, context) do
      {:ok, response} ->
        {user, access_token, refresh_token} = response.data

        conn
        |> put_status(200)
        |> json(format_auth_response(user, access_token, refresh_token, "Login successful"))

      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    context = %{action: :refresh_token}

    case ErrorHandler.with_error_handling(fn ->
      Context.refresh_tokens(refresh_token)
    end, context) do
      {:ok, response} ->
        {user, new_access_token, new_refresh_token} = response.data

        conn
        |> put_status(200)
        |> json(format_auth_response(user, new_access_token, new_refresh_token, "Tokens refreshed successfully"))

      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Logout user by revoking all refresh tokens.
  """
  def logout(conn, _params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :logout, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      Context.revoke_all_refresh_tokens_for_user(user_id)
    end, context) do
      {:ok, _response} ->
        conn
        |> put_status(200)
        |> json(format_logout_response())

      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  @doc """
  Get current user profile.
  """
  def me(conn, _params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :get_profile, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      Context.get_user!(user_id)
    end, context) do
      {:ok, response} ->
        render(conn, :show, %{user: response.data})
      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end
end

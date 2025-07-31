defmodule LedgerBankApiWeb.AuthController do
  @moduledoc """
  Optimized auth controller using base controller patterns.
  Provides authentication and user profile operations.
  """

  use LedgerBankApiWeb, :controller
  require LedgerBankApiWeb.BaseController

  alias LedgerBankApi.Users.Context
  alias LedgerBankApiWeb.AuthJSON
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

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
        |> json(AuthJSON.auth_response(user, access_token, refresh_token, "User registered successfully"))

      {:error, error_response} ->
        status_code = error_response.error.code
        conn |> put_status(status_code) |> json(error_response)
    end
  end

  def register(conn, _params) do
    context = %{action: :register}
    error_response = ErrorHandler.create_error_response(
      :validation_error,
      "Validation failed",
      %{errors: %{user: ["is required"]}, context: context}
    )
    conn |> put_status(400) |> json(error_response)
  end

  @doc """
  Login user with email and password.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    context = %{action: :login, email: email}

    case Context.login_user(email, password) do
      {:ok, user, access_token, refresh_token} ->
        conn
        |> put_status(200)
        |> json(AuthJSON.auth_response(user, access_token, refresh_token, "Login successful"))

      {:error, :invalid_credentials} ->
        error_response = ErrorHandler.create_error_response(:unauthorized, "Unauthorized access", %{context: context})
        conn |> put_status(401) |> json(error_response)
    end
  end

  def login(conn, _params) do
    context = %{action: :login}
    error_response = ErrorHandler.create_error_response(
      :validation_error,
      "Validation failed",
      %{errors: %{email: ["is required"], password: ["is required"]}, context: context}
    )
    conn |> put_status(400) |> json(error_response)
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    context = %{action: :refresh_token}

    case Context.refresh_tokens(refresh_token) do
      {:ok, user, new_access_token, new_refresh_token} ->
        conn
        |> put_status(200)
        |> json(AuthJSON.auth_response(user, new_access_token, new_refresh_token, "Tokens refreshed successfully"))

      {:error, :invalid_refresh_token} ->
        error_response = ErrorHandler.create_error_response(:unauthorized, "Unauthorized access", %{context: context})
        conn |> put_status(401) |> json(error_response)
    end
  end

  def refresh(conn, _params) do
    context = %{action: :refresh_token}
    error_response = ErrorHandler.create_error_response(
      :validation_error,
      "Validation failed",
      %{errors: %{refresh_token: ["is required"]}, context: context}
    )
    conn |> put_status(400) |> json(error_response)
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
        |> json(AuthJSON.logout_response())

      {:error, error_response} ->
        status_code = error_response.error.code
        conn |> put_status(status_code) |> json(error_response)
    end
  end

  @doc """
  Get current user profile.
  """
  def me(conn, _params) do
    user_id = conn.assigns.current_user_id
    context = %{action: :get_profile, user_id: user_id}

    case ErrorHandler.with_error_handling(fn ->
      Context.get!(user_id)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> json(%{
          data: %{
            user: LedgerBankApiWeb.JSON.UserJSON.format(response.data)
          }
        })
      {:error, error_response} ->
        status_code = error_response.error.code
        conn |> put_status(status_code) |> json(error_response)
    end
  end
end

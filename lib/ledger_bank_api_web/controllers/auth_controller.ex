defmodule LedgerBankApiWeb.Controllers.AuthController do
  @moduledoc """
  Authentication controller handling user login, logout, and token management.

  Uses action fallback for centralized error handling.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Accounts.AuthService
  alias LedgerBankApiWeb.Validation.InputValidator

  action_fallback(LedgerBankApiWeb.FallbackController)

  @doc """
  Login user with email and password.

  POST /api/auth/login
  Body: %{"email" => "user@example.com", "password" => "password123"}
  """
  def login(conn, params) do
    context = build_context(conn, :login)

    validate_and_execute(
      conn,
      context,
      InputValidator.validate_login(params),
      fn validated_params ->
        AuthService.login_user(validated_params.email, validated_params.password)
      end,
      fn %{access_token: access_token, refresh_token: refresh_token, user: user} ->
        handle_auth_success(conn, :login, %{
          access_token: access_token,
          refresh_token: refresh_token,
          user: user
        })
      end
    )
  end

  @doc """
  Refresh access token using refresh token.

  POST /api/auth/refresh
  Body: %{"refresh_token" => "refresh_token_here"}
  """
  def refresh(conn, params) do
    context = build_context(conn, :refresh)

    validate_and_execute(
      conn,
      context,
      InputValidator.validate_refresh_token(params),
      fn validated_params ->
        AuthService.refresh_access_token(validated_params.refresh_token)
      end,
      fn %{access_token: access_token, refresh_token: refresh_token} ->
        # The success format nests both tokens under the access_token key as a map
        handle_auth_success(conn, :refresh, %{
          access_token: %{access_token: access_token, refresh_token: refresh_token}
        })
      end
    )
  end

  @doc """
  Logout user by revoking refresh token.

  POST /api/auth/logout
  Body: %{"refresh_token" => "refresh_token_here"}
  """
  def logout(conn, params) do
    context = build_context(conn, :logout)

    validate_and_execute(
      conn,
      context,
      InputValidator.validate_refresh_token(params),
      fn validated_params ->
        AuthService.logout_user(validated_params.refresh_token)
      end,
      fn _ ->
        handle_auth_success(conn, :logout, "Logged out successfully")
      end
    )
  end

  @doc """
  Logout user from all devices.

  POST /api/auth/logout-all
  Headers: Authorization: Bearer <access_token>
  """
  def logout_all(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, _} <- AuthService.logout_user_all_devices(user.id) do
      handle_auth_success(conn, :logout_all, "Logged out from all devices successfully")
    end
  end

  @doc """
  Get current user information from access token.

  GET /api/auth/me
  Headers: Authorization: Bearer <access_token>
  """
  def me(conn, _params) do
    with {:ok, user} <- get_current_user(conn) do
      handle_auth_success(conn, :me, user)
    end
  end

  @doc """
  Validate access token.

  GET /api/auth/validate
  Headers: Authorization: Bearer <access_token>
  """
  def validate(conn, _params) do
    with {:ok, user} <- get_current_user(conn) do
      handle_auth_success(conn, :validate, %{
        user_id: user.id,
        role: user.role,
        expires_at: get_token_expiration(conn)
      })
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_current_user(conn) do
    with {:ok, token} <- get_auth_header(conn),
         {:ok, _validated_token} <- InputValidator.validate_access_token(token),
         {:ok, user} <- AuthService.get_user_from_token(token) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_auth_header(conn) do
    get_auth_token(conn)
  end

  defp get_token_expiration(conn) do
    with {:ok, token} <- get_auth_header(conn),
         {:ok, _validated_token} <- InputValidator.validate_access_token(token),
         {:ok, expiration} <- AuthService.get_token_expiration(token) do
      expiration
    else
      _ -> nil
    end
  end
end

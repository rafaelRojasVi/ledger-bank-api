defmodule LedgerBankApiWeb.Controllers.AuthController do
  @moduledoc """
  Authentication controller handling user login, logout, and token management.

  Uses the "one-thing" error handling pattern with canonical Error structs.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Accounts.AuthService

  @doc """
  Login user with email and password.

  POST /api/auth/login
  Body: %{"email" => "user@example.com", "password" => "password123"}
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case AuthService.login_user(email, password) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token, user: user}} ->
        response_data = %{
          access_token: access_token,
          refresh_token: refresh_token,
          user: %{
            id: user.id,
            email: user.email,
            full_name: user.full_name,
            role: user.role,
            status: user.status
          }
        }

        handle_success(conn, response_data)

      {:error, %Ecto.Changeset{} = changeset} ->
        handle_changeset_error(conn, changeset, %{action: :login})

      {:error, reason} ->
        handle_error(conn, reason, %{action: :login, email: email})
    end
  end

  def login(conn, _params) do
    handle_error(conn, :missing_fields, %{
      action: :login,
      required_fields: ["email", "password"]
    })
  end

  @doc """
  Refresh access token using refresh token.

  POST /api/auth/refresh
  Body: %{"refresh_token" => "refresh_token_here"}
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case AuthService.refresh_access_token(refresh_token) do
      {:ok, access_token} ->
        response_data = %{access_token: access_token}
        handle_success(conn, response_data)

      {:error, reason} ->
        handle_error(conn, reason, %{action: :refresh})
    end
  end

  def refresh(conn, _params) do
    handle_error(conn, :missing_fields, %{
      action: :refresh,
      required_fields: ["refresh_token"]
    })
  end

  @doc """
  Logout user by revoking refresh token.

  POST /api/auth/logout
  Body: %{"refresh_token" => "refresh_token_here"}
  """
  def logout(conn, %{"refresh_token" => refresh_token}) do
    case AuthService.logout_user(refresh_token) do
      {:ok, _} ->
        handle_success(conn, %{message: "Logged out successfully"})

      {:error, reason} ->
        handle_error(conn, reason, %{action: :logout})
    end
  end

  def logout(conn, _params) do
    handle_error(conn, :missing_fields, %{
      action: :logout,
      required_fields: ["refresh_token"]
    })
  end

  @doc """
  Logout user from all devices.

  POST /api/auth/logout-all
  Headers: Authorization: Bearer <access_token>
  """
  def logout_all(conn, _params) do
    with {:ok, user} <- get_current_user(conn) do
      case AuthService.logout_user_all_devices(user.id) do
        {:ok, _} ->
          handle_success(conn, %{message: "Logged out from all devices successfully"})

        {:error, reason} ->
          handle_error(conn, reason, %{action: :logout_all, user_id: user.id})
      end
    end
  end

  @doc """
  Get current user information from access token.

  GET /api/auth/me
  Headers: Authorization: Bearer <access_token>
  """
  def me(conn, _params) do
    with {:ok, user} <- get_current_user(conn) do
      user_data = %{
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        role: user.role,
        status: user.status,
        active: user.active,
        verified: user.verified,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }

      handle_success(conn, user_data)
    end
  end

  @doc """
  Validate access token.

  GET /api/auth/validate
  Headers: Authorization: Bearer <access_token>
  """
  def validate(conn, _params) do
    with {:ok, user} <- get_current_user(conn) do
      response_data = %{
        valid: true,
        user_id: user.id,
        role: user.role,
        expires_at: get_token_expiration(conn)
      }

      handle_success(conn, response_data)
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_current_user(conn) do
    case get_auth_header(conn) do
      {:ok, token} ->
        case AuthService.get_user_from_token(token) do
          {:ok, user} -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_auth_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :invalid_token}
    end
  end

  defp get_token_expiration(conn) do
    case get_auth_header(conn) do
      {:ok, token} ->
        case AuthService.get_token_expiration(token) do
          {:ok, expiration} -> expiration
          {:error, _} -> nil
        end

      {:error, _} ->
        nil
    end
  end
end

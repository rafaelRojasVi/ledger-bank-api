defmodule LedgerBankApi.Accounts.AuthService do
  @moduledoc """
  Authentication service for user authentication and authorization.

  Handles JWT token generation, verification, refresh, and user authentication.
  """

  @behaviour LedgerBankApi.Core.ServiceBehavior

  alias LedgerBankApi.Accounts.{UserService, Token}
  alias LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApiWeb.Logger, as: AppLogger

  # ============================================================================
  # SERVICE BEHAVIOR IMPLEMENTATION
  # ============================================================================

  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "auth_service"

  # ============================================================================
  # JWT TOKEN MANAGEMENT
  # ============================================================================

  @doc """
  Generate access token for user.
  """
  def generate_access_token(user) do
    Token.generate_access_token(user)
  end

  @doc """
  Generate refresh token for user.
  """
  def generate_refresh_token(user) do
    Token.generate_refresh_token(user)
  end

  @doc """
  Verify access token.
  """
  def verify_access_token(token) do
    Token.verify_access_token(token)
  end

  @doc """
  Verify refresh token.
  """
  def verify_refresh_token(token) do
    Token.verify_refresh_token(token)
  end

  @doc """
  Refresh access token using refresh token (with rotation for security).
  """
  def refresh_access_token(refresh_token) do
    # Trust that refresh_token is valid (web layer already validated)
    Token.refresh_access_token_with_rotation(refresh_token)
  end

  @doc """
  Revoke refresh token.
  """
  def revoke_refresh_token(token) do
    # Trust that token is valid (web layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :revoke_refresh_token, %{token_type: "refresh"})

    with {:ok, claims} <- verify_refresh_token(token),
         {:ok, result} <- UserService.revoke_refresh_token(claims["jti"]) do
      {:ok, result}
    end
  end

  @doc """
  Revoke all refresh tokens for user.
  """
  def revoke_all_refresh_tokens(user_id) do
    UserService.revoke_all_refresh_tokens(user_id)
  end

  # ============================================================================
  # AUTHENTICATION HELPERS
  # ============================================================================

  @doc """
  Get user from access token.
  """
  def get_user_from_token(token) do
    # Trust that token is valid (web layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :get_user_from_token, %{token_type: "access"})

    with {:ok, claims} <- verify_access_token(token),
         {:ok, user} <- UserService.get_user(claims["sub"]) do
      {:ok, user}
    end
  end

  @doc """
  Check if user is authenticated.
  """
  def authenticated?(token) do
    case verify_access_token(token) do
      {:ok, _claims} -> true
      {:error, _reason} -> false
    end
  end

  @doc """
  Check if user has specific role.
  """
  def has_role?(token, required_role) do
    case verify_access_token(token) do
      {:ok, claims} -> claims["role"] == required_role
      {:error, _reason} -> false
    end
  end

  @doc """
  Check if user is admin.
  """
  def is_admin?(token) do
    has_role?(token, "admin")
  end

  @doc """
  Check if user is support.
  """
  def is_support?(token) do
    has_role?(token, "support")
  end

  @doc """
  Check if user is regular user.
  """
  def is_user?(token) do
    has_role?(token, "user")
  end

  # ============================================================================
  # LOGIN/LOGOUT
  # ============================================================================

  @doc """
  Login user and return tokens.
  """
  def login_user(email, password) do
    # Trust that email and password are valid (web layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :login_user, %{email: email})

    with {:ok, user} <- UserService.authenticate_user(email, password),
         {:ok, access_token} <- generate_access_token(user),
         {:ok, refresh_token} <- generate_refresh_token(user) do
      # Log authentication event
      AppLogger.log_auth_event("user_login", user.id, %{
        email: email,
        correlation_id: context.correlation_id
      })

      {:ok, %{
        access_token: access_token,
        refresh_token: refresh_token,
        user: user
      }}
    end
  end

  @doc """
  Logout user by revoking refresh token.
  """
  def logout_user(refresh_token) do
    revoke_refresh_token(refresh_token)
  end

  @doc """
  Logout user from all devices.
  """
  def logout_user_all_devices(user_id) do
    revoke_all_refresh_tokens(user_id)
  end

  @doc """
  Validate token and get user.
  """
  def validate_token_and_get_user(token) do
    with {:ok, claims} <- verify_access_token(token),
         {:ok, user} <- get_user_from_claims(claims) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get user from JWT claims.
  """
  def get_user_from_claims(claims) do
    user_id = claims["sub"]
    UserService.get_user(user_id)
  end

  @doc """
  Check if token is valid for user.
  """
  def is_token_valid_for_user?(token, user_id) do
    case verify_access_token(token) do
      {:ok, claims} ->
        token_user_id = claims["sub"]
        {:ok, token_user_id == user_id}
      {:error, _reason} ->
        {:ok, false}
    end
  end

  @doc """
  Get token expiration time.
  """
  def get_token_expiration(token) do
    # Trust that token is valid (web layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :get_token_expiration, %{token_type: "access"})

    with {:ok, claims} <- verify_access_token(token) do
      exp = claims["exp"]
      {:ok, DateTime.from_unix!(exp)}
    end
  end

  @doc """
  Check if token is expired.
  """
  def is_token_expired?(token) do
    Token.is_token_expired?(token)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================
end

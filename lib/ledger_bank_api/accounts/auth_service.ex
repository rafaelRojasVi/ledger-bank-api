defmodule LedgerBankApi.Accounts.AuthService do
  @moduledoc """
  Authentication service for user authentication and authorization.

  Handles JWT token generation, verification, refresh, and user authentication.
  """

  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApi.Accounts.Schemas.RefreshToken
  alias LedgerBankApi.Core.{ErrorHandler, Error}

  # ============================================================================
  # JWT TOKEN MANAGEMENT
  # ============================================================================

  @doc """
  Generate access token for user.
  """
  def generate_access_token(user) do
    try do
      # Token expires in 15 minutes
      exp = System.system_time(:second) + 900

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => exp,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      secret = get_jwt_secret()
      token = Joken.generate_and_sign!(payload, Joken.Signer.create("HS256", secret))
      {:ok, token}
    rescue
      error ->
        {:error, ErrorHandler.business_error(:internal_server_error, %{error: inspect(error), source: "auth_service"})}
    end
  end

  @doc """
  Generate refresh token for user.
  """
  def generate_refresh_token(user) do
    try do
      # Token expires in 7 days
      exp = System.system_time(:second) + 604800

      jti = Ecto.UUID.generate()
      payload = %{
        "sub" => to_string(user.id),
        "jti" => jti,
        "exp" => exp,
        "iat" => System.system_time(:second),
        "type" => "refresh",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "nbf" => System.system_time(:second)
      }

      secret = get_jwt_secret()
      token = Joken.generate_and_sign!(payload, Joken.Signer.create("HS256", secret))

      # Store refresh token in database
      case UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: DateTime.from_unix!(exp)
      }) do
        {:ok, _refresh_token} -> {:ok, token}
        {:error, changeset} -> {:error, changeset}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:internal_server_error, %{error: inspect(error), source: "auth_service"})}
    end
  end

  @doc """
  Verify access token.
  """
  def verify_access_token(token) do
    try do
      secret = get_jwt_secret()
      case Joken.verify_and_validate(token, Joken.Signer.create("HS256", secret)) do
        {:ok, %{"type" => "access"} = claims} ->
          # Validate token security claims
          case validate_token_claims(claims) do
            :ok ->
              # Check if token is expired
              exp = claims["exp"]
              if exp > System.system_time(:second) do
                {:ok, claims}
              else
                {:error, ErrorHandler.business_error(:token_expired, %{token_type: "access", source: "auth_service"})}
              end
            {:error, reason} -> {:error, reason}
          end
        {:ok, _claims} ->
          {:error, ErrorHandler.business_error(:invalid_token_type, %{expected_type: "access", source: "auth_service"})}
        {:error, _reason} ->
          {:error, ErrorHandler.business_error(:invalid_token, %{token_type: "access", source: "auth_service"})}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:invalid_token, %{error: inspect(error), source: "auth_service"})}
    end
  end

  @doc """
  Verify refresh token.
  """
  def verify_refresh_token(token) do
    try do
      secret = get_jwt_secret()
      case Joken.verify_and_validate(token, Joken.Signer.create("HS256", secret)) do
        {:ok, %{"type" => "refresh"} = claims} ->
          # Check if token is expired
          exp = claims["exp"]
          if exp > System.system_time(:second) do
            # Check if token is revoked in database
            jti = claims["jti"]
            case UserService.get_refresh_token(jti) do
              {:ok, refresh_token} ->
                if RefreshToken.revoked?(refresh_token) do
                  {:error, ErrorHandler.business_error(:token_revoked, %{jti: jti, source: "auth_service"})}
                else
                  {:ok, claims}
                end
              {:error, %Error{} = error} ->
                {:error, error}
            end
          else
            {:error, ErrorHandler.business_error(:token_expired, %{token_type: "refresh", source: "auth_service"})}
          end
        {:ok, _claims} ->
          {:error, ErrorHandler.business_error(:invalid_token_type, %{expected_type: "refresh", source: "auth_service"})}
        {:error, _reason} ->
          {:error, ErrorHandler.business_error(:invalid_token, %{token_type: "refresh", source: "auth_service"})}
      end
    rescue
      error ->
        {:error, ErrorHandler.business_error(:invalid_token, %{error: inspect(error), source: "auth_service"})}
    end
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh_access_token(refresh_token) do
    case verify_refresh_token(refresh_token) do
      {:ok, claims} ->
        user_id = claims["sub"]
        case UserService.get_user(user_id) do
          {:ok, user} ->
            generate_access_token(user)
          {:error, %Error{} = error} ->
            {:error, error}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Revoke refresh token.
  """
  def revoke_refresh_token(token) do
    case verify_refresh_token(token) do
      {:ok, claims} ->
        jti = claims["jti"]
        UserService.revoke_refresh_token(jti)
      {:error, reason} ->
        {:error, reason}
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
    case verify_access_token(token) do
      {:ok, claims} ->
        user_id = claims["sub"]
        UserService.get_user(user_id)
      {:error, reason} ->
        {:error, reason}
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
    case UserService.authenticate_user(email, password) do
      {:ok, user} ->
        case generate_access_token(user) do
          {:ok, access_token} ->
            case generate_refresh_token(user) do
              {:ok, refresh_token} ->
                {:ok, %{
                  access_token: access_token,
                  refresh_token: refresh_token,
                  user: user
                }}
              {:error, reason} -> {:error, reason}
            end
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
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
    case verify_access_token(token) do
      {:ok, claims} ->
        exp = claims["exp"]
        {:ok, DateTime.from_unix!(exp)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if token is expired.
  """
  def is_token_expired?(token) do
    case verify_access_token(token) do
      {:ok, _claims} -> {:ok, false}
      {:error, %{error: %{type: "token_expired"}}} -> {:ok, true}
      {:error, _reason} -> {:ok, true}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  # ============================================================================
  # PRIVATE SECURITY FUNCTIONS
  # ============================================================================

  # Gets JWT secret from configuration with proper validation
  defp get_jwt_secret do
    case Application.get_env(:ledger_bank_api, :jwt_secret) do
      nil ->
        case System.get_env("JWT_SECRET") do
          nil ->
            require Logger
            Logger.error("JWT_SECRET not configured in application config or environment variables")
            raise "JWT_SECRET must be configured for security"
          secret when is_binary(secret) and byte_size(secret) >= 32 ->
            secret
          _ ->
            require Logger
            Logger.error("JWT_SECRET must be at least 32 characters long")
            raise "JWT_SECRET must be at least 32 characters long for security"
        end
      secret when is_binary(secret) and byte_size(secret) >= 32 ->
        secret
      _ ->
        require Logger
        Logger.error("JWT_SECRET in application config must be at least 32 characters long")
        raise "JWT_SECRET in application config must be at least 32 characters long for security"
    end
  end

  # Helper function to get missing required claims
  defp get_missing_claims(claims) do
    required_claims = ["sub", "exp", "iat"]
    Enum.filter(required_claims, fn claim -> is_nil(claims[claim]) end)
  end

  # Validates JWT token claims for security.
  defp validate_token_claims(claims) do
    cond do
      claims["iss"] != "ledger-bank-api" ->
        {:error, ErrorHandler.business_error(:invalid_token, %{expected: "ledger-bank-api", actual: claims["iss"], source: "auth_service"})}
      claims["aud"] != "ledger-bank-api" ->
        {:error, ErrorHandler.business_error(:invalid_token, %{expected: "ledger-bank-api", actual: claims["aud"], source: "auth_service"})}
      claims["nbf"] && claims["nbf"] > System.system_time(:second) ->
        {:error, ErrorHandler.business_error(:invalid_token, %{nbf: claims["nbf"], current_time: System.system_time(:second), source: "auth_service"})}
      is_nil(claims["sub"]) or is_nil(claims["exp"]) or is_nil(claims["iat"]) ->
        {:error, ErrorHandler.business_error(:invalid_token, %{missing_claims: get_missing_claims(claims), source: "auth_service"})}
      true ->
        :ok
    end
  end
end

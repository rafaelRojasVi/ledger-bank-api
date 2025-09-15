defmodule LedgerBankApi.Auth do
  @moduledoc """
  Consolidated authentication business logic.
  Combines functionality from auth/jwt.ex and related auth functionality.
  """

  alias LedgerBankApi.Users
  alias LedgerBankApi.Users.RefreshToken
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  # ============================================================================
  # JWT TOKEN MANAGEMENT
  # ============================================================================

  @doc """
  Generate access token for user.
  """
  def generate_access_token(user) do
    context = %{action: :generate_access_token, user_id: user.id}
    ErrorHandler.with_error_handling(fn ->
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
    end, context)
  end

  @doc """
  Generate refresh token for user.
  """
  def generate_refresh_token(user) do
    context = %{action: :generate_refresh_token, user_id: user.id}
    ErrorHandler.with_error_handling(fn ->
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
      case Users.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: DateTime.from_unix!(exp)
      }) do
        {:ok, _refresh_token} -> {:ok, token}
        {:error, changeset} -> {:error, changeset}
      end
    end, context)
  end

  @doc """
  Verify access token.
  """
  def verify_access_token(token) do
    context = %{action: :verify_access_token}
    ErrorHandler.with_error_handling(fn ->
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
                {:error, :token_expired}
              end
            {:error, reason} -> {:error, reason}
          end
        {:ok, _claims} -> {:error, :invalid_token_type}
        {:error, _reason} -> {:error, :invalid_token}
      end
    end, context)
  end

  @doc """
  Verify refresh token.
  """
  def verify_refresh_token(token) do
    context = %{action: :verify_refresh_token}
    ErrorHandler.with_error_handling(fn ->
      secret = get_jwt_secret()
      case Joken.verify_and_validate(token, Joken.Signer.create("HS256", secret)) do
        {:ok, %{"type" => "refresh"} = claims} ->
          # Check if token is expired
          exp = claims["exp"]
          if exp > System.system_time(:second) do
            # Check if token is revoked in database
            jti = claims["jti"]
            case Users.get_refresh_token(jti) do
              {:ok, refresh_token} ->
                if RefreshToken.revoked?(refresh_token) do
                  {:error, :token_revoked}
                else
                  {:ok, claims}
                end
              {:error, :not_found} -> {:error, :token_not_found}
            end
          else
            {:error, :token_expired}
          end
        {:ok, _claims} -> {:error, :invalid_token_type}
        {:error, _reason} -> {:error, :invalid_token}
      end
    end, context)
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh_access_token(refresh_token) do
    context = %{action: :refresh_access_token}
    ErrorHandler.with_error_handling(fn ->
      case verify_refresh_token(refresh_token) do
        {:ok, claims} ->
          user_id = claims["sub"]
          case Users.get_user(user_id) do
            {:ok, user} ->
              case generate_access_token(user) do
                {:ok, new_access_token} -> {:ok, new_access_token}
                {:error, reason} -> {:error, reason}
              end
            {:error, :not_found} -> {:error, :user_not_found}
          end
        {:error, reason} -> {:error, reason}
      end
    end, context)
  end

  @doc """
  Revoke refresh token.
  """
  def revoke_refresh_token(token) do
    context = %{action: :revoke_refresh_token}
    ErrorHandler.with_error_handling(fn ->
      case verify_refresh_token(token) do
        {:ok, claims} ->
          jti = claims["jti"]
          Users.revoke_refresh_token(jti)
        {:error, reason} -> {:error, reason}
      end
    end, context)
  end

  @doc """
  Revoke all refresh tokens for user.
  """
  def revoke_all_refresh_tokens(user_id) do
    context = %{action: :revoke_all_refresh_tokens, user_id: user_id}
    ErrorHandler.with_error_handling(fn ->
      Users.revoke_all_refresh_tokens(user_id)
    end, context)
  end

  # ============================================================================
  # AUTHENTICATION HELPERS
  # ============================================================================

  @doc """
  Get user from access token.
  """
  def get_user_from_token(token) do
    context = %{action: :get_user_from_token}
    ErrorHandler.with_error_handling(fn ->
      case verify_access_token(token) do
        {:ok, claims} ->
          user_id = claims["sub"]
          Users.get_user(user_id)
        {:error, reason} -> {:error, reason}
      end
    end, context)
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
  Authenticate user with email and password.
  """
  def authenticate_user(email, password) do
    context = %{action: :authenticate_user, email: email}
    ErrorHandler.with_error_handling(fn ->
      case Users.get_user_by_email(email) do
        {:ok, user} ->
          if Argon2.verify_pass(password, user.password_hash) do
            {:ok, user}
          else
            {:error, :invalid_password}
          end
        {:error, :not_found} -> {:error, :user_not_found}
      end
    end, context)
  end

  @doc """
  Login user and return tokens.
  """
  def login_user(email, password) do
    context = %{action: :login_user, email: email}
    ErrorHandler.with_error_handling(fn ->
      case authenticate_user(email, password) do
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
    end, context)
  end

  @doc """
  Logout user by revoking refresh token.
  """
  def logout_user(refresh_token) do
    context = %{action: :logout_user}
    ErrorHandler.with_error_handling(fn ->
      revoke_refresh_token(refresh_token)
    end, context)
  end

  @doc """
  Logout user from all devices.
  """
  def logout_user_all_devices(user_id) do
    context = %{action: :logout_user_all_devices, user_id: user_id}
    ErrorHandler.with_error_handling(fn ->
      revoke_all_refresh_tokens(user_id)
    end, context)
  end

  @doc """
  Validate token and get user.
  """
  def validate_token_and_get_user(token) do
    context = %{action: :validate_token_and_get_user}
    ErrorHandler.with_error_handling(fn ->
      with {:ok, claims} <- verify_access_token(token),
           {:ok, user} <- get_user_from_claims(claims) do
        {:ok, user}
      end
    end, context)
  end

  @doc """
  Get user from JWT claims.
  """
  def get_user_from_claims(claims) do
    context = %{action: :get_user_from_claims}
    ErrorHandler.with_error_handling(fn ->
      user_id = claims["sub"]
      Users.get_user(user_id)
    end, context)
  end

  @doc """
  Check if token is valid for user.
  """
  def is_token_valid_for_user?(token, user_id) do
    context = %{action: :is_token_valid_for_user, user_id: user_id}
    ErrorHandler.with_error_handling(fn ->
      case verify_access_token(token) do
        {:ok, claims} ->
          token_user_id = claims["sub"]
          {:ok, token_user_id == user_id}
        {:error, _reason} ->
          {:ok, false}
      end
    end, context)
  end

  @doc """
  Get token expiration time.
  """
  def get_token_expiration(token) do
    context = %{action: :get_token_expiration}
    ErrorHandler.with_error_handling(fn ->
      case verify_access_token(token) do
        {:ok, claims} ->
          exp = claims["exp"]
          {:ok, DateTime.from_unix!(exp)}
        {:error, reason} ->
          {:error, reason}
      end
    end, context)
  end

  @doc """
  Check if token is expired.
  """
  def is_token_expired?(token) do
    context = %{action: :is_token_expired}
    ErrorHandler.with_error_handling(fn ->
      case verify_access_token(token) do
        {:ok, _claims} -> {:ok, false}
        {:error, %{error: %{type: "token_expired"}}} -> {:ok, true}
        {:error, _reason} -> {:ok, true}
      end
    end, context)
  end

  # ============================================================================
  # MACRO GENERATED CRUD OPERATIONS
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

  # Validates JWT token claims for security.
  defp validate_token_claims(claims) do
    cond do
      claims["iss"] != "ledger-bank-api" ->
        {:error, :invalid_issuer}
      claims["aud"] != "ledger-bank-api" ->
        {:error, :invalid_audience}
      claims["nbf"] && claims["nbf"] > System.system_time(:second) ->
        {:error, :token_not_yet_valid}
      is_nil(claims["sub"]) or is_nil(claims["exp"]) or is_nil(claims["iat"]) ->
        {:error, :missing_required_claims}
      true ->
        :ok
    end
  end
end

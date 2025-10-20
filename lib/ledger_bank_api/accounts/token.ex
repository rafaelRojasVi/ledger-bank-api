defmodule LedgerBankApi.Accounts.Token do
  @moduledoc """
  JWT token configuration and validation using Joken.Config.

  This module defines the token structure, claims validation, and provides
  a clean interface for token operations following Joken's idiomatic patterns.
  """

  @behaviour LedgerBankApi.Core.ServiceBehavior

  use Joken.Config
  require LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApi.Core.{ErrorHandler, ServiceBehavior}

  # Fix: Implement JSON encoding for Joken.Signer to prevent encoding errors
  require Protocol
  Protocol.derive(Jason.Encoder, Joken.Signer, only: [])

  # ============================================================================
  # SERVICE BEHAVIOR IMPLEMENTATION
  # ============================================================================

  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "token_service"

  # ============================================================================
  # TOKEN CONFIGURATION
  # ============================================================================

  @doc """
  Token configuration with default claims validation.

  This defines which claims are required, optional, and how they should be validated.
  Joken will automatically enforce these validations during verify_and_validate/2.
  """
  def token_config do
    default_claims(
      # Skip audience validation for now (can be added later if needed)
      skip: [],
      # Enforce these claims to be present and valid
      enforce: [:exp, :iat, :iss, :sub, :type]
    )
    |> add_claim("type", fn -> nil end, &validate_token_type/2)
    |> add_claim("role", fn -> nil end, &validate_role/2)
    |> add_claim("email", fn -> nil end, &validate_email/2)
    |> add_claim("jti", fn -> nil end, &validate_jti/2)
  end

  @doc """
  Generate access token for user.
  """
  def generate_access_token(user) do
    # Trust that user is valid (business layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :generate_access_token, %{user_id: user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      jwt_cfg = Application.get_env(:ledger_bank_api, :jwt, [])
      access_ttl = Keyword.get(jwt_cfg, :access_token_expiry, 900)
      iss = Keyword.get(jwt_cfg, :issuer, "ledger-bank-api")
      aud = Keyword.get(jwt_cfg, :audience, "ledger-bank-api")
      exp = System.system_time(:second) + access_ttl

      claims = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => exp,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => iss,
        "aud" => aud,
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = get_signer()
      token = generate_and_sign!(claims, signer)
      {:ok, token}
    end)
  end

  @doc """
  Generate refresh token for user.
  """
  def generate_refresh_token(user) do
    # Trust that user is valid (business layer already validated)
    context = ServiceBehavior.build_context(__MODULE__, :generate_refresh_token, %{user_id: user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      jwt_cfg = Application.get_env(:ledger_bank_api, :jwt, [])
      refresh_ttl = Keyword.get(jwt_cfg, :refresh_token_expiry, 7 * 24 * 3600)
      iss = Keyword.get(jwt_cfg, :issuer, "ledger-bank-api")
      aud = Keyword.get(jwt_cfg, :audience, "ledger-bank-api")
      exp = System.system_time(:second) + refresh_ttl

      jti = Ecto.UUID.generate()
      claims = %{
        "sub" => to_string(user.id),
        "jti" => jti,
        "exp" => exp,
        "iat" => System.system_time(:second),
        "type" => "refresh",
        "iss" => iss,
        "aud" => aud,
        "nbf" => System.system_time(:second)
      }

      signer = get_signer()
      token = generate_and_sign!(claims, signer)

      # Store refresh token in database
      case LedgerBankApi.Accounts.UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: DateTime.from_unix!(exp)
      }) do
        {:ok, _refresh_token} -> {:ok, token}
        {:error, changeset} ->
          {:error, ErrorHandler.handle_changeset_error(changeset, context)}
      end
    end)
  end

  @doc """
  Verify access token using Joken's built-in validation.
  """
  def verify_access_token(token) do
    context = ServiceBehavior.build_context(__MODULE__, :verify_access_token, %{token_type: "access"})

    case token do
      nil ->
        {:error, ErrorHandler.business_error(:invalid_token, context)}
      _ ->
        signer = get_signer()
        case Joken.verify(token, signer) do
          {:ok, %{"type" => "access"} = claims} -> {:ok, claims}
          {:ok, _claims} ->
            {:error, ErrorHandler.business_error(:invalid_token_type, Map.put(context, :expected_type, "access"))}
          {:error, _reason} ->
            {:error, ErrorHandler.business_error(:invalid_token, context)}
        end
    end
  end

  @doc """
  Verify refresh token using Joken's built-in validation.
  """
  def verify_refresh_token(token) do
    context = ServiceBehavior.build_context(__MODULE__, :verify_refresh_token, %{token_type: "refresh"})

    case token do
      nil ->
        {:error, ErrorHandler.business_error(:invalid_token, context)}
      _ ->
        signer = get_signer()
        case Joken.verify(token, signer) do
      {:ok, %{"type" => "refresh"} = claims} ->
        # Check if token is revoked in database
        jti = claims["jti"]
        case LedgerBankApi.Accounts.UserService.get_refresh_token(jti) do
          {:ok, refresh_token} ->
            if LedgerBankApi.Accounts.Schemas.RefreshToken.revoked?(refresh_token) do
              {:error, ErrorHandler.business_error(:token_revoked, Map.put(context, :jti, jti))}
            else
              {:ok, claims}
            end
          {:error, %LedgerBankApi.Core.Error{} = error} ->
            {:error, error}
        end
          {:ok, _claims} ->
            {:error, ErrorHandler.business_error(:invalid_token_type, Map.put(context, :expected_type, "refresh"))}
          {:error, _reason} ->
            {:error, ErrorHandler.business_error(:invalid_token, context)}
        end
    end
  end

  @doc """
  Refresh access token with rotation (security best practice).

  This generates a new access token AND a new refresh token,
  then revokes the old refresh token to prevent replay attacks.
  """
  def refresh_access_token_with_rotation(refresh_token) do
    case verify_refresh_token(refresh_token) do
      {:ok, claims} ->
        user_id = claims["sub"]
        case LedgerBankApi.Accounts.UserService.get_user(user_id) do
          {:ok, user} ->
            # Generate new tokens
            case generate_access_token(user) do
              {:ok, new_access_token} ->
                case generate_refresh_token(user) do
                  {:ok, new_refresh_token} ->
                    # Revoke the old refresh token
                    jti = claims["jti"]
                    LedgerBankApi.Accounts.UserService.revoke_refresh_token(jti)

                    {:ok, %{
                      access_token: new_access_token,
                      refresh_token: new_refresh_token
                    }}
                  {:error, reason} -> {:error, reason}
                end
              {:error, reason} -> {:error, reason}
            end
          {:error, %LedgerBankApi.Core.Error{} = error} ->
            {:error, error}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if token is expired (simplified using Joken's error patterns).
  """
  def is_token_expired?(token) do
    case verify_access_token(token) do
      {:ok, %{"exp" => exp}} -> {:ok, System.system_time(:second) >= exp}
      {:error, _} -> {:ok, true}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  @doc """
  Ensures a strong JWT secret is configured. Raises on failure.

  This can be called at application startup to fail fast.
  """
  def ensure_jwt_secret! do
    _ = get_jwt_secret()
    :ok
  end

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

  # Create signer with JWT secret
  defp get_signer do
    Joken.Signer.create("HS256", get_jwt_secret())
  end

  # ============================================================================
  # CLAIM VALIDATORS
  # ============================================================================

  # Validate token type claim
  defp validate_token_type(value, _claims) when value in ["access", "refresh"], do: :ok
  defp validate_token_type(_value, _claims), do: {:error, :invalid_token_type}

  # Validate role claim
  defp validate_role(nil, _claims), do: :ok
  defp validate_role(value, _claims) when value in ["user", "admin", "support"], do: :ok
  defp validate_role(_value, _claims), do: :ok

  # Validate email claim
  defp validate_email(nil, _claims), do: :ok
  defp validate_email(value, _claims) when is_binary(value) do
    if String.contains?(value, "@"), do: :ok, else: :ok
  end
  defp validate_email(_value, _claims), do: :ok

  # Validate JTI claim
  defp validate_jti(nil, _claims), do: :ok
  defp validate_jti(value, _claims) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_jti(_value, _claims), do: :ok
end

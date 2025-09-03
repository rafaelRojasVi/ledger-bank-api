defmodule LedgerBankApi.Auth.JWT do
  @moduledoc """
  JWT token management for authentication.
  Handles token generation, validation, and refresh using Joken.Config.
  Now supports both access and refresh tokens, including user role in claims.
  """
  use Joken.Config

  @jwt_config Application.compile_env(:ledger_bank_api, :jwt, [])
  @access_token_expiry Keyword.get(@jwt_config, :access_token_expiry, 900) # 15 min
  @refresh_token_expiry Keyword.get(@jwt_config, :refresh_token_expiry, 7 * 24 * 3600) # 7 days
  @issuer Keyword.get(@jwt_config, :issuer, "ledger_bank_api")
  @audience Keyword.get(@jwt_config, :audience, "banking_api")
  @jwt_secret_key Application.compile_env(:ledger_bank_api, :jwt_secret_key, nil)
  @required_claims ["sub", "role", "type", "exp", "aud", "iss"]

  @doc """
  Returns the base token config for Joken.
  """
  def token_config do
    default_claims(skip: [:aud, :iss, :jti, :exp])
    |> add_claim("aud", fn -> @audience end, &(&1 == @audience), required: true)
    |> add_claim("iss", fn -> @issuer end, &(&1 == @issuer), required: true)
    |> add_claim("sub", fn -> nil end, &is_binary/1, required: true)
    |> add_claim("role", fn -> nil end, &is_binary/1, required: true)
    |> add_claim("exp", fn -> nil end, &is_integer/1, required: true)
    |> add_claim("type", fn -> nil end, &(&1 in ["access", "refresh"]), required: true)
  end

  @doc """
  Generates an access token for a user.
  Includes user_id, role, and email in claims.
  """
  def generate_access_token(%{id: user_id, role: role, email: email}) do
    now = DateTime.utc_now()
    claims = %{
      "sub" => user_id,
      "role" => role,
      "email" => email,
      "type" => "access",
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.add(now, @access_token_expiry, :second) |> DateTime.to_unix(),
      "aud" => @audience,
      "iss" => @issuer
    }
    sign_token(claims)
  end

  @doc """
  Generates a refresh token for a user.
  Includes user_id, role, email, and a unique jti.
  """
  def generate_refresh_token(%{id: user_id, role: role, email: email}) do
    now = DateTime.utc_now()
    jti = Ecto.UUID.generate()
    claims = %{
      "sub" => user_id,
      "role" => role,
      "email" => email,
      "type" => "refresh",
      "jti" => jti,
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.add(now, @refresh_token_expiry, :second) |> DateTime.to_unix(),
      "aud" => @audience,
      "iss" => @issuer
    }
    sign_token(claims)
  end

  defp sign_token(claims) do
    token = generate_and_sign!(claims, signer())
    {:ok, token}
  end

  @doc """
  Verifies a JWT and returns {:ok, claims} or {:error, reason}.
  """
  def verify_token(nil), do: {:error, :invalid_token}
  def verify_token(""), do: {:error, :invalid_token}
  def verify_token(token) when not is_binary(token), do: {:error, :invalid_token}

  def verify_token(token) do
    case verify_and_validate(token, signer()) do
      {:ok, claims} ->
        case validate_claims(claims) do
          :ok -> {:ok, claims}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
      _error -> {:error, :invalid_token}
    end
  end

  defp validate_claims(claims) do
    with :ok <- validate_required_claims(claims),
         :ok <- validate_iat_not_future(claims) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_claims(claims) do
    case Enum.all?(@required_claims, &Map.has_key?(claims, &1)) do
      true -> :ok
      false -> {:error, :missing_claims}
    end
  end

  defp validate_iat_not_future(claims) do
    case claims["iat"] do
      iat when is_integer(iat) ->
        now = DateTime.utc_now() |> DateTime.to_unix()
        if iat > now do
          {:error, :future_iat}
        else
          :ok
        end
      _ -> :ok
    end
  end

  @doc """
  Gets the user_id (sub) from a token.
  """
  def get_user_id(token) do
    with {:ok, claims} <- verify_token(token),
         false <- token_expired?(claims),
         user_id when is_binary(user_id) <- claims["sub"] do
      {:ok, user_id}
    else
      _ -> {:error, :invalid_token}
    end
  end

  @doc """
  Checks if a token is expired.
  """
  def token_expired?(token) when is_binary(token) do
    with {:ok, claims} <- verify_token(token) do
      token_expired?(claims)
    else
      _ -> true
    end
  end

  def token_expired?(claims) when is_map(claims) do
    case claims["exp"] do
      exp when is_integer(exp) ->
        DateTime.utc_now() |> DateTime.to_unix() > exp
      _ -> true
    end
  end

  @doc """
  Refreshes an access token using a valid refresh token.
  Returns {:ok, new_access_token, new_refresh_token} or {:error, reason}.
  """
  def refresh_access_token(refresh_token) do
    with {:ok, claims} <- verify_token(refresh_token),
         true <- claims["type"] == "refresh",
         false <- token_expired?(claims),
         user_id when is_binary(user_id) <- claims["sub"],
         role when is_binary(role) <- claims["role"],
         email when is_binary(email) <- claims["email"] do
      {:ok, new_access_token} = generate_access_token(%{id: user_id, role: role, email: email})
      {:ok, new_refresh_token} = generate_refresh_token(%{id: user_id, role: role, email: email})
      {:ok, new_access_token, new_refresh_token}
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  defp signer do
    Joken.Signer.create("HS256", @jwt_secret_key)
  end
end

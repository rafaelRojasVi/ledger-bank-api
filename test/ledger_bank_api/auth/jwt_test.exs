defmodule LedgerBankApi.Auth.JWTTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Auth.JWT

  @user %{id: "user-123", role: "admin"}

  test "generates and verifies access token" do
    {:ok, token} = JWT.generate_access_token(@user)
    assert {:ok, claims} = JWT.verify_token(token)
    assert claims["sub"] == @user.id
    assert claims["role"] == "admin"
    assert claims["type"] == "access"
  end

  test "generates and verifies refresh token" do
    {:ok, token} = JWT.generate_refresh_token(@user)
    assert {:ok, claims} = JWT.verify_token(token)
    assert claims["type"] == "refresh"
    assert is_binary(claims["jti"])
  end

  test "token_expired? returns true for expired token" do
    claims = %{"sub" => "u", "role" => "user", "type" => "access", "exp" => 0, "aud" => "banking_api", "iss" => "ledger_bank_api"}
    key = Application.get_env(:ledger_bank_api, :jwt_secret_key, "super-secret-key")
    signer = Joken.Signer.create("HS256", key)
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    assert JWT.token_expired?(token)
  end

  test "verify_token returns error for tampered token" do
    {:ok, token} = JWT.generate_access_token(@user)
    tampered = token <> "tamper"
    assert {:error, _} = JWT.verify_token(tampered)
  end

  test "verify_token returns error for expired token" do
    claims = %{"sub" => "u", "role" => "user", "type" => "access", "exp" => 0, "aud" => "banking_api", "iss" => "ledger_bank_api"}
    key = Application.get_env(:ledger_bank_api, :jwt_secret_key, "super-secret-key")
    signer = Joken.Signer.create("HS256", key)
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    assert JWT.token_expired?(token)
    assert {:ok, claims} = JWT.verify_token(token)
    assert DateTime.utc_now() |> DateTime.to_unix() > claims["exp"]
  end

  test "verify_token returns error for malformed JWT" do
    assert {:error, _} = JWT.verify_token("not.a.jwt")
    assert {:error, _} = JWT.verify_token("")
  end

  test "verify_token returns error for wrong audience" do
    claims = %{"sub" => "u", "role" => "user", "type" => "access", "exp" => DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.to_unix(), "aud" => "wrong_aud", "iss" => "ledger_bank_api"}
    key = Application.get_env(:ledger_bank_api, :jwt_secret_key, "super-secret-key")
    signer = Joken.Signer.create("HS256", key)
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    assert {:error, _} = JWT.verify_token(token)
  end

  test "verify_token returns error for wrong issuer" do
    claims = %{"sub" => "u", "role" => "user", "type" => "access", "exp" => DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.to_unix(), "aud" => "banking_api", "iss" => "wrong_iss"}
    key = Application.get_env(:ledger_bank_api, :jwt_secret_key, "super-secret-key")
    signer = Joken.Signer.create("HS256", key)
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    assert {:error, _} = JWT.verify_token(token)
  end

  test "verify_token returns error for missing required claims" do
    # Missing 'sub'
    claims = %{"role" => "user", "type" => "access", "exp" => DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.to_unix(), "aud" => "banking_api", "iss" => "ledger_bank_api"}
    key = Application.get_env(:ledger_bank_api, :jwt_secret_key, "super-secret-key")
    signer = Joken.Signer.create("HS256", key)
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    assert {:error, _} = JWT.verify_token(token)
  end
end

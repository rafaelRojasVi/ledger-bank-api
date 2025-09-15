defmodule LedgerBankApi.Auth.JwtSecretTest do
  use LedgerBankApi.DataCase
  alias LedgerBankApi.Auth

  describe "JWT secret validation" do
    test "raises error when JWT_SECRET is not configured" do
      # Temporarily remove the config
      Application.put_env(:ledger_bank_api, :jwt_secret, nil)
      System.put_env("JWT_SECRET", nil)

      assert_raise RuntimeError, "JWT_SECRET must be configured for security", fn ->
        # Access private function through public API
        Auth.generate_access_token(%{id: "test", email: "test@example.com", role: "user"})
      end
    end

    test "raises error when JWT_SECRET is too short" do
      # Set a short secret
      Application.put_env(:ledger_bank_api, :jwt_secret, "short")

      assert_raise RuntimeError, "JWT_SECRET in application config must be at least 32 characters long", fn ->
        Auth.generate_access_token(%{id: "test", email: "test@example.com", role: "user"})
      end
    end

    test "accepts valid JWT_SECRET" do
      # Set a valid secret
      valid_secret = String.duplicate("a", 64)
      Application.put_env(:ledger_bank_api, :jwt_secret, valid_secret)

      assert {:ok, _token} = Auth.generate_access_token(%{id: "test", email: "test@example.com", role: "user"})
    end

    test "accepts JWT_SECRET from environment variable" do
      # Clear config and set environment variable
      Application.put_env(:ledger_bank_api, :jwt_secret, nil)
      System.put_env("JWT_SECRET", String.duplicate("b", 64))

      assert {:ok, _token} = Auth.generate_access_token(%{id: "test", email: "test@example.com", role: "user"})
    end
  end
end


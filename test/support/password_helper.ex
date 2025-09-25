defmodule LedgerBankApi.PasswordHelper do
  @moduledoc """
  Password hashing helper for testing.

  This module provides a simple password hashing implementation for testing
  that doesn't require Argon2 compilation.
  """

  @doc """
  Hash a password for testing purposes.
  This is a simple implementation that should only be used in tests.
  """
  def hash_pwd_salt(password) when is_binary(password) do
    # Simple hash for testing - in production this would be Argon2
    :crypto.hash(:sha256, password <> "test_salt")
    |> Base.encode64()
  end

  @doc """
  Verify a password against a hash for testing purposes.
  """
  def verify_pass(password, hash) when is_binary(password) and is_binary(hash) do
    expected_hash = hash_pwd_salt(password)
    expected_hash == hash
  end
end

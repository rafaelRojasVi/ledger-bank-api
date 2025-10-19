defmodule LedgerBankApi.PasswordHelper do
  @moduledoc """
  Password hashing helper that adapts based on environment.

  - In test: Uses fast SHA256 hashing
  - In dev/prod: Uses secure PBKDF2 hashing

  This module exists to provide a consistent interface and prevent
  compile-time warnings about undefined modules.
  """

  @doc """
  Hash a password using the appropriate algorithm for the environment.
  """
  def hash_pwd_salt(password) when is_binary(password) do
    case Mix.env() do
      :test ->
        # Fast hashing for tests
        :crypto.hash(:sha256, password <> "test_salt")
        |> Base.encode64()

      _ ->
        # Secure hashing for dev/prod
        Pbkdf2.hash_pwd_salt(password)
    end
  end

  @doc """
  Verify a password against a hash.
  """
  def verify_pass(password, hash) when is_binary(password) and is_binary(hash) do
    case Mix.env() do
      :test ->
        # Fast verification for tests
        expected_hash = hash_pwd_salt(password)
        expected_hash == hash

      _ ->
        # Secure verification for dev/prod
        Pbkdf2.verify_pass(password, hash)
    end
  end
end

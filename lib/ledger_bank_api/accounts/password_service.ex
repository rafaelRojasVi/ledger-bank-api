defmodule LedgerBankApi.Accounts.PasswordService do
  @moduledoc """
  Password hashing service that uses configuration instead of Mix.env().

  This service provides a clean abstraction for password hashing that can be
  configured per environment without coupling to the Mix environment.

  ## Configuration

  The service reads configuration from `:ledger_bank_api, :password_hashing`:

  ```elixir
  config :ledger_bank_api, :password_hashing,
    algorithm: :pbkdf2,  # or :simple for testing
    options: [
      iterations: 100_000,
      length: 32,
      digest: :sha256
    ]
  ```

  ## Algorithms

  - `:pbkdf2` - Production-ready PBKDF2 hashing
  - `:simple` - Simple hashing for testing (faster)
  """

  @doc """
  Hash a password using the configured algorithm.

  ## Examples

      iex> hash_password("password123")
      "$pbkdf2-sha256$100000$..."

      iex> hash_password("password123")
      "simple_hash_for_testing"
  """
  def hash_password(password) when is_binary(password) do
    config = Application.get_env(:ledger_bank_api, :password_hashing, default_config())
    algorithm = Keyword.get(config, :algorithm, :pbkdf2)
    options = Keyword.get(config, :options, [])

    case algorithm do
      :pbkdf2 -> hash_with_pbkdf2(password, options)
      :simple -> hash_with_simple(password, options)
      _ -> raise "Unsupported password hashing algorithm: #{algorithm}"
    end
  end

  @doc """
  Verify a password against a hash.

  ## Examples

      iex> verify_password("password123", "$pbkdf2-sha256$100000$...")
      true

      iex> verify_password("wrong", "$pbkdf2-sha256$100000$...")
      false
  """
  def verify_password(password, hash) when is_binary(password) and is_binary(hash) do
    config = Application.get_env(:ledger_bank_api, :password_hashing, default_config())
    algorithm = Keyword.get(config, :algorithm, :pbkdf2)

    case algorithm do
      :pbkdf2 -> Pbkdf2.verify_pass(password, hash)
      :simple -> verify_with_simple(password, hash, config)
      _ -> raise "Unsupported password hashing algorithm: #{algorithm}"
    end
  end

  # Private functions

  defp hash_with_pbkdf2(password, _options) do
    Pbkdf2.hash_pwd_salt(password)
  end

  defp hash_with_simple(password, options) do
    salt = Keyword.get(options, :salt, "default_salt")

    :crypto.hash(:sha256, password <> salt)
    |> Base.encode64()
  end

  defp verify_with_simple(password, hash, config) do
    options = Keyword.get(config, :options, [])
    expected_hash = hash_with_simple(password, options)
    expected_hash == hash
  end

  defp default_config do
    [
      algorithm: :pbkdf2,
      options: [
        iterations: 100_000,
        length: 32,
        digest: :sha256
      ]
    ]
  end
end

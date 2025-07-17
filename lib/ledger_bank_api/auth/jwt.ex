defmodule LedgerBankApi.Auth.JWT do
  @moduledoc """
  JWT token management for authentication.
  Handles token generation, validation, and refresh using Joken.Config.
  """
  # JWT token management for authentication.
  # Handles token generation, validation, and refresh.
  # Now uses Joken.Config for easier configuration and validation.
  use Joken.Config
  # Compile-time fetch of all JWT-related config
  @jwt_config Application.compile_env(:ledger_bank_api, :jwt, [])
  @access_token_expiry Keyword.get(@jwt_config, :access_token_expiry, 3600)
  @refresh_token_expiry Keyword.get(@jwt_config, :refresh_token_expiry, 7 * 24 * 3600)
  @issuer Keyword.get(@jwt_config, :issuer, "ledger_bank_api")
  @audience Keyword.get(@jwt_config, :audience, "banking_api")
  @jwt_secret_key Application.compile_env(:ledger_bank_api, :jwt_secret_key, nil)
  def token_config do
    # ...
  end
  def generate_token(user_id, opts \\ []) do
    # ...
  end
  def verify_token(token) do
    # ...
  end
  def get_user_id(token) do
    # ...
  end
  def token_expired?(token) do
    # ...
  end
  def generate_refresh_token(user_id) do
    # ...
  end
  def refresh_access_token(refresh_token) do
    # ...
  end
  # Joken.Config callback: get secret from config/env
  # ...
end

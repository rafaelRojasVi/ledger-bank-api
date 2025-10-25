import Config

# Configure your database
#
# MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ledger_bank_api, LedgerBankApi.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "ledger_bank_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size:
    System.get_env("MIX_TEST_PARTITION")
    |> then(fn partition ->
      case partition do
        nil -> 10
        partition -> String.to_integer(partition) * 2 + 10
      end
    end),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

# No server during test. Configure the endpoint so VerifiedRoutes works in tests
config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  server: false,
  check_origin: false,
  secret_key_base:
    "test_secret_key_base_v1_please_replace_in_real_projects_abcdefghijklmnopqrstuvwxyz012345",
  http: [ip: {127, 0, 0, 1}, port: 4002]

# In test we don't send emails
config :ledger_bank_api, LedgerBankApi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :error

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Use mock for bank client in tests
config :ledger_bank_api, :bank_client, LedgerBankApi.Banking.BankApiClientMock

# JWT configuration for testing
config :ledger_bank_api, :jwt,
  issuer: "ledger-bank-api",
  audience: "ledger-bank-api",
  # 15 minutes for testing
  access_token_expiry: 900,
  # 7 days
  refresh_token_expiry: 7 * 24 * 3600,
  secret_key:
    System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# JWT secret for testing
config :ledger_bank_api,
       :jwt_secret,
       System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# Joken configuration for testing
config :joken,
  default_signer:
    System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# ============================================================================
# OBAN CONFIGURATION (Testing)
# ============================================================================
# Test-specific Oban overrides
# - Inline mode for faster, synchronous testing
# - Higher concurrency for test performance
# - Simplified plugin configuration
config :ledger_bank_api, Oban,
  # Run jobs immediately for faster testing
  testing: :inline,
  queues: [banking: 5, payments: 3, notifications: 2, default: 1],
  plugins: [
    # Keep pruner for cleanup
    Oban.Plugins.Pruner
  ]

# ============================================================================
# PASSWORD HASHING CONFIGURATION (Testing)
# ============================================================================
# Test-specific password hashing configuration
# Uses simple hashing for faster test execution
config :ledger_bank_api, :password_hashing,
  algorithm: :simple,
  options: [
    # Simple hashing for testing (faster than PBKDF2)
    salt: "test_salt"
  ]

# Legacy Argon2 configuration (commented out - not used)
# config :argon2_elixir,
#   t_cost: 1,
#   m_cost: 8,
#   parallelism: 1

# Cache configuration for testing
config :ledger_bank_api, :cache,
  ttl: 300,
  cleanup_interval: 60

# Configure Mox for mocking
config :ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialServiceMock

# Webhook secrets for testing
config :ledger_bank_api, :webhook_secrets, %{
  payment: "test_payment_webhook_secret",
  bank: "test_bank_webhook_secret",
  fraud: "test_fraud_webhook_secret"
}

# Test financial configuration
config :ledger_bank_api, :financial,
  # Match original test expectations
  checking_daily_limit: "1000.00",
  savings_daily_limit: "500.00",
  credit_daily_limit: "2000.00",
  investment_daily_limit: "5000.00",
  default_daily_limit: "1000.00",

  # Match original test expectations
  max_single_transaction: "10000.00",
  duplicate_window_minutes: "5",

  # Match original test expectations for password requirements
  admin_password_min_length: "15",
  support_password_min_length: "15",
  user_password_min_length: "8",

  # Short cache TTL for testing
  user_cache_ttl: "1",
  account_cache_ttl: "1",
  stats_cache_ttl: "1",
  default_cache_ttl: "1",

  # Test feature flags
  enable_advanced_validation: false,
  enable_duplicate_detection: true,
  enable_circuit_breaker: false,
  enable_telemetry: false,
  enable_rate_limiting: false,
  enable_security_audit: false,

  # Test retry configuration
  external_max_retries: "1",
  external_base_delay: "100",
  external_backoff_multiplier: "1.0",
  system_max_retries: "1",
  system_base_delay: "50",
  system_backoff_multiplier: "1.0",
  default_max_retries: "1",
  default_base_delay: "100",
  default_backoff_multiplier: "1.0"

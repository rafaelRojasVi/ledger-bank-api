import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ledger_bank_api, LedgerBankApi.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "ledger_bank_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.get_env("MIX_TEST_PARTITION") |> then(fn partition ->
    case partition do
      nil -> 10
      partition -> String.to_integer(partition) * 2 + 10
    end
  end),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

# We don't run a server during test. Configure the endpoint so VerifiedRoutes works in tests
config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  server: false,
  check_origin: false,
  secret_key_base: "test_secret_key_base_v1_please_replace_in_real_projects_abcdefghijklmnopqrstuvwxyz012345",
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
  issuer: "ledger:test",
  audience: "ledger:test",
  secret_key: System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# JWT secret for testing
config :ledger_bank_api, :jwt_secret, System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# Joken configuration for testing
config :joken, default_signer: System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")

# Configure Oban for testing - use inline mode for faster tests
config :ledger_bank_api, Oban,
  repo: LedgerBankApi.Repo,
  testing: :inline,  # Run jobs immediately for faster testing
  queues: [banking: 5, payments: 3, notifications: 2, default: 1],
  plugins: [
    Oban.Plugins.Pruner  # Keep pruner for cleanup
  ]

# Configure password hashing for testing - use a simpler algorithm
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8,
  parallelism: 1

# Cache configuration for testing
config :ledger_bank_api, :cache,
  ttl: 300,
  cleanup_interval: 60

# Configure Mox for mocking
config :ledger_bank_api, :financial_service, LedgerBankApi.Financial.FinancialServiceMock

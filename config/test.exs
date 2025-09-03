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

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ledger_bank_api_web, LedgerBankApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "H3se2fhV4VAb/y2jrP0O5Tv9gwz+yjePKZvOM/IfXGNkuYrWOmK7JzudVoJ27TXV",
  server: true

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
  secret_key: "super-secret-key-for-tests-only-change-me"

# Joken configuration for testing
config :joken, default_signer: "HS256"

# Configure Oban for testing - use manual mode for better control
config :ledger_bank_api, Oban,
  testing: :manual,
  queues: false,
  plugins: false

# Cache configuration for testing
config :ledger_bank_api, :cache,
  ttl: 300,
  cleanup_interval: 60

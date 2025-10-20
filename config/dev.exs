import Config

# Configure your database
db_name = System.get_env("DB_NAME", "ledger_bank_api_dev")

config :ledger_bank_api, LedgerBankApi.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: db_name,
  pool_size: 10,
  port: String.to_integer(System.get_env("DB_PORT", "5432"))

# For development, we disable any cache and enable
# debugging and code reloading.
config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  server: true,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "bWoE3DcxtV3QrO4Pe9ginuY2A1fk2OAwBC8O+eVJrXpSQtYgDl1P1cnFRMrU/7CG",
  watchers: []

# Enable dev routes for dashboard and mailbox
config :ledger_bank_api, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# JWT Configuration for development
# Generate a strong secret: openssl rand -base64 48
config :ledger_bank_api,
       :jwt_secret,
       System.get_env(
         "JWT_SECRET",
         "dev-secret-please-change-this-to-a-strong-64-char-secret-in-development"
       )

# Joken default signer for development
config :joken,
  default_signer:
    System.get_env(
      "JWT_SECRET",
      "dev-secret-please-change-this-to-a-strong-64-char-secret-in-development"
    )

# ============================================================================
# OBAN CONFIGURATION (Development)
# ============================================================================
# Development-specific Oban overrides
# - Manual testing mode for better debugging
# - Reduced queue concurrency for development
config :ledger_bank_api, Oban,
  testing: :manual,
  queues: [
    banking: 2,
    payments: 1,
    notifications: 1,
    default: 1
  ]

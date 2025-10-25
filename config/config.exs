# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Import OpenTelemetry configuration
import_config "telemetry.exs"

config :ledger_bank_api,
  ecto_repos: [LedgerBankApi.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Banking context configuration
config :ledger_bank_api, :banking,
  default_page_size: 20,
  max_page_size: 100,
  cache_ttl: 30_000

# Financial configuration with environment-driven settings
config :ledger_bank_api, :financial,
  # Daily limits by account type (can be overridden by environment variables)
  checking_daily_limit: "1000.00",
  savings_daily_limit: "500.00",
  credit_daily_limit: "2000.00",
  investment_daily_limit: "5000.00",
  default_daily_limit: "1000.00",

  # Transaction limits
  max_single_transaction: "10000.00",
  duplicate_window_minutes: "5",

  # Password requirements by role
  admin_password_min_length: "15",
  support_password_min_length: "15",
  user_password_min_length: "8",

  # Cache TTL settings (in seconds)
  user_cache_ttl: "300",
  account_cache_ttl: "60",
  stats_cache_ttl: "60",
  default_cache_ttl: "300",

  # Feature flags
  enable_advanced_validation: false,
  enable_duplicate_detection: true,
  enable_circuit_breaker: true,
  enable_telemetry: true,
  enable_rate_limiting: true,
  enable_security_audit: true,

  # Retry configuration
  external_max_retries: "3",
  external_base_delay: "1000",
  external_backoff_multiplier: "2.0",
  system_max_retries: "2",
  system_base_delay: "500",
  system_backoff_multiplier: "1.5",
  default_max_retries: "3",
  default_base_delay: "1000",
  default_backoff_multiplier: "2.0"

# Fetcher configuration
config :ledger_bank_api, :fetcher,
  timeout: 15_000,
  max_concurrency: 3,
  retry_attempts: 3

# External API configuration
config :ledger_bank_api, :external_api,
  max_retries: 3,
  retry_delay: 1000,
  timeout: 10_000,
  base_url: "https://example.com"

# JWT configuration
config :ledger_bank_api, :jwt,
  secret_key: System.get_env("JWT_SECRET"),
  algorithm: "HS256",
  issuer: "ledger-bank-api",
  audience: "ledger-bank-api",
  # 1 hour
  access_token_expiry: 3600,
  # 7 days
  refresh_token_expiry: 7 * 24 * 3600

# JWT secret for Joken (unified naming)
config :ledger_bank_api, :jwt_secret, System.get_env("JWT_SECRET")

# Configures the endpoint
config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: LedgerBankApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LedgerBankApi.PubSub,
  live_view: [signing_salt: "lVT9tEM4"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ledger_bank_api, LedgerBankApi.Mailer, adapter: Swoosh.Adapters.Local

# Configure your database
config :ledger_bank_api, LedgerBankApi.Repo, migration_primary_key: [type: :binary_id]

# Configure the telemetry
config :ledger_bank_api, :telemetry,
  enabled: true,
  metrics_interval: 10_000

# Configure logging
config :logger,
  backends: [:console],
  level: :info,
  format: "$time [$level] $message\n",
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

# Configure rate limiting
config :ledger_bank_api, :rate_limit,
  max_requests: 100,
  window_seconds: 60

# Configure caching
config :ledger_bank_api, :cache,
  default_ttl: 300,
  live_snapshot_ttl: 30,
  account_cache_ttl: 300

# Configure cache adapter (pluggable for horizontal scaling)
config :ledger_bank_api,
       :cache_adapter,
       # Default: ETS (single-node)
       LedgerBankApi.Core.Cache.EtsAdapter

# Future: LedgerBankApi.Core.Cache.RedisAdapter for distributed caching

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure OpenAPI/Swagger
config :ledger_bank_api, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: LedgerBankApiWeb.Router,
      endpoint: LedgerBankApiWeb.Endpoint
    ]
  }

# Configure OpenApiSpex
config :ledger_bank_api, :open_api_spex,
  title: "LedgerBankApi",
  version: "1.0.0",
  description: "A modern Elixir/Phoenix API for banking and financial data management",
  server_url: "http://localhost:4000"

# ============================================================================
# PASSWORD HASHING CONFIGURATION
# ============================================================================
# Password hashing configuration for different environments
# This allows for different hashing strategies without Mix.env() coupling

# Default password hashing configuration
config :ledger_bank_api, :password_hashing,
  algorithm: :pbkdf2,
  options: [
    # PBKDF2 options
    iterations: 100_000,
    length: 32,
    digest: :sha256
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# ============================================================================
# OBAN CONFIGURATION (Base)
# ============================================================================
# Base Oban configuration with conservative defaults
# Environment-specific overrides are in dev.exs, test.exs, and runtime.exs
config :ledger_bank_api, Oban,
  repo: LedgerBankApi.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
    # Cron plugin removed - use external schedulers for periodic jobs
  ],
  queues: [
    # Reduced concurrency to avoid overwhelming external APIs
    # and respect rate limits from bank providers
    # Bank API calls (external, slow, rate-limited)
    banking: 3,
    # Payment processing (external, critical)
    payments: 2,
    # Email/SMS notifications (external)
    notifications: 3,
    # Miscellaneous background tasks
    default: 1
  ]

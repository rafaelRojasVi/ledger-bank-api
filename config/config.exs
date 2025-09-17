# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ledger_bank_api,
  ecto_repos: [LedgerBankApi.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Banking context configuration
config :ledger_bank_api, :banking,
  default_page_size: 20,
  max_page_size: 100,
  cache_ttl: 30_000

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
  issuer: "ledger_bank_api",
  audience: "banking_api",
  access_token_expiry: 3600, # 1 hour
  refresh_token_expiry: 7 * 24 * 3600 # 7 days

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
config :ledger_bank_api, LedgerBankApi.Repo,
  migration_primary_key: [type: :binary_id]

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Configure Oban
config :ledger_bank_api, Oban,
  repo: LedgerBankApi.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # {"0 */6 * * *", LedgerBankApi.Workers.BankingDataSyncWorker},
       # {"0 2 * * *", LedgerBankApi.Workers.PaymentProcessingWorker}
     ]}
  ],
  queues: [
    banking: 10,
    payments: 5,
    notifications: 3,
    default: 1
  ]

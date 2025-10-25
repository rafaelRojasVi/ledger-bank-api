import Config

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: LedgerBankApi.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Production financial configuration
config :ledger_bank_api, :financial,
  # Higher limits for production
  checking_daily_limit: "5000.00",
  savings_daily_limit: "2000.00",
  credit_daily_limit: "10000.00",
  investment_daily_limit: "25000.00",
  default_daily_limit: "5000.00",

  # Higher transaction limits
  max_single_transaction: "50000.00",
  duplicate_window_minutes: "10",

  # Stricter password requirements
  admin_password_min_length: "20",
  support_password_min_length: "18",
  user_password_min_length: "12",

  # Production cache settings
  user_cache_ttl: "600",
  account_cache_ttl: "120",
  stats_cache_ttl: "300",
  default_cache_ttl: "600",

  # Production feature flags
  enable_advanced_validation: true,
  enable_duplicate_detection: true,
  enable_circuit_breaker: true,
  enable_telemetry: true,
  enable_rate_limiting: true,
  enable_security_audit: true,

  # Production retry configuration
  external_max_retries: "5",
  external_base_delay: "2000",
  external_backoff_multiplier: "2.5",
  system_max_retries: "3",
  system_base_delay: "1000",
  system_backoff_multiplier: "2.0",
  default_max_retries: "5",
  default_base_delay: "2000",
  default_backoff_multiplier: "2.5"

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

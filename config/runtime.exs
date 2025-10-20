import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/ledger_bank_api start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :ledger_bank_api, LedgerBankApiWeb.Endpoint, server: true
end

# ============================================================================
# OBAN CONFIGURATION (Production/Runtime)
# ============================================================================
# Production-specific Oban overrides
# - Environment-driven queue configuration
# - Production-optimized settings

# Parse queue configuration from environment variables
# Format: "banking:3,payments:2,notifications:3,default:1"
# Defaults are conservative to avoid overwhelming external APIs and respect rate limits
queues =
  System.get_env("OBAN_QUEUES", "banking:3,payments:2,notifications:3,default:1")
  |> String.split(",", trim: true)
  |> Enum.map(fn defn ->
    [name, limit] = String.split(defn, ":", parts: 2)
    {String.to_atom(name), String.to_integer(limit)}
  end)

# Configure Oban with environment-driven settings
config :ledger_bank_api, Oban,
  queues: queues,
  plugins: [
    # Clean up old jobs (7 days)
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
    # Note: Cron jobs removed - use external schedulers or explicit scheduling
    # Bank sync and payment processing should be triggered by business events,
    # not on a fixed schedule. If periodic processing is needed, use an
    # external scheduler (cron, Kubernetes CronJob, etc.) that calls your API
    # to trigger the appropriate jobs.
  ]

# ============================================================================
# OPENTELEMETRY CONFIGURATION (Production/Runtime)
# ============================================================================
# Production-specific OpenTelemetry configuration
# - Environment-driven resource attributes
# - Production-optimized settings

# Configure OpenTelemetry with environment-specific resource attributes
config :opentelemetry,
  resource_attributes: %{
    # Service identification
    "service.name" => System.get_env("OTEL_SERVICE_NAME", "ledger-bank-api"),
    "service.version" => System.get_env("OTEL_SERVICE_VERSION", "1.0.0"),
    "service.namespace" => System.get_env("OTEL_SERVICE_NAMESPACE", "financial"),

    # Deployment information
    "deployment.environment" => System.get_env("DEPLOYMENT_ENVIRONMENT", config_env() |> to_string()),
    "deployment.region" => System.get_env("DEPLOYMENT_REGION", "unknown"),
    "deployment.zone" => System.get_env("DEPLOYMENT_ZONE", "unknown"),
    "deployment.cluster" => System.get_env("DEPLOYMENT_CLUSTER", "unknown"),

    # Instance identification
    "service.instance.id" => System.get_env("HOSTNAME", System.get_env("POD_NAME", "unknown")),
    "k8s.pod.name" => System.get_env("POD_NAME"),
    "k8s.namespace" => System.get_env("K8S_NAMESPACE"),
    "k8s.node.name" => System.get_env("K8S_NODE_NAME"),
    "k8s.container.name" => System.get_env("K8S_CONTAINER_NAME", "ledger-bank-api"),

    # Infrastructure information
    "cloud.provider" => System.get_env("CLOUD_PROVIDER", "unknown"),
    "cloud.region" => System.get_env("CLOUD_REGION", System.get_env("DEPLOYMENT_REGION")),
    "cloud.availability_zone" => System.get_env("CLOUD_AZ", System.get_env("DEPLOYMENT_ZONE")),
    "cloud.account.id" => System.get_env("CLOUD_ACCOUNT_ID"),

    # Application information
    "app.name" => "ledger-bank-api",
    "app.version" => System.get_env("APP_VERSION", "1.0.0"),
    "app.build" => System.get_env("APP_BUILD", "unknown"),
    "app.commit" => System.get_env("APP_COMMIT", "unknown"),

    # Runtime information
    "runtime.name" => "BEAM",
    "runtime.version" => System.get_env("ERLANG_VERSION", "unknown"),
    "runtime.os" => System.get_env("RUNTIME_OS", "unknown"),
    "runtime.arch" => System.get_env("RUNTIME_ARCH", "unknown"),

    # Telemetry SDK information
    "telemetry.sdk.name" => "opentelemetry",
    "telemetry.sdk.language" => "erlang",
    "telemetry.sdk.version" => "1.3.0"
  }
  |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  |> Map.new()

# Configure OpenTelemetry exporter for production
config :opentelemetry_exporter,
  otlp_protocol: System.get_env("OTEL_EXPORTER_OTLP_PROTOCOL", "http_protobuf") |> String.to_atom(),
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318"),
  otlp_headers: %{}

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :ledger_bank_api, LedgerBankApi.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :ledger_bank_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :ledger_bank_api, LedgerBankApiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :ledger_bank_api, LedgerBankApi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

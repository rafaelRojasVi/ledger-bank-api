# OpenTelemetry configuration for distributed tracing
import Config

# OpenTelemetry configuration - disabled until instrumentation packages are available
# config :opentelemetry,
#   span_processor: :batch,
#   exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")

# Service name and version
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "ledger-bank-api"),
  service_version: System.get_env("OTEL_SERVICE_VERSION", "1.0.0")

# Resource attributes - aligned with deployment environment
config :opentelemetry,
  resource_attributes: %{
    # Service identification
    "service.name" => System.get_env("OTEL_SERVICE_NAME", "ledger-bank-api"),
    "service.version" => System.get_env("OTEL_SERVICE_VERSION", "1.0.0"),
    "service.namespace" => System.get_env("OTEL_SERVICE_NAMESPACE", "financial"),

    # Deployment information
    "deployment.environment" => System.get_env("DEPLOYMENT_ENVIRONMENT", Mix.env() |> to_string()),
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

# Sampling configuration
config :opentelemetry,
  sampler: {:parent_based, %{root: :always_on}}

# Instrumentation configurations (disabled - packages not available)
# config :opentelemetry_instrumentation_ecto,
#   traces: [:query]

# config :opentelemetry_instrumentation_phoenix,
#   traces: [:request]

# config :opentelemetry_instrumentation_cowboy,
#   traces: [:request]

# Batch span processor configuration - disabled until instrumentation packages are available
# config :opentelemetry,
#   span_processor: {:batch, %{
#     exporter: :otlp,
#     scheduled_delay_ms: 5000,
#     export_timeout_ms: 30000,
#     max_queue_size: 2048,
#     max_export_batch_size: 512
#   }}

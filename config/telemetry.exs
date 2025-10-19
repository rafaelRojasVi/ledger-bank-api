# OpenTelemetry configuration for distributed tracing
import Config

# OpenTelemetry configuration
config :opentelemetry,
  span_processor: :batch,
  exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")

# Service name and version
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "ledger-bank-api"),
  service_version: System.get_env("OTEL_SERVICE_VERSION", "1.0.0")

# Resource attributes
config :opentelemetry,
  resource_attributes: %{
    "service.name" => "ledger-bank-api",
    "service.version" => "1.0.0",
    "service.instance.id" => System.get_env("HOSTNAME", "unknown"),
    "deployment.environment" => Mix.env(),
    "telemetry.sdk.name" => "opentelemetry",
    "telemetry.sdk.language" => "erlang",
    "telemetry.sdk.version" => "1.3.0"
  }

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

# Batch span processor configuration
config :opentelemetry,
  span_processor: {:batch, %{
    exporter: :otlp,
    scheduled_delay_ms: 5000,
    export_timeout_ms: 30000,
    max_queue_size: 2048,
    max_export_batch_size: 512
  }}

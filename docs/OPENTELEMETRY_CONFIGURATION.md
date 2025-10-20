# OpenTelemetry Configuration Guide

This document explains how to configure OpenTelemetry for the LedgerBankApi application across different deployment environments.

## Overview

OpenTelemetry provides distributed tracing, metrics, and logging capabilities. The application is configured to emit telemetry data with rich resource attributes that help identify the source of telemetry data in your observability platform.

## Configuration Structure

The OpenTelemetry configuration is split across multiple files:

- `config/telemetry.exs` - Base configuration with resource attributes
- `config/runtime.exs` - Runtime configuration with environment-specific overrides

## Resource Attributes

Resource attributes provide context about where telemetry data originates. The application automatically sets these based on environment variables:

### Service Identification
- `service.name` - Service name (default: "ledger-bank-api")
- `service.version` - Service version (default: "1.0.0")
- `service.namespace` - Service namespace (default: "financial")
- `service.instance.id` - Unique instance identifier

### Deployment Information
- `deployment.environment` - Environment (dev/test/prod)
- `deployment.region` - Geographic region
- `deployment.zone` - Availability zone
- `deployment.cluster` - Cluster identifier

### Kubernetes Attributes (when running in K8s)
- `k8s.pod.name` - Pod name
- `k8s.namespace` - Kubernetes namespace
- `k8s.node.name` - Node name
- `k8s.container.name` - Container name

### Cloud Infrastructure
- `cloud.provider` - Cloud provider (aws, gcp, azure, etc.)
- `cloud.region` - Cloud region
- `cloud.availability_zone` - Availability zone
- `cloud.account.id` - Cloud account ID

### Application Information
- `app.name` - Application name
- `app.version` - Application version
- `app.build` - Build identifier
- `app.commit` - Git commit hash

### Runtime Information
- `runtime.name` - Runtime name (BEAM)
- `runtime.version` - Erlang/OTP version
- `runtime.os` - Operating system
- `runtime.arch` - Architecture

## Environment Variables

### Required for Production

```bash
# Service identification
OTEL_SERVICE_NAME=ledger-bank-api
OTEL_SERVICE_VERSION=1.0.0
OTEL_SERVICE_NAMESPACE=financial

# Deployment information
DEPLOYMENT_ENVIRONMENT=prod
DEPLOYMENT_REGION=us-west-2
DEPLOYMENT_ZONE=us-west-2a
DEPLOYMENT_CLUSTER=production

# Instance identification
HOSTNAME=ledger-bank-api-12345
POD_NAME=ledger-bank-api-12345  # For Kubernetes

# Infrastructure information
CLOUD_PROVIDER=aws
CLOUD_REGION=us-west-2
CLOUD_AZ=us-west-2a
CLOUD_ACCOUNT_ID=123456789012

# Application information
APP_VERSION=1.0.0
APP_BUILD=build-123
APP_COMMIT=abc123def456

# Runtime information
ERLANG_VERSION=26.0
RUNTIME_OS=linux
RUNTIME_ARCH=x86_64
```

### OpenTelemetry Exporter Configuration

```bash
# OTLP Exporter settings
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http_protobuf
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer token,User-Agent=ledger-bank-api"
```

## Deployment Examples

### Local Development

```bash
# Minimal configuration for local development
export OTEL_SERVICE_NAME=ledger-bank-api
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

### Docker Compose

```yaml
version: '3.8'
services:
  ledger-bank-api:
    image: ledger-bank-api:latest
    environment:
      - OTEL_SERVICE_NAME=ledger-bank-api
      - OTEL_SERVICE_VERSION=1.0.0
      - DEPLOYMENT_ENVIRONMENT=dev
      - DEPLOYMENT_REGION=local
      - HOSTNAME=ledger-bank-api-dev
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-bank-api
spec:
  template:
    spec:
      containers:
      - name: ledger-bank-api
        image: ledger-bank-api:latest
        env:
        - name: OTEL_SERVICE_NAME
          value: "ledger-bank-api"
        - name: OTEL_SERVICE_VERSION
          value: "1.0.0"
        - name: DEPLOYMENT_ENVIRONMENT
          value: "prod"
        - name: DEPLOYMENT_REGION
          valueFrom:
            fieldRef:
              fieldPath: metadata.labels['topology.kubernetes.io/region']
        - name: DEPLOYMENT_ZONE
          valueFrom:
            fieldRef:
              fieldPath: metadata.labels['topology.kubernetes.io/zone']
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: K8S_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: K8S_CONTAINER_NAME
          value: "ledger-bank-api"
        - name: CLOUD_PROVIDER
          value: "aws"
        - name: CLOUD_ACCOUNT_ID
          value: "123456789012"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://jaeger-collector:4318"
```

### AWS ECS

```json
{
  "family": "ledger-bank-api",
  "taskDefinition": {
    "containerDefinitions": [
      {
        "name": "ledger-bank-api",
        "image": "ledger-bank-api:latest",
        "environment": [
          {"name": "OTEL_SERVICE_NAME", "value": "ledger-bank-api"},
          {"name": "OTEL_SERVICE_VERSION", "value": "1.0.0"},
          {"name": "DEPLOYMENT_ENVIRONMENT", "value": "prod"},
          {"name": "DEPLOYMENT_REGION", "value": "us-west-2"},
          {"name": "CLOUD_PROVIDER", "value": "aws"},
          {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "http://jaeger:4318"}
        ]
      }
    ]
  }
}
```

## Observability Platform Integration

### Jaeger

```bash
# Jaeger collector endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector:4318
```

### DataDog

```bash
# DataDog APM endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=https://trace.agent.datadoghq.com:4318
OTEL_EXPORTER_OTLP_HEADERS="DD-API-KEY=your-api-key"
```

### New Relic

```bash
# New Relic OTLP endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp.nr-data.net:4318
OTEL_EXPORTER_OTLP_HEADERS="api-key=your-license-key"
```

### Honeycomb

```bash
# Honeycomb OTLP endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io:443
OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=your-api-key"
```

## Sampling Configuration

The application uses parent-based sampling:

```elixir
config :opentelemetry,
  sampler: {:parent_based, %{root: :always_on}}
```

This means:
- If a trace is already started (has a parent), follow the parent's sampling decision
- If starting a new trace (root span), always sample

For production, consider using probabilistic sampling:

```elixir
config :opentelemetry,
  sampler: {:trace_id_ratio_based, 0.1}  # Sample 10% of traces
```

## Troubleshooting

### Common Issues

1. **No traces appearing**: Check that `OTEL_EXPORTER_OTLP_ENDPOINT` is correct and accessible
2. **Missing resource attributes**: Ensure environment variables are set correctly
3. **High memory usage**: Consider reducing sampling rate or batch size

### Debug Mode

Enable debug logging:

```bash
export OTEL_LOG_LEVEL=debug
```

### Verification

Check that telemetry is being emitted:

```bash
# Check if spans are being created
curl -X GET http://localhost:4318/v1/traces

# Check resource attributes
curl -X GET http://localhost:4318/v1/resource
```

## Best Practices

1. **Set meaningful service names**: Use consistent naming across environments
2. **Include version information**: Helps with debugging and rollbacks
3. **Use deployment attributes**: Helps identify which deployment caused issues
4. **Monitor resource usage**: Telemetry can impact performance
5. **Configure appropriate sampling**: Balance between observability and performance

## Security Considerations

1. **Secure endpoints**: Use HTTPS for OTLP endpoints in production
2. **Authentication**: Include API keys in OTLP headers
3. **Network policies**: Restrict access to telemetry endpoints
4. **Data privacy**: Be careful with sensitive data in spans

## Performance Impact

OpenTelemetry has minimal performance impact when configured correctly:

- **CPU**: < 1% overhead
- **Memory**: ~10MB additional memory usage
- **Network**: Minimal bandwidth usage with batching
- **Latency**: < 1ms additional latency per request

Monitor these metrics in production and adjust sampling if needed.

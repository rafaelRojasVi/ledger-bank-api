# Configuration Guide

This document describes the configuration options available in the LedgerBank API, including financial limits, feature flags, and environment-specific settings.

## Overview

The LedgerBank API uses a hierarchical configuration system that allows for environment-specific customization without code changes:

1. **Environment Variables** (highest priority) - Production overrides
2. **Runtime Configuration** - Staging/development overrides  
3. **Application Configuration** - Default values
4. **Hardcoded Defaults** - Fallback values

## Financial Configuration

### Daily Limits by Account Type

Configure daily spending limits for different account types:

```elixir
# Environment variables (production)
export CHECKING_DAILY_LIMIT="5000.00"
export SAVINGS_DAILY_LIMIT="2000.00"
export CREDIT_DAILY_LIMIT="10000.00"
export INVESTMENT_DAILY_LIMIT="25000.00"
export DEFAULT_DAILY_LIMIT="5000.00"

# Or in config files
config :ledger_bank_api, :financial,
  checking_daily_limit: "5000.00",
  savings_daily_limit: "2000.00",
  credit_daily_limit: "10000.00",
  investment_daily_limit: "25000.00",
  default_daily_limit: "5000.00"
```

### Transaction Limits

```elixir
# Maximum single transaction amount
config :ledger_bank_api, :financial,
  max_single_transaction: "50000.00",
  duplicate_window_minutes: "10"
```

### Password Requirements

Configure minimum password length by role:

```elixir
config :ledger_bank_api, :financial,
  admin_password_min_length: "20",
  support_password_min_length: "18",
  user_password_min_length: "12"
```

## Feature Flags

Enable or disable features at runtime:

```elixir
config :ledger_bank_api, :financial,
  enable_advanced_validation: true,
  enable_duplicate_detection: true,
  enable_circuit_breaker: true,
  enable_telemetry: true,
  enable_rate_limiting: true,
  enable_security_audit: true
```

### Feature Descriptions

- **advanced_validation**: Enables additional business rule validation
- **duplicate_detection**: Enables duplicate transaction detection
- **circuit_breaker**: Enables circuit breaker pattern for external services
- **telemetry**: Enables telemetry and metrics collection
- **rate_limiting**: Enables API rate limiting
- **security_audit**: Enables security audit logging

## Cache Configuration

Configure cache TTL (Time To Live) for different data types:

```elixir
config :ledger_bank_api, :financial,
  user_cache_ttl: "600",        # 10 minutes
  account_cache_ttl: "120",     # 2 minutes
  stats_cache_ttl: "300",      # 5 minutes
  default_cache_ttl: "600"      # 10 minutes
```

## Retry Configuration

Configure retry behavior for different error types:

```elixir
config :ledger_bank_api, :financial,
  # External dependency errors (API calls, database connections)
  external_max_retries: "5",
  external_base_delay: "2000",      # 2 seconds
  external_backoff_multiplier: "2.5",
  
  # System errors (internal processing)
  system_max_retries: "3",
  system_base_delay: "1000",       # 1 second
  system_backoff_multiplier: "2.0",
  
  # Default retry settings
  default_max_retries: "5",
  default_base_delay: "2000",
  default_backoff_multiplier: "2.5"
```

## Environment-Specific Configurations

### Development

```elixir
# config/dev.exs
config :ledger_bank_api, :financial,
  # Lower limits for development
  checking_daily_limit: "1000.00",
  max_single_transaction: "10000.00",
  
  # Relaxed password requirements
  user_password_min_length: "8",
  
  # Feature flags for development
  enable_advanced_validation: false,
  enable_telemetry: true
```

### Testing

```elixir
# config/test.exs
config :ledger_bank_api, :financial,
  # Very low limits for testing
  checking_daily_limit: "100.00",
  max_single_transaction: "1000.00",
  
  # Relaxed requirements for testing
  user_password_min_length: "6",
  
  # Disable most features for testing
  enable_advanced_validation: false,
  enable_telemetry: false,
  enable_rate_limiting: false
```

### Production

```elixir
# config/prod.exs
config :ledger_bank_api, :financial,
  # Higher limits for production
  checking_daily_limit: "5000.00",
  max_single_transaction: "50000.00",
  
  # Stricter requirements for production
  user_password_min_length: "12",
  
  # Enable all features for production
  enable_advanced_validation: true,
  enable_telemetry: true,
  enable_rate_limiting: true
```

## Environment Variables

For production deployments, you can override any configuration using environment variables:

```bash
# Financial limits
export CHECKING_DAILY_LIMIT="10000.00"
export MAX_SINGLE_TRANSACTION="100000.00"

# Password requirements
export USER_PASSWORD_MIN_LENGTH="15"

# Feature flags
export ENABLE_ADVANCED_VALIDATION="true"
export ENABLE_RATE_LIMITING="true"

# Cache settings
export USER_CACHE_TTL="900"
export ACCOUNT_CACHE_TTL="300"

# Retry settings
export EXTERNAL_MAX_RETRIES="3"
export EXTERNAL_BASE_DELAY="1000"
```

## Configuration Validation

The application validates configuration on startup to ensure all values are valid:

- Financial limits must be positive numbers
- Password requirements must be at least 6 characters
- Cache TTL values must be non-negative
- Retry settings must have valid values

If validation fails, the application will not start and will log the specific error.

## Runtime Configuration Changes

Some configuration values can be changed at runtime using the `FinancialConfig` module:

```elixir
# Check current configuration
LedgerBankApi.Core.FinancialConfig.get_config_summary()

# Check if a feature is enabled
LedgerBankApi.Core.FinancialConfig.feature_enabled?(:advanced_validation)

# Get current limits
LedgerBankApi.Core.FinancialConfig.daily_limit("CHECKING")
LedgerBankApi.Core.FinancialConfig.max_single_transaction_limit()
```

## Best Practices

1. **Use environment variables for production** - Allows changes without code deployment
2. **Set appropriate limits per environment** - Development should have lower limits than production
3. **Enable all features in production** - Ensure security and monitoring are active
4. **Disable non-essential features in testing** - Focus on core functionality
5. **Monitor configuration changes** - Log when configuration values change
6. **Validate before deployment** - Test configuration changes in staging first

## Troubleshooting

### Configuration Not Loading

Check the application logs for configuration validation errors:

```bash
# Check if configuration validation passed
grep "Financial configuration validated" logs/app.log

# Check for validation errors
grep "configuration validation failed" logs/app.log
```

### Feature Flags Not Working

Verify the feature flag is enabled:

```elixir
# In IEx console
LedgerBankApi.Core.FinancialConfig.feature_enabled?(:advanced_validation)
```

### Limits Not Applied

Check if the configuration is being used:

```elixir
# Check current limits
LedgerBankApi.Core.FinancialConfig.get_daily_limits()
LedgerBankApi.Core.FinancialConfig.max_single_transaction_limit()
```

## Security Considerations

- **Password requirements**: Set appropriate minimum lengths for each role
- **Transaction limits**: Set reasonable limits to prevent abuse
- **Feature flags**: Disable unnecessary features in production
- **Environment variables**: Use secure methods to set sensitive configuration
- **Validation**: Always validate configuration values before use

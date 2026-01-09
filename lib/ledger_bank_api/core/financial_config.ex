defmodule LedgerBankApi.Core.FinancialConfig do
  @moduledoc """
  Financial configuration management with environment-driven settings.

  This module provides centralized access to financial limits, rules, and settings
  that can be configured per environment without code changes.

  ## Configuration Sources (in order of precedence):
  1. Environment variables (production)
  2. Runtime configuration (staging)
  3. Application configuration (development)
  4. Default values (fallback)

  ## Usage

      # Get daily limit for account type
      FinancialConfig.daily_limit("CHECKING")
      # => Decimal.new("1000.00")

      # Get max single transaction limit
      FinancialConfig.max_single_transaction_limit()
      # => Decimal.new("10000.00")

      # Check if feature is enabled
      FinancialConfig.feature_enabled?(:advanced_validation)
      # => true
  """

  require Logger

  @doc """
  Get daily spending limit for account type.
  """
  def daily_limit(account_type) do
    limits = get_daily_limits()
    Map.get(limits, account_type, limits["DEFAULT"])
  end

  @doc """
  Get maximum single transaction limit.
  """
  def max_single_transaction_limit do
    get_config_value(:max_single_transaction, "10000.00")
    |> Decimal.new()
  end

  @doc """
  Get duplicate transaction detection window in minutes.
  """
  def duplicate_detection_window_minutes do
    get_config_value(:duplicate_window_minutes, "5")
    |> String.to_integer()
  end

  @doc """
  Get password requirements by role.
  """
  def password_min_length(role) do
    requirements = get_password_requirements()
    Map.get(requirements, role, requirements["user"])
  end

  @doc """
  Get cache TTL settings.
  """
  def cache_ttl(type) do
    ttl_settings = get_cache_ttl_settings()
    Map.get(ttl_settings, type, ttl_settings["default"])
  end

  @doc """
  Check if a feature flag is enabled.
  """
  def feature_enabled?(feature) do
    features = get_feature_flags()
    Map.get(features, feature, false)
  end

  @doc """
  Get retry configuration for error types.
  """
  def retry_config(error_type) do
    retry_settings = get_retry_settings()
    Map.get(retry_settings, error_type, retry_settings["default"])
  end

  @doc """
  Get all daily limits as a map.
  """
  def get_daily_limits do
    %{
      "CHECKING" => get_config_value(:checking_daily_limit, "1000.00") |> Decimal.new(),
      "SAVINGS" => get_config_value(:savings_daily_limit, "500.00") |> Decimal.new(),
      "CREDIT" => get_config_value(:credit_daily_limit, "2000.00") |> Decimal.new(),
      "INVESTMENT" => get_config_value(:investment_daily_limit, "5000.00") |> Decimal.new(),
      "DEFAULT" => get_config_value(:default_daily_limit, "1000.00") |> Decimal.new()
    }
  end

  @doc """
  Get password requirements by role.
  """
  def get_password_requirements do
    %{
      "admin" => get_config_value(:admin_password_min_length, "15") |> String.to_integer(),
      "support" => get_config_value(:support_password_min_length, "15") |> String.to_integer(),
      "user" => get_config_value(:user_password_min_length, "8") |> String.to_integer()
    }
  end

  @doc """
  Get cache TTL settings in seconds.
  """
  def get_cache_ttl_settings do
    %{
      "user" => get_config_value(:user_cache_ttl, "300") |> String.to_integer(),
      "account" => get_config_value(:account_cache_ttl, "60") |> String.to_integer(),
      "statistics" => get_config_value(:stats_cache_ttl, "60") |> String.to_integer(),
      "default" => get_config_value(:default_cache_ttl, "300") |> String.to_integer()
    }
  end

  @doc """
  Get feature flags configuration.
  """
  def get_feature_flags do
    %{
      :advanced_validation => get_config_boolean(:enable_advanced_validation, false),
      :duplicate_detection => get_config_boolean(:enable_duplicate_detection, true),
      :circuit_breaker => get_config_boolean(:enable_circuit_breaker, true),
      :telemetry => get_config_boolean(:enable_telemetry, true),
      :rate_limiting => get_config_boolean(:enable_rate_limiting, true),
      :security_audit => get_config_boolean(:enable_security_audit, true)
    }
  end

  @doc """
  Get retry configuration for different error types.
  """
  def get_retry_settings do
    %{
      "external_dependency" => %{
        max_retries: get_config_value(:external_max_retries, "3") |> String.to_integer(),
        base_delay: get_config_value(:external_base_delay, "1000") |> String.to_integer(),
        backoff_multiplier:
          get_config_value(:external_backoff_multiplier, "2.0") |> String.to_float()
      },
      "system" => %{
        max_retries: get_config_value(:system_max_retries, "2") |> String.to_integer(),
        base_delay: get_config_value(:system_base_delay, "500") |> String.to_integer(),
        backoff_multiplier:
          get_config_value(:system_backoff_multiplier, "1.5") |> String.to_float()
      },
      "default" => %{
        max_retries: get_config_value(:default_max_retries, "3") |> String.to_integer(),
        base_delay: get_config_value(:default_base_delay, "1000") |> String.to_integer(),
        backoff_multiplier:
          get_config_value(:default_backoff_multiplier, "2.0") |> String.to_float()
      }
    }
  end

  @doc """
  Validate configuration on startup.
  """
  def validate_configuration do
    with :ok <- validate_financial_limits(),
         :ok <- validate_password_requirements(),
         :ok <- validate_cache_settings(),
         :ok <- validate_retry_settings() do
      Logger.info("Financial configuration validated successfully")
      :ok
    else
      {:error, reason} ->
        Logger.error("Financial configuration validation failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Get configuration summary for debugging.
  """
  def get_config_summary do
    %{
      daily_limits: get_daily_limits(),
      max_single_transaction: max_single_transaction_limit(),
      duplicate_window: duplicate_detection_window_minutes(),
      password_requirements: get_password_requirements(),
      cache_ttl: get_cache_ttl_settings(),
      feature_flags: get_feature_flags(),
      retry_settings: get_retry_settings()
    }
  end

  # Private helper functions

  defp get_config_value(key, default) do
    # Try environment variable first (production)
    env_key = key |> Atom.to_string() |> String.upcase()

    case System.get_env(env_key) do
      nil ->
        # Try application config - convert keyword list to map
        config = Application.get_env(:ledger_bank_api, :financial, %{})
        config_map = if is_list(config), do: Map.new(config), else: config
        Map.get(config_map, key, default)

      value ->
        value
    end
  end

  defp get_config_boolean(key, default) do
    case get_config_value(key, to_string(default)) do
      "true" -> true
      "false" -> false
      "1" -> true
      "0" -> false
      _ -> default
    end
  end

  defp validate_financial_limits do
    limits = get_daily_limits()

    Enum.each(limits, fn {account_type, limit} ->
      if Decimal.lt?(limit, Decimal.new("0")) do
        raise "Invalid daily limit for #{account_type}: #{limit}"
      end
    end)

    max_transaction = max_single_transaction_limit()

    if Decimal.lt?(max_transaction, Decimal.new("0")) do
      raise "Invalid max single transaction limit: #{max_transaction}"
    end

    :ok
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp validate_password_requirements do
    requirements = get_password_requirements()

    Enum.each(requirements, fn {role, min_length} ->
      if min_length < 6 do
        raise "Password minimum length for #{role} too low: #{min_length}"
      end
    end)

    :ok
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp validate_cache_settings do
    ttl_settings = get_cache_ttl_settings()

    Enum.each(ttl_settings, fn {type, ttl} ->
      if ttl < 0 do
        raise "Invalid cache TTL for #{type}: #{ttl}"
      end
    end)

    :ok
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp validate_retry_settings do
    retry_settings = get_retry_settings()

    Enum.each(retry_settings, fn {error_type, config} ->
      if config.max_retries < 0 or config.base_delay < 0 or config.backoff_multiplier < 1.0 do
        raise "Invalid retry config for #{error_type}: #{inspect(config)}"
      end
    end)

    :ok
  rescue
    error -> {:error, Exception.message(error)}
  end
end

defmodule LedgerBankApi.Core.Cache.RedisAdapter do
  @moduledoc """
  Redis-based cache adapter implementation.

  Provides distributed caching using Redis for multi-node deployments.
  Suitable for horizontal scaling scenarios.

  ## Characteristics

  - **Distributed** - Shared cache across all nodes
  - **Persistent** - Survives application restarts (if Redis persistence enabled)
  - **Scalable** - Handles high throughput
  - **TTL support** - Automatic expiration
  - **Connection pooling** - Efficient connection management

  ## Configuration

      # config/runtime.exs or config/prod.exs
      config :ledger_bank_api, :cache_adapter,
        LedgerBankApi.Core.Cache.RedisAdapter

      config :ledger_bank_api, :redis,
        url: System.get_env("REDIS_URL", "redis://localhost:6379"),
        pool_size: 10,
        reconnect_on_error: true

  ## Limitations

  - Requires Redis server running
  - Network latency (vs in-memory ETS)
  - Additional infrastructure dependency
  """

  @behaviour LedgerBankApi.Core.CacheAdapter

  require Logger
  alias LedgerBankApiWeb.Logger, as: AppLogger

  @default_ttl 300
  @max_ttl 3600
  @connection_name :ledger_cache_redis

  # ============================================================================
  # CACHE ADAPTER CALLBACKS
  # ============================================================================

  @impl true
  def init do
    redis_url = get_redis_url()
    pool_size = get_pool_size()

    case start_redix_pool(redis_url, pool_size) do
      :ok ->
        Logger.info("Redis cache adapter initialized successfully", %{
          url: sanitize_url(redis_url),
          pool_size: pool_size
        })

        :ok

      {:error, reason} ->
        Logger.error("Failed to initialize Redis cache adapter: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get(key) do
    case Redix.command(@connection_name, ["GET", encode_key(key)]) do
      {:ok, nil} ->
        AppLogger.log_business_event("cache_miss_not_found", %{key: key})
        :not_found

      {:ok, value} ->
        case decode_value(value) do
          {:ok, decoded_value} ->
            # Update access count (stored separately)
            update_access_count(key)
            AppLogger.log_business_event("cache_hit", %{key: key})
            {:ok, decoded_value}

          {:error, reason} ->
            Logger.warning("Failed to decode cached value for key #{key}: #{inspect(reason)}")
            :not_found
        end

      {:error, %Redix.Error{message: message}} ->
        Logger.error("Redis GET failed for key #{key}: #{message}")
        :not_found

      {:error, reason} ->
        Logger.error("Redis GET failed for key #{key}: #{inspect(reason)}")
        :not_found

      other ->
        Logger.error("Unexpected Redis response for key #{key}: #{inspect(other)}")
        :not_found
    end
  end

  @impl true
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    ttl = min(ttl, @max_ttl)

    encoded_key = encode_key(key)
    encoded_value = encode_value(value)

    # Store value with TTL
    case Redix.command(@connection_name, [
           "SETEX",
           encoded_key,
           Integer.to_string(ttl),
           encoded_value
         ]) do
      {:ok, "OK"} ->
        # Store metadata (created_at, access_count)
        metadata_key = metadata_key(key)

        metadata = %{
          created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          access_count: 0,
          ttl: ttl
        }

        Redix.command(@connection_name, ["SET", metadata_key, encode_value(metadata)])
        AppLogger.log_business_event("cache_put", %{key: key, ttl: ttl})
        :ok

      {:error, %Redix.Error{message: message}} ->
        Logger.error("Redis SETEX failed for key #{key}: #{message}")
        :ok

      # Return :ok even on error to avoid breaking application flow

      {:error, reason} ->
        Logger.error("Redis SETEX failed for key #{key}: #{inspect(reason)}")
        :ok

      other ->
        Logger.error("Unexpected Redis response for SETEX key #{key}: #{inspect(other)}")
        :ok
    end
  end

  @impl true
  def get_or_put(key, fun, opts \\ []) when is_function(fun, 0) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}

      :not_found ->
        # Compute the value
        case fun.() do
          {:ok, value} ->
            put(key, value, opts)
            {:ok, value}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @impl true
  def delete(key) do
    encoded_key = encode_key(key)
    metadata_key = metadata_key(key)

    # Delete both value and metadata
    Redix.command(@connection_name, ["DEL", encoded_key, metadata_key])
    AppLogger.log_business_event("cache_delete", %{key: key})
    :ok
  end

  @impl true
  def clear do
    # Get all keys with our prefix
    pattern = encode_key("*")

    case Redix.command(@connection_name, ["KEYS", pattern]) do
      {:ok, keys} when is_list(keys) ->
        if length(keys) > 0 do
          Redix.command(@connection_name, ["DEL" | keys])
        end

        AppLogger.log_business_event("cache_clear", %{keys_cleared: length(keys)})
        :ok

      {:error, reason} ->
        Logger.error("Redis KEYS failed during clear: #{inspect(reason)}")
        :ok
    end
  end

  @impl true
  def stats do
    pattern = encode_key("*")

    case Redix.command(@connection_name, ["KEYS", pattern]) do
      {:ok, keys} when is_list(keys) ->
        # Filter out metadata keys
        value_keys = Enum.filter(keys, fn k -> not String.ends_with?(k, ":meta") end)
        metadata_keys = Enum.filter(keys, fn k -> String.ends_with?(k, ":meta") end)

        # Get access counts from metadata
        access_counts =
          Enum.map(metadata_keys, fn meta_key ->
            case Redix.command(@connection_name, ["GET", meta_key]) do
              {:ok, nil} ->
                0

              {:ok, encoded_meta} ->
                case decode_value(encoded_meta) do
                  {:ok, %{access_count: count}} -> count
                  _ -> 0
                end

              _ ->
                0
            end
          end)

        total_access_count = Enum.sum(access_counts)

        stats = %{
          total_entries: length(value_keys),
          active_entries: length(value_keys),
          expired_entries: 0,
          total_access_count: total_access_count,
          average_access_count:
            if length(value_keys) > 0 do
              total_access_count / length(value_keys)
            else
              0
            end,
          adapter: "redis"
        }

        AppLogger.log_business_event("cache_stats", stats)
        stats

      {:error, reason} ->
        Logger.error("Redis KEYS failed during stats: #{inspect(reason)}")

        %{
          total_entries: 0,
          active_entries: 0,
          expired_entries: 0,
          total_access_count: 0,
          average_access_count: 0,
          adapter: "redis"
        }
    end
  end

  @impl true
  def cleanup do
    # Redis handles TTL automatically, but we can clean up metadata for expired keys
    pattern = encode_key("*")

    case Redix.command(@connection_name, ["KEYS", pattern]) do
      {:ok, keys} when is_list(keys) ->
        # Check which value keys are expired
        value_keys = Enum.filter(keys, fn k -> not String.ends_with?(k, ":meta") end)

        expired_keys =
          Enum.filter(value_keys, fn key ->
            case Redix.command(@connection_name, ["TTL", key]) do
              {:ok, -1} -> true
              {:ok, -2} -> true
              {:ok, _ttl} -> false
              _ -> false
            end
          end)

        # Delete expired keys and their metadata
        if length(expired_keys) > 0 do
          metadata_keys = Enum.map(expired_keys, &metadata_key/1)
          all_keys_to_delete = expired_keys ++ metadata_keys
          Redix.command(@connection_name, ["DEL" | all_keys_to_delete])
        end

        AppLogger.log_business_event("cache_cleanup", %{
          expired_entries_removed: length(expired_keys)
        })

        length(expired_keys)

      {:error, reason} ->
        Logger.error("Redis cleanup failed: #{inspect(reason)}")
        0
    end
  end

  @impl true
  def get_entry_details(key) do
    encoded_key = encode_key(key)
    metadata_key = metadata_key(key)

    with {:ok, value} <- Redix.command(@connection_name, ["GET", encoded_key]),
         {:ok, ttl} <- Redix.command(@connection_name, ["TTL", encoded_key]),
         {:ok, metadata_encoded} <- Redix.command(@connection_name, ["GET", metadata_key]),
         {:ok, metadata} <- decode_value(metadata_encoded || "{}") do
      if value == nil,
        do: nil,
        else: %{
          key: key,
          value: decode_value(value) |> elem(1),
          created_at: parse_datetime(metadata[:created_at] || metadata["created_at"]),
          expires_at: calculate_expires_at(ttl),
          access_count: metadata[:access_count] || metadata["access_count"] || 0,
          is_expired: ttl < 0,
          ttl_remaining: if(ttl > 0, do: ttl, else: 0),
          adapter: "redis"
        }
    else
      {:ok, nil} ->
        nil

      {:error, reason} ->
        Logger.warning("Failed to get entry details for #{key}: #{inspect(reason)}")
        nil
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp start_redix_pool(url, _pool_size) when is_binary(url) do
    # Redix.start_link/2 expects (uri_string, options); name is in options
    case Redix.start_link(url, name: @connection_name) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_redis_url do
    Application.get_env(:ledger_bank_api, :redis, [])
    |> Keyword.get(:url, System.get_env("REDIS_URL", "redis://localhost:6379"))
  end

  defp get_pool_size do
    Application.get_env(:ledger_bank_api, :redis, [])
    |> Keyword.get(:pool_size, 10)
  end

  defp encode_key(key) when is_binary(key) do
    "ledger_cache:#{key}"
  end

  defp metadata_key(key) do
    "#{encode_key(key)}:meta"
  end

  defp encode_value(value) do
    Jason.encode!(value)
  end

  defp decode_value(encoded) when is_binary(encoded) do
    Jason.decode(encoded)
  end

  defp decode_value(nil), do: {:error, :nil_value}

  defp update_access_count(key) do
    metadata_key = metadata_key(key)

    case Redix.command(@connection_name, ["GET", metadata_key]) do
      {:ok, nil} ->
        # Create new metadata
        metadata = %{access_count: 1, created_at: DateTime.utc_now() |> DateTime.to_iso8601()}
        Redix.command(@connection_name, ["SET", metadata_key, encode_value(metadata)])

      {:ok, encoded_meta} ->
        case decode_value(encoded_meta) do
          {:ok, metadata} ->
            updated_count = (metadata["access_count"] || metadata[:access_count] || 0) + 1
            updated_metadata = Map.put(metadata, "access_count", updated_count)
            Redix.command(@connection_name, ["SET", metadata_key, encode_value(updated_metadata)])

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp calculate_expires_at(ttl) when ttl > 0 do
    DateTime.add(DateTime.utc_now(), ttl, :second)
  end

  defp calculate_expires_at(_), do: DateTime.utc_now()

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(dt), do: dt

  defp sanitize_url(url) do
    # Remove password from URL for logging
    String.replace(url, ~r/:[^:@]+@/, ":****@")
  end
end

defmodule LedgerBankApi.Database.CacheMacros do
  @moduledoc """
  Macros for standardizing cache operation patterns to reduce code repetition.
  """

  import LedgerBankApi.Database.Macros

  @doc """
  Macro to generate cache operations with error handling.

  Usage:
    use_cache_operations()
  """
  defmacro use_cache_operations do
    quote do
      @doc """
      Gets a value from cache with standardized return pattern.
      Returns {:ok, value} or {:error, :not_found}.
      """
      def get(key) do
        with_error_handling(:cache_get, %{key: key}) do
          case :ets.lookup(:ledger_cache, key) do
            [{^key, value, expires_at}] ->
              now = System.system_time(:second)

              if now < expires_at do
                {:ok, value}
              else
                :ets.delete(:ledger_cache, key)
                {:error, :not_found}
              end

            [] ->
              {:error, :not_found}
          end
        end
      end

      @doc """
      Sets a value in cache with TTL and standardized return pattern.
      Returns {:ok, value} or {:error, reason}.
      """
      def set(key, value, ttl \\ 300) do
        with_error_handling(:cache_set, %{key: key, ttl: ttl}) do
          expires_at = System.system_time(:second) + ttl
          :ets.insert(:ledger_cache, {key, value, expires_at})
          {:ok, value}
        end
      end

      @doc """
      Deletes a value from cache with standardized return pattern.
      Returns {:ok, :deleted} or {:error, reason}.
      """
      def delete(key) do
        with_error_handling(:cache_delete, %{key: key}) do
          :ets.delete(:ledger_cache, key)
          {:ok, :deleted}
        end
      end

      @doc """
      Invalidates cache by pattern with standardized return pattern.
      Returns {:ok, deleted_count} or {:error, reason}.
      NOTE: As written, this clears ALL entries. Adjust the match-spec for true pattern invalidation.
      """
      def invalidate_pattern(pattern) do
        _ = pattern
        with_error_handling(:cache_invalidate_pattern, %{pattern: pattern}) do
          deleted_count = :ets.select_delete(:ledger_cache, [{{:_, :_, :_}, [], [true]}])
          {:ok, deleted_count}
        end
      end

      @doc """
      Gets cache statistics for monitoring.
      Returns {:ok, stats} or {:error, reason}.
      """
      def get_stats do
        with_error_handling(:get_cache_stats, %{}) do
          total_entries = :ets.info(:ledger_cache, :size)
          memory_words  = :ets.info(:ledger_cache, :memory)
          word_size     = :erlang.system_info(:wordsize)

          {:ok,
           %{
             total_entries: total_entries,
             memory_usage_bytes: memory_words * word_size,
             cache_ttl_seconds: 300
           }}
        end
      end

      @doc """
      Clears all cache entries with standardized return pattern.
      Returns {:ok, deleted_count} or {:error, reason}.
      """
      def clear_all do
        with_error_handling(:clear_all_cache, %{}) do
          deleted_count = :ets.select_delete(:ledger_cache, [{{:_, :_, :_}, [], [true]}])
          {:ok, deleted_count}
        end
      end

      @doc """
      Cleans up expired cache entries.
      Returns {:ok, deleted_count} or {:error, reason}.
      """
      def cleanup_expired do
        with_error_handling(:cleanup_expired_cache, %{}) do
          now = System.system_time(:second)

          # Delete entries where expires_at <= now
          deleted_count =
            :ets.select_delete(
              :ledger_cache,
              [
                {{:_, :_, :"$1"}, [{:"=<", :"$1", now}], [true]}
              ]
            )

          {:ok, deleted_count}
        end
      end
    end
  end

  @doc """
  Macro to generate cache operations for specific data types.

  Usage:
    use_typed_cache_operations(:account_balance, "account_balance", 60)
    use_typed_cache_operations(:user_accounts, "user_accounts", 300)
  """
  defmacro use_typed_cache_operations(type, cache_prefix, default_ttl) do
    get_fn_name = String.to_atom("get_#{type}")
    set_fn_name = String.to_atom("set_#{type}")
    invalidate_fn_name = String.to_atom("invalidate_#{type}")
    fallback_fn_name = String.to_atom("get_#{type}_with_fallback")

    quote do
      @doc """
      Gets #{unquote(type)} from cache.
      """
      def unquote(get_fn_name)(id) do
        cache_key = "#{unquote(cache_prefix)}:#{id}"
        get(cache_key)
      end

      @doc """
      Sets #{unquote(type)} in cache.
      """
      def unquote(set_fn_name)(id, value, ttl \\ unquote(default_ttl)) do
        cache_key = "#{unquote(cache_prefix)}:#{id}"
        set(cache_key, value, ttl)
      end

      @doc """
      Invalidates #{unquote(type)} cache.
      """
      def unquote(invalidate_fn_name)(id) do
        cache_key = "#{unquote(cache_prefix)}:#{id}"
        delete(cache_key)
      end

      @doc """
      Gets #{unquote(type)} with fallback to database.
      """
      def unquote(fallback_fn_name)(id, fallback_fun) do
        case unquote(get_fn_name)(id) do
          {:ok, value} ->
            {:ok, value}

          {:error, :not_found} ->
            case fallback_fun.() do
              {:ok, value} ->
                unquote(set_fn_name)(id, value)
                {:ok, value}

              error ->
                error
            end
        end
      end
    end
  end
end

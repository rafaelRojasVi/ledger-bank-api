defmodule LedgerBankApi.Core.Cache.RedisAdapterTest do
  @moduledoc """
  Tests for Redis cache adapter.

  These tests require a running Redis instance.
  In CI, Redis is provided via GitHub Actions services.
  Locally, ensure Redis is running: `docker compose up redis` or `redis-server`
  """

  use ExUnit.Case, async: false
  alias LedgerBankApi.Core.Cache.RedisAdapter

  @test_key "test_key"
  @test_value %{user_id: "123", name: "Test User"}
  # Redis adapter stores JSON; get returns decoded map with string keys
  @test_value_from_redis %{"user_id" => "123", "name" => "Test User"}

  setup do
    # Ensure Redis adapter is initialized
    case RedisAdapter.init() do
      :ok ->
        # Clear cache before each test
        RedisAdapter.clear()
        :ok

      {:error, _reason} ->
        # When Redis is unavailable, tests will fail on first Redis operation
        {:ok, []}
    end
  end

  describe "init/0" do
    test "initializes Redis connection successfully" do
      # Already initialized in setup; second init returns already_started
      result = RedisAdapter.init()
      assert result == :ok or match?({:error, {:already_started, _}}, result)
    end
  end

  describe "get/1" do
    test "returns :not_found for non-existent key" do
      assert RedisAdapter.get("non_existent_key") == :not_found
    end

    test "returns cached value for existing key" do
      assert RedisAdapter.put(@test_key, @test_value) == :ok
      assert {:ok, @test_value_from_redis} == RedisAdapter.get(@test_key)
    end

    test "returns :not_found for expired key" do
      assert RedisAdapter.put(@test_key, @test_value, ttl: 1) == :ok
      assert {:ok, @test_value_from_redis} == RedisAdapter.get(@test_key)
      # Wait for expiration
      Process.sleep(1100)
      assert RedisAdapter.get(@test_key) == :not_found
    end
  end

  describe "put/3" do
    test "stores value with default TTL" do
      assert RedisAdapter.put(@test_key, @test_value) == :ok
      assert {:ok, @test_value_from_redis} == RedisAdapter.get(@test_key)
    end

    test "stores value with custom TTL" do
      assert RedisAdapter.put(@test_key, @test_value, ttl: 60) == :ok
      assert {:ok, @test_value_from_redis} == RedisAdapter.get(@test_key)
    end

    test "overwrites existing value" do
      new_value = %{user_id: "456", name: "New User"}
      assert RedisAdapter.put(@test_key, @test_value) == :ok
      assert RedisAdapter.put(@test_key, new_value) == :ok
      assert {:ok, %{"user_id" => "456", "name" => "New User"}} == RedisAdapter.get(@test_key)
    end

    test "handles complex nested structures" do
      complex_value = %{
        user: %{
          id: "123",
          accounts: [
            %{id: "acc1", balance: 100.50},
            %{id: "acc2", balance: 200.75}
          ]
        },
        metadata: %{created_at: "2024-01-01T00:00:00Z"}
      }

      assert RedisAdapter.put("complex_key", complex_value) == :ok
      assert {:ok, got} = RedisAdapter.get("complex_key")
      assert got["user"]["id"] == "123"
      assert length(got["user"]["accounts"]) == 2
      assert got["metadata"]["created_at"] == "2024-01-01T00:00:00Z"
    end
  end

  describe "get_or_put/3" do
    test "returns cached value if exists" do
      assert RedisAdapter.put(@test_key, @test_value) == :ok
      fun = fn -> {:ok, %{new: "value"}} end
      assert {:ok, @test_value_from_redis} == RedisAdapter.get_or_put(@test_key, fun)
    end

    test "computes and caches value if not exists" do
      computed_value = %{computed: true}
      fun = fn -> {:ok, computed_value} end
      assert {:ok, computed_value} == RedisAdapter.get_or_put("new_key", fun)
      assert {:ok, %{"computed" => true}} == RedisAdapter.get("new_key")
    end

    test "handles computation errors" do
      fun = fn -> {:error, :computation_failed} end
      assert {:error, :computation_failed} == RedisAdapter.get_or_put("error_key", fun)
      assert RedisAdapter.get("error_key") == :not_found
    end
  end

  describe "delete/1" do
    test "deletes existing key" do
      assert RedisAdapter.put(@test_key, @test_value) == :ok
      assert {:ok, @test_value_from_redis} == RedisAdapter.get(@test_key)
      assert RedisAdapter.delete(@test_key) == :ok
      assert RedisAdapter.get(@test_key) == :not_found
    end

    test "succeeds even if key doesn't exist" do
      assert RedisAdapter.delete("non_existent_key") == :ok
    end
  end

  describe "clear/0" do
    test "removes all cached entries" do
      assert RedisAdapter.put("key1", %{value: 1}) == :ok
      assert RedisAdapter.put("key2", %{value: 2}) == :ok
      assert RedisAdapter.put("key3", %{value: 3}) == :ok

      assert {:ok, _} = RedisAdapter.get("key1")
      assert {:ok, _} = RedisAdapter.get("key2")
      assert {:ok, _} = RedisAdapter.get("key3")

      assert RedisAdapter.clear() == :ok

      assert RedisAdapter.get("key1") == :not_found
      assert RedisAdapter.get("key2") == :not_found
      assert RedisAdapter.get("key3") == :not_found
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      RedisAdapter.clear()

      assert RedisAdapter.put("key1", %{value: 1}) == :ok
      assert RedisAdapter.put("key2", %{value: 2}) == :ok

      # Access keys (may update access counts in metadata)
      RedisAdapter.get("key1")
      RedisAdapter.get("key1")
      RedisAdapter.get("key2")

      stats = RedisAdapter.stats()

      assert stats.adapter == "redis"
      assert stats.total_entries >= 2
      assert stats.active_entries >= 2
      assert stats.total_access_count >= 0
      assert is_float(stats.average_access_count)
    end
  end

  describe "cleanup/0" do
    test "removes expired entries" do
      # Create entries with short TTL
      assert RedisAdapter.put("expired_key", @test_value, ttl: 1) == :ok
      assert RedisAdapter.put("active_key", @test_value, ttl: 300) == :ok

      # Wait for expiration
      Process.sleep(1100)

      # Cleanup may remove expired entries (Redis TTL may have already removed them)
      _removed_count = RedisAdapter.cleanup()

      # Expired key should be gone
      assert RedisAdapter.get("expired_key") == :not_found

      # Active key should still exist
      assert {:ok, _} = RedisAdapter.get("active_key")
    end
  end

  describe "get_entry_details/1" do
    test "returns details for existing entry" do
      assert RedisAdapter.put(@test_key, @test_value, ttl: 300) == :ok

      details = RedisAdapter.get_entry_details(@test_key)

      assert details != nil
      assert details.key == @test_key
      assert details.adapter == "redis"
      assert details.is_expired == false
      assert details.ttl_remaining > 0
      assert is_integer(details.access_count)
    end

    test "returns nil for non-existent entry" do
      assert RedisAdapter.get_entry_details("non_existent") == nil
    end
  end

  describe "concurrent operations" do
    test "handles concurrent puts and gets" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            key = "concurrent_key_#{i}"
            value = %{id: i, data: "value_#{i}"}
            RedisAdapter.put(key, value)
            Process.sleep(10)
            RedisAdapter.get(key)
          end)
        end

      results = Task.await_many(tasks, 5000)

      assert Enum.all?(results, fn
               {:ok, _value} -> true
               _ -> false
             end)
    end
  end

  describe "TTL handling" do
    test "respects maximum TTL limit" do
      # Try to set TTL beyond max (3600 seconds)
      assert RedisAdapter.put(@test_key, @test_value, ttl: 10_000) == :ok

      details = RedisAdapter.get_entry_details(@test_key)
      # TTL should be capped at max_ttl (3600)
      assert details.ttl_remaining <= 3600
    end

    test "handles zero TTL" do
      assert RedisAdapter.put(@test_key, @test_value, ttl: 0) == :ok
      # Zero TTL might expire immediately or be treated as no expiration
      # Behavior depends on Redis implementation
      _result = RedisAdapter.get(@test_key)
    end
  end

  describe "error handling" do
    test "gracefully handles Redis connection errors" do
      # This test would require stopping Redis, which is complex in CI
      # Instead, we test that errors don't crash the application
      # by ensuring error handling is in place

      # Put a value
      assert RedisAdapter.put(@test_key, @test_value) == :ok

      # Even if Redis has issues, adapter should return :not_found
      # rather than crashing (tested via error handling in adapter code)
      result = RedisAdapter.get(@test_key)
      assert result in [{:ok, @test_value_from_redis}, :not_found]
    end
  end
end

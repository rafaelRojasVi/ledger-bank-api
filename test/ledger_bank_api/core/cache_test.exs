defmodule LedgerBankApi.Core.CacheTest do
  use LedgerBankApi.DataCase, async: true

  alias LedgerBankApi.Core.Cache

  setup do
    # Initialize cache for each test
    Cache.init()
    :ok
  end

  describe "cache operations" do
    test "put and get work correctly" do
      key = "test_key"
      value = %{name: "John", age: 30}

      # Put value in cache
      assert :ok = Cache.put(key, value)

      # Get value from cache
      assert {:ok, ^value} = Cache.get(key)
    end

    test "get returns :not_found for non-existent key" do
      assert :not_found = Cache.get("non_existent_key")
    end

    test "get_or_put computes value when not in cache" do
      key = "computed_key"
      computed_value = %{computed: true}

      # First call should compute the value
      assert {:ok, ^computed_value} =
               Cache.get_or_put(key, fn ->
                 {:ok, computed_value}
               end)

      # Second call should return cached value
      assert {:ok, ^computed_value} =
               Cache.get_or_put(key, fn ->
                 {:ok, %{different: true}}
               end)
    end

    test "get_or_put handles computation errors" do
      key = "error_key"

      assert {:error, :computation_failed} =
               Cache.get_or_put(key, fn ->
                 {:error, :computation_failed}
               end)

      # Key should not be in cache after error
      assert :not_found = Cache.get(key)
    end

    test "delete removes key from cache" do
      key = "delete_key"
      value = %{to_delete: true}

      # Put value in cache
      Cache.put(key, value)
      assert {:ok, ^value} = Cache.get(key)

      # Delete value
      assert :ok = Cache.delete(key)
      assert :not_found = Cache.get(key)
    end

    test "clear removes all entries" do
      # Put multiple values
      Cache.put("key1", "value1")
      Cache.put("key2", "value2")
      Cache.put("key3", "value3")

      # Verify they exist
      assert {:ok, "value1"} = Cache.get("key1")
      assert {:ok, "value2"} = Cache.get("key2")
      assert {:ok, "value3"} = Cache.get("key3")

      # Clear cache
      assert :ok = Cache.clear()

      # Verify all are gone
      assert :not_found = Cache.get("key1")
      assert :not_found = Cache.get("key2")
      assert :not_found = Cache.get("key3")
    end

    test "stats returns correct statistics" do
      # Clear cache first to ensure clean state
      Cache.clear()

      # Initially empty
      stats = Cache.stats()
      assert stats.total_entries == 0
      assert stats.active_entries == 0

      # Add some entries
      Cache.put("key1", "value1")
      Cache.put("key2", "value2")

      # Access one entry multiple times
      Cache.get("key1")
      Cache.get("key1")

      stats = Cache.stats()
      assert stats.total_entries == 2
      assert stats.active_entries == 2
      assert stats.total_access_count == 2
      assert stats.average_access_count == 1.0
    end

    test "get_entry_details returns correct information" do
      key = "details_key"
      value = %{details: true}

      # Put value in cache
      Cache.put(key, value, ttl: 300)

      # Get entry details
      details = Cache.get_entry_details(key)
      assert details.key == key
      assert details.value == value
      assert details.access_count == 0
      assert details.is_expired == false
      assert details.ttl_remaining > 0

      # Access the entry
      Cache.get(key)

      # Get updated details
      details = Cache.get_entry_details(key)
      assert details.access_count == 1
    end

    test "cleanup removes expired entries" do
      # Put entries with very short TTL
      Cache.put("expired_key", "value", ttl: 1)

      # Wait for expiration
      Process.sleep(1100)

      # Put a non-expired entry
      Cache.put("active_key", "value", ttl: 300)

      # Cleanup should remove expired entries
      removed_count = Cache.cleanup()
      assert removed_count == 1

      # Verify expired entry is gone
      assert :not_found = Cache.get("expired_key")
      assert {:ok, "value"} = Cache.get("active_key")
    end
  end
end

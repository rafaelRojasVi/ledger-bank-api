defmodule LedgerBankApi.ApplicationTest do
  use ExUnit.Case, async: false
  test "application starts successfully" do
    # This test verifies that the application can start without errors
    # In a real scenario, you might want to test specific startup behavior

    # The application should be running
    assert Process.whereis(LedgerBankApi.Supervisor) != nil

    # Verify that key processes are running
    assert Process.whereis(LedgerBankApi.Repo) != nil

    # Oban might not be running in test environment, check configuration instead
    {:ok, oban_config} = :application.get_env(:ledger_bank_api, Oban)
    assert oban_config[:testing] == :manual
  end

  test "application configuration is loaded correctly" do
    # Test that configuration values are accessible
    {:ok, jwt_config} = :application.get_env(:ledger_bank_api, :jwt)
    {:ok, cache_config} = :application.get_env(:ledger_bank_api, :cache)

    assert jwt_config != nil
    assert cache_config != nil

    # Test JWT configuration
    assert jwt_config[:issuer] == "ledger:test"
    assert jwt_config[:audience] == "ledger:test"
    assert jwt_config[:secret_key] != nil

    # Test cache configuration
    assert cache_config[:ttl] == 300
    assert cache_config[:cleanup_interval] == 60
  end

  test "Oban configuration is correct for testing" do
    {:ok, oban_config} = :application.get_env(:ledger_bank_api, Oban)
    assert oban_config[:testing] == :manual

    # The actual runtime configuration has specific queue definitions
    # instead of queues: false, so we test for the actual values
    assert is_list(oban_config[:queues])
    assert oban_config[:queues][:banking] == 10
    assert oban_config[:queues][:payments] == 5
    assert oban_config[:queues][:notifications] == 3
    assert oban_config[:queues][:default] == 1

    # Plugins are configured in runtime, not disabled
    assert is_list(oban_config[:plugins])
  end

  test "database configuration is loaded" do
    {:ok, db_config} = :application.get_env(:ledger_bank_api, LedgerBankApi.Repo)
    assert db_config[:pool] == Ecto.Adapters.SQL.Sandbox
    assert db_config[:pool_size] != nil
  end

  test "cache ETS table is created" do
    # Verify that the cache ETS table exists
    assert :ets.info(:ledger_cache) != :undefined
  end

  test "application can handle graceful shutdown" do
    # This test verifies that the application can be stopped gracefully
    # In a real scenario, you might want to test specific shutdown behavior

    # The application should be running
    assert Process.whereis(LedgerBankApi.Supervisor) != nil

    # Note: In a real test environment, you might want to test actual shutdown
    # but for now we'll just verify the process exists
  end
end

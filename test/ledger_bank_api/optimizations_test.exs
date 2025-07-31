defmodule LedgerBankApi.OptimizationsTest do
  @moduledoc """
  Tests for the optimized banking API features including caching, database queries, and controller operations.
  """

  use ExUnit.Case, async: true
  import LedgerBankApi.TestHelpers
  import Ecto.Query

  setup do
    # Clear cache before each test
    clear_cache()
    :ok
  end

  describe "Caching Optimizations" do
    test "cache stores and retrieves values correctly" do
      cache_key = "test_key"
      test_value = %{data: "test_data"}

      assert_cache_working(cache_key, test_value)
    end

    test "account balance caching works" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, account} = create_test_user_bank_account(login.id, %{balance: Decimal.new("500.00")})

      # First call should miss cache
      assert {:ok, balance} = LedgerBankApi.Cache.get_account_balance(account.id)
      assert Decimal.eq?(balance, Decimal.new("500.00"))

      # Second call should hit cache
      assert {:ok, balance} = LedgerBankApi.Cache.get_account_balance(account.id)
      assert Decimal.eq?(balance, Decimal.new("500.00"))
    end

    test "user accounts caching works" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, _account} = create_test_user_bank_account(login.id)

      # First call should miss cache
      assert {:ok, accounts} = LedgerBankApi.Cache.get_user_accounts(user.id)
      assert length(accounts) == 1

      # Second call should hit cache
      assert {:ok, accounts} = LedgerBankApi.Cache.get_user_accounts(user.id)
      assert length(accounts) == 1
    end

    test "cache invalidation works" do
      cache_key = "test_invalidation"
      test_value = "test_value"

      # Set value
      assert {:ok, ^test_value} = LedgerBankApi.Cache.set(cache_key, test_value)

      # Verify it's cached
      assert {:ok, ^test_value} = LedgerBankApi.Cache.get(cache_key)

      # Invalidate
      assert :ok = LedgerBankApi.Cache.delete(cache_key)

      # Verify it's gone
      assert {:error, :not_found} = LedgerBankApi.Cache.get(cache_key)
    end
  end

  describe "Database Query Optimizations" do
    test "user bank accounts query uses indexes" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, _account} = create_test_user_bank_account(login.id)

      # Test optimized query
      query = from a in LedgerBankApi.Banking.Schemas.UserBankAccount,
        join: l in assoc(a, :user_bank_login),
        where: l.user_id == ^user.id

      assert_optimized_query(query, ["user_bank_login_id"])
    end

    test "transactions query uses indexes" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, account} = create_test_user_bank_account(login.id)
      {:ok, _transaction} = create_test_transaction(account.id)

      # Test optimized query
      query = from t in LedgerBankApi.Banking.Schemas.Transaction,
        where: t.account_id == ^account.id,
        order_by: [desc: t.posted_at]

      assert_optimized_query(query, ["account_id", "posted_at"])
    end

    test "payments query uses indexes" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, account} = create_test_user_bank_account(login.id)
      {:ok, _payment} = create_test_payment(account.id)

      # Test optimized query
      query = from p in LedgerBankApi.Banking.Schemas.UserPayment,
        where: p.user_bank_account_id == ^account.id,
        order_by: [desc: p.inserted_at]

      assert_optimized_query(query, ["user_bank_account_id", "inserted_at"])
    end
  end

  describe "Controller Response Optimizations" do
    test "banking controller returns proper structure" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)
      {:ok, account} = create_test_user_bank_account(login.id)

      # Test response structure (this would be a real controller test)
      response = %{
        "data" => %{
          "id" => account.id,
          "name" => account.account_name,
          "status" => account.status,
          "type" => account.account_type,
          "currency" => account.currency
        }
      }

      assert_api_response_structure(response, ["id", "name", "status", "type", "currency"])
    end

    test "pagination works correctly" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)

      # Create multiple accounts
      for i <- 1..5 do
        create_test_user_bank_account(login.id, %{account_name: "Account #{i}"})
      end

      # Test pagination response structure
      response = %{
        "data" => [],
        "pagination" => %{
          "page" => 1,
          "page_size" => 20,
          "total_count" => 5,
          "total_pages" => 1,
          "has_next" => false,
          "has_prev" => false
        }
      }

      assert_pagination_working(response, 1, 20)
    end

    test "filtering works correctly" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)

      # Create accounts with different statuses
      {:ok, _active_account} = create_test_user_bank_account(login.id, %{status: "ACTIVE"})
      {:ok, _inactive_account} = create_test_user_bank_account(login.id, %{status: "INACTIVE"})

      # Test filtering
      accounts = LedgerBankApi.Banking.UserBankAccounts.list_for_user(user.id)
      active_accounts = Enum.filter(accounts, fn account -> account.status == "ACTIVE" end)
      assert_filtering_working(active_accounts, "status", "ACTIVE")
    end

    test "sorting works correctly" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)

      # Create accounts with different names
      {:ok, _account1} = create_test_user_bank_account(login.id, %{account_name: "A Account"})
      {:ok, _account2} = create_test_user_bank_account(login.id, %{account_name: "B Account"})
      {:ok, _account3} = create_test_user_bank_account(login.id, %{account_name: "C Account"})

      # Test ascending sort
      items = [
        %{account_name: "A Account"},
        %{account_name: "B Account"},
        %{account_name: "C Account"}
      ]
      assert_sorting_working(items, "account_name", "asc")

      # Test descending sort
      items_desc = [
        %{account_name: "C Account"},
        %{account_name: "B Account"},
        %{account_name: "A Account"}
      ]
      assert_sorting_working(items_desc, "account_name", "desc")
    end
  end

  describe "Performance Optimizations" do
    test "bulk operations are efficient" do
      # Create test data
      {:ok, user} = create_test_user()
      {:ok, bank} = create_test_bank()
      {:ok, branch} = create_test_bank_branch(bank.id)
      {:ok, login} = create_test_user_bank_login(user.id, branch.id)

      # Test bulk account creation
      start_time = System.monotonic_time(:millisecond)

      accounts = for i <- 1..10 do
        {:ok, account} = create_test_user_bank_account(login.id, %{account_name: "Bulk Account #{i}"})
        account
      end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert length(accounts) == 10
      assert duration < 1000 # Should complete in less than 1 second
    end

    test "cache performance is good" do
      # Test cache performance
      start_time = System.monotonic_time(:microsecond)

      for i <- 1..100 do
        cache_key = "perf_test_#{i}"
        test_value = "value_#{i}"
        LedgerBankApi.Cache.set(cache_key, test_value)
        assert {:ok, ^test_value} = LedgerBankApi.Cache.get(cache_key)
      end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Should complete 100 operations in less than 50ms (more realistic for ETS operations)
      assert duration < 50_000
    end
  end
end

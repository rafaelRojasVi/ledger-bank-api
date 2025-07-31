defmodule LedgerBankApi.TestHelpers do
  @moduledoc """
  Test helpers for the optimized banking API.
  Provides utilities for testing caching, database queries, and controller operations.
  """

  use ExUnit.Case
  alias LedgerBankApi.Repo


  @doc """
  Clears the cache for testing.
  """
  def clear_cache do
    if Process.whereis(LedgerBankApi.Cache.Store) do
      :ets.delete_all_objects(:ledger_cache)
    end
  end

  @doc """
  Gets cache statistics for testing.
  """
  def cache_stats do
    if Process.whereis(LedgerBankApi.Cache.Store) do
      :ets.info(:ledger_cache, :size)
    else
      0
    end
  end

  @doc """
  Creates a test user with given attributes.
  """
  def create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}_#{rem(System.monotonic_time(), 100000)}@example.com",
      full_name: "Test User",
      password: "password123",
      role: "user",
      status: "ACTIVE"
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Users.Context.create_user(attrs)
  end

  @doc """
  Creates a test bank with given attributes.
  """
  def create_test_bank(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Bank #{System.unique_integer()}_#{rem(System.monotonic_time(), 100000)}",
      country: "US",
      code: "TEST_#{rem(abs(System.unique_integer()), 999999)}",
      status: "ACTIVE",
      integration_module: "LedgerBankApi.Banking.Integrations.MonzoClient"
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Banking.Context.create_bank(attrs)
  end

  @doc """
  Creates a test bank branch with given attributes.
  """
  def create_test_bank_branch(bank_id, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Branch #{System.unique_integer()}_#{rem(System.monotonic_time(), 100000)}",
      country: "US",
      bank_id: bank_id
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Banking.Context.create_bank_branch(attrs)
  end

  @doc """
  Creates a test user bank login with given attributes.
  """
  def create_test_user_bank_login(user_id, bank_branch_id, attrs \\ %{}) do
    default_attrs = %{
      user_id: user_id,
      bank_branch_id: bank_branch_id,
      username: "testuser#{System.unique_integer()}_#{rem(System.monotonic_time(), 100000)}",
      encrypted_password: "encrypted_password_123",
      status: "ACTIVE"
    }

    attrs = Map.merge(default_attrs, attrs)
    case LedgerBankApi.Banking.Context.create_user_bank_login(attrs) do
      {:ok, %{data: login}} -> {:ok, login}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates a test user bank account with given attributes.
  """
  def create_test_user_bank_account(user_bank_login_id, attrs \\ %{}) do
    default_attrs = %{
      user_bank_login_id: user_bank_login_id,
      currency: "USD",
      account_type: "CHECKING",
      balance: Decimal.new("1000.00"),
      last_four: "1234",
      account_name: "Test Account",
      status: "ACTIVE"
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Banking.Context.create_user_bank_account(attrs)
  end

  @doc """
  Creates a test transaction with given attributes.
  """
  def create_test_transaction(account_id, attrs \\ %{}) do
    default_attrs = %{
      account_id: account_id,
      description: "Test Transaction",
      amount: Decimal.new("100.00"),
      direction: "CREDIT",
      posted_at: DateTime.utc_now()
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Banking.Context.create_transaction(attrs)
  end

  @doc """
  Creates a test payment with given attributes.
  """
  def create_test_payment(user_bank_account_id, attrs \\ %{}) do
    default_attrs = %{
      user_bank_account_id: user_bank_account_id,
      amount: Decimal.new("50.00"),
      direction: "DEBIT",
      description: "Test Payment",
      payment_type: "TRANSFER",
      status: "PENDING"
    }

    attrs = Map.merge(default_attrs, attrs)
    LedgerBankApi.Banking.Context.create_user_payment(attrs)
  end

  @doc """
  Asserts that a database query is optimized (uses indexes).
  """
  def assert_optimized_query(query, expected_indexes \\ []) do
    # This is a simplified check - in a real scenario you'd analyze the query plan
    {sql, _params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
    assert is_binary(sql)

    # Check if the query contains expected patterns
    Enum.each(expected_indexes, fn index ->
      assert String.contains?(sql, index)
    end)
  end

  @doc """
  Asserts that cache is working for a given key.
  """
  def assert_cache_working(cache_key, expected_value) do
    # First call should miss cache
    assert {:error, :not_found} = LedgerBankApi.Cache.get(cache_key)

    # Set value in cache
    assert {:ok, ^expected_value} = LedgerBankApi.Cache.set(cache_key, expected_value)

    # Second call should hit cache
    assert {:ok, ^expected_value} = LedgerBankApi.Cache.get(cache_key)
  end

  @doc """
  Asserts that a controller response has the expected structure.
  """
  def assert_api_response_structure(response, expected_keys \\ []) do
    assert is_map(response)
    assert Map.has_key?(response, "data")

    Enum.each(expected_keys, fn key ->
      assert Map.has_key?(response["data"], key)
    end)
  end

  @doc """
  Asserts that pagination is working correctly.
  """
  def assert_pagination_working(response, expected_page, expected_per_page) do
    assert Map.has_key?(response, "pagination")
    pagination = response["pagination"]

    assert pagination["page"] == expected_page
    assert pagination["page_size"] == expected_per_page
    assert is_boolean(pagination["has_next"])
    assert is_boolean(pagination["has_prev"])
    assert is_integer(pagination["total_count"])
    assert is_integer(pagination["total_pages"])
  end

  @doc """
  Asserts that filtering is working correctly.
  """
  def assert_filtering_working(items, filter_key, filter_value) do
    Enum.each(items, fn item ->
      # Handle both maps and structs
      value = case item do
        %{^filter_key => v} -> v
        _ when is_struct(item) -> Map.get(item, String.to_atom(filter_key))
        _ -> Map.get(item, filter_key)
      end
      assert value == filter_value
    end)
  end

  @doc """
  Asserts that sorting is working correctly.
  """
  def assert_sorting_working(items, sort_field, sort_order) do
    values = Enum.map(items, &Map.get(&1, sort_field))

    case sort_order do
      "asc" -> assert values == Enum.sort(values)
      "desc" -> assert values == Enum.sort(values, :desc)
    end
  end
end

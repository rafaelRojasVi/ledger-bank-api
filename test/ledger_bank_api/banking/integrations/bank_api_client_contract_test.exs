defmodule LedgerBankApi.Banking.BankApiClientContractTest do
  use LedgerBankApi.DataCase, async: true
  use LedgerBankApi.MoxCase

  alias LedgerBankApi.Banking.BankApiClientMock

  test "fetch_accounts contract returns list on success" do
    expect(BankApiClientMock, :fetch_accounts, fn %{access_token: "valid_token"} ->
      {:ok, [
        %{
          "id" => "acc_123",
          "name" => "Main Account",
          "type" => "CHECKING",
          "currency" => "GBP",
          "balance" => "1000.00"
        }
      ]}
    end)

    assert {:ok, accounts} = BankApiClientMock.fetch_accounts(%{access_token: "valid_token"})
    assert length(accounts) == 1
    assert accounts |> List.first() |> Map.get("id") == "acc_123"
  end

  test "fetch_accounts contract handles empty response" do
    expect(BankApiClientMock, :fetch_accounts, fn %{access_token: "valid_token"} ->
      {:ok, []}
    end)

    assert {:ok, accounts} = BankApiClientMock.fetch_accounts(%{access_token: "valid_token"})
    assert accounts == []
  end

  test "fetch_accounts contract handles error response" do
    expect(BankApiClientMock, :fetch_accounts, fn %{access_token: "invalid_token"} ->
      {:error, :unauthorized}
    end)

    assert {:error, :unauthorized} = BankApiClientMock.fetch_accounts(%{access_token: "invalid_token"})
  end

  test "fetch_transactions contract returns list on success" do
    expect(BankApiClientMock, :fetch_transactions, fn %{access_token: "valid_token", account_id: "acc_123"} ->
      {:ok, [
        %{
          "id" => "txn_456",
          "amount" => "25.00",
          "description" => "Coffee",
          "date" => "2024-01-15"
        }
      ]}
    end)

    assert {:ok, transactions} = BankApiClientMock.fetch_transactions(%{
      access_token: "valid_token",
      account_id: "acc_123"
    })
    assert length(transactions) == 1
    assert transactions |> List.first() |> Map.get("id") == "txn_456"
  end

  test "fetch_transactions contract handles pagination" do
    expect(BankApiClientMock, :fetch_transactions, fn %{access_token: "valid_token", account_id: "acc_123", page: 2} ->
      {:ok, [
        %{
          "id" => "txn_789",
          "amount" => "50.00",
          "description" => "Lunch",
          "date" => "2024-01-14"
        }
      ]}
    end)

    assert {:ok, transactions} = BankApiClientMock.fetch_transactions(%{
      access_token: "valid_token",
      account_id: "acc_123",
      page: 2
    })
    assert length(transactions) == 1
    assert transactions |> List.first() |> Map.get("id") == "txn_789"
  end

  test "fetch_transactions contract handles date filtering" do
    expect(BankApiClientMock, :fetch_transactions, fn %{access_token: "valid_token", account_id: "acc_123", from_date: "2024-01-01"} ->
      {:ok, [
        %{
          "id" => "txn_101",
          "amount" => "100.00",
          "description" => "January Transaction",
          "date" => "2024-01-15"
        }
      ]}
    end)

    assert {:ok, transactions} = BankApiClientMock.fetch_transactions(%{
      access_token: "valid_token",
      account_id: "acc_123",
      from_date: "2024-01-01"
    })
    assert length(transactions) == 1
    assert transactions |> List.first() |> Map.get("description") == "January Transaction"
  end

  test "create_payment contract returns success" do
    expect(BankApiClientMock, :create_payment, fn %{access_token: "valid_token", account_id: "acc_123", amount: "25.00"} ->
      {:ok, %{
        "id" => "payment_123",
        "status" => "PENDING",
        "reference" => "REF123"
      }}
    end)

    assert {:ok, payment} = BankApiClientMock.create_payment(%{
      access_token: "valid_token",
      account_id: "acc_123",
      amount: "25.00",
      description: "Coffee"
    })
    assert payment["id"] == "payment_123"
    assert payment["status"] == "PENDING"
  end

  test "create_payment contract handles insufficient funds" do
    expect(BankApiClientMock, :create_payment, fn %{access_token: "valid_token", account_id: "acc_123", amount: "10000.00"} ->
      {:error, :insufficient_funds}
    end)

    assert {:error, :insufficient_funds} = BankApiClientMock.create_payment(%{
      access_token: "valid_token",
      account_id: "acc_123",
      amount: "10000.00",
      description: "Large Payment"
    })
  end

  test "get_payment_status contract returns status" do
    expect(BankApiClientMock, :get_payment_status, fn %{access_token: "valid_token", payment_id: "payment_123"} ->
      {:ok, %{
        "id" => "payment_123",
        "status" => "COMPLETED",
        "completed_at" => "2024-01-15T10:30:00Z"
      }}
    end)

    assert {:ok, status} = BankApiClientMock.get_payment_status(%{
      access_token: "valid_token",
      payment_id: "payment_123"
    })
    assert status["status"] == "COMPLETED"
  end

  test "get_payment_status contract handles not found" do
    expect(BankApiClientMock, :get_payment_status, fn %{access_token: "valid_token", payment_id: "invalid_id"} ->
      {:error, :not_found}
    end)

    assert {:error, :not_found} = BankApiClientMock.get_payment_status(%{
      access_token: "valid_token",
      payment_id: "invalid_id"
    })
  end

  test "refresh_token contract returns new tokens" do
    expect(BankApiClientMock, :refresh_token, fn %{refresh_token: "old_refresh_token"} ->
      {:ok, %{
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 3600
      }}
    end)

    assert {:ok, tokens} = BankApiClientMock.refresh_token(%{refresh_token: "old_refresh_token"})
    assert tokens["access_token"] == "new_access_token"
    assert tokens["refresh_token"] == "new_refresh_token"
    assert tokens["expires_in"] == 3600
  end

  test "refresh_token contract handles expired refresh token" do
    expect(BankApiClientMock, :refresh_token, fn %{refresh_token: "expired_refresh_token"} ->
      {:error, :token_expired}
    end)

    assert {:error, :token_expired} = BankApiClientMock.refresh_token(%{refresh_token: "expired_refresh_token"})
  end
end

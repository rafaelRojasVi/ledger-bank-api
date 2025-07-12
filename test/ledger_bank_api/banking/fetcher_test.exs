defmodule LedgerBankApi.Banking.FetcherTest do
  use LedgerBankApi.DataCase, async: true
  import Mox
  setup :verify_on_exit!

  test "returns combined results" do
    LedgerBankApi.External.BankClientMock
    |> expect(:accounts, fn _ -> {:ok, [%{id: 1}]} end)
    |> expect(:balances, fn _ -> {:ok, [%{id: 1, balance: 42}]} end)
    |> expect(:transactions, fn _ -> {:ok, []} end)

    result = LedgerBankApi.Banking.Fetcher.fetch_all("enr-123")

    assert %{accounts: [_], balances: [_], transactions: []} = result
  end


end

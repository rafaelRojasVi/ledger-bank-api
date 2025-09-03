defmodule LedgerBankApi.CacheCase do
  use ExUnit.CaseTemplate

  setup do
    # Clear the cache before each test
    :ets.delete_all_objects(:ledger_cache)
    :ok
  end
end

defmodule LedgerBankApi.MoxCase do
  use ExUnit.CaseTemplate

  setup do
    Mox.verify_on_exit!()
    :ok
  end

  using do
    quote do
      import Mox
    end
  end
end

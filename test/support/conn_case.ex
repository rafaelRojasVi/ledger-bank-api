defmodule LedgerBankApiWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      alias LedgerBankApiWeb.Router.Helpers, as: Routes
      @endpoint LedgerBankApiWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LedgerBankApi.Repo)
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(LedgerBankApi.Repo, {:shared, self()})
    end
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

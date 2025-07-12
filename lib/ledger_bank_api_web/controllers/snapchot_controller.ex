defmodule LedgerBankApiWeb.SnapshotController do
  use LedgerBankApiWeb, :controller

  def show(conn, %{"id" => id}) do
    result = LedgerBankApi.Banking.fetch_live_snapshot(id)
    json(conn, result)
  end
end

# lib/ledger_bank_api_web/plugs/client_auth.ex
defmodule LedgerBankApiWeb.Plugs.ClientAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:access_token, "dev-token")
  end
end

Mix.Task.run("app.start")
import Phoenix.ConnTest
alias LedgerBankApiWeb.Endpoint

auth_conn =
  build_conn()
  |> put_req_header("authorization", "Bearer bench")

Benchee.run(
  %{
    "GET /api/accounts" => fn ->
      auth_conn
      |> get(~p"/api/accounts")
      |> Plug.Conn.resp_body()
    end
  },
  time: 5
)

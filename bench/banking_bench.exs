# bench/banking_bench.exs
Mix.Task.run("app.start")
Mix.Task.run("ecto.create", ["--quiet"])
Mix.Task.run("ecto.migrate", ["--quiet"])


alias LedgerBankApi.Banking
alias LedgerBankApi.Banking.Account
alias LedgerBankApi.Repo

# quick inline seed
Repo.insert!(%Account{
  user_id: Ecto.UUID.generate(),
  institution: "Bench Bank",
  type: "checking",
  last4: "1111",
  balance: Decimal.new("42.00")
})

Benchee.run(
  %{
    "list_accounts()"          => fn -> Banking.list_accounts() end,
    "list_accounts_id_only()"  => fn ->
      import Ecto.Query
      LedgerBankApi.Banking.Account |> select([a], a.id) |> LedgerBankApi.Repo.all()
    end
  },
  time: 3,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console],
  # comparison: true   ← delete this line
)

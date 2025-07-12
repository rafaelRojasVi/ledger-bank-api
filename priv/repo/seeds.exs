# priv/repo/seeds.exs
alias LedgerBankApi.Repo
alias LedgerBankApi.Banking.{Account, Transaction}

{:ok, acct} =
  %Account{
    user_id: Ecto.UUID.generate(),
    institution: "Demo Bank",
    type: "checking",
    last4: "4242",
    balance: Decimal.new("1000.00")
  }
  |> Repo.insert()

Repo.insert!(%Transaction{
  account_id:  acct.id,
  amount:      Decimal.new("-20.50"),
  posted_at:   DateTime.utc_now() |> DateTime.truncate(:second),
})

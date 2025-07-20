defmodule LedgerBankApi.Workers.BankSyncWorkerTest do
  use ExUnit.Case, async: true
  import Mimic
  alias LedgerBankApi.Workers.BankSyncWorker
  alias LedgerBankApi.Banking.Schemas.{UserBankLogin, BankBranch, Bank}
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Mimic.copy(LedgerBankApi.Banking.Integrations.MonzoClient)
    :ok
  end

  test "BankSyncWorker calls integration and logs success" do
    bank = Repo.insert!(%Bank{
      name: "Monzo",
      country: "UK",
      code: "MONZO_UK",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    branch = Repo.insert!(%BankBranch{
      name: "Test Branch",
      iban: "IBAN123",
      country: "UK",
      bank_id: bank.id
    })
    user = Repo.insert!(%User{
      email: "test@example.com",
      full_name: "Test User",
      status: "ACTIVE"
    })
    login = Repo.insert!(%UserBankLogin{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    })

    # Mock the integration
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)

    job = %Oban.Job{args: %{"login_id" => login.id}}
    assert {:ok, %{data: :ok, success: true}} = BankSyncWorker.perform(job)
  end
end

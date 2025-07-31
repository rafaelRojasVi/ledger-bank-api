defmodule LedgerBankApi.Banking.UserBankLoginsTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.UserBankLogins
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create_user_bank_login/1 creates a login" do
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
    attrs = %{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    }
    assert {:ok, %{data: %UserBankLogin{} = login}} = UserBankLogins.create_user_bank_login(attrs)
    assert login.username == "test"
  end

  test "create_user_bank_login/1 enforces uniqueness of user_id, bank_branch_id, username" do
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
    attrs = %{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    }
    assert {:ok, %{data: %UserBankLogin{}}} = UserBankLogins.create_user_bank_login(attrs)
    assert {:error, error_response} = UserBankLogins.create_user_bank_login(attrs)
    assert error_response.error.type == :internal_server_error
    # The error details should contain information about the constraint violation
    assert error_response.error.details.error
  end

  test "sync_login/1 calls integration and logs success" do
    Mimic.copy(LedgerBankApi.Banking.Integrations.MonzoClient)
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

    LedgerBankApi.Banking.Integrations.MonzoClient
    |> Mimic.expect(:fetch_accounts, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)

    assert {:ok, %{data: :ok, success: true, timestamp: _timestamp, metadata: %{}}} = UserBankLogins.sync_login(login.id)
  end
end

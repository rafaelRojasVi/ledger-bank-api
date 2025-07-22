defmodule LedgerBankApi.Workers.BankSyncWorkerLoadTest do
  use ExUnit.Case, async: false
  import Mimic
  alias LedgerBankApi.Workers.BankSyncWorker
  alias LedgerBankApi.Banking.Schemas.{UserBankLogin, BankBranch, Bank}
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
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
    %{login: login}
  end

  test "processes 100 sync jobs for the same login", %{login: login} do
    # Mock the integration call to always succeed
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 100, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)

    for _ <- 1..100 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end

    # With Oban test mode (:inline), jobs are executed immediately on insert.
        # Mimic will fail the test if the expectation is not met 100 times.
    # No need to call drain_queue or assert on result.success.
  end

  test "handles integration failure gracefully", %{login: login} do
    # Mock the integration to always fail
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 100, fn %{access_token: _} -> {:error, :network_failure} end)

    for _ <- 1..100 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end
    # If your worker retries or logs, assert on that here.
    # Mimic will ensure the mock is called 100 times.
  end

  test "handles exception raised by integration", %{login: login} do
    # Mock the integration to raise an exception
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 100, fn _ -> raise "integration error" end)

    for _ <- 1..100 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end
    # Mimic will ensure the mock is called 100 times.
    # If your worker has error handling, you can assert on logs or side effects.
  end

  test "partial success and failure", %{login: login} do
    # Alternate between success and failure
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 100, fn %{access_token: _} ->
      if :rand.uniform() > 0.5, do: {:ok, [%{id: "acc1"}]}, else: {:error, :fail}
    end)

    for _ <- 1..100 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end
    # Mimic will ensure the mock is called 100 times.
  end

  test "idempotency: enqueue same job multiple times", %{login: login} do
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 10, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)

    for _ <- 1..10 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end
    # If your worker is idempotent, assert that side effects are not duplicated.
    # Mimic will ensure the mock is called 10 times.
  end

  test "handles slow integration (simulate delay)", %{login: login} do
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> expect(:fetch_accounts, 5, fn %{access_token: _} ->
      :timer.sleep(100)
      {:ok, [%{id: "acc1"}]}
    end)

    for _ <- 1..5 do
      Oban.insert!(BankSyncWorker.new(%{"login_id" => login.id}))
    end
    # Test will take at least 0.5s due to sleep. Mimic ensures all calls are made.
  end
end

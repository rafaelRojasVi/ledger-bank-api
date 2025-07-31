defmodule LedgerBankApi.Integration.UserPaymentFlowTest do
  use ExUnit.Case, async: false
  alias LedgerBankApi.Users.Context, as: UserContext
  alias LedgerBankApi.Banking.Context, as: BankingContext
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "full user registration, login, payment, and failure flows" do
    # 1. Register user
    {:ok, user} = UserContext.create_user(%{
      email: "test@flow.com",
      full_name: "Test Flow",
      password: "Password123",
      role: "user"
    })
    assert user.id

    # 2. Login user (success)
    {:ok, db_user, access_token, refresh_token} = UserContext.login_user("test@flow.com", "Password123")
    assert db_user.id == user.id
    assert is_binary(access_token)
    assert is_binary(refresh_token)

    # 2b. Login user (failure)
    assert {:error, :invalid_credentials} = UserContext.login_user("test@flow.com", "wrongpass")
    assert {:error, :invalid_credentials} = UserContext.login_user("notfound@flow.com", "Password123")

    # 3. Create bank, branch, login, account
    {:ok, bank} = BankingContext.create_bank(%{
      name: "FlowBank",
      country: "US",
      code: "FLOWBANK_US",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    {:ok, branch} = BankingContext.create_bank_branch(%{name: "Main", country: "US", bank_id: bank.id})
    {:ok, %{data: login}} = BankingContext.create_user_bank_login(%{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "flowuser",
      encrypted_password: "pw"
    })
    {:ok, account} = BankingContext.create_user_bank_account(%{
      user_bank_login_id: login.id,
      currency: "USD",
      account_type: "CHECKING"
    })

    # 3b. Create multiple logins for the same user
    {:ok, branch2} = BankingContext.create_bank_branch(%{name: "Branch2", country: "US", bank_id: bank.id})
    {:ok, %{data: login2}} = BankingContext.create_user_bank_login(%{
      user_id: user.id,
      bank_branch_id: branch2.id,
      username: "flowuser2",
      encrypted_password: "pw2"
    })
    {:ok, account2} = BankingContext.create_user_bank_account(%{
      user_bank_login_id: login2.id,
      currency: "USD",
      account_type: "SAVINGS"
    })

    # 4. Create and process payment (success)
    {:ok, payment} = BankingContext.create_user_payment(%{
      user_bank_account_id: account.id,
      amount: Decimal.new("50.00"),
      payment_type: "PAYMENT",
      direction: "DEBIT"
    })
    assert payment.status == "PENDING"

    # Simulate payment processing (call worker logic directly)
    {:ok, %{data: {:ok, txn}, success: true}} =
      LedgerBankApi.Banking.UserPayments.process_payment(payment.id)
    assert txn.amount == Decimal.new("50.00")

    # 4b. Attempt to process the same payment again (should fail)
    {:error, %{error: %{type: :internal_server_error, message: msg}}} =
      LedgerBankApi.Banking.UserPayments.process_payment(payment.id)
    assert msg =~ "already_processed"

    # 4c. Create and process payment for second account
    {:ok, payment2} = BankingContext.create_user_payment(%{
      user_bank_account_id: account2.id,
      amount: Decimal.new("20.00"),
      payment_type: "TRANSFER",
      direction: "DEBIT"
    })
    {:ok, %{data: {:ok, txn2}, success: true}} =
      LedgerBankApi.Banking.UserPayments.process_payment(payment2.id)
    assert txn2.amount == Decimal.new("20.00")

    # 5. Refresh tokens (success)
    {:ok, _user2, new_access, new_refresh} = UserContext.refresh_tokens(refresh_token)
    assert is_binary(new_access)
    assert is_binary(new_refresh)
    refute new_refresh == refresh_token

    # 5b. Refresh tokens (failure: use revoked/old token)
    {count, _} = UserContext.revoke_all_refresh_tokens_for_user(user.id)
    assert count >= 1
    assert {:error, :invalid_refresh_token} = UserContext.refresh_tokens(new_refresh)

    # 6. Simulate sync worker for login (success)
    Mimic.copy(LedgerBankApi.Banking.Integrations.MonzoClient)
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> Mimic.expect(:fetch_accounts, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)
    assert {:ok, %{data: :ok}} = LedgerBankApi.Banking.UserBankLogins.sync_login(login.id)

    # 6b. Simulate sync worker for many logins (simulate all for user)
    LedgerBankApi.Banking.Integrations.MonzoClient
    |> Mimic.expect(:fetch_accounts, 2, fn %{access_token: _} -> {:ok, [%{id: "acc1"}]} end)
    for l <- [login, login2] do
      assert {:ok, %{data: :ok}} = LedgerBankApi.Banking.UserBankLogins.sync_login(l.id)
    end

    # 6c. Simulate sync worker failure (bad login id)
    assert {:error, %{error: %{type: :internal_server_error}}} =
      LedgerBankApi.Banking.UserBankLogins.sync_login(Ecto.UUID.generate())
  end
end

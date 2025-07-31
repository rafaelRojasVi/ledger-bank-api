defmodule LedgerBankApi.Factories do
  @moduledoc """
  Test factories for creating test data consistently across the test suite.
  Uses ExMachina for factory definitions and provides helper functions for common scenarios.
  """

  use ExMachina.Ecto, repo: LedgerBankApi.Repo

  # User factories
  def user_factory do
    %LedgerBankApi.Users.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      full_name: sequence(:full_name, &"User #{&1}"),
      password_hash: Argon2.hash_pwd_salt("password123"),
      role: "user",
      status: "ACTIVE"
    }
  end

  def admin_user_factory do
    %LedgerBankApi.Users.User{
      email: sequence(:email, &"admin#{&1}@example.com"),
      full_name: sequence(:full_name, &"Admin #{&1}"),
      password_hash: Argon2.hash_pwd_salt("password123"),
      role: "admin",
      status: "ACTIVE"
    }
  end

  def suspended_user_factory do
    %LedgerBankApi.Users.User{
      email: sequence(:email, &"suspended#{&1}@example.com"),
      full_name: sequence(:full_name, &"Suspended #{&1}"),
      password_hash: Argon2.hash_pwd_salt("password123"),
      role: "user",
      status: "SUSPENDED"
    }
  end

  # Bank factories
  def bank_factory do
    %LedgerBankApi.Banking.Schemas.Bank{
      name: sequence(:bank_name, &"Bank #{&1}"),
      country: "UK",
      code: sequence(:bank_code, &"BANK_#{&1}"),
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    }
  end

  def monzo_bank_factory do
    %LedgerBankApi.Banking.Schemas.Bank{
      name: sequence(:monzo_bank_name, &"Monzo-#{&1}"),
      country: "UK",
      code: sequence(:monzo_bank_code, &"MONZO_UK_#{&1}"),
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    }
  end

  # Bank branch factories
  def bank_branch_factory do
    %LedgerBankApi.Banking.Schemas.BankBranch{
      name: sequence(:branch_name, &"Branch #{&1}"),
      iban: sequence(:iban, &"IBAN#{&1}"),
      country: "UK",
      bank: build(:bank)
    }
  end

  def bank_branch_with_bank_factory do
    %LedgerBankApi.Banking.Schemas.BankBranch{
      name: sequence(:branch_name, &"Branch #{&1}"),
      iban: sequence(:iban, &"IBAN#{&1}"),
      country: "UK",
      bank: insert(:bank)
    }
  end

  # User bank login factories
  def user_bank_login_factory do
    %LedgerBankApi.Banking.Schemas.UserBankLogin{
      user: build(:user),
      bank_branch: build(:bank_branch_with_bank),
      username: sequence(:username, &"user#{&1}"),
      encrypted_password: "encrypted_password"
    }
  end

  def user_bank_login_factory(attrs) do
    user_bank_login_factory()
    |> Map.merge(attrs)
  end

  # Factory for creating user bank login with existing bank branch
  def user_bank_login_with_branch_factory do
    %LedgerBankApi.Banking.Schemas.UserBankLogin{
      user: build(:user),
      username: sequence(:username, &"user#{&1}"),
      encrypted_password: "encrypted_password"
    }
  end

  # User bank account factories
  def user_bank_account_factory do
    %LedgerBankApi.Banking.Schemas.UserBankAccount{
      user_bank_login: build(:user_bank_login),
      currency: "USD",
      account_type: "CHECKING",
      account_name: sequence(:account_name, &"Account #{&1}"),
      status: "ACTIVE",
      balance: Decimal.new("1000.00"),
      last_four: "1234"
    }
  end

  # Transaction factories
  def transaction_factory do
    %LedgerBankApi.Banking.Schemas.Transaction{
      user_bank_account: build(:user_bank_account),
      amount: Decimal.new("100.00"),
      posted_at: DateTime.utc_now(),
      description: sequence(:description, &"Transaction #{&1}"),
      direction: "DEBIT"
    }
  end

  # User payment factories
  def user_payment_factory do
    %LedgerBankApi.Banking.Schemas.UserPayment{
      user_bank_account: build(:user_bank_account),
      amount: Decimal.new("50.00"),
      payment_type: "PAYMENT",
      status: "PENDING",
      direction: "DEBIT",
      description: sequence(:description, &"Payment #{&1}")
    }
  end

  def processed_payment_factory do
    %LedgerBankApi.Banking.Schemas.UserPayment{
      user_bank_account: build(:user_bank_account),
      amount: Decimal.new("50.00"),
      payment_type: "PAYMENT",
      status: "PROCESSED",
      direction: "DEBIT",
      description: sequence(:description, &"Payment #{&1}")
    }
  end

  # Refresh token factories
  def refresh_token_factory do
    %LedgerBankApi.Users.RefreshToken{
      user: build(:user),
      jti: sequence(:jti, &"jti_#{&1}"),
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  def expired_refresh_token_factory do
    %LedgerBankApi.Users.RefreshToken{
      user: build(:user),
      jti: sequence(:jti, &"jti_#{&1}"),
      expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
    }
  end

  def revoked_refresh_token_factory do
    %LedgerBankApi.Users.RefreshToken{
      user: build(:user),
      jti: sequence(:jti, &"jti_#{&1}"),
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      revoked_at: DateTime.utc_now()
    }
  end

  # Helper functions for common scenarios
  def create_user_with_tokens do
    user = insert(:user)
    {:ok, access_token} = LedgerBankApi.Auth.JWT.generate_access_token(user)
    {:ok, refresh_token} = LedgerBankApi.Auth.JWT.generate_refresh_token(user)
    {:ok, _db_token} = LedgerBankApi.Users.Context.store_refresh_token(user, refresh_token)

    {user, access_token, refresh_token}
  end

  def create_complete_banking_setup do
    user = insert(:user)
    bank = insert(:monzo_bank)
    branch = insert(:bank_branch, bank: bank)
    login = insert(:user_bank_login, user: user, bank_branch: branch)
    account = insert(:user_bank_account, user_bank_login: login)

    {user, bank, branch, login, account}
  end

  def create_payment_with_transaction do
    {_user, _bank, _branch, _login, account} = create_complete_banking_setup()
    payment = insert(:user_payment, user_bank_account: account)

    # Process the payment to create a transaction
    {:ok, %{data: {:ok, transaction}}} =
      LedgerBankApi.Banking.UserPayments.process_payment(payment.id)

    {payment, transaction}
  end

  # Factory for testing different currencies
  def user_bank_account_eur_factory do
    %LedgerBankApi.Banking.Schemas.UserBankAccount{
      user_bank_login: build(:user_bank_login),
      currency: "EUR",
      account_type: "SAVINGS",
      account_name: sequence(:account_name, &"EUR Account #{&1}"),
      status: "ACTIVE",
      balance: Decimal.new("1000.00"),
      last_four: "5678"
    }
  end

  # Factory for testing different payment types
  def transfer_payment_factory do
    %LedgerBankApi.Banking.Schemas.UserPayment{
      user_bank_account: build(:user_bank_account),
      amount: Decimal.new("25.00"),
      payment_type: "TRANSFER",
      status: "PENDING",
      direction: "CREDIT",
      description: sequence(:description, &"Transfer #{&1}")
    }
  end

  # Factory for testing large amounts
  def large_payment_factory do
    %LedgerBankApi.Banking.Schemas.UserPayment{
      user_bank_account: build(:user_bank_account),
      amount: Decimal.new("10000.00"),
      payment_type: "PAYMENT",
      status: "PENDING",
      direction: "DEBIT",
      description: sequence(:description, &"Large Payment #{&1}")
    }
  end
end

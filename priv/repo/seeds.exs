alias LedgerBankApi.Repo
alias LedgerBankApi.Accounts.Schemas.User

alias LedgerBankApi.Financial.Schemas.{
  Bank,
  BankBranch,
  UserBankLogin,
  UserBankAccount,
  UserPayment,
  Transaction
}

# USERS
user1 =
  Repo.insert!(
    User.changeset(%User{}, %{
      email: "alice@example.com",
      full_name: "Alice Example",
      status: "ACTIVE",
      role: "user",
      password: "password123!",
      password_confirmation: "password123!"
    })
  )

user2 =
  Repo.insert!(
    User.changeset(%User{}, %{
      email: "bob@example.com",
      full_name: "Bob Example",
      status: "ACTIVE",
      role: "user",
      password: "password123!",
      password_confirmation: "password123!"
    })
  )

_admin_user =
  Repo.insert!(
    User.changeset(%User{}, %{
      email: "admin@example.com",
      full_name: "Admin User",
      status: "ACTIVE",
      role: "admin",
      password: "admin123!",
      password_confirmation: "admin123!"
    })
  )

# BANKS
bank1 =
  Repo.insert!(
    Bank.changeset(%Bank{}, %{
      name: "Demo Bank",
      country: "US",
      code: "DEMO_BANK_US",
      logo_url: "https://logo1.png",
      api_endpoint: "https://api.demobank.com",
      status: "ACTIVE",
      integration_module: "LedgerBankApi.Financial.Integrations.MonzoClient"
    })
  )

bank2 =
  Repo.insert!(
    Bank.changeset(%Bank{}, %{
      name: "Test Bank",
      country: "UK",
      code: "TEST_BANK_UK",
      logo_url: "https://logo2.png",
      api_endpoint: "https://api.testbank.com",
      status: "ACTIVE",
      integration_module: "LedgerBankApi.Financial.Integrations.MonzoClient"
    })
  )

# BANK BRANCHES
branch1 =
  Repo.insert!(
    BankBranch.changeset(%BankBranch{}, %{
      name: "Main Branch",
      iban: "US1234567890",
      country: "US",
      routing_number: "111000025",
      swift_code: "DEMOUS33XXX",
      bank_id: bank1.id
    })
  )

branch2 =
  Repo.insert!(
    BankBranch.changeset(%BankBranch{}, %{
      name: "London Branch",
      iban: "GB9876543210",
      country: "UK",
      routing_number: "222000111",
      swift_code: "TESTGB2LXXX",
      bank_id: bank2.id
    })
  )

# USER BANK LOGINS
login1 =
  Repo.insert!(
    UserBankLogin.changeset(%UserBankLogin{}, %{
      user_id: user1.id,
      bank_branch_id: branch1.id,
      username: "alice123",
      status: "ACTIVE",
      access_token: "mock_access_token_1",
      refresh_token: "mock_refresh_token_1",
      scope: "read write",
      token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    })
  )

login2 =
  Repo.insert!(
    UserBankLogin.changeset(%UserBankLogin{}, %{
      user_id: user2.id,
      bank_branch_id: branch2.id,
      username: "bob456",
      status: "ACTIVE",
      access_token: "mock_access_token_2",
      refresh_token: "mock_refresh_token_2",
      scope: "read write",
      token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    })
  )

# USER BANK ACCOUNTS
account1 =
  Repo.insert!(
    UserBankAccount.changeset(%UserBankAccount{}, %{
      user_bank_login_id: login1.id,
      user_id: user1.id,
      currency: "USD",
      account_type: "CHECKING",
      balance: Decimal.new("1500.00"),
      last_four: "1234",
      account_name: "Alice Checking",
      status: "ACTIVE",
      last_sync_at: DateTime.utc_now()
    })
  )

account2 =
  Repo.insert!(
    UserBankAccount.changeset(%UserBankAccount{}, %{
      user_bank_login_id: login2.id,
      user_id: user2.id,
      currency: "GBP",
      account_type: "SAVINGS",
      balance: Decimal.new("2500.00"),
      last_four: "5678",
      account_name: "Bob Savings",
      status: "ACTIVE",
      last_sync_at: DateTime.utc_now()
    })
  )

# USER PAYMENTS
_payment1 =
  Repo.insert!(
    UserPayment.changeset(%UserPayment{}, %{
      user_bank_account_id: account1.id,
      user_id: user1.id,
      amount: Decimal.new("100.00"),
      description: "Grocery Shopping",
      payment_type: "WITHDRAWAL",
      status: "COMPLETED",
      posted_at: DateTime.utc_now(),
      direction: "DEBIT"
    })
  )

_payment2 =
  Repo.insert!(
    UserPayment.changeset(%UserPayment{}, %{
      user_bank_account_id: account2.id,
      user_id: user2.id,
      amount: Decimal.new("500.00"),
      description: "Salary Deposit",
      payment_type: "DEPOSIT",
      status: "COMPLETED",
      posted_at: DateTime.utc_now(),
      direction: "CREDIT"
    })
  )

# TRANSACTIONS
Repo.insert!(
  Transaction.changeset(%Transaction{}, %{
    account_id: account1.id,
    user_id: user1.id,
    amount: Decimal.new("45.50"),
    posted_at: DateTime.utc_now(),
    description: "Restaurant",
    direction: "DEBIT"
  })
)

Repo.insert!(
  Transaction.changeset(%Transaction{}, %{
    account_id: account1.id,
    user_id: user1.id,
    amount: Decimal.new("200.00"),
    posted_at: DateTime.utc_now(),
    description: "Refund",
    direction: "CREDIT"
  })
)

Repo.insert!(
  Transaction.changeset(%Transaction{}, %{
    account_id: account2.id,
    user_id: user2.id,
    amount: Decimal.new("60.00"),
    posted_at: DateTime.utc_now(),
    description: "Online Shopping",
    direction: "DEBIT"
  })
)

Repo.insert!(
  Transaction.changeset(%Transaction{}, %{
    account_id: account2.id,
    user_id: user2.id,
    amount: Decimal.new("1200.00"),
    posted_at: DateTime.utc_now(),
    description: "Bonus",
    direction: "CREDIT"
  })
)

IO.puts(
  "Seeded users (including admin), banks, branches, logins, accounts, payments, and transactions!"
)

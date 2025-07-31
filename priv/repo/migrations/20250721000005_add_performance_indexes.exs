defmodule LedgerBankApi.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # User bank accounts indexes
    create_if_not_exists index(:user_bank_accounts, [:user_bank_login_id])
    create_if_not_exists index(:user_bank_accounts, [:status])
    create_if_not_exists index(:user_bank_accounts, [:account_type])
    create_if_not_exists index(:user_bank_accounts, [:currency])
    create_if_not_exists index(:user_bank_accounts, [:last_four])
    create_if_not_exists index(:user_bank_accounts, [:inserted_at])
    create_if_not_exists index(:user_bank_accounts, [:updated_at])

    # Composite indexes for common queries
    create_if_not_exists index(:user_bank_accounts, [:user_bank_login_id, :status])
    create_if_not_exists index(:user_bank_accounts, [:user_bank_login_id, :account_type])
    create_if_not_exists index(:user_bank_accounts, [:user_bank_login_id, :inserted_at])

    # User bank logins indexes
    create_if_not_exists index(:user_bank_logins, [:user_id])
    create_if_not_exists index(:user_bank_logins, [:bank_branch_id])
    create_if_not_exists index(:user_bank_logins, [:status])
    create_if_not_exists index(:user_bank_logins, [:inserted_at])

    # Composite indexes for user bank logins
    create_if_not_exists index(:user_bank_logins, [:user_id, :status])
    create_if_not_exists index(:user_bank_logins, [:user_id, :inserted_at])

    # Transactions indexes
    create_if_not_exists index(:transactions, [:account_id])
    create_if_not_exists index(:transactions, [:posted_at])
    create_if_not_exists index(:transactions, [:direction])
    create_if_not_exists index(:transactions, [:inserted_at])

    # Composite indexes for transactions
    create_if_not_exists index(:transactions, [:account_id, :posted_at])
    create_if_not_exists index(:transactions, [:account_id, :direction])
    create_if_not_exists index(:transactions, [:account_id, :inserted_at])

    # User payments indexes
    create_if_not_exists index(:user_payments, [:user_bank_account_id])
    create_if_not_exists index(:user_payments, [:status])
    create_if_not_exists index(:user_payments, [:payment_type])
    create_if_not_exists index(:user_payments, [:direction])
    create_if_not_exists index(:user_payments, [:posted_at])
    create_if_not_exists index(:user_payments, [:inserted_at])

    # Composite indexes for user payments
    create_if_not_exists index(:user_payments, [:user_bank_account_id, :status])
    create_if_not_exists index(:user_payments, [:user_bank_account_id, :posted_at])
    create_if_not_exists index(:user_payments, [:user_bank_account_id, :inserted_at])

    # Users indexes
    create_if_not_exists index(:users, [:email])
    create_if_not_exists index(:users, [:role])
    create_if_not_exists index(:users, [:status])
    create_if_not_exists index(:users, [:inserted_at])

    # Composite indexes for users
    create_if_not_exists index(:users, [:role, :status])
    create_if_not_exists index(:users, [:status, :inserted_at])

    # Banks indexes
    create_if_not_exists index(:banks, [:status])
    create_if_not_exists index(:banks, [:country])
    create_if_not_exists index(:banks, [:code])
    create_if_not_exists index(:banks, [:inserted_at])

    # Bank branches indexes
    create_if_not_exists index(:bank_branches, [:bank_id])
    create_if_not_exists index(:bank_branches, [:country])
    create_if_not_exists index(:bank_branches, [:iban])
    create_if_not_exists index(:bank_branches, [:swift_code])
    create_if_not_exists index(:bank_branches, [:inserted_at])

    # Composite indexes for bank branches
    create_if_not_exists index(:bank_branches, [:bank_id, :country])
    create_if_not_exists index(:bank_branches, [:bank_id, :inserted_at])

    # Refresh tokens indexes
    create_if_not_exists index(:refresh_tokens, [:user_id])
    create_if_not_exists index(:refresh_tokens, [:jti])
    create_if_not_exists index(:refresh_tokens, [:expires_at])
    create_if_not_exists index(:refresh_tokens, [:revoked_at])

    # Composite indexes for refresh tokens
    create_if_not_exists index(:refresh_tokens, [:user_id, :revoked_at])
    create_if_not_exists index(:refresh_tokens, [:jti, :revoked_at])
  end
end

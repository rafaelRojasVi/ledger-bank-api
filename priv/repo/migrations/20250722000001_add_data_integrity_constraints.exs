defmodule LedgerBankApi.Repo.Migrations.AddDataIntegrityConstraints do
  use Ecto.Migration

  def change do
    # Add missing unique constraints
    create_if_not_exists unique_index(:users, [:email])
    create_if_not_exists unique_index(:banks, [:code])
    create_if_not_exists unique_index(:bank_branches, [:iban])
    create_if_not_exists unique_index(:bank_branches, [:swift_code])
    create_if_not_exists unique_index(:user_bank_logins, [:user_id, :bank_branch_id, :username])
    create_if_not_exists unique_index(:user_bank_accounts, [:external_account_id])
    create_if_not_exists unique_index(:user_payments, [:external_transaction_id])
    create_if_not_exists unique_index(:refresh_tokens, [:jti])

    # Add missing foreign key constraints
    # Add the missing user_id column to transactions
    alter table(:transactions) do
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict)
    end

    # Add missing user_id column to user_bank_accounts
    alter table(:user_bank_accounts) do
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict)
    end

    # user_bank_logins already has correct foreign key constraints from creation migration

    # Add missing user_id column to user_payments
    alter table(:user_payments) do
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict)
    end

    # bank_branches already has correct foreign key constraints from creation migration

    # refresh_tokens already has correct foreign key constraints from creation migration

    # Add check constraints for data validation
    create constraint(:user_bank_accounts, :balance_not_negative_for_non_credit,
      check: "account_type = 'CREDIT' OR balance >= 0"
    )

    create constraint(:user_bank_accounts, :valid_account_type,
      check: "account_type IN ('CHECKING', 'SAVINGS', 'CREDIT', 'INVESTMENT')"
    )

    create constraint(:user_bank_accounts, :valid_status,
      check: "status IN ('ACTIVE', 'INACTIVE', 'CLOSED')"
    )

    create constraint(:user_bank_logins, :valid_status,
      check: "status IN ('ACTIVE', 'INACTIVE', 'ERROR')"
    )

    create constraint(:user_bank_logins, :valid_sync_frequency,
      check: "sync_frequency >= 300 AND sync_frequency <= 86400"
    )

    create constraint(:user_payments, :valid_direction,
      check: "direction IN ('CREDIT', 'DEBIT')"
    )

    create constraint(:user_payments, :valid_payment_type,
      check: "payment_type IN ('TRANSFER', 'PAYMENT', 'DEPOSIT', 'WITHDRAWAL')"
    )

    create constraint(:user_payments, :valid_payment_status,
      check: "status IN ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED')"
    )

    create constraint(:user_payments, :amount_not_negative,
      check: "amount >= 0"
    )

    create constraint(:transactions, :valid_direction,
      check: "direction IN ('CREDIT', 'DEBIT')"
    )

    create constraint(:transactions, :amount_not_negative,
      check: "amount >= 0"
    )

    create constraint(:banks, :valid_status,
      check: "status IN ('ACTIVE', 'INACTIVE')"
    )

    create constraint(:users, :valid_role,
      check: "role IN ('admin', 'support', 'user')"
    )

    create constraint(:users, :valid_status,
      check: "status IN ('ACTIVE', 'SUSPENDED', 'DELETED')"
    )

    # Add additional performance indexes for complex queries
    create_if_not_exists index(:user_bank_accounts, [:user_id, :status, :account_type])
    create_if_not_exists index(:user_bank_logins, [:user_id, :status, :last_sync_at])
    create_if_not_exists index(:transactions, [:user_id, :direction, :posted_at])
    create_if_not_exists index(:user_payments, [:user_id, :status, :payment_type])
    create_if_not_exists index(:user_payments, [:user_bank_account_id, :status, :posted_at])
    create_if_not_exists index(:refresh_tokens, [:user_id, :expires_at, :revoked_at])
    create_if_not_exists index(:banks, [:status, :country, :integration_module])
    create_if_not_exists index(:bank_branches, [:bank_id, :country])

    # Add indexes for text search (using standard B-tree indexes for now)
    # Note: GIN indexes with trigram operators require pg_trgm extension
    create_if_not_exists index(:users, [:email])
    create_if_not_exists index(:banks, [:name])
    create_if_not_exists index(:bank_branches, [:name])
    create_if_not_exists index(:transactions, [:description])
    create_if_not_exists index(:user_payments, [:description])

    # Add partial indexes for active records
    create_if_not_exists index(:user_bank_accounts, [:user_id], where: "status = 'ACTIVE'")
    create_if_not_exists index(:user_bank_logins, [:user_id], where: "status = 'ACTIVE'")
    create_if_not_exists index(:banks, [:country], where: "status = 'ACTIVE'")
    create_if_not_exists index(:bank_branches, [:bank_id])

    # Add indexes for cleanup operations
    create_if_not_exists index(:refresh_tokens, [:expires_at], where: "revoked_at IS NULL")
    create_if_not_exists index(:user_bank_logins, [:last_sync_at], where: "status = 'ACTIVE'")
    create_if_not_exists index(:user_payments, [:posted_at], where: "status = 'PENDING'")
  end
end

defmodule LedgerBankApi.Repo.Migrations.AddDataIntegrityConstraints do
  use Ecto.Migration

  def change do
    # Add check constraints for data integrity
    alter table(:users) do
      modify :status, :string, check: "status IN ('ACTIVE', 'SUSPENDED', 'DELETED')"
      modify :role, :string, check: "role IN ('user', 'admin', 'support')"
    end

    alter table(:banks) do
      modify :status, :string, check: "status IN ('ACTIVE', 'INACTIVE')"
    end

    alter table(:user_bank_logins) do
      modify :status, :string, check: "status IN ('ACTIVE', 'INACTIVE', 'EXPIRED')"
      modify :sync_frequency, :integer, check: "sync_frequency >= 300 AND sync_frequency <= 86400"
    end

    alter table(:user_bank_accounts) do
      modify :account_type, :string, check: "account_type IN ('CHECKING', 'SAVINGS', 'CREDIT', 'INVESTMENT')"
      modify :status, :string, check: "status IN ('ACTIVE', 'INACTIVE', 'CLOSED')"
      modify :balance, :decimal, check: "balance >= 0 OR account_type = 'CREDIT'"
    end

    alter table(:user_payments) do
      modify :direction, :string, check: "direction IN ('CREDIT', 'DEBIT')"
      modify :payment_type, :string, check: "payment_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT')"
      modify :status, :string, check: "status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')"
      modify :amount, :decimal, check: "amount > 0"
    end

    alter table(:transactions) do
      modify :direction, :string, check: "direction IN ('CREDIT', 'DEBIT')"
      modify :amount, :decimal, check: "amount > 0"
    end
  end
end

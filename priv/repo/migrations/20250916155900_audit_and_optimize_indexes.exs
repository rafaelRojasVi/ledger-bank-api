defmodule LedgerBankApi.Repo.Migrations.AuditAndOptimizeIndexes do
  use Ecto.Migration

  def up do
    # ============================================================================
    # INDEX AUDIT AND OPTIMIZATION
    # ============================================================================
    # This migration adds missing indexes based on common query patterns
    # identified in the codebase audit.

    # ============================================================================
    # USERS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for common user filtering patterns
    # Used in: UserService.list_users/1 with status + role filtering
    create index(:users, [:status, :role], name: :users_status_role_index)

    # Composite index for active user queries
    # Used in: UserService.list_users/1 with active filtering
    create index(:users, [:active, :status], name: :users_active_status_index)

    # Composite index for pagination with sorting
    # Used in: UserService.list_users/1 with order_by inserted_at
    create index(:users, [:inserted_at, :id], name: :users_inserted_at_id_index)

    # Composite index for user verification queries
    # Used in: UserService.list_users/1 with verified filtering
    create index(:users, [:verified, :active], name: :users_verified_active_index)

    # ============================================================================
    # USER_PAYMENTS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for user payment queries with status filtering
    # Used in: FinancialService.list_user_payments/2 with status filtering
    create index(:user_payments, [:user_id, :status], name: :user_payments_user_id_status_index)

    # Composite index for payment type filtering
    # Used in: FinancialService.list_user_payments/2 with payment_type filtering
    create index(:user_payments, [:user_id, :payment_type], name: :user_payments_user_id_payment_type_index)

    # Composite index for direction filtering
    # Used in: FinancialService.list_user_payments/2 with direction filtering
    create index(:user_payments, [:user_id, :direction], name: :user_payments_user_id_direction_index)

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_user_payments/2 with order_by
    create index(:user_payments, [:user_id, :inserted_at, :id], name: :user_payments_user_id_inserted_at_id_index)

    # Composite index for daily limit calculations
    # Used in: FinancialService.validate_daily_limits/2
    create index(:user_payments, [:user_bank_account_id, :direction, :status, :posted_at],
      name: :user_payments_account_direction_status_posted_at_index)

    # Composite index for duplicate detection
    # Used in: FinancialService.validate_duplicate_payment/1
    create index(:user_payments, [:user_id, :amount, :description, :direction, :status],
      name: :user_payments_duplicate_detection_index)

    # Composite index for external transaction ID lookups
    # Used in: FinancialService.get_payment_by_external_id/1
    create index(:user_payments, [:external_transaction_id, :status],
      name: :user_payments_external_id_status_index)

    # ============================================================================
    # TRANSACTIONS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for user transaction queries
    # Used in: FinancialService.list_user_transactions/2
    create index(:transactions, [:user_id, :posted_at], name: :transactions_user_id_posted_at_index)

    # Composite index for account transaction queries
    # Used in: FinancialService.list_account_transactions/2
    # Note: This index already exists from the original migration, skipping to avoid duplicate

    # Composite index for direction filtering
    # Used in: FinancialService.list_user_transactions/2 with direction filtering
    create index(:transactions, [:user_id, :direction, :posted_at], name: :transactions_user_id_direction_posted_at_index)

    # Composite index for amount range queries
    # Used in: FinancialService.list_user_transactions/2 with amount filtering
    create index(:transactions, [:user_id, :amount, :posted_at], name: :transactions_user_id_amount_posted_at_index)

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_user_transactions/2 with order_by
    create index(:transactions, [:user_id, :inserted_at, :id], name: :transactions_user_id_inserted_at_id_index)

    # ============================================================================
    # USER_BANK_ACCOUNTS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for user account queries
    # Used in: FinancialService.list_user_accounts/1
    create index(:user_bank_accounts, [:user_id, :status], name: :user_bank_accounts_user_id_status_index)

    # Composite index for account type filtering
    # Used in: FinancialService.list_user_accounts/1 with account_type filtering
    create index(:user_bank_accounts, [:user_id, :account_type], name: :user_bank_accounts_user_id_account_type_index)

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_user_accounts/1 with order_by
    create index(:user_bank_accounts, [:user_id, :inserted_at, :id], name: :user_bank_accounts_user_id_inserted_at_id_index)

    # ============================================================================
    # REFRESH_TOKENS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for user token queries
    # Used in: UserService.get_user_from_token/1
    create index(:refresh_tokens, [:user_id, :revoked_at], name: :refresh_tokens_user_id_revoked_at_index)

    # Composite index for token cleanup
    # Used in: UserService.cleanup_expired_tokens/0
    # Note: This index already exists from the original migration, skipping to avoid duplicate

    # Composite index for token validation
    # Used in: UserService.validate_refresh_token/1
    create index(:refresh_tokens, [:user_id, :expires_at, :revoked_at], name: :refresh_tokens_user_id_expires_at_revoked_at_index)

    # ============================================================================
    # OBAN_JOBS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for job status queries
    # Used in: PaymentWorker.get_job_status/1
    create index(:oban_jobs, [:args, :state], name: :oban_jobs_args_state_index)

    # Composite index for job cleanup
    # Used in: Oban.Plugins.Pruner
    create index(:oban_jobs, [:state, :inserted_at], name: :oban_jobs_state_inserted_at_index)

    # Composite index for job retry logic
    # Used in: PaymentWorker retry logic
    create index(:oban_jobs, [:queue, :state, :attempt], name: :oban_jobs_queue_state_attempt_index)

    # ============================================================================
    # USER_BANK_LOGINS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for user login queries
    # Used in: FinancialService.list_user_logins/1
    create index(:user_bank_logins, [:user_id, :status], name: :user_bank_logins_user_id_status_index)

    # Composite index for bank login queries
    # Used in: FinancialService.list_bank_logins/1
    create index(:user_bank_logins, [:bank_branch_id, :status], name: :user_bank_logins_bank_branch_id_status_index)

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_user_logins/1 with order_by
    create index(:user_bank_logins, [:user_id, :inserted_at, :id], name: :user_bank_logins_user_id_inserted_at_id_index)

    # ============================================================================
    # BANKS TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for bank filtering
    # Used in: FinancialService.list_banks/1 with status filtering
    create index(:banks, [:status, :country], name: :banks_status_country_index)

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_banks/1 with order_by
    create index(:banks, [:inserted_at, :id], name: :banks_inserted_at_id_index)

    # ============================================================================
    # BANK_BRANCHES TABLE OPTIMIZATIONS
    # ============================================================================

    # Composite index for bank branch queries
    # Used in: FinancialService.list_bank_branches/1
    # Note: bank_branches_bank_id_index already exists from the original migration, skipping to avoid duplicate

    # Composite index for pagination with sorting
    # Used in: FinancialService.list_bank_branches/1 with order_by
    create index(:bank_branches, [:bank_id, :inserted_at, :id], name: :bank_branches_bank_id_inserted_at_id_index)
  end

  def down do
    # Drop all the indexes we created
    drop index(:users, [:status, :role], name: :users_status_role_index)
    drop index(:users, [:active, :status], name: :users_active_status_index)
    drop index(:users, [:inserted_at, :id], name: :users_inserted_at_id_index)
    drop index(:users, [:verified, :active], name: :users_verified_active_index)

    drop index(:user_payments, [:user_id, :status], name: :user_payments_user_id_status_index)
    drop index(:user_payments, [:user_id, :payment_type], name: :user_payments_user_id_payment_type_index)
    drop index(:user_payments, [:user_id, :direction], name: :user_payments_user_id_direction_index)
    drop index(:user_payments, [:user_id, :inserted_at, :id], name: :user_payments_user_id_inserted_at_id_index)
    drop index(:user_payments, [:user_bank_account_id, :direction, :status, :posted_at],
      name: :user_payments_account_direction_status_posted_at_index)
    drop index(:user_payments, [:user_id, :amount, :description, :direction, :status],
      name: :user_payments_duplicate_detection_index)
    drop index(:user_payments, [:external_transaction_id, :status],
      name: :user_payments_external_id_status_index)

    drop index(:transactions, [:user_id, :posted_at], name: :transactions_user_id_posted_at_index)
    # Note: transactions_account_id_posted_at_index is not dropped as it was created in the original migration
    drop index(:transactions, [:user_id, :direction, :posted_at], name: :transactions_user_id_direction_posted_at_index)
    drop index(:transactions, [:user_id, :amount, :posted_at], name: :transactions_user_id_amount_posted_at_index)
    drop index(:transactions, [:user_id, :inserted_at, :id], name: :transactions_user_id_inserted_at_id_index)

    drop index(:user_bank_accounts, [:user_id, :status], name: :user_bank_accounts_user_id_status_index)
    drop index(:user_bank_accounts, [:user_id, :account_type], name: :user_bank_accounts_user_id_account_type_index)
    drop index(:user_bank_accounts, [:user_id, :inserted_at, :id], name: :user_bank_accounts_user_id_inserted_at_id_index)

    drop index(:refresh_tokens, [:user_id, :revoked_at], name: :refresh_tokens_user_id_revoked_at_index)
    # Note: refresh_tokens_expires_at_index is not dropped as it was created in the original migration
    drop index(:refresh_tokens, [:user_id, :expires_at, :revoked_at], name: :refresh_tokens_user_id_expires_at_revoked_at_index)

    drop index(:oban_jobs, [:args, :state], name: :oban_jobs_args_state_index)
    drop index(:oban_jobs, [:state, :inserted_at], name: :oban_jobs_state_inserted_at_index)
    drop index(:oban_jobs, [:queue, :state, :attempt], name: :oban_jobs_queue_state_attempt_index)

    drop index(:user_bank_logins, [:user_id, :status], name: :user_bank_logins_user_id_status_index)
    drop index(:user_bank_logins, [:bank_branch_id, :status], name: :user_bank_logins_bank_branch_id_status_index)
    drop index(:user_bank_logins, [:user_id, :inserted_at, :id], name: :user_bank_logins_user_id_inserted_at_id_index)

    drop index(:banks, [:status, :country], name: :banks_status_country_index)
    drop index(:banks, [:inserted_at, :id], name: :banks_inserted_at_id_index)

    # Note: bank_branches_bank_id_index is not dropped as it was created in the original migration
    drop index(:bank_branches, [:bank_id, :inserted_at, :id], name: :bank_branches_bank_id_inserted_at_id_index)
  end
end

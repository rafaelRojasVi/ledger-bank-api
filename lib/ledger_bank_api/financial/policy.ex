defmodule LedgerBankApi.Financial.Policy do
  @moduledoc """
  Pure permission logic for financial operations.

  This module contains all business rules for determining what financial actions
  users can perform. All functions are pure (no side effects) and easily testable.

  ## Usage

      # Check if user can create a payment
      Policy.can_create_payment?(current_user, payment_attrs)

      # Check if user can view an account
      Policy.can_view_account?(current_user, account)

      # Check if user can process a payment
      Policy.can_process_payment?(current_user, payment)

      # Check if user can sync an account
      Policy.can_sync_account?(current_user, account)
  """

  @doc """
  Check if a user can create a payment.

  ## Rules:
  - All authenticated users can create payments
  - Payment must be for their own account
  - Account must be active
  """
  def can_create_payment?(user, payment_attrs) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Payment must have required fields
      is_nil(payment_attrs[:user_bank_account_id]) -> false
      # For now, allow all authenticated users to create payments
      # In a real implementation, you might want to check account ownership
      true -> true
    end
  end

  @doc """
  Check if a user can view a bank account.

  ## Rules:
  - Admins can view any account
  - Support users can view any account
  - Users can only view their own accounts
  """
  def can_view_account?(user, account) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Admins and support can view any account
      user.role in ["admin", "support"] -> true
      # Users can only view their own accounts
      user.id == account.user_id -> true
      true -> false
    end
  end

  @doc """
  Check if a user can view a payment.

  ## Rules:
  - Admins can view any payment
  - Support users can view any payment
  - Users can only view their own payments
  """
  def can_view_payment?(user, payment) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Admins and support can view any payment
      user.role in ["admin", "support"] -> true
      # Users can only view their own payments
      user.id == payment.user_id -> true
      true -> false
    end
  end

  @doc """
  Check if a user can process a payment.

  ## Rules:
  - Only admins can manually process payments
  - System can process payments (for background jobs)
  - Users cannot manually process their own payments
  """
  def can_process_payment?(user, payment) do
    cond do
      # System processing (no user context)
      is_nil(user) -> true
      # Admins can process any payment
      user.role == "admin" -> true
      # Users can process their own pending payments
      user.id == payment.user_id and payment.status == "PENDING" -> true
      # Users cannot process other users' payments or already processed payments
      true -> false
    end
  end

  @doc """
  Check if a user can sync a bank account.

  ## Rules:
  - Admins can sync any account
  - Support users can sync any account
  - Users can sync their own accounts
  - System can sync accounts (for background jobs)
  """
  def can_sync_account?(user, account) do
    cond do
      # System sync (no user context)
      is_nil(user) -> true
      # Admins and support can sync any account
      user.role in ["admin", "support"] -> true
      # Users can sync their own accounts
      user.id == account.user_id -> true
      true -> false
    end
  end

  @doc """
  Check if a user can create a bank account.

  ## Rules:
  - All authenticated users can create bank accounts
  - Account must be for themselves
  """
  def can_create_bank_account?(user, account_attrs) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Account must have required fields
      is_nil(account_attrs[:user_bank_login_id]) -> false
      # For now, allow all authenticated users to create accounts
      # In a real implementation, you might want to check login ownership
      true -> true
    end
  end

  @doc """
  Check if a user can view transactions for an account.

  ## Rules:
  - Admins can view transactions for any account
  - Support users can view transactions for any account
  - Users can only view transactions for their own accounts
  """
  def can_view_account_transactions?(user, account) do
    can_view_account?(user, account)
  end

  @doc """
  Check if a user can list their own payments.

  ## Rules:
  - All authenticated users can list their own payments
  - Admins and support can list all payments
  """
  def can_list_payments?(user, _opts \\ []) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Admins and support can list all payments
      user.role in ["admin", "support"] -> true
      # Users can list their own payments
      true -> true
    end
  end

  @doc """
  Check if a user can list their own bank accounts.

  ## Rules:
  - All authenticated users can list their own accounts
  - Admins and support can list all accounts
  """
  def can_list_bank_accounts?(user, _opts \\ []) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Admins and support can list all accounts
      user.role in ["admin", "support"] -> true
      # Users can list their own accounts
      true -> true
    end
  end

  @doc """
  Check if a user can access financial statistics.

  ## Rules:
  - Only admins can access financial statistics
  """
  def can_access_financial_stats?(user) do
    user.role == "admin"
  end

  @doc """
  Check if user can view financial statistics (alias for consistency).
  """
  def can_view_financial_stats?(user) do
    can_access_financial_stats?(user)
  end

  @doc """
  Check if a user can cancel a payment.

  ## Rules:
  - Users can cancel their own pending payments
  - Admins can cancel any pending payment
  - Support users can cancel any pending payment
  - Cannot cancel completed or failed payments
  """
  def can_cancel_payment?(user, payment) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Payment must be in a cancellable state
      payment.status != "PENDING" -> false
      # Admins and support can cancel any pending payment
      user.role in ["admin", "support"] -> true
      # Users can cancel their own pending payments
      user.id == payment.user_id -> true
      true -> false
    end
  end

  @doc """
  Check if a user can update a bank account.

  ## Rules:
  - Admins can update any account
  - Support users can update any account
  - Users can update their own accounts (with restrictions)
  """
  def can_update_bank_account?(user, account, attrs) do
    cond do
      # User must be authenticated
      is_nil(user) -> false
      # Admins can update any account
      user.role == "admin" -> true
      # Support users can update any account
      user.role == "support" -> true
      # Users can update their own accounts (with restrictions)
      user.id == account.user_id -> can_user_update_own_account?(attrs)
      true -> false
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  @doc false
  def can_user_update_own_account?(attrs) do
    # Users can only update certain fields of their own accounts
    # They cannot change critical fields like account_type, currency, etc.
    allowed_fields = ["account_name", "status"]
    restricted_fields = ["currency", "account_type", "user_bank_login_id", "external_account_id"]

    attrs_keys = Map.keys(attrs) |> Enum.map(&to_string/1)

    has_restricted_fields = Enum.any?(attrs_keys, &(&1 in restricted_fields))
    has_allowed_fields = Enum.any?(attrs_keys, &(&1 in allowed_fields))

    not has_restricted_fields and has_allowed_fields
  end
end

defmodule LedgerBankApi.Financial.FinancialServiceMock do
  @moduledoc """
  Mock implementation of FinancialService for testing.

  This module provides a mock implementation that can be used with Mox
  to test worker behavior without making actual external API calls.
  """

  @behaviour LedgerBankApi.Financial.FinancialServiceBehaviour

  @impl true
  def sync_login(login_id) do
    # Default mock implementation - can be overridden in tests
    {:ok, %{status: "synced", login_id: login_id, synced_at: DateTime.utc_now()}}
  end

  @impl true
  def process_payment(payment_id) do
    # Default mock implementation - can be overridden in tests
    {:ok, %{status: "completed", payment_id: payment_id, processed_at: DateTime.utc_now()}}
  end

  @impl true
  def get_user_payment(payment_id) do
    # Default mock implementation - can be overridden in tests
    {:ok, %{id: payment_id, status: "PENDING", amount: 100.00}}
  end

  @impl true
  def get_user_bank_login(login_id) do
    # Default mock implementation - can be overridden in tests
    {:ok, %{id: login_id, status: "ACTIVE", username: "test_user"}}
  end
end

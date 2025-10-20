defmodule LedgerBankApi.Financial.FinancialServiceBehaviour do
  @moduledoc """
  Behaviour for FinancialService to enable mocking in tests.

  This behaviour defines the contract that both the real FinancialService
  and the mock implementation must follow.
  """

  @doc """
  Synchronizes bank login data with external bank API.
  """
  @callback sync_login(login_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Processes a user payment.
  """
  @callback process_payment(payment_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Gets a user payment by ID.
  """
  @callback get_user_payment(payment_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Gets a user bank login by ID.
  """
  @callback get_user_bank_login(login_id :: String.t()) ::
              {:ok, map()} | {:error, term()}
end

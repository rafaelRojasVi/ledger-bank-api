defmodule LedgerBankApi.BankClient do
  @moduledoc """
  Behaviour for bank client operations.
  """

  @callback sync_accounts(login :: map()) :: {:ok, list()} | {:error, term()}
  @callback get_balance(account_id :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback get_transactions(account_id :: String.t()) :: {:ok, list()} | {:error, term()}
  @callback initiate_payment(payment :: map()) :: {:ok, map()} | {:error, term()}
end

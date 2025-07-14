defmodule LedgerBankApi.PaymentProcessor do
  @moduledoc """
  Behaviour for payment processing operations.
  """

  @callback process_payment(payment :: map()) :: {:ok, map()} | {:error, term()}
  @callback validate_payment(payment :: map()) :: :ok | {:error, term()}
  @callback create_payee(payee :: map()) :: {:ok, map()} | {:error, term()}
  @callback get_payment_schemes(account_id :: String.t()) :: {:ok, list()} | {:error, term()}
end

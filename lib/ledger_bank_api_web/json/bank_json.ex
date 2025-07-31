defmodule LedgerBankApiWeb.JSON.BankJSON do
  @moduledoc """
  JSON formatting for bank data.
  """

  @doc """
  Format bank data consistently.
  """
  def format(bank) do
    %{
      id: bank.id,
      name: bank.name,
      country: bank.country,
      logo_url: bank.logo_url,
      status: bank.status,
      code: bank.code
    }
  end
end

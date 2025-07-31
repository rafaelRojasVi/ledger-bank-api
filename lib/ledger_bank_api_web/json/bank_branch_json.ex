defmodule LedgerBankApiWeb.JSON.BankBranchJSON do
  @moduledoc """
  JSON formatting for bank branch data.
  """

  @doc """
  Format bank branch data consistently.
  """
  def format(branch) do
    %{
      id: branch.id,
      name: branch.name,
      country: branch.country,
      iban: branch.iban,
      swift_code: branch.swift_code,
      routing_number: branch.routing_number,
      bank: LedgerBankApiWeb.JSON.BankJSON.format(branch.bank)
    }
  end
end

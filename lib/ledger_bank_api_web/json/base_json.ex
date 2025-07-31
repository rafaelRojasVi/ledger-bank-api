defmodule LedgerBankApiWeb.JSON.BaseJSON do
  @moduledoc """
  Base JSON module providing standardized response formatting and common data transformations.
  Reduces duplication across JSON views.
  """

  @doc """
  Standard response wrapper for list endpoints.
  """
  def list_response(data, resource_name) do
    %{data: Enum.map(data, &format_resource(&1, resource_name))}
  end

  @doc """
  Standard response wrapper for single resource endpoints.
  """
  def show_response(data, resource_name) do
    %{data: format_resource(data, resource_name)}
  end

  @doc """
  Standard response wrapper for paginated endpoints.
  """
  def paginated_response(data, pagination, resource_name) do
    %{
      data: Enum.map(data, &format_resource(&1, resource_name)),
      pagination: pagination
    }
  end

  @doc """
  Standard response wrapper for relationships.
  """
  def relationship_response(data, resource_name) do
    %{data: format_resource(data, resource_name)}
  end

  # Private helper functions

  defp format_resource(data, resource_name) do
    case resource_name do
      :user -> LedgerBankApiWeb.JSON.UserJSON.format(data)
      :account -> LedgerBankApiWeb.JSON.AccountJSON.format(data)
      :transaction -> LedgerBankApiWeb.JSON.TransactionJSON.format(data)
      :payment -> LedgerBankApiWeb.JSON.PaymentJSON.format(data)
      :user_bank_login -> LedgerBankApiWeb.JSON.UserBankLoginJSON.format(data)
      :bank -> LedgerBankApiWeb.JSON.BankJSON.format(data)
      :bank_branch -> LedgerBankApiWeb.JSON.BankBranchJSON.format(data)
      _ -> data
    end
  end
end

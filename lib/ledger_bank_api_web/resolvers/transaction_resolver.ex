defmodule LedgerBankApiWeb.Resolvers.TransactionResolver do
  @moduledoc """
  GraphQL resolvers for transaction-related operations.
  """

  def list(%{account_id: _account_id, limit: _limit, offset: _offset}, %{context: %{current_user: _current_user}}) do
    # TODO: Implement transaction service integration
    {:ok, []}
  end

  def list(%{limit: _limit, offset: _offset}, %{context: %{current_user: _current_user}}) do
    # TODO: Implement transaction service integration
    {:ok, []}
  end

  def list(_args, _resolution) do
    {:error, "Authentication required"}
  end
end

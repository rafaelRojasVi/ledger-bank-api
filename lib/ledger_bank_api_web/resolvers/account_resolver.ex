defmodule LedgerBankApiWeb.Resolvers.AccountResolver do
  @moduledoc """
  GraphQL resolvers for account-related operations.
  """

  def list(_args, %{context: %{current_user: _current_user}}) do
    # This would integrate with your account service
    # For now, return empty list
    {:ok, []}
  end

  def list(_args, _resolution) do
    {:error, "Authentication required"}
  end
end

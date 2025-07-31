defmodule LedgerBankApiWeb.JSON.AccountJSON do
  @moduledoc """
  JSON formatting for account data.
  """

  @doc """
  Format account data consistently.
  """
  def format(%Ecto.Association.NotLoaded{}), do: nil
  def format(account) do
    %{
      id: account.id,
      name: account.account_name,
      status: account.status,
      type: account.account_type,
      currency: account.currency,
      institution: format_institution(account),
      last_four: account.last_four,
      balance: account.balance,
      last_sync_at: account.last_sync_at,
      links: build_account_links(account.id)
    }
  end

  @doc """
  Format account summary (for nested objects).
  """
  def format_summary(%Ecto.Association.NotLoaded{}), do: nil
  def format_summary(account) do
    %{
      id: account.id,
      account_name: account.account_name,
      last_four: account.last_four,
      currency: account.currency
    }
  end

  @doc """
  Format balance response.
  """
  def format_balance_response(%Ecto.Association.NotLoaded{}), do: %{data: nil}
  def format_balance_response(account) do
    %{
      data: %{
        account_id: account.id,
        balance: account.balance,
        currency: account.currency,
        last_updated: account.last_sync_at
      }
    }
  end

  # Private helper functions

  defp format_institution(account) do
    case {account.user_bank_login, account.user_bank_login && account.user_bank_login.bank_branch} do
      {%Ecto.Association.NotLoaded{}, _} -> nil
      {nil, _} -> nil
      {_login, %Ecto.Association.NotLoaded{}} -> nil
      {_login, nil} -> nil
      {_login, branch} ->
        case branch.bank do
          %Ecto.Association.NotLoaded{} -> nil
          nil -> nil
          bank -> %{
            id: bank.id,
            name: bank.name
          }
        end
    end
  end

  defp build_account_links(account_id) do
    %{
      self: "/api/accounts/#{account_id}",
      transactions: "/api/accounts/#{account_id}/transactions",
      balances: "/api/accounts/#{account_id}/balances",
      payments: "/api/accounts/#{account_id}/payments"
    }
  end
end

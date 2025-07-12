# lib/ledger_bank_api/external/bank_client.ex
defmodule LedgerBankApi.External.BankClient do
  @moduledoc "Thin wrapper around outbound HTTP. Swap for mocks in tests."

  @callback accounts(String.t())      :: {:ok, list()} | {:error, any()}
  @callback balances(String.t())      :: {:ok, list()} | {:error, any()}
  @callback transactions(String.t())  :: {:ok, list()} | {:error, any()}

  @behaviour __MODULE__

  @base_url Application.compile_env(:ledger_bank_api, :bank_base_url, "https://example.com")
  @client   Application.compile_env(:ledger_bank_api, :bank_client, __MODULE__)

  # -- public --------------------------------------------------------------

  def accounts(id) do
    delegate_or_http(@client, :accounts, id, "/enrollments/#{id}/accounts")
  end

  def balances(id) do
    delegate_or_http(@client, :balances, id, "/enrollments/#{id}/balances")
  end

  def transactions(id) do
    delegate_or_http(@client, :transactions, id, "/enrollments/#{id}/transactions")
  end

  # -- private helpers -----------------------------------------------------

  defp delegate_or_http(mod, fun, id, path) do
    if mod == __MODULE__ do
      get(path)
    else
      apply(mod, fun, [id])
    end
  end

  defp get(path) do
    url = @base_url <> path

    case Finch.build(:get, url) |> Finch.request(LedgerBankApi.Finch) do
      {:ok, %{status: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status: status}}          -> {:error, status}
      {:error, err}                     -> {:error, err}
    end
  end
end

# lib/ledger_bank_api/banking/fetcher.ex
defmodule LedgerBankApi.Banking.Fetcher do
  @moduledoc "Fan-out to three upstream endpoints in parallel."
  alias LedgerBankApi.External.BankClient
  @timeout 15_000

  # public ------------------------------------------------------------------
  def fetch_all(enrollment_id) do
    Task.Supervisor.async_stream_nolink(
      LedgerBankApi.TaskSupervisor,
      task_fns(),                                   # enumerable
      fn task_fun -> task_fun.(enrollment_id) end,  # 1-arity wrapper
      max_concurrency: 3,
      timeout: @timeout
    )
    |> Enum.reduce(%{}, &merge/2)
  end

  # private -----------------------------------------------------------------
  defp task_fns,
    do: [&fetch_accounts/1, &fetch_balances/1, &fetch_transactions/1]

  defp fetch_accounts(id),     do: {:accounts,     BankClient.accounts(id)}
  defp fetch_balances(id),     do: {:balances,     BankClient.balances(id)}
  defp fetch_transactions(id), do: {:transactions, BankClient.transactions(id)}

  defp merge({:ok, {key, {:ok, v}}}, acc),     do: Map.put(acc, key, v)
  defp merge({:ok, {_k, {:error, e}}}, acc),   do: Map.update(acc, :errors, [e], &[e | &1])
  defp merge({:exit, reason}, acc),            do: Map.update(acc, :errors, [reason], &[reason | &1])
end

defmodule Mix.Tasks.BenchCi do
  use Mix.Task
  @shortdoc "Fails if list_accounts/0 slower than 300 µs"

  def run(_) do
    Mix.Task.run("app.start")
    {micros, _} =
      :timer.tc(fn -> LedgerBankApi.Banking.list_accounts() end)

    max = String.to_integer(System.get_env("MAX_LIST_ACCT_US") || "300")
    if micros > max, do: Mix.raise("Performance regression: #{micros} µs > #{max} µs")
  end
end

defmodule LedgerBankApi.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias LedgerBankApi.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import LedgerBankApi.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LedgerBankApi.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(LedgerBankApi.Repo, {:shared, self()})
    end

    :ok
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

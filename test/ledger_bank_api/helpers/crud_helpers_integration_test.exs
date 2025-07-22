defmodule LedgerBankApi.Helpers.CrudHelpersIntegrationTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Repo

  defmodule DummySchema do
    use Ecto.Schema
    import LedgerBankApi.CrudHelpers
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "dummy_schemas" do
      field :status, :string
      field :role, :string
    end
    default_changeset(:base_changeset, [:status, :role], [:status, :role])
  end

  defmodule DummyContext do
    use LedgerBankApi.CrudHelpers, schema: LedgerBankApi.Helpers.CrudHelpersIntegrationTest.DummySchema
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "list_by/2 returns only matching records" do
    Repo.insert!(%DummySchema{status: "ACTIVE", role: "admin"})
    Repo.insert!(%DummySchema{status: "INACTIVE", role: "user"})
    result = DummyContext.list_by(:status, "ACTIVE")
    assert length(result) == 1
    assert Enum.all?(result, &(&1.status == "ACTIVE"))
  end

  test "list_by_fields/1 returns only matching records for multiple fields" do
    Repo.insert!(%DummySchema{status: "ACTIVE", role: "admin"})
    Repo.insert!(%DummySchema{status: "ACTIVE", role: "user"})
    result = DummyContext.list_by_fields(%{status: "ACTIVE", role: "admin"})
    assert length(result) == 1
    assert Enum.all?(result, &(&1.status == "ACTIVE" and &1.role == "admin"))
  end
end

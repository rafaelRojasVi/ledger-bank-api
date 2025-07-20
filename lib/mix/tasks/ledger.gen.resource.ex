defmodule Mix.Tasks.Ledger.Gen.Resource do
  @moduledoc """
  Mix task to generate a new resource (schema, context, test) following DRY, secure, and idiomatic patterns.

  Usage:
    mix ledger.gen.resource UserProfile field1:type field2:type ...

  Example:
    mix ledger.gen.resource UserProfile name:string age:integer
  """
  use Mix.Task
  import Mix.Generator

  @shortdoc "Generates a resource schema, context, and test."

  def run([resource | fields]) do
    app = Mix.Project.config()[:app] |> to_string()
    underscored = Macro.underscore(resource)
    plural = Inflex.pluralize(underscored)
    module = "#{Macro.camelize(app)}.#{resource}"
    context_mod = "#{Macro.camelize(app)}.#{plural |> Macro.camelize()}"
    schema_path = "lib/#{app}/#{plural}/#{underscored}.ex"
    context_path = "lib/#{app}/#{plural}/context.ex"
    test_path = "test/#{app}/#{plural}_test.exs"

    field_defs = Enum.map(fields, &parse_field/1)
    field_lines = Enum.map(field_defs, fn {name, type} -> "    field :#{name}, :#{type}" end) |> Enum.join("\n")
    required_fields = Enum.map(field_defs, fn {name, _} -> ":#{name}" end) |> Enum.join(", ")
    all_fields = required_fields

    # Schema file
    create_file schema_path, '''
defmodule #{module} do
  @moduledoc """
  Schema for #{resource}.
  """
  use Ecto.Schema
  import LedgerBankApi.CrudHelpers, only: [default_changeset: 3]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "#{plural}" do
#{field_lines}
    timestamps(type: :utc_datetime)
  end

  @fields [#{all_fields}]
  @required_fields [#{required_fields}]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(struct, attrs), do: base_changeset(struct, attrs)
end
'''

    # Context file
    create_file context_path, '''
defmodule #{context_mod} do
  @moduledoc """
  Context for #{resource}.
  """
  alias #{module}
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: #{module}
end
'''

    # Test file
    create_file test_path, '''
defmodule #{context_mod}Test do
  use ExUnit.Case, async: true
  alias #{context_mod}
  alias #{module}

  test "basic CRUD" do
    attrs = %{}
    assert {:ok, _} = Context.create(attrs)
  end
end
'''

    Mix.shell().info([:green, "Generated resource #{resource}!"])
  end

  defp parse_field(field) do
    [name, type] = String.split(field, ":")
    {name, String.to_atom(type)}
  end
end

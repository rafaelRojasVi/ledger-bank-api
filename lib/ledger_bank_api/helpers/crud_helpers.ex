defmodule LedgerBankApi.CrudHelpers do
  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    quote do
      alias LedgerBankApi.Repo
      def list, do: Repo.all(unquote(schema))
      def get!(id), do: Repo.get!(unquote(schema), id)
      def create(attrs \\ %{}), do: %unquote(schema){} |> unquote(schema).changeset(attrs) |> Repo.insert()
      def update(struct, attrs), do: struct |> unquote(schema).changeset(attrs) |> Repo.update()
      def delete(struct), do: Repo.delete(struct)
    end
  end

  @doc """
  Macro to define a list_by_field function for a given field.
  Usage: list_by(:status, "ACTIVE")
  """
  defmacro list_by(field, value) do
    quote do
      import Ecto.Query
      Repo.all(from s in __MODULE__, where: field(s, ^unquote(field)) == ^unquote(value))
    end
  end

  @doc """
  Macro to define a list_by_fields function for multiple fields.
  Usage: list_by_fields(%{status: "ACTIVE", role: "admin"})
  """
  defmacro list_by_fields(fields) do
    quote do
      import Ecto.Query
      query = Enum.reduce(unquote(fields), __MODULE__, fn {field, value}, acc ->
        from s in acc, where: field(s, ^field) == ^value
      end)
      Repo.all(query)
    end
  end

  @doc """
  Macro to add unique_constraint(s) to a changeset for one or more fields.
  Usage:
    |> unique_constraints(:field)
    |> unique_constraints([:field1, :field2])
  """
  defmacro unique_constraints(changeset, fields) do
    quote do
      case unquote(fields) do
        list when is_list(list) ->
          Enum.reduce(list, unquote(changeset), fn field, acc ->
            Ecto.Changeset.unique_constraint(acc, field)
          end)
        field ->
          Ecto.Changeset.unique_constraint(unquote(changeset), field)
      end
    end
  end

  @doc """
  Macro to add validate_required for a list of fields.
  Usage:
    |> require_fields([:field1, :field2])
  """
  defmacro require_fields(changeset, fields) do
    quote do
      Ecto.Changeset.validate_required(unquote(changeset), unquote(fields))
    end
  end

  @doc """
  Macro to add foreign_key_constraint(s) to a changeset for one or more fields.
  Usage:
    |> foreign_key_constraints([:field1, :field2])
  """
  defmacro foreign_key_constraints(changeset, fields) do
    quote do
      Enum.reduce(unquote(fields), unquote(changeset), fn field, acc ->
        Ecto.Changeset.foreign_key_constraint(acc, field)
      end)
    end
  end

  @doc """
  Macro to add validate_inclusion for multiple fields.
  Usage:
    |> validate_inclusions([status: ["ACTIVE", "SUSPENDED"], role: ["user", "admin"]])
  """
  defmacro validate_inclusions(changeset, field_values) do
    quote do
      Enum.reduce(unquote(field_values), unquote(changeset), fn {field, values}, acc ->
        Ecto.Changeset.validate_inclusion(acc, field, values)
      end)
    end
  end

  @doc """
  Macro to add validate_format for multiple fields.
  Usage:
    |> validate_formats([email: ~r/@/, code: ~r/^[a-z0-9_]+$/])
  """
  defmacro validate_formats(changeset, field_patterns) do
    quote do
      Enum.reduce(unquote(field_patterns), unquote(changeset), fn {field, pattern}, acc ->
        Ecto.Changeset.validate_format(acc, field, pattern)
      end)
    end
  end

  @doc """
  Macro to add validate_length for multiple fields.
  Usage:
    |> validate_lengths([password: [min: 8], code: [max: 20]])
  """
  defmacro validate_lengths(changeset, field_opts) do
    quote do
      Enum.reduce(unquote(field_opts), unquote(changeset), fn {field, opts}, acc ->
        Ecto.Changeset.validate_length(acc, field, opts)
      end)
    end
  end

  defmacro default_changeset(fun_name, fields, required_fields) do
    quote do
      def unquote(fun_name)(struct, attrs) do
        struct
        |> Ecto.Changeset.cast(attrs, unquote(fields))
        |> Ecto.Changeset.validate_required(unquote(required_fields))
      end
    end
  end
end

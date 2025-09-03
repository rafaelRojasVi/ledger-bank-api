defmodule LedgerBankApi.CrudHelpers do
  @moduledoc """
  Enhanced CRUD helpers with standardized return patterns and comprehensive error handling.
  All functions return {:ok, data} or {:error, reason} for consistency.
  """

  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    quote do
      alias LedgerBankApi.Repo
      alias LedgerBankApi.Banking.Behaviours.ErrorHandler

      @doc """
      Lists all records with standardized return pattern.
      Returns {:ok, list} or {:error, reason}.
      """
      def list do
        context = %{action: :list, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          Repo.all(unquote(schema))
        end, context)
      end

      @doc """
      Gets a record by ID with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def get!(id) do
        context = %{action: :get, id: id, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          Repo.get!(unquote(schema), id)
        end, context)
      end

      @doc """
      Creates a record with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def create(attrs \\ %{}) do
        context = %{action: :create, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          %unquote(schema){} |> unquote(schema).changeset(attrs) |> Repo.insert()
        end, context)
      end

      @doc """
      Updates a record with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def update(struct, attrs) do
        context = %{action: :update, schema: unquote(schema), id: struct.id}
        ErrorHandler.with_error_handling(fn ->
          struct |> unquote(schema).changeset(attrs) |> Repo.update()
        end, context)
      end

      @doc """
      Deletes a record with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def delete(struct) do
        context = %{action: :delete, schema: unquote(schema), id: struct.id}
        ErrorHandler.with_error_handling(fn ->
          Repo.delete(struct)
        end, context)
      end

      @doc """
      Lists records by field with standardized return pattern.
      Returns {:ok, list} or {:error, reason}.
      """
      def list_by(field, value) do
        context = %{action: :list_by, field: field, value: value, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          import Ecto.Query
          Repo.all(from s in unquote(schema), where: field(s, ^field) == ^value)
        end, context)
      end

      @doc """
      Lists records by multiple fields with standardized return pattern.
      Returns {:ok, list} or {:error, reason}.
      """
      def list_by_fields(fields) do
        context = %{action: :list_by_fields, fields: fields, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          import Ecto.Query
          query = Enum.reduce(fields, unquote(schema), fn {field, value}, acc ->
            from s in acc, where: field(s, ^field) == ^value
          end)
          Repo.all(query)
        end, context)
      end

      @doc """
      Gets a record by field with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def get_by(field, value) do
        context = %{action: :get_by, field: field, value: value, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          case Repo.get_by(unquote(schema), [{field, value}]) do
            nil -> {:error, :not_found}
            record -> {:ok, record}
          end
        end, context)
      end

      @doc """
      Gets a record by multiple fields with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def get_by_fields(fields) do
        context = %{action: :get_by_fields, fields: fields, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          case Repo.get_by(unquote(schema), fields) do
            nil -> {:error, :not_found}
            record -> {:ok, record}
          end
        end, context)
      end

      @doc """
      Counts records with optional where clause.
      Returns {:ok, count} or {:error, reason}.
      """
      def count(where_clause \\ []) do
        context = %{action: :count, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          import Ecto.Query
          query = from s in unquote(schema)
          query = if Enum.empty?(where_clause) do
            query
          else
            Enum.reduce(where_clause, query, fn {field, value}, acc ->
              from s in acc, where: field(s, ^field) == ^value
            end)
          end
          Repo.aggregate(query, :count)
        end, context)
      end

      @doc """
      Checks if a record exists with standardized return pattern.
      Returns {:ok, boolean} or {:error, reason}.
      """
      def exists?(where_clause) do
        context = %{action: :exists, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          import Ecto.Query
          query = from s in unquote(schema), select: 1, limit: 1
          query = Enum.reduce(where_clause, query, fn {field, value}, acc ->
            from s in acc, where: field(s, ^field) == ^value
          end)
          case Repo.one(query) do
            nil -> false
            _ -> true
          end
        end, context)
      end

      @doc """
      Updates a record by field with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def update_by(field, value, attrs) do
        context = %{action: :update_by, field: field, value: value, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          case Repo.get_by(unquote(schema), [{field, value}]) do
            nil -> {:error, :not_found}
            record ->
              record
              |> unquote(schema).changeset(attrs)
              |> Repo.update()
          end
        end, context)
      end

      @doc """
      Deletes a record by field with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def delete_by(field, value) do
        context = %{action: :delete_by, field: field, value: value, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          case Repo.get_by(unquote(schema), [{field, value}]) do
            nil -> {:error, :not_found}
            record -> Repo.delete(record)
          end
        end, context)
      end

      @doc """
      Gets a record with preloads with standardized return pattern.
      Returns {:ok, record} or {:error, reason}.
      """
      def get_with_preloads!(id, preloads) do
        context = %{action: :get_with_preloads, id: id, preloads: preloads, schema: unquote(schema)}
        ErrorHandler.with_error_handling(fn ->
          unquote(schema)
          |> Repo.get!(id)
          |> Repo.preload(preloads)
        end, context)
      end
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

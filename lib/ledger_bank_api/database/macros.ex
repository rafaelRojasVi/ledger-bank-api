defmodule LedgerBankApi.Database.Macros do
  @moduledoc """
  Macros for generating common database operations to reduce code repetition.
  """

  import Ecto.Query, warn: false

  @doc """
  Macro to generate filter, sort, and pagination functions for a schema.

  Usage:
    use_query_operations(Bank, :b)
    use_query_operations(UserBankAccount, :uba)
  """
  defmacro use_query_operations(schema, field_alias) do
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last() |> Macro.underscore()

    quote do
      @doc """
      Apply filters to query for #{unquote(schema_name)}.
      """
      def unquote(:"apply_#{schema_name}_filters")(query, nil), do: query
      def unquote(:"apply_#{schema_name}_filters")(query, []), do: query
      def unquote(:"apply_#{schema_name}_filters")(query, filters) when is_map(filters) do
        Enum.reduce(filters, query, fn {field, value}, acc ->
          case field do
            :status when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :status) == ^value)
            :user_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :user_id) == ^value)
            :bank_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :bank_id) == ^value)
            :account_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :account_id) == ^value)
            :user_bank_account_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :user_bank_account_id) == ^value)
            :bank_branch_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :bank_branch_id) == ^value)
            :user_bank_login_id when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :user_bank_login_id) == ^value)
            :active when is_boolean(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :active) == ^value)
            :verified when is_boolean(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :verified) == ^value)
            :country when is_binary(value) ->
              where(acc, [unquote(field_alias)], field(unquote(field_alias), :country) == ^value)
            _ ->
              acc
          end
        end)
      end

      @doc """
      Apply sorting to query for #{unquote(schema_name)}.
      """
      def unquote(:"apply_#{schema_name}_sorting")(query, nil), do: query
      def unquote(:"apply_#{schema_name}_sorting")(query, []), do: query
      def unquote(:"apply_#{schema_name}_sorting")(query, sort) when is_list(sort) do
        Enum.reduce(sort, query, fn {field, direction}, acc ->
          case direction do
            :asc -> order_by(acc, [unquote(field_alias)], asc: field(unquote(field_alias), ^field))
            :desc -> order_by(acc, [unquote(field_alias)], desc: field(unquote(field_alias), ^field))
            _ -> acc
          end
        end)
      end

      @doc """
      Apply pagination to query for #{unquote(schema_name)}.
      """
      def unquote(:"apply_#{schema_name}_pagination")(query, nil), do: query
      def unquote(:"apply_#{schema_name}_pagination")(query, %{page: page, page_size: page_size}) do
        offset = (page - 1) * page_size
        query
        |> limit(^page_size)
        |> offset(^offset)
      end
    end
  end

  @doc """
  Macro to generate error handling wrapper with context creation.

  Usage:
    with_error_handling(:get_user, %{user_id: user_id}, fn ->
      # actual logic here
    end)
  """
  defmacro with_error_handling(action, context_data, do: block) do
    quote do
      context = Map.merge(%{action: unquote(action)}, unquote(context_data))
      LedgerBankApi.Banking.Behaviours.ErrorHandler.with_error_handling(fn ->
        unquote(block)
      end, context)
    end
  end

  @doc """
  Macro to generate CRUD operations with error handling for a schema.

  Usage:
    use_crud_with_error_handling(Bank)
    use_crud_with_error_handling(UserBankAccount)
  """
  defmacro use_crud_with_error_handling(schema) do
    schema_name = schema |> Macro.expand(__CALLER__) |> Module.split() |> List.last() |> String.downcase()

    quote do
      @doc """
      Get a #{unquote(schema_name)} by ID with error handling.
      """
      def unquote(:"get_#{schema_name}")(id) do
        with_error_handling(:"get_#{unquote(schema_name)}", %{id: id}, do:
          case LedgerBankApi.Repo.get(unquote(schema), id) do
            nil -> {:error, :not_found}
            record -> {:ok, record}
          end
        )
      end

      @doc """
      Create a #{unquote(schema_name)} with error handling.
      """
      def unquote(:"create_#{schema_name}")(attrs) do
        with_error_handling(:"create_#{unquote(schema_name)}", %{attrs: attrs}, do:
          %unquote(schema){}
          |> unquote(schema).changeset(attrs)
          |> LedgerBankApi.Repo.insert()
        )
      end

      @doc """
      Update a #{unquote(schema_name)} with error handling.
      """
      def unquote(:"update_#{schema_name}")(record, attrs) do
        with_error_handling(:"update_#{unquote(schema_name)}", %{id: record.id, attrs: attrs}, do:
          record
          |> unquote(schema).changeset(attrs)
          |> LedgerBankApi.Repo.update()
        )
      end

      @doc """
      Delete a #{unquote(schema_name)} with error handling.
      """
      def unquote(:"delete_#{schema_name}")(record) do
        with_error_handling(:"delete_#{unquote(schema_name)}", %{id: record.id}, do:
          LedgerBankApi.Repo.delete(record)
        )
      end

      @doc """
      List #{unquote(schema_name)}s with options and error handling.
      """
      def unquote(:"list_#{schema_name}s")(opts \\ []) do
        with_error_handling(:"list_#{unquote(schema_name)}s", %{opts: opts}, do:
          unquote(schema)
          |> unquote(:"apply_#{schema_name}_filters")(opts[:filters])
          |> unquote(:"apply_#{schema_name}_sorting")(opts[:sort])
          |> unquote(:"apply_#{schema_name}_pagination")(opts[:pagination])
          |> LedgerBankApi.Repo.all()
        )
      end
    end
  end
end

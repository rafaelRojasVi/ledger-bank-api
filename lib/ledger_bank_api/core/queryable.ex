defmodule LedgerBankApi.Core.Queryable do
  @moduledoc """
  Behaviour for standardized query building with filters, sorting, and pagination.

  Promotes consistent API design and reduces boilerplate across services.

  ## Philosophy

  - **Explicit field whitelisting** - No magic, all fields declared
  - **Composable** - Works with standard Ecto.Query functions
  - **Override-friendly** - Custom filter logic when needed
  - **Type-aware** - Different filter types (string, boolean, etc.)

  ## Usage

      defmodule LedgerBankApi.Accounts.UserQueries do
        use LedgerBankApi.Core.Queryable

        @impl true
        def filterable_fields do
          %{
            status: :string,
            role: :string,
            active: :boolean,
            verified: :boolean
          }
        end

        @impl true
        def sortable_fields do
          [:email, :full_name, :inserted_at, :updated_at]
        end
      end

      # In UserService
      def list_users(opts) do
        User
        |> UserQueries.apply_filters(opts[:filters])
        |> UserQueries.apply_sorting(opts[:sort])
        |> UserQueries.apply_pagination(opts[:pagination])
        |> Repo.all()
      end

  ## Evaluation

  **Implemented because:**
  - ✅ 4+ resources with similar filtering (User, Bank, Payment, Transaction)
  - ✅ Consistent patterns across services
  - ✅ Eliminates ~240 lines of duplicated query logic
  - ✅ Makes adding new resources easier

  **Kept simple:**
  - ❌ No DSL magic
  - ❌ No runtime field discovery
  - ❌ Explicit field whitelisting required
  """

  import Ecto.Query

  @doc """
  Define filterable fields and their types.

  Returns a map of field_name => type where type is:
  - `:string` - Exact match on string field
  - `:boolean` - Exact match on boolean field
  - `:integer` - Exact match on integer field
  - `:date_range` - Range query on datetime field
  """
  @callback filterable_fields() :: %{atom() => atom()}

  @doc """
  Define sortable fields.

  Returns a list of field names that can be used in ORDER BY.
  """
  @callback sortable_fields() :: list(atom())

  defmacro __using__(_opts) do
    quote do
      @behaviour LedgerBankApi.Core.Queryable
      import Ecto.Query

      @doc """
      Apply filters to a query based on filterable_fields definition.

      Filters are applied as exact matches based on field type.
      Returns the query unchanged if filters is nil or empty.
      """
      def apply_filters(query, nil), do: query
      def apply_filters(query, filters) when filters == %{}, do: query
      def apply_filters(query, filters) when is_map(filters) do
        field_types = filterable_fields()

        Enum.reduce(filters, query, fn {field, value}, acc ->
          field_type = Map.get(field_types, field)

          if field_type do
            apply_field_filter(acc, field, value, field_type)
          else
            # Field not in whitelist, skip
            acc
          end
        end)
      end

      @doc """
      Apply sorting to a query based on sortable_fields definition.

      Returns the query unchanged if sort is nil or empty.
      """
      def apply_sorting(query, nil), do: query
      def apply_sorting(query, []), do: query
      def apply_sorting(query, sort) when is_list(sort) do
        sortable = sortable_fields()

        Enum.reduce(sort, query, fn {field, direction}, acc ->
          if field in sortable and direction in [:asc, :desc] do
            order_by(acc, [r], [{^direction, field(r, ^field)}])
          else
            # Field not sortable or invalid direction, skip
            acc
          end
        end)
      end
      def apply_sorting(query, %{field: field, direction: direction}) do
        apply_sorting(query, [{field, direction}])
      end

      @doc """
      Apply pagination to a query.

      Returns the query unchanged if pagination is nil.
      """
      def apply_pagination(query, nil), do: query
      def apply_pagination(query, %{page: page, page_size: page_size})
          when is_integer(page) and is_integer(page_size) and page >= 1 and page_size >= 1 do
        offset = (page - 1) * page_size
        query
        |> limit(^page_size)
        |> offset(^offset)
      end

      # ========================================================================
      # PRIVATE HELPER (Override for custom filter logic)
      # ========================================================================

      @doc false
      defp apply_field_filter(query, field, value, :string) when is_binary(value) do
        where(query, [r], field(r, ^field) == ^value)
      end

      defp apply_field_filter(query, field, value, :boolean) when is_boolean(value) do
        where(query, [r], field(r, ^field) == ^value)
      end

      defp apply_field_filter(query, field, value, :integer) when is_integer(value) do
        where(query, [r], field(r, ^field) == ^value)
      end

      defp apply_field_filter(query, field, value, :date_range) when is_binary(value) do
        # Expects format: "2024-01-01T00:00:00Z"
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} ->
            where(query, [r], field(r, ^field) >= ^datetime)
          _ ->
            query
        end
      end

      defp apply_field_filter(query, _field, _value, _type) do
        # Unknown type or invalid value, skip
        query
      end

      # Allow overriding filter logic in implementing modules
      defoverridable [apply_field_filter: 4]
    end
  end
end

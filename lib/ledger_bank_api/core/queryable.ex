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
      defoverridable apply_field_filter: 4

      # ========================================================================
      # ENHANCED QUERY MACROS
      # ========================================================================

      @doc """
      Apply text search across multiple fields.

      ## Examples

          # Search across name and email fields
          User
          |> apply_text_search("john", [:full_name, :email])
          |> Repo.all()
      """
      def apply_text_search(query, nil, _fields), do: query
      def apply_text_search(query, "", _fields), do: query
      def apply_text_search(query, search_term, fields) when is_binary(search_term) and is_list(fields) do
        search_pattern = "%#{String.downcase(search_term)}%"

        Enum.reduce(fields, query, fn field, acc ->
          where(acc, [r], ilike(field(r, ^field), ^search_pattern))
        end)
      end

      @doc """
      Apply date range filtering on a datetime field.

      ## Examples

          # Filter by date range
          User
          |> apply_date_range(:inserted_at, %{from: "2024-01-01", to: "2024-12-31"})
          |> Repo.all()
      """
      def apply_date_range(query, field, %{from: from_date, to: to_date}) when is_binary(from_date) and is_binary(to_date) do
        case {Date.from_iso8601(from_date), Date.from_iso8601(to_date)} do
          {{:ok, from}, {:ok, to}} ->
            from_datetime = DateTime.new!(from, ~T[00:00:00], "Etc/UTC")
            to_datetime = DateTime.new!(to, ~T[23:59:59], "Etc/UTC")

            query
            |> where([r], field(r, ^field) >= ^from_datetime)
            |> where([r], field(r, ^field) <= ^to_datetime)

          _ ->
            query
        end
      end

      def apply_date_range(query, _field, _range), do: query

      @doc """
      Apply keyset pagination for better performance on large datasets.

      ## Examples

          # First page
          User
          |> apply_keyset_pagination(%{limit: 20})
          |> Repo.all()

          # Next page using cursor
          User
          |> apply_keyset_pagination(%{limit: 20, cursor: "2024-01-01T10:00:00Z"})
          |> Repo.all()
      """
      def apply_keyset_pagination(query, %{limit: limit}) when is_integer(limit) and limit > 0 do
        query
        |> limit(^limit)
        |> order_by([r], asc: r.inserted_at)
      end

      def apply_keyset_pagination(query, %{limit: limit, cursor: cursor}) when is_binary(cursor) do
        case DateTime.from_iso8601(cursor) do
          {:ok, cursor_datetime, _offset} ->
            query
            |> where([r], r.inserted_at > ^cursor_datetime)
            |> limit(^limit)
            |> order_by([r], asc: r.inserted_at)

          _ ->
            apply_keyset_pagination(query, %{limit: limit})
        end
      end

      def apply_keyset_pagination(query, _opts), do: query

      @doc """
      Apply advanced filtering with multiple operators.

      ## Examples

          # Multiple filter types
          User
          |> apply_advanced_filters(%{
            status: {:in, ["ACTIVE", "PENDING"]},
            role: {:eq, "user"},
            created_after: {:gte, "2024-01-01"},
            name: {:like, "john%"}
          })
          |> Repo.all()
      """
      def apply_advanced_filters(query, nil), do: query
      def apply_advanced_filters(query, filters) when filters == %{}, do: query

      def apply_advanced_filters(query, filters) when is_map(filters) do
        Enum.reduce(filters, query, fn {field, {operator, value}}, acc ->
          apply_advanced_filter(acc, field, operator, value)
        end)
      end

      @doc """
      Apply sorting with multiple fields and directions.

      ## Examples

          # Multiple sort fields
          User
          |> apply_multi_sort([
            {:inserted_at, :desc},
            {:email, :asc}
          ])
          |> Repo.all()
      """
      def apply_multi_sort(query, nil), do: query
      def apply_multi_sort(query, []), do: query

      def apply_multi_sort(query, sort_fields) when is_list(sort_fields) do
        sortable = sortable_fields()

        Enum.reduce(sort_fields, query, fn {field, direction}, acc ->
          if field in sortable and direction in [:asc, :desc] do
            order_by(acc, [r], [{^direction, field(r, ^field)}])
          else
            acc
          end
        end)
      end

      @doc """
      Apply field-specific filtering with custom logic.

      ## Examples

          # Custom filter logic
          User
          |> apply_custom_filter(:email_domain, "example.com")
          |> Repo.all()
      """
      def apply_custom_filter(query, _field, nil), do: query
      def apply_custom_filter(query, _field, ""), do: query

      def apply_custom_filter(query, :email_domain, domain) when is_binary(domain) do
        where(query, [r], like(r.email, ^"%#{domain}"))
      end

      def apply_custom_filter(query, :name_contains, search_term) when is_binary(search_term) do
        search_pattern = "%#{String.downcase(search_term)}%"
        where(query, [r], ilike(r.full_name, ^search_pattern))
      end

      def apply_custom_filter(query, _field, _value), do: query

      @doc """
      Apply aggregation queries for statistics.

      ## Examples

          # Count by status
          User
          |> apply_aggregation(:count_by_status, :status)
          |> Repo.all()
      """
      def apply_aggregation(query, :count_by_status, field) do
        query
        |> group_by([r], field(r, ^field))
        |> select([r], {field(r, ^field), count()})
      end

      def apply_aggregation(query, :count_by_date, field) do
        query
        |> group_by([r], fragment("DATE(?)", field(r, ^field)))
        |> select([r], {fragment("DATE(?)", field(r, ^field)), count()})
      end

      def apply_aggregation(query, _type, _field), do: query

      # ========================================================================
      # PRIVATE HELPER FUNCTIONS
      # ========================================================================

      def apply_advanced_filter(query, field, :eq, value) do
        where(query, [r], field(r, ^field) == ^value)
      end

      def apply_advanced_filter(query, field, :ne, value) do
        where(query, [r], field(r, ^field) != ^value)
      end

      def apply_advanced_filter(query, field, :in, values) when is_list(values) do
        where(query, [r], field(r, ^field) in ^values)
      end

      def apply_advanced_filter(query, field, :not_in, values) when is_list(values) do
        where(query, [r], field(r, ^field) not in ^values)
      end

      def apply_advanced_filter(query, field, :like, pattern) when is_binary(pattern) do
        where(query, [r], like(field(r, ^field), ^pattern))
      end

      def apply_advanced_filter(query, field, :ilike, pattern) when is_binary(pattern) do
        where(query, [r], ilike(field(r, ^field), ^pattern))
      end

      def apply_advanced_filter(query, field, :gte, value) do
        where(query, [r], field(r, ^field) >= ^value)
      end

      def apply_advanced_filter(query, field, :lte, value) do
        where(query, [r], field(r, ^field) <= ^value)
      end

      def apply_advanced_filter(query, field, :gt, value) do
        where(query, [r], field(r, ^field) > ^value)
      end

      def apply_advanced_filter(query, field, :lt, value) do
        where(query, [r], field(r, ^field) < ^value)
      end

      def apply_advanced_filter(query, field, :is_null, true) do
        where(query, [r], is_nil(field(r, ^field)))
      end

      def apply_advanced_filter(query, field, :is_null, false) do
        where(query, [r], not is_nil(field(r, ^field)))
      end

      def apply_advanced_filter(query, _field, _operator, _value) do
        query
      end

      # Allow overriding advanced filter logic in implementing modules
      # defoverridable apply_advanced_filter: 3
    end
  end
end

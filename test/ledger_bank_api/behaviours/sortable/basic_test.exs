defmodule LedgerBankApi.Behaviours.SortableTest do
  use ExUnit.Case, async: true
  import Mimic
  import Ecto.Query
  require Ecto.Query

  alias LedgerBankApi.Behaviours.Sortable

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "extract_sort_params/1" do
    test "extracts sort params with defaults" do
      params = %{}
      result = Sortable.extract_sort_params(params)

      assert result.sort_by == "posted_at"
      assert result.sort_order == "desc"
    end

    test "extracts sort params with custom values" do
      params = %{"sort_by" => "amount", "sort_order" => "asc"}
      result = Sortable.extract_sort_params(params)

      assert result.sort_by == "amount"
      assert result.sort_order == "asc"
    end
  end

  describe "validate_sort_params/2" do
    test "validates correct sort params" do
      params = %{sort_by: "posted_at", sort_order: "desc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.validate_sort_params(params, allowed_fields)

      assert result == {:ok, %{sort_by: "posted_at", sort_order: "desc"}}
    end

    test "rejects invalid sort field" do
      params = %{sort_by: "invalid_field", sort_order: "desc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.validate_sort_params(params, allowed_fields)

      assert result == {:error, "Invalid sort field. Allowed: posted_at, amount, description"}
    end

    test "rejects invalid sort order" do
      params = %{sort_by: "posted_at", sort_order: "invalid"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.validate_sort_params(params, allowed_fields)

      assert result == {:error, "Sort order must be 'asc' or 'desc'"}
    end

    test "accepts asc sort order" do
      params = %{sort_by: "amount", sort_order: "asc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.validate_sort_params(params, allowed_fields)

      assert result == {:ok, %{sort_by: "amount", sort_order: "asc"}}
    end

    test "accepts desc sort order" do
      params = %{sort_by: "description", sort_order: "desc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.validate_sort_params(params, allowed_fields)

      assert result == {:ok, %{sort_by: "description", sort_order: "desc"}}
    end
  end

  describe "apply_sorting/2" do
    test "applies sorting to posted_at field" do
      query = from(t in "transactions")
      sort_params = %{sort_by: "posted_at", sort_order: "desc"}

      result = Sortable.apply_sorting(query, sort_params)

      # Verify the query has the correct order_by clause
      assert length(result.order_bys) == 1
      order_by = List.first(result.order_bys)
      assert order_by.expr == [desc: {{:., [], [{:&, [], [0]}, :posted_at]}, [], []}]
    end

    test "applies sorting to amount field" do
      query = from(t in "transactions")
      sort_params = %{sort_by: "amount", sort_order: "asc"}

      result = Sortable.apply_sorting(query, sort_params)

      # Verify the query has the correct order_by clause
      assert length(result.order_bys) == 1
      order_by = List.first(result.order_bys)
      assert order_by.expr == [asc: {{:., [], [{:&, [], [0]}, :amount]}, [], []}]
    end

    test "applies sorting to description field" do
      query = from(t in "transactions")
      sort_params = %{sort_by: "description", sort_order: "desc"}

      result = Sortable.apply_sorting(query, sort_params)

      # Verify the query has the correct order_by clause
      assert length(result.order_bys) == 1
      order_by = List.first(result.order_bys)
      assert order_by.expr == [desc: {{:., [], [{:&, [], [0]}, :description]}, [], []}]
    end

    test "applies sorting to created_at field" do
      query = from(t in "transactions")
      sort_params = %{sort_by: "created_at", sort_order: "asc"}

      result = Sortable.apply_sorting(query, sort_params)

      # Verify the query has the correct order_by clause
      assert length(result.order_bys) == 1
      order_by = List.first(result.order_bys)
      assert order_by.expr == [asc: {{:., [], [{:&, [], [0]}, :inserted_at]}, [], []}]
    end

    test "returns original query for unknown field" do
      query = from(t in "transactions")
      sort_params = %{sort_by: "unknown_field", sort_order: "desc"}

      result = Sortable.apply_sorting(query, sort_params)

      # Should return the original query unchanged
      assert result == query
    end
  end

  describe "create_sort_struct/2" do
    test "creates valid sort struct" do
      params = %{"sort_by" => "amount", "sort_order" => "asc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.create_sort_struct(params, allowed_fields)

      assert {:ok, struct} = result
      assert struct.sort_by == "amount"
      assert struct.sort_order == "asc"
    end

    test "returns error for invalid sort field" do
      params = %{"sort_by" => "invalid_field", "sort_order" => "desc"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.create_sort_struct(params, allowed_fields)

      assert result == {:error, "Invalid sort field. Allowed: posted_at, amount, description"}
    end

    test "returns error for invalid sort order" do
      params = %{"sort_by" => "amount", "sort_order" => "invalid"}
      allowed_fields = ["posted_at", "amount", "description"]
      result = Sortable.create_sort_struct(params, allowed_fields)

      assert result == {:error, "Sort order must be 'asc' or 'desc'"}
    end
  end

  describe "behaviour contract" do
    test "module implementing behaviour must have required callbacks" do
      assert function_exported?(Sortable, :extract_sort_params, 1)
      assert function_exported?(Sortable, :validate_sort_params, 2)
    end
  end
end

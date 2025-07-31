defmodule LedgerBankApi.Banking.Behaviours.SortableTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Behaviours.Sortable

  test "extract_sort_params returns default values when no params provided" do
    result = Sortable.extract_sort_params(%{})
    assert result.sort_by == "posted_at"
    assert result.sort_order == "desc"
  end

  test "extract_sort_params returns custom values when provided" do
    result = Sortable.extract_sort_params(%{"sort_by" => "amount", "sort_order" => "asc"})
    assert result.sort_by == "amount"
    assert result.sort_order == "asc"
  end

  test "extract_sort_params extracts sort_order as provided" do
    result = Sortable.extract_sort_params(%{"sort_order" => "ASC"})
    assert result.sort_order == "ASC"
  end

  test "validate_sort_params returns error for invalid sort_order" do
    assert {:error, "Sort order must be 'asc' or 'desc'"} = Sortable.validate_sort_params(%{sort_by: "amount", sort_order: "invalid"}, ["amount"])
  end

  test "validate_sort_params returns error for invalid sort_by" do
    assert {:error, "Invalid sort field. Allowed: amount, created_at"} = Sortable.validate_sort_params(%{sort_by: "invalid_field", sort_order: "asc"}, ["amount", "created_at"])
  end

  test "validate_sort_params returns ok for valid params" do
    assert {:ok, %{sort_by: "amount", sort_order: "desc"}} = Sortable.validate_sort_params(%{sort_by: "amount", sort_order: "desc"}, ["amount"])
  end

  test "apply_sorting function exists" do
    # Test that the function exists
    assert Code.ensure_loaded?(Sortable)
    assert function_exported?(Sortable, :apply_sorting, 2)
  end
end

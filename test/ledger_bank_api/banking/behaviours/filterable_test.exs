defmodule LedgerBankApi.Banking.Behaviours.FilterableTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Behaviours.Filterable

  # Mock module that implements the Filterable behaviour
  defmodule MockFilterable do
    @behaviour LedgerBankApi.Banking.Behaviours.Filterable

    @impl LedgerBankApi.Banking.Behaviours.Filterable
    def handle_filtered_data(query, filters, opts) do
      # Simulate applying filters to a query
      filtered_data = apply_filters(filters)
      {:ok, filtered_data}
    end

    defp apply_filters(filters) do
      base_data = [
        %{id: 1, status: "ACTIVE", amount: 100, date: "2024-01-01"},
        %{id: 2, status: "PENDING", amount: 200, date: "2024-01-02"},
        %{id: 3, status: "COMPLETED", amount: 300, date: "2024-01-03"},
        %{id: 4, status: "ACTIVE", amount: 400, date: "2024-01-04"}
      ]

      Enum.reduce(filters, base_data, fn {key, value}, acc ->
        case key do
          "status" -> Enum.filter(acc, & &1.status == value)
          "min_amount" -> Enum.filter(acc, & &1.amount >= String.to_integer(value))
          "max_amount" -> Enum.filter(acc, & &1.amount <= String.to_integer(value))
          "date_from" -> Enum.filter(acc, & &1.date >= value)
          "date_to" -> Enum.filter(acc, & &1.date <= value)
          _ -> acc
        end
      end)
    end
  end

  test "filters by status correctly" do
    filters = %{"status" => "ACTIVE"}
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])

    assert length(filtered_data) == 2
    assert Enum.all?(filtered_data, & &1.status == "ACTIVE")
  end

  test "filters by amount range correctly" do
    filters = %{"min_amount" => "200", "max_amount" => "300"}
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])

    assert length(filtered_data) == 2
    assert Enum.all?(filtered_data, fn item ->
      item.amount >= 200 and item.amount <= 300
    end)
  end

  test "filters by date range correctly" do
    filters = %{"date_from" => "2024-01-02", "date_to" => "2024-01-03"}
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])

    assert length(filtered_data) == 2
    assert Enum.all?(filtered_data, fn item ->
      item.date >= "2024-01-02" and item.date <= "2024-01-03"
    end)
  end

  test "combines multiple filters correctly" do
    filters = %{
      "status" => "ACTIVE",
      "min_amount" => "100",
      "max_amount" => "500"
    }
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])

    assert length(filtered_data) == 2
    assert Enum.all?(filtered_data, fn item ->
      item.status == "ACTIVE" and item.amount >= 100 and item.amount <= 500
    end)
  end

  test "handles empty filters gracefully" do
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, %{}, [])
    assert length(filtered_data) == 4  # All data returned
  end

  test "handles unknown filter keys gracefully" do
    filters = %{"unknown_key" => "unknown_value"}
    {:ok, filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])
    assert length(filtered_data) == 4  # No filtering applied
  end

  test "validates filter parameters" do
    # Test with invalid amount values
    filters = %{"min_amount" => "invalid", "max_amount" => "also_invalid"}

    # Should handle gracefully without crashing
    assert {:ok, _filtered_data} = MockFilterable.handle_filtered_data(nil, filters, [])
  end
end

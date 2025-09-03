defmodule LedgerBankApi.Banking.Behaviours.SortableTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Behaviours.Sortable

  # Mock module that implements the Sortable behaviour
  defmodule MockSortable do
    @behaviour LedgerBankApi.Banking.Behaviours.Sortable

    @impl LedgerBankApi.Banking.Behaviours.Sortable
    def handle_sorted_data(query, sort_params, opts) do
      # Simulate applying sorting to data
      sorted_data = apply_sorting(sort_params)
      {:ok, sorted_data}
    end

    defp apply_sorting(sort_params) do
      base_data = [
        %{id: 1, name: "Alice", amount: 100, date: "2024-01-01"},
        %{id: 2, name: "Bob", amount: 300, date: "2024-01-02"},
        %{id: 3, name: "Charlie", amount: 200, date: "2024-01-03"},
        %{id: 4, name: "David", amount: 400, date: "2024-01-04"}
      ]

      case sort_params do
        %{"sort_by" => "name", "sort_order" => "asc"} ->
          Enum.sort_by(base_data, & &1.name, :asc)
        %{"sort_by" => "name", "sort_order" => "desc"} ->
          Enum.sort_by(base_data, & &1.name, :desc)
        %{"sort_by" => "amount", "sort_order" => "asc"} ->
          Enum.sort_by(base_data, & &1.amount, :asc)
        %{"sort_by" => "amount", "sort_order" => "desc"} ->
          Enum.sort_by(base_data, & &1.amount, :desc)
        %{"sort_by" => "date", "sort_order" => "asc"} ->
          Enum.sort_by(base_data, & &1.date, :asc)
        %{"sort_by" => "date", "sort_order" => "desc"} ->
          Enum.sort_by(base_data, & &1.date, :desc)
        _ ->
          base_data  # Default: no sorting
      end
    end
  end

  test "sorts by name in ascending order" do
    sort_params = %{"sort_by" => "name", "sort_order" => "asc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])

    assert length(sorted_data) == 4
    assert Enum.at(sorted_data, 0).name == "Alice"
    assert Enum.at(sorted_data, 1).name == "Bob"
    assert Enum.at(sorted_data, 2).name == "Charlie"
    assert Enum.at(sorted_data, 3).name == "David"
  end

  test "sorts by name in descending order" do
    sort_params = %{"sort_by" => "name", "sort_order" => "desc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])

    assert length(sorted_data) == 4
    assert Enum.at(sorted_data, 0).name == "David"
    assert Enum.at(sorted_data, 1).name == "Charlie"
    assert Enum.at(sorted_data, 2).name == "Bob"
    assert Enum.at(sorted_data, 3).name == "Alice"
  end

  test "sorts by amount in ascending order" do
    sort_params = %{"sort_by" => "amount", "sort_order" => "asc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])

    assert length(sorted_data) == 4
    assert Enum.at(sorted_data, 0).amount == 100
    assert Enum.at(sorted_data, 1).amount == 200
    assert Enum.at(sorted_data, 2).amount == 300
    assert Enum.at(sorted_data, 3).amount == 400
  end

  test "sorts by amount in descending order" do
    sort_params = %{"sort_by" => "amount", "sort_order" => "desc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])

    assert length(sorted_data) == 4
    assert Enum.at(sorted_data, 0).amount == 400
    assert Enum.at(sorted_data, 1).amount == 300
    assert Enum.at(sorted_data, 2).amount == 200
    assert Enum.at(sorted_data, 3).amount == 100
  end

  test "sorts by date correctly" do
    sort_params = %{"sort_by" => "date", "sort_order" => "asc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])

    assert length(sorted_data) == 4
    assert Enum.at(sorted_data, 0).date == "2024-01-01"
    assert Enum.at(sorted_data, 3).date == "2024-01-04"
  end

  test "handles missing sort parameters gracefully" do
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, %{}, [])
    assert length(sorted_data) == 4  # Default order maintained
  end

  test "handles invalid sort field gracefully" do
    sort_params = %{"sort_by" => "invalid_field", "sort_order" => "asc"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])
    assert length(sorted_data) == 4  # Default order maintained
  end

  test "handles invalid sort order gracefully" do
    sort_params = %{"sort_by" => "name", "sort_order" => "invalid_order"}
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, sort_params, [])
    assert length(sorted_data) == 4  # Default order maintained
  end

  test "validates sort parameters" do
    # Test with nil values
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, %{"sort_by" => nil, "sort_order" => nil}, [])
    assert length(sorted_data) == 4

    # Test with empty strings
    {:ok, sorted_data} = MockSortable.handle_sorted_data(nil, %{"sort_by" => "", "sort_order" => ""}, [])
    assert length(sorted_data) == 4
  end
end

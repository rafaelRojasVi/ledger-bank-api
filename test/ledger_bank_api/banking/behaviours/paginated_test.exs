defmodule LedgerBankApi.Banking.Behaviours.PaginatedTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Behaviours.Paginated

  # Mock module that implements the Paginated behaviour
  defmodule MockPaginated do
    @behaviour LedgerBankApi.Banking.Behaviours.Paginated

    @impl LedgerBankApi.Banking.Behaviours.Paginated
    def handle_paginated_data(query, params, opts) do
      page = String.to_integer(params["page"] || "1")
      per_page = String.to_integer(params["per_page"] || "20")

      total_count = 100
      offset = (page - 1) * per_page

      data = Enum.slice(1..total_count, offset, per_page)

      {:ok, data, %{
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: ceil(total_count / per_page),
        has_next: page < ceil(total_count / per_page),
        has_prev: page > 1
      }}
    end
  end

  test "validates pagination parameters correctly" do
    # Test valid parameters
    assert {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"page" => "1", "per_page" => "10"}, [])
    assert meta.page == 1
    assert meta.per_page == 10

    # Test default values
    assert {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{}, [])
    assert meta.page == 1
    assert meta.per_page == 20
  end

  test "calculates pagination metadata correctly" do
    {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"page" => "3", "per_page" => "25"}, [])

    assert meta.total_count == 100
    assert meta.page == 3
    assert meta.per_page == 25
    assert meta.total_pages == 4
    assert meta.has_next == true
    assert meta.has_prev == true
  end

  test "handles edge cases correctly" do
    # First page
    {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"page" => "1", "per_page" => "50"}, [])
    assert meta.has_prev == false
    assert meta.has_next == true

    # Last page
    {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"page" => "4", "per_page" => "25"}, [])
    assert meta.has_prev == true
    assert meta.has_next == false
  end

  test "respects per_page limits" do
    # Test within limits
    assert {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"per_page" => "50"}, [])
    assert meta.per_page == 50

    # Test max limit (assuming 100 is max)
    assert {:ok, _data, meta} = MockPaginated.handle_paginated_data(nil, %{"per_page" => "150"}, [])
    assert meta.per_page <= 100
  end
end

defmodule LedgerBankApi.Banking.Behaviours.PaginatedTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Behaviours.Paginated

  test "extract_pagination_params returns default values when no params provided" do
    result = Paginated.extract_pagination_params(%{})
    assert result.page == 1
    assert result.page_size == 20
  end

  test "extract_pagination_params returns custom values when provided" do
    result = Paginated.extract_pagination_params(%{"page" => "3", "page_size" => "50"})
    assert result.page == 3
    assert result.page_size == 50
  end

  test "extract_pagination_params extracts values without validation" do
    result = Paginated.extract_pagination_params(%{"page" => "0"})
    assert result.page == 0
  end

  test "extract_pagination_params extracts large values without validation" do
    result = Paginated.extract_pagination_params(%{"page_size" => "1000"})
    assert result.page_size == 1000
  end

  test "validate_pagination_params returns error for invalid page" do
    assert {:error, "Page must be greater than 0"} = Paginated.validate_pagination_params(%{page: -1, page_size: 20})
  end

  test "validate_pagination_params returns error for invalid page_size" do
    assert {:error, "Page size must be greater than 0"} = Paginated.validate_pagination_params(%{page: 1, page_size: 0})
  end

  test "validate_pagination_params returns ok for valid params" do
    assert {:ok, %{page: 1, page_size: 20}} = Paginated.validate_pagination_params(%{page: 1, page_size: 20})
  end

  test "build_pagination_metadata returns correct metadata" do
    metadata = Paginated.build_pagination_metadata(1, 20, 100)
    assert metadata.total_count == 100
    assert metadata.page == 1
    assert metadata.page_size == 20
    assert metadata.total_pages == 5
    assert metadata.has_next == true
    assert metadata.has_prev == false
  end

  test "build_pagination_metadata handles last page correctly" do
    metadata = Paginated.build_pagination_metadata(100, 5, 20)
    assert metadata.has_next == false
    assert metadata.has_prev == true
  end

  test "build_pagination_metadata handles single page correctly" do
    metadata = Paginated.build_pagination_metadata(1, 20, 15)
    assert metadata.total_pages == 1
    assert metadata.has_next == false
    assert metadata.has_prev == false
  end
end

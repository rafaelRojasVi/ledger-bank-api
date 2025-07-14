defmodule LedgerBankApi.Behaviours.Paginated.AdvancedTest do
  use ExUnit.Case, async: true
  import Mimic

  alias LedgerBankApi.Behaviours.Paginated

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "calculate_offset/2" do
    test "calculates offset correctly" do
      assert Paginated.calculate_offset(1, 20) == 0
      assert Paginated.calculate_offset(2, 20) == 20
      assert Paginated.calculate_offset(3, 10) == 20
    end
  end

  describe "build_pagination_metadata/3" do
    test "builds pagination metadata correctly" do
      metadata = Paginated.build_pagination_metadata(2, 10, 25)

      assert metadata.page == 2
      assert metadata.page_size == 10
      assert metadata.total_count == 25
      assert metadata.total_pages == 3
      assert metadata.has_next == true
      assert metadata.has_prev == true
    end

    test "handles first page correctly" do
      metadata = Paginated.build_pagination_metadata(1, 10, 25)

      assert metadata.has_prev == false
      assert metadata.has_next == true
    end

    test "handles last page correctly" do
      metadata = Paginated.build_pagination_metadata(3, 10, 25)

      assert metadata.has_prev == true
      assert metadata.has_next == false
    end
  end

  describe "create_pagination_struct/1" do
    test "creates valid pagination struct" do
      params = %{"page" => "2", "page_size" => "15"}
      result = Paginated.create_pagination_struct(params)

      assert {:ok, struct} = result
      assert struct.page == 2
      assert struct.page_size == 15
    end

    test "returns error for invalid params" do
      params = %{"page" => "0", "page_size" => "15"}
      result = Paginated.create_pagination_struct(params)

      assert result == {:error, "Page must be greater than 0"}
    end
  end

  describe "behaviour contract" do
    test "module implementing behaviour must have required callbacks" do
      assert function_exported?(Paginated, :extract_pagination_params, 1)
      assert function_exported?(Paginated, :validate_pagination_params, 1)
    end
  end
end

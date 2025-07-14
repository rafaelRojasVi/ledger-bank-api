defmodule LedgerBankApi.Behaviours.Paginated.BasicTest do
  use ExUnit.Case, async: true
  import Mimic

  alias LedgerBankApi.Behaviours.Paginated

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "extract_pagination_params/1" do
    test "extracts pagination params with defaults" do
      params = %{}
      result = Paginated.extract_pagination_params(params)

      assert result.page == 1
      assert result.page_size == 20
    end

    test "extracts pagination params with custom values" do
      params = %{"page" => "3", "page_size" => "15"}
      result = Paginated.extract_pagination_params(params)

      assert result.page == 3
      assert result.page_size == 15
    end

    test "handles string params correctly" do
      params = %{"page" => "5", "page_size" => "25"}
      result = Paginated.extract_pagination_params(params)

      assert result.page == 5
      assert result.page_size == 25
    end
  end

  describe "validate_pagination_params/1" do
    test "validates correct pagination params" do
      params = %{page: 2, page_size: 10}
      result = Paginated.validate_pagination_params(params)

      assert result == {:ok, %{page: 2, page_size: 10}}
    end

    test "rejects page less than 1" do
      params = %{page: 0, page_size: 10}
      result = Paginated.validate_pagination_params(params)

      assert result == {:error, "Page must be greater than 0"}
    end

    test "rejects page_size less than 1" do
      params = %{page: 1, page_size: 0}
      result = Paginated.validate_pagination_params(params)

      assert result == {:error, "Page size must be greater than 0"}
    end

    test "rejects page_size greater than 100" do
      params = %{page: 1, page_size: 101}
      result = Paginated.validate_pagination_params(params)

      assert result == {:error, "Page size cannot exceed 100"}
    end
  end
end

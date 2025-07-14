defmodule LedgerBankApi.Behaviours.IntegrationTest do
  use ExUnit.Case, async: true
  import Mimic

  alias LedgerBankApi.Behaviours.{Paginated, Filterable, Sortable, ErrorHandler}

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "behaviours working together" do
    test "complete API request flow with all behaviours" do
      # Simulate API request params
      params = %{
        "page" => "2",
        "page_size" => "10",
        "date_from" => "2025-01-01T00:00:00Z",
        "date_to" => "2025-01-31T23:59:59Z",
        "sort_by" => "amount",
        "sort_order" => "asc"
      }

      # Step 1: Extract and validate pagination
      pagination_params = Paginated.extract_pagination_params(params)
      assert {:ok, validated_pagination} = Paginated.validate_pagination_params(pagination_params)
      assert validated_pagination.page == 2
      assert validated_pagination.page_size == 10

      # Step 2: Extract and validate filters
      filter_params = Filterable.extract_filter_params(params)
      assert {:ok, validated_filters} = Filterable.validate_filter_params(filter_params)
      assert Map.has_key?(validated_filters, :date_from)
      assert Map.has_key?(validated_filters, :date_to)

      # Step 3: Extract and validate sorting
      sort_params = Sortable.extract_sort_params(params)
      allowed_fields = ["posted_at", "amount", "description"]
      assert {:ok, validated_sort} = Sortable.validate_sort_params(sort_params, allowed_fields)
      assert validated_sort.sort_by == "amount"
      assert validated_sort.sort_order == "asc"

      # Step 4: Simulate successful data processing
      mock_data = [
        %{id: "1", amount: "10.00", posted_at: "2025-01-15T10:00:00Z"},
        %{id: "2", amount: "20.00", posted_at: "2025-01-16T11:00:00Z"}
      ]

      success_response = ErrorHandler.create_success_response(mock_data, %{
        pagination: validated_pagination,
        filters: validated_filters,
        sorting: validated_sort
      })

      assert success_response.data == mock_data
      assert success_response.success == true
      assert success_response.metadata.pagination == validated_pagination
      assert success_response.metadata.filters == validated_filters
      assert success_response.metadata.sorting == validated_sort
    end

    test "error handling in complete flow" do
      # Simulate API request with invalid params
      params = %{
        "page" => "0",  # Invalid page
        "page_size" => "101",  # Invalid page size
        "date_from" => "invalid-date",  # Invalid date
        "sort_by" => "invalid_field"  # Invalid sort field
      }

      # Step 1: Pagination validation should fail
      pagination_params = Paginated.extract_pagination_params(params)
      assert {:error, "Page must be greater than 0"} = Paginated.validate_pagination_params(pagination_params)

      # Step 2: Filter validation should pass (only validates when both dates are present)
      filter_params = Filterable.extract_filter_params(params)
      assert {:ok, _} = Filterable.validate_filter_params(filter_params)

      # Step 3: Sort validation should fail
      sort_params = Sortable.extract_sort_params(params)
      allowed_fields = ["posted_at", "amount", "description"]
      assert {:error, _} = Sortable.validate_sort_params(sort_params, allowed_fields)

      # Step 4: Error handling should format errors consistently
      error_response = ErrorHandler.handle_common_error({:error, "Validation failed"}, %{
        context: "api_request",
        params: params
      })

      assert error_response.error.type == :unprocessable_entity
      assert error_response.error.message == "Validation failed"
      assert Map.has_key?(error_response.error, :timestamp)
    end

    test "struct creation with all behaviours" do
      # Valid params
      params = %{
        "page" => "1",
        "page_size" => "20",
        "date_from" => "2025-01-01T00:00:00Z",
        "sort_by" => "posted_at",
        "sort_order" => "desc"
      }

      # Create structs for all behaviours
      assert {:ok, pagination_struct} = Paginated.create_pagination_struct(params)
      assert {:ok, filter_struct} = Filterable.create_filter_struct(params)
      assert {:ok, sort_struct} = Sortable.create_sort_struct(params, ["posted_at", "amount", "description"])

      # Verify structs have correct values
      assert pagination_struct.page == 1
      assert pagination_struct.page_size == 20
      assert filter_struct.date_from != nil
      assert sort_struct.sort_by == "posted_at"
      assert sort_struct.sort_order == "desc"
    end

    test "with_error_handling wrapper with behaviours" do
      # Test successful operation
      success_fun = fn ->
        {:ok, %{data: "success", pagination: %{page: 1, page_size: 10}}}
      end

      result = ErrorHandler.with_error_handling(success_fun, %{context: "test"})
      assert {:ok, response} = result
      assert response.data.data == "success"
      assert response.success == true

      # Test error operation
      error_fun = fn ->
        {:error, :not_found}
      end

      result = ErrorHandler.with_error_handling(error_fun, %{context: "test"})
      assert {:error, response} = result
      assert response.error.type == :not_found
      assert response.error.message == "Resource not found"
    end
  end

  describe "behaviour reusability" do
    test "behaviours can be used in different contexts" do
      # Simulate using behaviours in a worker context
      worker_params = %{
        "page" => "1",
        "page_size" => "50",
        "date_from" => "2025-01-01T00:00:00Z",
        "sort_by" => "posted_at",
        "sort_order" => "desc"
      }

      # Same validation logic works in worker context
      pagination_params = Paginated.extract_pagination_params(worker_params)
      filter_params = Filterable.extract_filter_params(worker_params)
      sort_params = Sortable.extract_sort_params(worker_params)

      assert {:ok, _} = Paginated.validate_pagination_params(pagination_params)
      assert {:ok, _} = Filterable.validate_filter_params(filter_params)
      assert {:ok, _} = Sortable.validate_sort_params(sort_params, ["posted_at", "amount"])

      # Error handling works the same way
      error_response = ErrorHandler.handle_common_error({:error, "Worker error"}, %{
        context: "worker_job",
        job_id: "123"
      })

      assert error_response.error.type == :unprocessable_entity
      assert error_response.error.message == "Worker error"
    end
  end
end

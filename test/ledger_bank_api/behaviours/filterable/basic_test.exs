defmodule LedgerBankApi.Behaviours.FilterableTest do
  use ExUnit.Case, async: true
  import Mimic

  alias LedgerBankApi.Behaviours.Filterable

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "extract_filter_params/1" do
    test "extracts filter params with nil values" do
      params = %{}
      result = Filterable.extract_filter_params(params)

      assert result.date_from == nil
      assert result.date_to == nil
      assert result.amount_min == nil
      assert result.amount_max == nil
      assert result.description == nil
      assert result.status == nil
    end

    test "extracts filter params with values" do
      params = %{
        "date_from" => "2025-01-01T00:00:00Z",
        "date_to" => "2025-01-31T23:59:59Z",
        "amount_min" => "10.00",
        "description" => "test"
      }
      result = Filterable.extract_filter_params(params)

      assert result.date_from == "2025-01-01T00:00:00Z"
      assert result.date_to == "2025-01-31T23:59:59Z"
      assert result.amount_min == "10.00"
      assert result.description == "test"
    end
  end

  describe "validate_filter_params/1" do
    test "validates empty filters" do
      filters = %{}
      result = Filterable.validate_filter_params(filters)

      assert result == {:ok, %{}}
    end

    test "validates filters with valid date range" do
      filters = %{
        date_from: "2025-01-01T00:00:00Z",
        date_to: "2025-01-31T23:59:59Z"
      }
      result = Filterable.validate_filter_params(filters)

      assert {:ok, validated_filters} = result
      assert Map.has_key?(validated_filters, :date_from)
      assert Map.has_key?(validated_filters, :date_to)
    end

    test "rejects invalid date_from format" do
      filters = %{
        date_from: "invalid-date",
        date_to: "2025-01-31T23:59:59Z"
      }
      result = Filterable.validate_filter_params(filters)

      assert result == {:error, "Invalid date_from format"}
    end

    test "rejects invalid date_to format" do
      filters = %{
        date_from: "2025-01-01T00:00:00Z",
        date_to: "invalid-date"
      }
      result = Filterable.validate_filter_params(filters)

      assert result == {:error, "Invalid date_to format"}
    end

    test "rejects date_from after date_to" do
      filters = %{
        date_from: "2025-01-31T23:59:59Z",
        date_to: "2025-01-01T00:00:00Z"
      }
      result = Filterable.validate_filter_params(filters)

      assert result == {:error, "Date from must be before date to"}
    end

    test "validates filters with only date_from" do
      filters = %{
        date_from: "2025-01-01T00:00:00Z"
      }
      result = Filterable.validate_filter_params(filters)

      assert {:ok, validated_filters} = result
      assert Map.has_key?(validated_filters, :date_from)
      refute Map.has_key?(validated_filters, :date_to)
    end

    test "validates filters with only date_to" do
      filters = %{
        date_to: "2025-01-31T23:59:59Z"
      }
      result = Filterable.validate_filter_params(filters)

      assert {:ok, validated_filters} = result
      assert Map.has_key?(validated_filters, :date_to)
      refute Map.has_key?(validated_filters, :date_from)
    end

    test "removes nil values from filters" do
      filters = %{
        date_from: nil,
        date_to: "2025-01-31T23:59:59Z",
        amount_min: nil,
        description: "test"
      }
      result = Filterable.validate_filter_params(filters)

      assert {:ok, validated_filters} = result
      refute Map.has_key?(validated_filters, :date_from)
      refute Map.has_key?(validated_filters, :amount_min)
      assert Map.has_key?(validated_filters, :date_to)
      assert Map.has_key?(validated_filters, :description)
    end
  end

  describe "create_filter_struct/1" do
    test "creates valid filter struct" do
      params = %{
        "date_from" => "2025-01-01T00:00:00Z",
        "date_to" => "2025-01-31T23:59:59Z",
        "description" => "test"
      }
      result = Filterable.create_filter_struct(params)

      assert {:ok, struct} = result
      assert struct.description == "test"
    end

    test "returns error for invalid params" do
      params = %{
        "date_from" => "invalid-date",
        "date_to" => "2025-01-31T23:59:59Z"
      }
      result = Filterable.create_filter_struct(params)

      assert result == {:error, "Invalid date_from format"}
    end
  end

  describe "behaviour contract" do
    test "module implementing behaviour must have required callbacks" do
      assert function_exported?(Filterable, :extract_filter_params, 1)
      assert function_exported?(Filterable, :validate_filter_params, 1)
    end
  end
end

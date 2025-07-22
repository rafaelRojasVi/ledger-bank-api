defmodule LedgerBankApi.Banking.Behaviours.FilterablePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias LedgerBankApi.Banking.Behaviours.Filterable

  property "extract_filter_params always returns a map with expected keys" do
    check all params <- map_of(string(:alphanumeric), string(:alphanumeric)) do
      result = Filterable.extract_filter_params(params)
      assert Map.has_key?(result, :date_from)
      assert Map.has_key?(result, :date_to)
      assert Map.has_key?(result, :amount_min)
      assert Map.has_key?(result, :amount_max)
      assert Map.has_key?(result, :description)
      assert Map.has_key?(result, :status)
    end
  end

  property "validate_filter_params returns error if date_from > date_to" do
    check all from <- date_time(), to <- date_time() do
      filters = %{date_from: DateTime.to_iso8601(from), date_to: DateTime.to_iso8601(to)}
      result = Filterable.validate_filter_params(filters)
      if DateTime.compare(from, to) == :gt do
        assert result == {:error, "Date from must be before date to"}
      else
        assert match?({:ok, _}, result)
      end
    end
  end

  defp date_time do
    # Generate DateTime structs within a reasonable range
    integer(1_600_000_000..1_700_000_000)
    |> map(&DateTime.from_unix!(&1))
  end
end

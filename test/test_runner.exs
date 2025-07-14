#!/usr/bin/env elixir

# Test Runner Script for LedgerBankApi
# Usage: elixir test/test_runner.exs [command]

defmodule TestRunner do
  @moduledoc """
  A simple test runner to organize and run tests by category.
  """

  def main do
    case System.argv() do
      ["pagination"] -> run_pagination_tests()
      ["filtering"] -> run_filtering_tests()
      ["sorting"] -> run_sorting_tests()
      ["error-handling"] -> run_error_handling_tests()
      ["behaviours"] -> run_all_behaviour_tests()
      ["integration"] -> run_integration_tests()
      ["controllers"] -> run_controller_tests()
      ["unit"] -> run_unit_tests()
      ["all"] -> run_all_tests()
      ["help"] -> show_help()
      _ -> show_help()
    end
  end

  def run_pagination_tests do
    IO.puts("🧪 Running Pagination Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/paginated/"])
  end

  def run_filtering_tests do
    IO.puts("🔍 Running Filtering Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/filterable/"])
  end

  def run_sorting_tests do
    IO.puts("📊 Running Sorting Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/sortable/"])
  end

  def run_error_handling_tests do
    IO.puts("⚠️  Running Error Handling Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/error_handler/"])
  end

  def run_all_behaviour_tests do
    IO.puts("🎭 Running All Behaviour Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/"])
  end

  def run_integration_tests do
    IO.puts("🔗 Running Integration Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/behaviours/integration_test.exs"])
  end

  def run_controller_tests do
    IO.puts("🎮 Running Controller Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api_web/controllers/"])
  end

  def run_unit_tests do
    IO.puts("🧩 Running Unit Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/"])
  end

  def run_all_tests do
    IO.puts("🚀 Running All Tests...")
    System.cmd("mix", ["test"])
  end

  def show_help do
    IO.puts("""
    🧪 LedgerBankApi Test Runner

    Usage: elixir test/test_runner.exs [command]

    Commands:
      pagination      - Run pagination behaviour tests
      filtering       - Run filtering behaviour tests
      sorting         - Run sorting behaviour tests
      error-handling  - Run error handling behaviour tests
      behaviours      - Run all behaviour tests
      integration     - Run integration tests
      controllers     - Run controller tests
      unit            - Run unit tests
      all             - Run all tests
      help            - Show this help message

    Examples:
      elixir test/test_runner.exs pagination
      elixir test/test_runner.exs behaviours
      elixir test/test_runner.exs all
    """)
  end
end

TestRunner.main()

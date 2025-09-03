#!/usr/bin/env elixir

# Test Runner Script for LedgerBankApi
# Usage: elixir test/test_runner.exs [command]

defmodule TestRunner do
  @moduledoc """
  A simple test runner to organize and run tests by category.
  """

  def main do
    case System.argv() do
      ["auth"] -> run_auth_tests()
      ["banking"] -> run_banking_tests()
      ["users"] -> run_users_tests()
      ["cache"] -> run_cache_tests()
      ["integration"] -> run_integration_tests()
      ["unit"] -> run_unit_tests()
      ["all"] -> run_all_tests()
      ["help"] -> show_help()
      _ -> show_help()
    end
  end

  def run_auth_tests do
    IO.puts("🔐 Running Authentication Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/auth/"])
  end

  def run_banking_tests do
    IO.puts("🏦 Running Banking Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/banking/"])
  end

  def run_users_tests do
    IO.puts("👥 Running User Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/users/"])
  end

  def run_cache_tests do
    IO.puts("💾 Running Cache Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/cache_test.exs"])
  end

  def run_integration_tests do
    IO.puts("🔗 Running Integration Tests...")
    System.cmd("mix", ["test", "test/ledger_bank_api/integration/"])
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
      auth         - Run authentication tests
      banking      - Run banking tests
      users        - Run user management tests
      cache        - Run cache tests
      integration  - Run integration tests
      unit         - Run unit tests
      all          - Run all tests
      help         - Show this help message

    Examples:
      elixir test/test_runner.exs auth
      elixir test/test_runner.exs banking
      elixir test/test_runner.exs all
    """)
  end
end

TestRunner.main()

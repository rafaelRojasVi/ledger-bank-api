{:ok, _} = Application.ensure_all_started(:ledger_bank_api)

# Configure Ecto sandbox for testing
Ecto.Adapters.SQL.Sandbox.mode(LedgerBankApi.Repo, :manual)

# Start ExUnit with proper configuration
ExUnit.start(
  formatters: [ExUnit.CLIFormatter],
  capture_log: true,
  trace: false
)

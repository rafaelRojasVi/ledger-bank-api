#!/bin/bash

# Set environment variables for database connection
export DB_USER=postgres
export DB_PASS=postgres
export DB_HOST=localhost
export DB_PORT=5432

echo "🧪 Setting up test environment..."

# Ensure Docker PostgreSQL is running
if ! docker compose ps db | grep -q "Up"; then
  echo "🛢️  Starting PostgreSQL container..."
  docker compose up -d db
  
  echo "⏳ Waiting for PostgreSQL to be ready..."
  until docker compose exec -T db pg_isready -U postgres; do
    echo "Waiting for PostgreSQL..."
    sleep 2
  done
fi

echo "🗑️  Setting up Test Database..."
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

echo "🧹 Clearing any existing cache..."
# Clear any existing cache data (if running in test mode)
MIX_ENV=test mix run -e "if Process.whereis(LedgerBankApi.Cache.Store), do: :ets.delete_all_objects(:ledger_cache)"

echo "✅ Test environment ready! Run 'mix test' to execute tests."
echo ""
echo "💡 Testing Tips:"
echo "  - Run specific modules: mix test:auth, mix test:banking, mix test:users"
echo "  - Run integration tests: mix test:integration"
echo "  - Run all unit tests: mix test:unit"
echo "  - Run with coverage: mix test --cover"
echo "  - Run specific files: mix test test/path/to/test.exs" 
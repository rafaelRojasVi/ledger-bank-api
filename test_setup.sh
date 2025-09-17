#!/bin/bash

# Set environment variables for database connection
export DB_USER=postgres
export DB_PASS=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=ledger_bank_api_dev
export JWT_SECRET="test-secret-key-for-testing-only-must-be-64-chars-long"

echo "🧪 Setting up LedgerBankApi test environment..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker first."
  exit 1
fi

# Ensure Docker PostgreSQL is running
if ! docker compose ps db | grep -q "Up"; then
  echo "🛢️  Starting PostgreSQL container..."
  docker compose up -d db
  
  echo "⏳ Waiting for PostgreSQL to be ready..."
  until docker compose exec -T db pg_isready -U postgres; do
    echo "Waiting for PostgreSQL..."
    sleep 2
  done
  echo "✅ PostgreSQL is ready!"
else
  echo "✅ PostgreSQL container is already running"
fi

echo "🔧 Setting up development database..."
# Set up dev database first
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

echo "🗑️  Setting up Test Database..."
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

echo "🧹 Clearing any existing cache..."
# Clear any existing cache data (if running in test mode)
MIX_ENV=test mix run -e "if Process.whereis(LedgerBankApi.Cache.Store), do: :ets.delete_all_objects(:ledger_cache)" 2>/dev/null || true

echo "✅ Environment setup complete!"
echo ""
echo "🚀 You can now:"
echo "  📊 Start the server: mix phx.server"
echo "  🧪 Run tests: mix test"
echo "  🔍 Test specific modules:"
echo "    - mix test:auth"
echo "    - mix test:users" 
echo "    - mix test:banking"
echo "    - mix test:integration"
echo "    - mix test:unit"
echo ""
echo "🌐 Server will be available at: http://localhost:4000"
echo "📋 API endpoints:"
echo "  - Health: GET /api/health"
echo "  - Login: POST /api/auth/login"
echo "  - Users: GET /api/users"
echo "  - User Stats: GET /api/users/stats"
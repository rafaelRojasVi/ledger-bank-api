#!/bin/bash

# Set environment variables for database connection
export DB_USER=postgres
export DB_PASS=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=ledger_bank_api_dev

echo "🧹 Cleaning and compiling..."
mix clean && mix compile

echo "🛢️  Restarting Docker PostgreSQL container..."
docker compose down && docker compose up -d db

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker compose exec -T db pg_isready -U postgres; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "🗑️  Setting up Development Database..."
MIX_ENV=dev mix ecto.drop
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate
MIX_ENV=dev mix run priv/repo/seeds.exs

echo "🧪 Setting up Test Database..."
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

echo "✅ Running tests to verify setup..."
mix test --no-start

echo "🚀 Starting Phoenix server..."
mix phx.server &
SERVER_PID=$!

echo "⏳ Waiting 3 seconds for server to boot..."
sleep 3

echo "✅ All set! Server running at http://localhost:4000"
echo "📊 Test database ready for: mix test"
echo "Press Ctrl+C to stop."

# Keep the script running to maintain the Phoenix server process
wait $SERVER_PID

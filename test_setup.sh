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

echo "✅ Test environment ready! Run 'mix test' to execute tests." 
#!/bin/bash
mix clean && mix compile

echo "🛢️  Restarting Docker PostgreSQL container..."
docker compose down && docker compose up -d db

echo "⏳ Waiting 5 seconds for PostgreSQL to be ready..."
sleep 5

echo "🗑️  Resetting Database..."
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

echo "🚀 Starting Phoenix server..."
mix phx.server &
SERVER_PID=$!

echo "⏳ Waiting 3 seconds for server to boot..."
sleep 3

echo "✅ All set! Server running at http://localhost:4000"
echo "Press Ctrl+C to stop."

# Keep the script running to maintain the Phoenix server process
wait $SERVER_PID

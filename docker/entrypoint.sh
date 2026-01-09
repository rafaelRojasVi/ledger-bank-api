#!/bin/sh
set -e

echo "⏳  Waiting for Postgres @ $PGHOST:$PGPORT ..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; do
  sleep 0.5
done
echo "✅  Postgres is up."

echo "🔍 Debugging release structure..."
echo "Current directory: $(pwd)"
echo "Contents of /app:"
ls -la /app/ || echo "Cannot list /app"
echo "Contents of /app/ledger_bank_api:"
ls -la /app/ledger_bank_api/ || echo "Cannot list /app/ledger_bank_api"
echo "Looking for bin directory..."
find /app -name "ledger_bank_api" -type f 2>/dev/null || echo "Cannot find release binary"

echo "🛠  Running migrations..."
/app/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

echo "🚀  Launching Phoenix..."
exec /app/ledger_bank_api/bin/ledger_bank_api start

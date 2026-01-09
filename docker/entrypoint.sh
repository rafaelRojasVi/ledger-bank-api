#!/bin/sh
set -e

echo "⏳  Waiting for Postgres @ $PGHOST:$PGPORT ..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; do
  sleep 0.5
done
echo "✅  Postgres is up."

echo "🔍 Debugging release binary..."
ls -la /app/ledger_bank_api/bin/ || echo "bin directory not found"
test -f /app/ledger_bank_api/bin/ledger_bank_api && echo "✅ Release binary exists" || echo "❌ Release binary NOT found"
head -1 /app/ledger_bank_api/bin/ledger_bank_api || echo "Cannot read release binary"

echo "🛠  Running migrations..."
/app/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

echo "🚀  Launching Phoenix..."
exec /app/ledger_bank_api/bin/ledger_bank_api start

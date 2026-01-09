#!/bin/sh
set -e

echo "⏳  Waiting for Postgres @ $PGHOST:$PGPORT ..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; do
  sleep 0.5
done
echo "✅  Postgres is up."

echo "🛠  Running migrations..."
/opt/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

echo "🚀  Launching Phoenix..."
exec /opt/ledger_bank_api/bin/ledger_bank_api start

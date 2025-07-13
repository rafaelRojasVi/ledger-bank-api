#!/bin/bash

# Development database connection helper
# Usage: source scripts/dev-db.sh

# Function to use Docker database (recommended)
use_docker_db() {
    echo "🔗 Connecting to Docker PostgreSQL..."
    export DB_HOST=localhost
    export DB_PORT=5432
    export DB_USER=postgres
    export DB_PASS=postgres
    export DB_NAME=ledger_bank_api_dev
    echo "✅ Using Docker PostgreSQL at localhost:5432"
    echo "   Make sure Docker Compose is running: docker-compose up -d db"
}

# Function to use native PostgreSQL (if you prefer)
use_native_db() {
    echo "🔗 Connecting to native PostgreSQL..."
    export DB_HOST=localhost
    export DB_PORT=5432
    export DB_USER=postgres
    export DB_PASS=postgres
    export DB_NAME=ledger_bank_api_dev
    echo "✅ Using native PostgreSQL at localhost:5432"
    echo "   Make sure native PostgreSQL is running"
}

# Function to show current database connection
show_db_status() {
    echo "📊 Current database configuration:"
    echo "   DB_HOST: ${DB_HOST:-localhost}"
    echo "   DB_PORT: ${DB_PORT:-5432}"
    echo "   DB_NAME: ${DB_NAME:-ledger_bank_api_dev}"
    
    if pg_isready -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" >/dev/null 2>&1; then
        echo "✅ Database is accepting connections"
    else
        echo "❌ Database is not accepting connections"
    fi
}

# Default to Docker database
use_docker_db 


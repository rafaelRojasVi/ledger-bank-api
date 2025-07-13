# Development database connection helper for Windows/WSL
# Usage: . scripts/dev-db.ps1

# Function to use Docker database (recommended)
function Use-DockerDB {
    Write-Host "🔗 Connecting to Docker PostgreSQL..." -ForegroundColor Green
    $env:DB_HOST = "localhost"
    $env:DB_PORT = "5432"
    $env:DB_USER = "postgres"
    $env:DB_PASS = "postgres"
    $env:DB_NAME = "ledger_bank_api_dev"
    Write-Host "✅ Using Docker PostgreSQL at localhost:5432" -ForegroundColor Green
    Write-Host "   Make sure Docker Compose is running: docker-compose up -d db" -ForegroundColor Yellow
}

# Function to use native PostgreSQL (if you prefer)
function Use-NativeDB {
    Write-Host "🔗 Connecting to native PostgreSQL..." -ForegroundColor Green
    $env:DB_HOST = "localhost"
    $env:DB_PORT = "5432"
    $env:DB_USER = "postgres"
    $env:DB_PASS = "postgres"
    $env:DB_NAME = "ledger_bank_api_dev"
    Write-Host "✅ Using native PostgreSQL at localhost:5432" -ForegroundColor Green
    Write-Host "   Make sure native PostgreSQL is running" -ForegroundColor Yellow
}

# Function to show current database connection
function Show-DBStatus {
    Write-Host "📊 Current database configuration:" -ForegroundColor Cyan
    Write-Host "   DB_HOST: $($env:DB_HOST ?? 'localhost')" -ForegroundColor White
    Write-Host "   DB_PORT: $($env:DB_PORT ?? '5432')" -ForegroundColor White
    Write-Host "   DB_NAME: $($env:DB_NAME ?? 'ledger_bank_api_dev')" -ForegroundColor White
    
    # Note: pg_isready check would need to be adapted for Windows
    Write-Host "   (Database connectivity check not available in PowerShell)" -ForegroundColor Yellow
}

# Default to Docker database
Use-DockerDB 


# Development startup script for Windows/WSL
# This script sets up the environment and starts development

Write-Host "🚀 Starting LedgerBankApi Development Environment..." -ForegroundColor Green

# Set environment variables for development
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_USER = "postgres"
$env:DB_PASS = "postgres"
$env:DB_NAME = "ledger_bank_api_dev"
$env:MIX_ENV = "dev"
$env:SECRET_KEY_BASE = "dev-insecure"

Write-Host "✅ Environment variables set" -ForegroundColor Green

# Start database
Write-Host "🗄️ Starting PostgreSQL database..." -ForegroundColor Yellow
docker-compose up -d db

# Wait for database to be ready
Write-Host "⏳ Waiting for database to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Run migrations
Write-Host "🔄 Running database migrations..." -ForegroundColor Yellow
mix ecto.migrate

Write-Host "✅ Database setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Start Phoenix server: iex -S mix phx.server" -ForegroundColor White
Write-Host "  2. Access API: http://localhost:4000" -ForegroundColor White
Write-Host "  3. Access LiveDashboard: http://localhost:4000/dev/dashboard" -ForegroundColor White
Write-Host ""
Write-Host "💡 Tip: Use 'docker-compose logs -f db' to view database logs" -ForegroundColor Gray 
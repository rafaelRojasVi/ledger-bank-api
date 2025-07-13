# Development Setup Guide

## 🗄️ Database Architecture

### One PostgreSQL, Everywhere

This project uses a **single PostgreSQL database** that serves all environments:

- **Development**: Host tools (WSL) reach it via `localhost:5432`
- **Docker**: Containers reach it via Docker DNS name `db:5432`
- **CI/CD**: GitHub Actions uses `localhost:5432` (service container)

This ensures **data consistency** across all environments - what you insert from host IEx is immediately visible to the running Phoenix API.

## 🛠️ Development Setup

### 1. Environment Configuration

Copy the environment template and customize for your setup:

```bash
cp env.example .env
```

Edit `.env` with your values:

```bash
# Database Configuration
DB_HOST=localhost      # each dev will change this in their own .env
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=ledger_bank_api_dev

# Phoenix
SECRET_KEY_BASE=replace-me-with-mix-phx-gen-secret

# External mock service
BANK_BASE_URL=http://localhost:4001/mock
```

### 2. Database Setup

#### Option A: Docker PostgreSQL (Recommended)

```bash
# Start PostgreSQL in Docker
docker-compose up -d db

# Set environment variables (Windows PowerShell)
. scripts/dev-db.ps1

# Or manually set them
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASS=postgres
export DB_NAME=ledger_bank_api_dev

# Run migrations
mix ecto.migrate
```

#### Option B: Native PostgreSQL

If you prefer to use your native PostgreSQL installation:

1. **Stop the native PostgreSQL service** (to avoid port conflicts):
   ```bash
   # Windows
   net stop postgresql-x64-16
   
   # Or disable the service
   sc config postgresql-x64-16 start=disabled
   ```

2. **Use the Docker database** as described in Option A.

### 3. Start Development

```bash
# Start Phoenix server from host
iex -S mix phx.server

# Or use the container
docker-compose up web
```

## 🔧 Environment Variables

### Required Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DB_HOST` | Database host | `localhost` | `localhost` |
| `DB_PORT` | Database port | `5432` | `5432` |
| `DB_USER` | Database user | `postgres` | `postgres` |
| `DB_PASS` | Database password | `postgres` | `postgres` |
| `DB_NAME` | Database name | `ledger_bank_api_dev` | `ledger_bank_api_dev` |
| `SECRET_KEY_BASE` | Phoenix secret key | - | Generate with `mix phx.gen.secret` |
| `BANK_BASE_URL` | External API URL | `http://localhost:4001/mock` | `http://localhost:4001/mock` |

### Environment-Specific Configurations

#### Development (WSL + Docker)
```bash
DB_HOST=localhost
DB_PORT=5432
```

#### Docker Container
```bash
DB_HOST=db
DB_PORT=5432
```

#### CI/CD (GitHub Actions)
```bash
DB_HOST=localhost
DB_PORT=5432
```

## 🐳 Docker Development

### Database Only
```bash
# Start only PostgreSQL
docker-compose up -d db

# Run migrations from host
mix ecto.migrate

# Start Phoenix from host
iex -S mix phx.server
```

### Full Stack
```bash
# Start all services
docker-compose up -d

# Access the API
curl -H "Authorization: Bearer your-token" http://localhost:4000/api/accounts
```

### Container Debugging
```bash
# Access container shell
docker-compose exec web /bin/bash

# Access remote IEx
docker-compose exec web /app/ledger_bank_api/bin/ledger_bank_api remote

# View logs
docker-compose logs -f web
```

## 🔍 Verification

To verify both host and container are using the same database:

### 1. From WSL Host
```bash
iex -S mix
# Insert test data
%LedgerBankApi.Banking.Account{name: "Test Account"} |> LedgerBankApi.Repo.insert!()
```

### 2. From Container
```bash
docker-compose exec web /app/ledger_bank_api/bin/ledger_bank_api remote
# Check the data
LedgerBankApi.Repo.all(LedgerBankApi.Banking.Account)
```

### 3. Via API
```bash
curl -H "Authorization: Bearer your-token" http://localhost:4000/api/accounts
```

All three should show the same data, confirming you have a single source of truth.

## 🛠️ Helper Scripts

### PowerShell Script (Windows)
```powershell
# Load database environment
. scripts/dev-db.ps1

# Available functions:
Use-DockerDB    # Connect to Docker PostgreSQL
Use-NativeDB    # Connect to native PostgreSQL
Show-DBStatus   # Show current configuration
```

### Bash Script (WSL/Linux)
```bash
# Load database environment
source scripts/dev-db.sh

# Available functions:
use_docker_db   # Connect to Docker PostgreSQL
use_native_db   # Connect to native PostgreSQL
show_db_status  # Show current configuration
```

## 🚨 Troubleshooting

### Port Conflicts

If you get port conflicts:

1. **Check what's using port 5432**:
   ```bash
   # Windows
   netstat -ano | findstr :5432
   
   # WSL
   sudo netstat -tlnp | grep :5432
   ```

2. **Stop the conflicting service**:
   ```bash
   # Windows
   net stop postgresql-x64-16
   
   # Or change the Docker port mapping in docker-compose.yml
   ports:
     - "5433:5432"  # Use 5433 on host, 5432 in container
   ```

### Database Connection Issues

1. **Verify Docker PostgreSQL is running**:
   ```bash
   docker-compose ps db
   ```

2. **Check database connectivity**:
   ```bash
   # From WSL
   pg_isready -h localhost -p 5432 -U postgres
   
   # From container
   docker-compose exec web pg_isready -h db -p 5432 -U postgres
   ```

3. **Reset database**:
   ```bash
   mix ecto.reset
   ```

### WSL-Specific Issues

- **Docker Desktop Integration**: Ensure Docker Desktop is configured to work with WSL2
- **Port Forwarding**: Docker Desktop automatically handles port forwarding to WSL
- **File Permissions**: If you encounter permission issues, ensure your WSL user has proper permissions

## 📊 Development Tools

### Database Management
```bash
# Create and migrate database
mix ecto.setup

# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate

# Drop database
mix ecto.drop
```

### Interactive Development
```bash
# Start with Phoenix server
iex -S mix phx.server

# Start without Phoenix
iex -S mix

# Start with code reloading
iex -S mix phx.server --no-halt
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/ledger_bank_api/banking_test.exs

# Run with coverage
mix test --cover

# Run tests in watch mode
mix test.watch
```

## 🔧 IDE Configuration

### VS Code Extensions
- **ElixirLS**: Elixir language server
- **Phoenix Framework**: Phoenix-specific features
- **Docker**: Docker integration

### VS Code Settings
```json
{
  "elixirLS.dialyzerEnabled": true,
  "elixirLS.fetchDeps": true,
  "elixirLS.mixEnv": "dev"
}
```

## 📈 Performance Monitoring

### LiveDashboard
Access at `http://localhost:4000/dev/dashboard` in development mode.

### Telemetry
The application includes built-in telemetry for monitoring:
- Database query performance
- API endpoint response times
- Memory usage

### Benchmarking
```bash
# Run banking benchmarks
mix bench

# Run endpoint benchmarks
mix bench:endpt

# Run CI benchmarks
mix bench:ci
```

## 🔐 Security Notes

- **Development Mode**: Authentication is currently in development mode
- **Environment Variables**: Never commit `.env` files to version control
- **Database**: Use strong passwords in production
- **Secrets**: Generate proper secret keys for production

## 🚀 Quick Commands Reference

```bash
# Complete development setup (Windows PowerShell)
. scripts/start-dev.ps1
iex -S mix phx.server

# Or manual setup
cp env.example .env
docker-compose up -d db
. scripts/dev-db.ps1
mix ecto.migrate
iex -S mix phx.server

# Common development tasks
mix test                    # Run tests
mix ecto.migrate           # Run migrations
mix ecto.reset             # Reset database
docker-compose logs -f     # View logs
mix phx.routes             # Show routes
``` 


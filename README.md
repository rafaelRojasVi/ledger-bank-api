# LedgerBankApi

A modern Elixir/Phoenix API for banking and financial data management with clean architecture, reusable behaviours, and comprehensive testing. This API provides access to account information, transactions, and payment processing with built-in pagination, filtering, sorting, and error handling.

## 🚀 Features

- **Account Management**: Create and manage user bank accounts
- **Transaction Tracking**: Record and query financial transactions with pagination
- **Payment Processing**: Background job processing for payments using Oban
- **RESTful API**: Clean, REST-compliant endpoints with consistent error handling
- **PostgreSQL Database**: Robust data persistence with Ecto
- **Docker Support**: Containerized deployment with Docker Compose
- **JWT Authentication**: Secure authentication system
- **Reusable Behaviours**: Consistent patterns for pagination, filtering, and sorting
- **Comprehensive Testing**: Organized test suite with focused test categories
- **Background Jobs**: Oban for reliable background job processing

## 🏗️ Architecture

The application follows a clean architecture pattern with:

- **Contexts**: Banking context for business logic
- **Web Layer**: Phoenix controllers and JSON views
- **Data Layer**: Ecto schemas and PostgreSQL
- **Background Jobs**: Oban workers for payment processing
- **Behaviours**: Reusable patterns for common API functionality

### Core Modules

- `LedgerBankApi.Banking` - Main business logic for accounts and transactions
- `LedgerBankApi.Users` - User management
- `LedgerBankApi.Behaviours` - Reusable patterns (Paginated, Filterable, Sortable, ErrorHandler)
- `LedgerBankApi.Workers` - Background job processing
- `LedgerBankApiWeb` - Phoenix web layer with controllers

## 📋 Prerequisites

- Elixir 1.18+
- Erlang/OTP
- Docker & Docker Compose
- WSL2 (Windows) or Linux/macOS

## 🛠️ Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd ledger_bank_api
```

### 2. Environment Configuration

```bash
# Copy environment template
cp env.example .env

# Edit .env with your values
```

### 3. Database Setup

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

### 4. Start Development Server

```bash
# Start Phoenix server
iex -S mix phx.server
```

### 5. Access the API

- **API**: http://localhost:4000
- **LiveDashboard**: http://localhost:4000/dev/dashboard
- **Mailbox Preview**: http://localhost:4000/dev/mailbox

## 🗄️ Database Schema

### Core Tables

#### Users
- `id` (UUID) - Primary key
- `email` (string) - User email (unique)
- `full_name` (string) - User's full name
- `status` (string) - User status (ACTIVE/SUSPENDED)
- `created_at` / `updated_at` - Timestamps

#### User Bank Accounts
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `bank_id` (UUID) - Foreign key to banks
- `account_number` (string) - Account number
- `account_type` (string) - Account type
- `balance` (decimal) - Current balance
- `currency` (string) - Account currency
- `created_at` / `updated_at` - Timestamps

#### Transactions
- `id` (UUID) - Primary key
- `user_bank_account_id` (UUID) - Foreign key to user bank accounts
- `description` (string) - Transaction description
- `amount` (decimal) - Transaction amount
- `currency` (string) - Transaction currency
- `posted_at` (datetime) - When transaction was posted
- `created_at` / `updated_at` - Timestamps

#### User Payments
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `amount` (decimal) - Payment amount
- `description` (string) - Payment description
- `payment_type` (string) - Payment type (TRANSFER/PAYMENT/DEPOSIT/WITHDRAWAL)
- `status` (string) - Payment status (PENDING/COMPLETED/FAILED/CANCELLED)
- `posted_at` (datetime) - When payment was posted
- `created_at` / `updated_at` - Timestamps

## 📚 API Endpoints

### Authentication
All API endpoints require authentication via JWT Bearer token.

### Health Check
- `GET /api/health` - Basic health check

### Accounts
- `GET /api/accounts` - List all accounts
- `GET /api/accounts/:id` - Get account details

### Transactions
- `GET /api/accounts/:id/transactions` - Get transactions for an account
  - Supports pagination: `?page=1&page_size=20`
  - Supports filtering: `?date_from=2025-01-01T00:00:00Z&date_to=2025-01-31T23:59:59Z`
  - Supports sorting: `?sort_by=posted_at&sort_order=desc`

## 🎭 Reusable Behaviours

The application uses behaviours to ensure consistent patterns across all modules:

### 1. Paginated
Handles pagination logic with validation and metadata generation.

### 2. Filterable  
Handles filtering logic with date range and field filtering.

### 3. Sortable
Handles sorting logic with field validation and query building.

### 4. ErrorHandler
Provides consistent error handling and response formatting.

### Usage Examples

#### Controllers
```elixir
defmodule LedgerBankApiWeb.BankingController do
  @behaviour LedgerBankApi.Behaviours.Paginated
  @behaviour LedgerBankApi.Behaviours.Filterable
  @behaviour LedgerBankApi.Behaviours.Sortable
  @behaviour LedgerBankApi.Behaviours.ErrorHandler

  @impl LedgerBankApi.Behaviours.Paginated
  def handle_paginated_data(conn, params, opts) do
    # Handle paginated request
  end
end
```

#### Context Modules
```elixir
defmodule LedgerBankApi.Banking do
  @behaviour LedgerBankApi.Behaviours.Filterable
  
  @impl LedgerBankApi.Behaviours.Filterable
  def handle_filtered_data(query, filters, opts) do
    # Apply filters to query
  end
end
```

## 🧪 Testing

The project has a comprehensive, well-organized test suite:

### Test Structure
```
test/
├── ledger_bank_api/
│   ├── behaviours/
│   │   ├── paginated/
│   │   │   ├── basic_test.exs      # Basic pagination functionality
│   │   │   └── advanced_test.exs   # Advanced pagination features
│   │   ├── filterable/
│   │   │   └── basic_test.exs      # Filtering functionality
│   │   ├── sortable/
│   │   │   └── basic_test.exs      # Sorting functionality
│   │   ├── error_handler/
│   │   │   └── basic_test.exs      # Error handling functionality
│   │   └── integration_test.exs    # Integration tests
│   └── [other unit tests]
├── ledger_bank_api_web/
│   └── controllers/
│       └── banking_controller_test.exs
└── support/
    └── conn_case.ex
```

### Running Tests

#### Method 1: Mix Aliases (Recommended)
```bash
# Run specific test groups
mix test:paginated      # Pagination tests only
mix test:filterable     # Filtering tests only
mix test:sortable       # Sorting tests only
mix test:error-handler  # Error handling tests only
mix test:behaviours     # All behaviour tests
mix test:controllers    # Controller tests only
mix test:integration    # Integration tests only
mix test:unit          # Unit tests only

# Run all tests
mix test
```

#### Method 2: Test Runner Script
```bash
# Use the custom test runner
elixir test/test_runner.exs pagination
elixir test/test_runner.exs behaviours
elixir test/test_runner.exs all
elixir test/test_runner.exs help
```

#### Method 3: Direct Mix Commands
```bash
# Run specific directories
mix test test/ledger_bank_api/behaviours/paginated/
mix test test/ledger_bank_api/behaviours/filterable/
mix test test/ledger_bank_api/behaviours/sortable/
mix test test/ledger_bank_api/behaviours/error_handler/

# Run specific files
mix test test/ledger_bank_api/behaviours/integration_test.exs
mix test test/ledger_bank_api_web/controllers/banking_controller_test.exs
```

### Test Categories

1. **Unit Tests** (`test/ledger_bank_api/`)
   - Test individual functions and modules
   - Fast and focused
   - No external dependencies

2. **Behaviour Tests** (`test/ledger_bank_api/behaviours/`)
   - Test the behaviour contracts and implementations
   - Ensure consistent interfaces across modules
   - Organized by functionality

3. **Integration Tests** (`test/ledger_bank_api/behaviours/integration_test.exs`)
   - Test how behaviours work together
   - End-to-end scenarios
   - Real-world usage patterns

4. **Controller Tests** (`test/ledger_bank_api_web/controllers/`)
   - Test HTTP endpoints
   - Request/response handling
   - Error scenarios

## 🔧 Configuration

### Environment Variables

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=ledger_bank_api_dev

# JWT Configuration
JWT_SECRET_KEY=your-secret-key-here

# Phoenix
SECRET_KEY_BASE=replace-me-with-mix-phx-gen-secret

# External mock service
BANK_BASE_URL=http://localhost:4001/mock
```

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

## 🔄 Background Jobs with Oban

The application uses **Oban** for reliable background job processing:

- **Payment Processing**: Processes pending payments
- **Notifications**: Sends payment completion notifications

### Job Queues

- `payments` - Payment processing jobs
- `notifications` - Notification jobs
- `default` - General background jobs

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

### Performance Monitoring

#### LiveDashboard
Access at `http://localhost:4000/dev/dashboard` in development mode.

#### Telemetry
The application includes built-in telemetry for monitoring:
- Database query performance
- API endpoint response times
- Memory usage

## 🔐 Security Notes

- **Development Mode**: Authentication is currently in development mode
- **Environment Variables**: Never commit `.env` files to version control
- **Database**: Use strong passwords in production
- **Secrets**: Generate proper secret keys for production

## 🚀 Deployment

### Production Setup

1. Set proper environment variables
2. Configure JWT secret key
3. Set up PostgreSQL database
4. Run migrations: `mix ecto.migrate`
5. Start the application: `mix phx.server`

### Docker Production

```bash
# Build and run with Docker Compose
docker-compose -f docker-compose.yml up -d
```

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

# Test specific categories
mix test:paginated         # Run pagination tests
mix test:behaviours        # Run all behaviour tests
mix test:controllers       # Run controller tests
```

## 📝 License

This project is licensed under the MIT License.

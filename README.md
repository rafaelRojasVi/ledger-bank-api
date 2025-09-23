# LedgerBankApi

> **Note:** For the latest updates and detailed changes, see [CHANGELOG.md](./CHANGELOG.md).

A modern Elixir/Phoenix API for banking and financial data management with clean architecture, comprehensive error handling, and OAuth2 integration. This API provides secure access to account information, transactions, and payment processing with built-in pagination, filtering, sorting, and robust error handling.

## 🚀 Features

- **JWT Authentication**: Secure authentication system with access and refresh tokens, user roles, and comprehensive token management
- **OAuth2 Integration**: Bank API integration with OAuth2 token management and refresh capabilities
- **Centralized Error Handling**: Unified error handling with canonical Error structs, error categories, and retry policies
- **Account Management**: Create and manage user bank accounts with balance tracking
- **Transaction Tracking**: Record and query financial transactions with pagination and filtering
- **Payment Processing**: Background job processing for payments using Oban workers
- **Bank Synchronization**: Automated bank data synchronization with external APIs
- **RESTful API**: Clean, REST-compliant endpoints with consistent error handling
- **PostgreSQL Database**: Robust data persistence with Ecto and comprehensive migrations
- **Docker Support**: Containerized deployment with Docker Compose
- **Background Jobs**: Oban for reliable background job processing
- **Comprehensive Testing**: Organized test suite with focused test categories
- **Migration Management**: Clean migration system with full database recreation capabilities

## 🏗️ Architecture

The application follows a clean architecture pattern with:

- **Core Layer**: Error handling, error catalog, and core business logic
- **Accounts Context**: User management, authentication, and authorization
- **Financial Context**: Banking operations, payments, and transactions
- **Web Layer**: Phoenix controllers, adapters, and error handling
- **Data Layer**: Ecto schemas, migrations, and PostgreSQL
- **Background Jobs**: Oban workers for payment processing and bank synchronization

### Core Modules

- `LedgerBankApi.Core` - Error handling, error catalog, and core business logic
- `LedgerBankApi.Accounts` - User management, authentication, and authorization
- `LedgerBankApi.Financial` - Banking operations, payments, and transactions
- `LedgerBankApiWeb` - Phoenix web layer with controllers and adapters
- `LedgerBankApi.Repo` - Database repository and migrations

## �� Prerequisites

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

#### Option A: Automated Setup (Recommended)
```bash
# Use the automated setup script
./test_setup.sh
```

#### Option B: Manual Setup
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

# Seed the database
mix run priv/repo/seeds.exs
```

### 4. Start Development Server

```bash
# Start Phoenix server
iex -S mix phx.server
```

### 5. Access the API

- **API**: http://localhost:4000
- **Health Check**: http://localhost:4000/api/health
- **User Stats**: http://localhost:4000/api/users/stats
- **LiveDashboard**: http://localhost:4000/dev/dashboard

## 🗄️ Database Schema

### Core Tables

#### Users
- `id` (UUID) - Primary key
- `email` (string) - User email (unique)
- `full_name` (string) - User's full name
- `status` (string) - User status (ACTIVE/SUSPENDED/DELETED)
- `role` (string) - User role (user/admin/support)
- `password_hash` (string) - Hashed password
- `active` (boolean) - Account active status
- `verified` (boolean) - Email verification status
- `suspended` (boolean) - Suspension status
- `deleted` (boolean) - Soft delete status
- `created_at` / `updated_at` - Timestamps

#### Banks
- `id` (UUID) - Primary key
- `name` (string) - Bank name
- `country` (string) - Country code
- `code` (string) - Bank code (unique)
- `logo_url` (string) - Bank logo URL
- `api_endpoint` (string) - Bank API endpoint
- `status` (string) - Bank status (ACTIVE/INACTIVE)
- `integration_module` (string) - Integration module name
- `created_at` / `updated_at` - Timestamps

#### Bank Branches
- `id` (UUID) - Primary key
- `bank_id` (UUID) - Foreign key to banks
- `name` (string) - Branch name
- `iban` (string) - IBAN code
- `country` (string) - Country code
- `routing_number` (string) - Routing number
- `swift_code` (string) - SWIFT code
- `created_at` / `updated_at` - Timestamps

#### User Bank Logins
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `bank_branch_id` (UUID) - Foreign key to bank branches
- `username` (string) - Bank username
- `status` (string) - Login status (ACTIVE/INACTIVE/ERROR)
- `last_sync_at` (datetime) - Last synchronization time
- `sync_frequency` (integer) - Sync frequency in seconds
- `access_token` (string) - OAuth2 access token
- `refresh_token` (string) - OAuth2 refresh token
- `token_expires_at` (datetime) - Token expiration time
- `scope` (string) - OAuth2 scopes
- `provider_user_id` (string) - Provider user ID
- `created_at` / `updated_at` - Timestamps

#### User Bank Accounts
- `id` (UUID) - Primary key
- `user_bank_login_id` (UUID) - Foreign key to user bank logins
- `user_id` (UUID) - Foreign key to users
- `currency` (string) - Account currency
- `account_type` (string) - Account type (CHECKING/SAVINGS/CREDIT/INVESTMENT)
- `balance` (decimal) - Current balance
- `last_four` (string) - Last four digits of account
- `account_name` (string) - Account name
- `status` (string) - Account status (ACTIVE/INACTIVE/CLOSED)
- `last_sync_at` (datetime) - Last synchronization time
- `external_account_id` (string) - External account ID
- `created_at` / `updated_at` - Timestamps

#### Transactions
- `id` (UUID) - Primary key
- `account_id` (UUID) - Foreign key to user bank accounts
- `user_id` (UUID) - Foreign key to users
- `description` (string) - Transaction description
- `amount` (decimal) - Transaction amount
- `direction` (string) - Transaction direction (CREDIT/DEBIT)
- `posted_at` (datetime) - When transaction was posted
- `created_at` / `updated_at` - Timestamps

#### User Payments
- `id` (UUID) - Primary key
- `user_bank_account_id` (UUID) - Foreign key to user bank accounts
- `user_id` (UUID) - Foreign key to users
- `amount` (decimal) - Payment amount
- `direction` (string) - Payment direction (CREDIT/DEBIT)
- `description` (string) - Payment description
- `payment_type` (string) - Payment type (TRANSFER/PAYMENT/DEPOSIT/WITHDRAWAL)
- `status` (string) - Payment status (PENDING/COMPLETED/FAILED/CANCELLED)
- `posted_at` (datetime) - When payment was posted
- `external_transaction_id` (string) - External transaction ID
- `created_at` / `updated_at` - Timestamps

#### Refresh Tokens
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to users
- `jti` (string) - JWT token identifier
- `expires_at` (datetime) - Token expiration time
- `revoked_at` (datetime) - Token revocation time
- `created_at` / `updated_at` - Timestamps

## 📚 API Endpoints

### Authentication
All API endpoints require authentication via JWT Bearer token.

### Health Check
- `GET /api/health` - Basic health check

### Users
- `GET /api/users` - List all users (with pagination, filtering, sorting)
- `GET /api/users/:id` - Get user details
- `POST /api/users` - Create a new user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user
- `GET /api/users/stats` - Get user statistics

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - User logout

## 🔄 Migration Management

The application includes a comprehensive migration system with full database recreation capabilities:

### Migration Recreation Process

When you need to completely rebuild your database schema:

```bash
# 1. Drop the database
mix ecto.drop

# 2. Delete all migration files (keep the directory)
rm priv/repo/migrations/*.exs

# 3. Create new migrations
mix ecto.gen.migration create_users
mix ecto.gen.migration create_banks
mix ecto.gen.migration create_bank_branches
mix ecto.gen.migration create_user_bank_logins
mix ecto.gen.migration create_user_bank_accounts
mix ecto.gen.migration create_user_payments
mix ecto.gen.migration create_transactions
mix ecto.gen.migration create_refresh_tokens
mix ecto.gen.migration create_oban_jobs
mix ecto.gen.migration add_data_integrity_constraints

# 4. Recreate and migrate
mix ecto.create
mix ecto.migrate

# 5. Seed the database
mix run priv/repo/seeds.exs
```

### Automated Setup

Use the `test_setup.sh` script for automated setup:

```bash
# This script handles:
# - Dropping and recreating databases
# - Running all migrations
# - Seeding development database
# - Starting Docker containers
# - Clearing cache
./test_setup.sh
```

## 🎭 Error Handling System

The application uses a comprehensive error handling system:

### Error Categories
- `:validation` - Input validation failures (400)
- `:not_found` - Resource not found (404)
- `:authentication` - Authentication failures (401)
- `:authorization` - Authorization failures (403)
- `:conflict` - Resource conflicts (409)
- `:business_rule` - Business logic violations (422)
- `:external_dependency` - External service failures (503)
- `:system` - Internal system errors (500)

### Error Policy Matrix
| Category | Retryable | Circuit Breaker | Max Retries | Retry Delay |
|----------|-----------|-----------------|-------------|-------------|
| validation | No | No | 0 | 0ms |
| not_found | No | No | 0 | 0ms |
| authentication | No | No | 0 | 0ms |
| authorization | No | No | 0 | 0ms |
| conflict | No | No | 0 | 0ms |
| business_rule | No | No | 0 | 0ms |
| external_dependency | Yes | Yes | 3 | 1000ms |
| system | Yes | Yes | 2 | 500ms |

## 🧪 Testing

The project has a comprehensive, well-organized test suite:

### Running Tests

```bash
# Run all tests
mix test

# Run specific test categories
mix test test/ledger_bank_api/accounts/
mix test test/ledger_bank_api/financial/
mix test test/ledger_bank_api/core/
mix test test/ledger_bank_api_web/
```

## �� Configuration

### Environment Variables

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=ledger_bank_api_dev

# JWT Configuration
JWT_SECRET=your-secret-key-here-must-be-at-least-32-characters

# Phoenix
SECRET_KEY_BASE=replace-me-with-mix-phx-gen-secret

# External bank API
MONZO_CLIENT_ID=your-monzo-client-id
MONZO_CLIENT_SECRET=your-monzo-client-secret
MONZO_API_URL=https://api.monzo.com
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
curl -H "Authorization: Bearer your-token" http://localhost:4000/api/health
```

## �� Background Jobs with Oban

The application uses **Oban** for reliable background job processing:

### Job Queues
- `payments` - Payment processing jobs
- `banking` - Bank synchronization jobs
- `default` - General background jobs

### Workers
- `PaymentWorker` - Processes user payments
- `BankSyncWorker` - Synchronizes bank data

## 🚨 Troubleshooting

### Database Issues

1. **Reset Database**:
   ```bash
   mix ecto.reset
   ```

2. **Recreate Migrations**:
   ```bash
   # Use the automated setup script
   ./test_setup.sh
   ```

3. **Check Database Connection**:
   ```bash
   # From WSL
   pg_isready -h localhost -p 5432 -U postgres
   ```

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

# Seed database
mix run priv/repo/seeds.exs
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
- Error tracking

## 🔐 Security Notes

- **JWT Secret**: Must be at least 32 characters long
- **Environment Variables**: Never commit `.env` files to version control
- **Database**: Use strong passwords in production
- **OAuth2**: Secure token storage and refresh mechanisms
- **Password Requirements**: Minimum 8 characters for regular users, 15 characters for admin accounts (NIST 2024 standards)

## 🚀 Deployment

### Production Setup

1. Set proper environment variables
2. Configure JWT secret key (minimum 32 characters)
3. Set up PostgreSQL database
4. Run migrations: `mix ecto.migrate`
5. Seed database: `mix run priv/repo/seeds.exs`
6. Start the application: `mix phx.server`

### Docker Production

```bash
# Build and run with Docker Compose
docker-compose -f docker-compose.yml up -d
```

## 🚀 Quick Commands Reference

```bash
# Complete development setup
./test_setup.sh
iex -S mix phx.server

# Or manual setup
cp env.example .env
docker-compose up -d db
mix ecto.migrate
mix run priv/repo/seeds.exs
iex -S mix phx.server

# Common development tasks
mix test                    # Run tests
mix ecto.migrate           # Run migrations
mix ecto.reset             # Reset database
mix run priv/repo/seeds.exs # Seed database
docker-compose logs -f     # View logs
mix phx.routes             # Show routes

# Database recreation
mix ecto.drop
rm priv/repo/migrations/*.exs
# Create new migrations...
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

## 📝 License

This project is licensed under the MIT License.
# LedgerBankApi

A high-performance Elixir/Phoenix API for banking and financial data management. This API provides real-time access to account information, transactions, and live snapshots from external banking systems.

## 🚀 Features

- **Real-time Banking Data**: Fetch account balances, transactions, and live snapshots
- **Parallel Data Fetching**: Efficient fan-out pattern for concurrent API calls
- **RESTful API**: Clean, REST-compliant endpoints
- **PostgreSQL Database**: Robust data persistence with Ecto
- **Docker Support**: Containerized deployment with Docker Compose
- **Performance Monitoring**: Built-in benchmarking and telemetry
- **Authentication**: Client authentication system (currently in development mode)

## 🏗️ Architecture

The application follows a clean architecture pattern with:

- **Contexts**: Banking context for business logic
- **External Services**: Bank client for external API integration
- **Web Layer**: Phoenix controllers and JSON views
- **Data Layer**: Ecto schemas and PostgreSQL

### Core Modules

- `LedgerBankApi.Banking` - Main business logic for accounts and transactions
- `LedgerBankApi.External.BankClient` - External banking API integration
- `LedgerBankApi.Banking.Fetcher` - Parallel data fetching with fan-out pattern
- `LedgerBankApiWeb` - Phoenix web layer with controllers and JSON views

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

### 2. Configure Environment

```bash
# Copy environment template
cp env.example .env

# Edit .env with your values
# (See DEVELOPMENT.md for detailed setup)
```

### 3. Start Database

```bash
# Start PostgreSQL in Docker
docker-compose up -d db
```

### 4. Run Migrations

```bash
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

### 5. Start Development Server

```bash
# Start Phoenix server
iex -S mix phx.server
```

### 6. Access the API

- **API**: http://localhost:4000
- **LiveDashboard**: http://localhost:4000/dev/dashboard
- **Mailbox Preview**: http://localhost:4000/dev/mailbox

## 🗄️ Database Architecture

### One PostgreSQL, Everywhere

This project uses a **single PostgreSQL database** that serves all environments:

- **Development**: Host tools (WSL) reach it via `localhost:5432`
- **Docker**: Containers reach it via Docker DNS name `db:5432`
- **CI/CD**: GitHub Actions uses `localhost:5432` (service container)

### Database Schema

#### Accounts
- `id` (UUID) - Primary key
- `user_id` (UUID) - User identifier
- `institution` (string) - Bank institution name
- `type` (string) - Account type
- `last4` (string) - Last 4 digits of account
- `balance` (decimal) - Current balance
- `inserted_at` / `updated_at` - Timestamps

#### Transactions
- `id` (UUID) - Primary key
- `account_id` (UUID) - Foreign key to accounts
- `description` (string) - Transaction description
- `amount` (decimal) - Transaction amount
- `posted_at` (datetime) - When transaction was posted
- `inserted_at` / `updated_at` - Timestamps

## 📚 API Endpoints

### Authentication
All API endpoints require authentication. Currently using a development token.

### Accounts
- `GET /api/accounts` - List all accounts
- `GET /api/accounts/:id` - Get account details

### Transactions
- `GET /api/accounts/:id/transactions` - Get transactions for an account

### Live Snapshots
- `GET /api/enrollments/:id/live_snapshot` - Get real-time banking data snapshot

## 🔧 Configuration

### Environment Variables

The application uses environment variables for configuration. Copy `env.example` to `.env` and customize:

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

### Development Configuration

The application includes development-specific features:
- LiveDashboard at `/dev/dashboard`
- Swoosh mailbox preview at `/dev/mailbox`

## 🐳 Docker Deployment

### Full Stack (Database + API)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Database Only (for development)

```bash
# Start only PostgreSQL
docker-compose up -d db

# Run migrations from host
mix ecto.migrate
```

## 🧪 Testing

```bash
# Run test suite
mix test

# Run with coverage
mix test --cover
```

## 📊 Performance & Benchmarking

```bash
# Run banking benchmarks
mix bench

# Run endpoint benchmarks
mix bench:endpt

# Run CI benchmarks
mix bench:ci
```

## 🔍 Development Tools

### Database Management
```bash
# Create and migrate database
mix ecto.setup

# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate
```

### Interactive Shell
```bash
# Start with Phoenix server
iex -S mix phx.server

# Start without Phoenix
iex -S mix
```

## 📈 Monitoring

- **LiveDashboard**: Available at `/dev/dashboard` in development
- **Telemetry**: Built-in metrics collection
- **Health Checks**: Database health monitoring in Docker

## 🔐 Security

- Client authentication system (currently in development mode)
- Secure database connections
- Environment-based configuration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions:
- Check the [Phoenix documentation](https://hexdocs.pm/phoenix)
- Visit the [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
- Review the [Phoenix guides](https://hexdocs.pm/phoenix/overview.html)

---

**Ready for production?** Check the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for production deployment instructions.

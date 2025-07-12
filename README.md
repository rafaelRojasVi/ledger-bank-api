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
- PostgreSQL 16+
- Docker & Docker Compose (for containerized deployment)

## 🛠️ Installation & Setup

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ledger_bank_api
   ```

2. **Install dependencies and setup database**
   ```bash
   mix setup
   ```

3. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

4. **Visit the application**
   Open [http://localhost:4000](http://localhost:4000) in your browser.

### Docker Deployment

1. **Start the services**
   ```bash
   docker-compose up -d
   ```

2. **Access the application**
   The API will be available at `http://localhost:4000`

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

## 🗄️ Database Schema

### Accounts
- `id` (UUID) - Primary key
- `user_id` (UUID) - User identifier
- `institution` (string) - Bank institution name
- `type` (string) - Account type
- `last4` (string) - Last 4 digits of account
- `balance` (decimal) - Current balance
- `inserted_at` / `updated_at` - Timestamps

### Transactions
- `id` (UUID) - Primary key
- `account_id` (UUID) - Foreign key to accounts
- `description` (string) - Transaction description
- `amount` (decimal) - Transaction amount
- `posted_at` (datetime) - When transaction was posted
- `inserted_at` / `updated_at` - Timestamps

## 🔧 Configuration

### Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key base
- `BANK_BASE_URL` - External banking API base URL

### Development Configuration

The application includes development-specific features:
- LiveDashboard at `/dev/dashboard`
- Swoosh mailbox preview at `/dev/mailbox`

## 🧪 Testing

Run the test suite:
```bash
mix test
```

## 📊 Performance & Benchmarking

The project includes comprehensive benchmarking:

```bash
# Run banking benchmarks
mix bench

# Run endpoint benchmarks
mix bench:endpt

# Run CI benchmarks
mix bench:ci
```

## 🐳 Docker

### Building the Image
```bash
docker build -t ledger-bank-api .
```

### Running with Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
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

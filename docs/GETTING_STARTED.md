# 🚀 Getting Started with LedgerBank API

This guide will get you up and running with LedgerBank API in under 10 minutes.

## 📋 **Prerequisites**

- **Elixir 1.18+** and **Erlang/OTP 26+**
- **PostgreSQL 16+**
- **Docker & Docker Compose** (optional, for containerized setup)
- **Git**

### **Installation Check**

```bash
# Check versions
elixir --version  # Should be 1.18+
mix --version     # Should be 1.18+
psql --version    # Should be 16+
docker --version  # Optional
```

## ⚡ **Quick Setup (5 minutes)**

### **Option 1: Automated Setup (Recommended)**

```bash
# Clone the repository
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api

# Run the setup script (handles everything)
./test_setup.sh

# Start the server
mix phx.server
```

**That's it!** Your API is running at `http://localhost:4000`

### **Option 2: Manual Setup**

```bash
# 1. Clone and install dependencies
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api
mix deps.get

# 2. Setup database
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# 3. Start server
mix phx.server
```

### **Option 3: Docker Setup**

```bash
# Clone and start with Docker
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api
docker compose up -d

# Wait for services to start (30 seconds)
# API available at http://localhost:4000
```

## 🧪 **Verify Installation**

### **1. Health Check**

```bash
curl http://localhost:4000/api/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "uptime": 12345
}
```

### **2. API Documentation**

Open your browser: **http://localhost:4000/api/docs**

You should see:
- 📖 Interactive Swagger UI
- 🔐 "Authorize" button for JWT authentication
- 📋 "Try it out" buttons for testing endpoints

### **3. Test Authentication**

```bash
# Create a user
curl -X POST http://localhost:4000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "full_name": "Test User",
    "password": "password123",
    "password_confirmation": "password123"
  }'

# Login
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

## 🎯 **First Steps**

### **1. Explore the API**

Visit **http://localhost:4000/api/docs** and try:
- `GET /api/health` - Service status
- `POST /api/auth/login` - User authentication
- `GET /api/auth/me` - Get current user (requires JWT)

### **2. Run Tests**

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/ledger_bank_api/accounts/user_service_test.exs
```

### **3. Check Logs**

```bash
# View application logs
tail -f log/dev.log

# Or with Docker
docker compose logs -f web
```

## 🔧 **Configuration**

### **Environment Variables**

Create `.env` file (optional):

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=ledger_bank_api_dev

# JWT Secret (generate with: mix phx.gen.secret 64)
JWT_SECRET=your-64-character-secret-here

# Optional: External APIs
MONZO_CLIENT_ID=your_client_id
MONZO_CLIENT_SECRET=your_client_secret
```

### **Database Configuration**

Default database settings in `config/dev.exs`:

```elixir
config :ledger_bank_api, LedgerBankApi.Repo,
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "ledger_bank_api_dev",
  pool_size: 10
```

## 🐛 **Troubleshooting**

### **Common Issues**

#### **"Port 4000 already in use"**

```bash
# Find and kill process using port 4000
lsof -ti:4000 | xargs kill -9

# Or use different port
PORT=4001 mix phx.server
```

#### **"Database does not exist"**

```bash
# Create database
mix ecto.create

# Or reset everything
mix ecto.reset
```

#### **"JWT_SECRET not configured"**

```bash
# Generate secret
JWT_SECRET=$(mix phx.gen.secret 64)

# Export for current session
export JWT_SECRET

# Or add to .env file
echo "JWT_SECRET=$JWT_SECRET" >> .env
```

#### **"Dependencies not found"**

```bash
# Clean and reinstall
mix deps.clean --all
mix deps.get
mix deps.compile
```

### **Docker Issues**

#### **"Container won't start"**

```bash
# Check logs
docker compose logs web

# Rebuild containers
docker compose down
docker compose build --no-cache
docker compose up -d
```

#### **"Database connection refused"**

```bash
# Wait for database to be ready
docker compose logs db

# Check database health
docker compose exec db pg_isready -U postgres
```

## 📚 **Next Steps**

### **For Developers**

1. **Read the Architecture Guide** - [docs/ARCHITECTURE.md](ARCHITECTURE.md)
2. **Explore the API** - [docs/API_REFERENCE.md](API_REFERENCE.md)
3. **Check the Developer Guide** - [docs/DEVELOPER.md](DEVELOPER.md)

### **For Deployment**

1. **Follow Deployment Guide** - [docs/DEPLOYMENT.md](DEPLOYMENT.md)
2. **Configure Production** - Environment variables and secrets
3. **Setup Monitoring** - Health checks and logging

### **For Testing**

1. **Run Test Suite** - `mix test`
2. **Read Testing Guide** - [docs/TESTING.md](TESTING.md)
3. **Add Your Tests** - Follow existing patterns

## 🆘 **Getting Help**

### **Documentation**

- **API Reference** - Complete endpoint documentation
- **Architecture Guide** - System design and patterns
- **Developer Guide** - Code conventions and workflows

### **Community**

- **GitHub Issues** - Bug reports and feature requests
- **Email Support** - rafarojasv6@gmail.com

### **Debugging**

```bash
# Start IEx with the app loaded
iex -S mix

# Useful IEx commands
iex> h LedgerBankApi.Accounts.UserService  # Get help
iex> LedgerBankApi.Repo.all(LedgerBankApi.Accounts.Schemas.User)  # Query DB
iex> LedgerBankApi.Core.Cache.stats()  # Check cache
```

---

**Ready to dive deeper?** Check out the [Architecture Guide](ARCHITECTURE.md) to understand how the system works!

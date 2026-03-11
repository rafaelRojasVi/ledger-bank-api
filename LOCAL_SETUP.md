# 🚀 Local Setup Guide

Quick guide to run LedgerBank API locally on your machine (Windows/WSL/Linux/Mac).

## ⚡ **Quick Start (Recommended - 2 minutes)**

### **Option 1: Docker Compose (Easiest)**

```bash
# 1. Start database and Redis
docker compose up -d db redis

# 2. Wait for services to be ready (10-15 seconds)
docker compose ps

# 3. Install dependencies
mix deps.get

# 4. Setup database
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# 5. Start the server
mix phx.server
```

**✅ API will be running at:** `http://localhost:4000`

---

## 🔧 **Option 2: Manual Setup (WSL/Linux/Mac)**

### **Prerequisites Check**

```bash
# Check if you have everything
elixir --version  # Should be 1.18+
mix --version     # Should be 1.18+
psql --version    # Should be 16+ (or use Docker)
docker --version  # For Redis/PostgreSQL
```

### **Step-by-Step Setup**

#### **1. Start Services (PostgreSQL + Redis)**

```bash
# Using Docker Compose (recommended)
docker compose up -d db redis

# OR manually with Docker
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=ledger_bank_api_dev \
  -p 5432:5432 \
  postgres:16

docker run -d --name redis \
  -p 6379:6379 \
  redis:7-alpine
```

#### **2. Install Dependencies**

```bash
# Get all Elixir dependencies
mix deps.get

# Compile the project
mix compile
```

#### **3. Setup Database**

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Seed initial data (optional)
mix run priv/repo/seeds.exs
```

#### **4. Set Environment Variables**

```bash
# Create .env file (optional)
cat > .env << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=ledger_bank_api_dev
JWT_SECRET=test-secret-key-for-testing-only-must-be-64-chars-long
REDIS_URL=redis://localhost:6379
EOF

# Load environment variables (Linux/Mac/WSL)
export $(cat .env | xargs)

# Or set individually
export JWT_SECRET="test-secret-key-for-testing-only-must-be-64-chars-long"
export REDIS_URL="redis://localhost:6379"
```

#### **5. Start the Server**

```bash
# Start Phoenix server
mix phx.server
```

**✅ Server running at:** `http://localhost:4000`

---

## 🧪 **Test the New Features**

### **1. Test with Default ETS Cache (Single-Node)**

```bash
# Default - uses ETS adapter
mix phx.server

# Test cache
curl http://localhost:4000/api/health
```

### **2. Test with Redis Cache (Multi-Node Ready)**

```bash
# Set environment variable to use Redis
export CACHE_ADAPTER=redis
export REDIS_URL=redis://localhost:6379

# Restart server
mix phx.server

# Test cache (should use Redis now)
curl http://localhost:4000/api/health
```

### **3. Verify Redis Adapter is Working**

```bash
# In another terminal, connect to Redis
docker compose exec redis redis-cli

# Inside redis-cli:
KEYS ledger_cache:*
# Should show cached keys if you've made API calls
```

---

## 🎯 **Quick Test Commands**

### **1. Health Check**

```bash
curl http://localhost:4000/api/health
```

### **2. Login (Get JWT Token)**

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "password123"
  }'
```

**Copy the `access_token` from response**

### **3. Get User Profile (Requires Token)**

```bash
# Replace YOUR_TOKEN with the token from step 2
curl http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### **4. View API Documentation**

Open in browser: **http://localhost:4000/api/docs**

---

## 🧪 **Run Tests**

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ledger_bank_api/core/cache/redis_adapter_test.exs

# Run with coverage
mix test --cover
```

---

## 🔍 **Verify Everything Works**

### **Check Services**

```bash
# Check Docker containers
docker compose ps

# Should show:
# - db (healthy)
# - redis (healthy)
```

### **Check Application Logs**

```bash
# View logs
docker compose logs -f web

# Or if running locally
# Logs appear in terminal where you ran `mix phx.server`
```

### **Test Cache Adapter**

```bash
# Start IEx console
iex -S mix

# In IEx:
# Check which adapter is active
Application.get_env(:ledger_bank_api, :cache_adapter)

# Test cache
LedgerBankApi.Core.Cache.put("test_key", %{test: "value"})
LedgerBankApi.Core.Cache.get("test_key")

# Check cache stats
LedgerBankApi.Core.Cache.stats()
```

---

## 🐛 **Troubleshooting**

### **"Port 4000 already in use"**

```bash
# Find what's using port 4000
# Linux/Mac/WSL:
lsof -ti:4000 | xargs kill -9

# Windows PowerShell:
Get-NetTCPConnection -LocalPort 4000 | Select-Object -ExpandProperty OwningProcess | ForEach-Object { Stop-Process -Id $_ }

# Or use different port
PORT=4001 mix phx.server
```

### **"Database connection refused"**

```bash
# Check if PostgreSQL is running
docker compose ps db

# Check PostgreSQL logs
docker compose logs db

# Restart database
docker compose restart db
```

### **"Redis connection failed"**

```bash
# Check if Redis is running
docker compose ps redis

# Test Redis connection
docker compose exec redis redis-cli ping
# Should return: PONG

# Check Redis logs
docker compose logs redis
```

### **"JWT_SECRET not configured"**

```bash
# Set JWT_SECRET
export JWT_SECRET="test-secret-key-for-testing-only-must-be-64-chars-long"

# Or add to .env file
echo 'JWT_SECRET=test-secret-key-for-testing-only-must-be-64-chars-long' >> .env
```

### **"Mix compile errors"**

```bash
# Clean and rebuild
mix clean
mix deps.get
mix compile
```

---

## 📊 **What's Running?**

After setup, you'll have:

- ✅ **Phoenix Server** - `http://localhost:4000`
- ✅ **PostgreSQL** - `localhost:5432`
- ✅ **Redis** - `localhost:6379`
- ✅ **API Docs** - `http://localhost:4000/api/docs`

---

## 🎓 **Next Steps**

1. **Explore API Docs** - Visit `http://localhost:4000/api/docs`
2. **Run Tests** - `mix test`
3. **Read Architecture** - `docs/ARCHITECTURE.md`
4. **Test Redis Adapter** - Set `CACHE_ADAPTER=redis` and restart

---

## 💡 **Pro Tips**

### **WSL Users**

```bash
# If using WSL, you can access Windows Docker
# Make sure Docker Desktop is running on Windows

# Check Docker is accessible
docker ps

# If not, start Docker Desktop on Windows
```

### **Development Workflow**

```bash
# Terminal 1: Run server
mix phx.server

# Terminal 2: Run tests
mix test --watch

# Terminal 3: IEx console for debugging
iex -S mix
```

### **Quick Reset**

```bash
# Reset everything (database + cache)
mix ecto.reset
docker compose restart redis
```

---

**Happy coding! 🚀**



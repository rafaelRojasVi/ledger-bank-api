# 🚀 Deployment Guide

This guide covers deploying LedgerBank API to various platforms for your portfolio.

**⚠️ Important:** This is a learning project. Deploy for demonstration purposes only, not for handling real financial data.

---

## 📋 Table of Contents

- [Quick Deploy Options](#-quick-deploy-options)
- [Render.com (Free, Easiest)](#rendercom-free-easiest)
- [Fly.io (Free, Fast)](#flyio-free-fast)
- [Railway.app (Simple)](#railwayapp-simple)
- [Docker Self-Hosted](#-docker-self-hosted)
- [Environment Variables](#-environment-variables)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Quick Deploy Options

| Platform | Difficulty | Cost | Best For | Time to Deploy |
|----------|------------|------|----------|----------------|
| **Render.com** | ⭐ Easy | Free tier | Portfolio demos | 10 minutes |
| **Fly.io** | ⭐⭐ Medium | Free tier ($5/mo credits) | Fast global edge | 15 minutes |
| **Railway.app** | ⭐ Easy | $5/mo after trial | Simple UI | 10 minutes |
| **Heroku** | ⭐ Easy | ~$10/mo | Quick prototypes | 10 minutes |
| **DigitalOcean** | ⭐⭐⭐ Hard | $6-12/mo | Full control | 60 minutes |

**Recommendation for Portfolio:** Use **Render.com** (free tier) or **Fly.io** (free credits).

---

## 🟢 Render.com (Free, Easiest)

Perfect for portfolios. Free tier includes:
- ✅ 750 hours/month (enough for demos)
- ✅ Managed PostgreSQL database (90-day free trial)
- ✅ Automatic deploys from GitHub
- ✅ SSL certificates (HTTPS)
- ✅ Health check monitoring

### **Step-by-Step Guide**

#### 1. Prepare Your Repository

Ensure your code is pushed to GitHub:

```bash
git add .
git commit -m "Portfolio-ready banking API"
git push origin main
```

#### 2. Create Render Account

1. Go to [Render.com](https://render.com)
2. Sign up with GitHub
3. Authorize Render to access your repository

#### 3. Create PostgreSQL Database

1. Click **New** → **PostgreSQL**
2. Configure:
   - **Name:** `ledger-bank-api-db`
   - **Database:** `ledger_bank_api_prod`
   - **User:** `postgres` (default)
   - **Region:** Choose closest to you
   - **Plan:** Free (500 MB storage, 1 connection)
3. Click **Create Database**
4. Wait ~2 minutes for provisioning
5. Copy the **Internal Database URL** (starts with `postgres://`)

#### 4. Create Web Service

1. Click **New** → **Web Service**
2. Connect your GitHub repository: `ledger-bank-api`
3. Configure:

**Basic Settings:**
```
Name: ledger-bank-api
Region: Same as database
Branch: main
Root Directory: (leave blank)
Runtime: Docker
```

**Build Command:**
```bash
# Render auto-detects Dockerfile, leave blank
```

**Start Command:**
```bash
# Render auto-starts with your Dockerfile CMD
# No changes needed if using our Dockerfile
```

#### 5. Add Environment Variables

In the **Environment** tab, add these variables:

**Required Variables:**
```bash
# Application
MIX_ENV=prod
PHX_SERVER=true
PHX_HOST=your-app-name.onrender.com  # Replace with your Render URL
PORT=4000

# Database (from Step 3)
DATABASE_URL=<paste_internal_database_url_from_step_3>

# JWT Secret (generate new for production)
JWT_SECRET=<generate_with_mix_phx_gen_secret_64_chars>

# Phoenix Secret (generate new)
SECRET_KEY_BASE=<generate_with_mix_phx_gen_secret>

# Oban Queues (optional, defaults work)
OBAN_QUEUES=banking:3,payments:2,notifications:3,default:1
```

**Generate Secrets:**
```bash
# On your local machine:
mix phx.gen.secret 64  # For JWT_SECRET
mix phx.gen.secret     # For SECRET_KEY_BASE
```

#### 6. Deploy

1. Click **Create Web Service**
2. Render will:
   - Clone your repository
   - Build Docker image (takes ~5 minutes first time)
   - Run database migrations (via `docker/entrypoint.sh`)
   - Start the application
3. Monitor build logs in Render dashboard

#### 7. Verify Deployment

Once deployed (status shows "Live"), test your API:

```bash
# Health check
curl https://your-app-name.onrender.com/api/health

# Expected:
# {"status":"ok","timestamp":"...","version":"1.0.0","uptime":...}

# Test Problem Registry (new RFC 9457 feature)
curl https://your-app-name.onrender.com/api/problems

# View API docs in browser
https://your-app-name.onrender.com/api/docs
```

#### 8. Seed Initial Data

If you want demo data:

```bash
# Run seeds via Render Shell (Dashboard → Shell tab)
/app/ledger_bank_api/bin/ledger_bank_api eval "Mix.Tasks.Run.run(['priv/repo/seeds.exs'])"
```

Or create users via API:

```bash
# Create admin user
curl -X POST https://your-app-name.onrender.com/api/users/admin \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <admin_token>" \
  -d '{
    "email": "admin@example.com",
    "full_name": "Admin User",
    "password": "admin123456789!",
    "password_confirmation": "admin123456789!",
    "role": "admin"
  }'
```

#### 9. Update Your README

Add this to your README:

```markdown
## 🌐 Live Demo

**API Base URL:** https://your-app-name.onrender.com/api

**Interactive Docs:** https://your-app-name.onrender.com/api/docs

Try it:
```bash
curl https://your-app-name.onrender.com/api/health
```
```

### Render.com Notes

**Pros:**
- ✅ Free tier perfect for portfolios
- ✅ Automatic deploys on git push
- ✅ Managed database with backups
- ✅ SSL/HTTPS included
- ✅ Simple web UI

**Cons:**
- ⚠️ Free tier spins down after 15 minutes of inactivity (cold starts ~30 seconds)
- ⚠️ Database is free for 90 days, then $7/month
- ⚠️ Limited to 512 MB RAM on free tier

**Optimization Tips:**
- Use a cron job to ping `/api/health` every 10 minutes to keep it warm
- Enable "Auto-Deploy" for automatic updates on git push
- Set up health check URL: `/api/health/ready`

---

## 🪽 Fly.io (Free, Fast)

Fly.io offers $5/month free credits and runs on global edge locations.

### **Step-by-Step Guide**

#### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
iwr https://fly.io/install.ps1 -useb | iex
```

#### 2. Authenticate

```bash
flyctl auth login
```

#### 3. Create Fly.toml Configuration

Create `fly.toml` in your project root:

```toml
app = "ledger-bank-api"  # Must be globally unique
primary_region = "sjc"   # San Jose, CA (change to nearest)

[build]

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  
[http_service.concurrency]
  type = "connections"
  soft_limit = 200
  hard_limit = 250

[[services]]
  protocol = "tcp"
  internal_port = 4000
  processes = ["app"]

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 250
    soft_limit = 200

[[services.tcp_checks]]
  interval = "15s"
  timeout = "2s"
  grace_period = "5s"
  restart_limit = 0

[[services.http_checks]]
  interval = 10000
  grace_period = "5s"
  method = "get"
  path = "/api/health/ready"
  protocol = "http"
  timeout = 2000
  tls_skip_verify = false

[env]
  MIX_ENV = "prod"
  PHX_SERVER = "true"
  PORT = "4000"
```

#### 4. Create PostgreSQL Database

```bash
# Create Postgres cluster
flyctl postgres create \
  --name ledger-bank-api-db \
  --region sjc \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --volume-size 1

# Attach database to app
flyctl postgres attach ledger-bank-api-db --app ledger-bank-api
```

This automatically sets `DATABASE_URL` in your app.

#### 5. Set Secrets

```bash
# Generate secrets
JWT_SECRET=$(mix phx.gen.secret 64)
SECRET_KEY_BASE=$(mix phx.gen.secret)

# Set in Fly
flyctl secrets set \
  JWT_SECRET="$JWT_SECRET" \
  SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  --app ledger-bank-api
```

#### 6. Deploy

```bash
# Launch (first deploy)
flyctl launch --no-deploy  # Answer prompts
flyctl deploy              # Actually deploy

# View logs
flyctl logs

# Open in browser
flyctl open
```

#### 7. Run Migrations

```bash
# SSH into the app
flyctl ssh console --app ledger-bank-api

# Run migrations
/app/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"

# Exit
exit
```

#### 8. Verify

```bash
curl https://ledger-bank-api.fly.dev/api/health
```

### Fly.io Notes

**Pros:**
- ✅ Global edge locations (low latency worldwide)
- ✅ Auto-scaling to zero (save credits)
- ✅ Better performance than Render
- ✅ Good free tier ($5/month credits)

**Cons:**
- ⚠️ CLI-focused (less UI than Render)
- ⚠️ Credit card required (even for free tier)
- ⚠️ More complex configuration

---

## 🚂 Railway.app (Simple)

Railway offers the simplest deployment experience.

### **Quick Start**

#### 1. Install Railway CLI

```bash
npm install -g @railway/cli
railway login
```

#### 2. Initialize Project

```bash
# In your project directory
railway init
```

#### 3. Add PostgreSQL

```bash
railway add postgresql
```

#### 4. Set Environment Variables

```bash
railway variables set \
  MIX_ENV=prod \
  PHX_SERVER=true \
  JWT_SECRET="$(mix phx.gen.secret 64)" \
  SECRET_KEY_BASE="$(mix phx.gen.secret)"
```

#### 5. Deploy

```bash
railway up
```

#### 6. Get Your URL

```bash
railway domain
```

Railway automatically:
- Detects Dockerfile
- Builds and deploys
- Runs migrations (via entrypoint.sh)
- Provides HTTPS domain

---

## 🐳 Docker Self-Hosted

Deploy on your own VPS (DigitalOcean, AWS EC2, Linode, etc.)

### **Prerequisites**

- Ubuntu 22.04 LTS server
- Docker & Docker Compose installed
- Domain name pointed to your server (optional but recommended)
- SSH access to server

### **Step-by-Step Guide**

#### 1. Connect to Your Server

```bash
ssh user@your-server-ip
```

#### 2. Install Docker

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get install docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

#### 3. Clone Repository

```bash
# Clone your project
git clone https://github.com/rafaelRojasVi/ledger-bank-api.git
cd ledger-bank-api
```

#### 4. Create Production Environment File

```bash
# Create .env.production
cat > .env.production << 'EOF'
# Application
MIX_ENV=prod
PHX_SERVER=true
PHX_HOST=yourdomain.com
PORT=4000

# Database
DB_HOST=db
DB_PORT=5432
DB_USER=postgres
DB_PASS=<your_strong_password>
DB_NAME=ledger_bank_api_prod

# Secrets (generate these!)
SECRET_KEY_BASE=<generate_with_mix_phx_gen_secret>
JWT_SECRET=<generate_with_mix_phx_gen_secret_64_chars>

# Oban Configuration
OBAN_QUEUES=banking:3,payments:2,notifications:3,default:1

# Optional: External APIs
MONZO_CLIENT_ID=your_client_id
MONZO_CLIENT_SECRET=your_client_secret
EOF
```

#### 5. Update docker-compose.yml for Production

Create `docker-compose.prod.yml`:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  web:
    build: .
    env_file: .env.production
    environment:
      DATABASE_URL: ecto://${DB_USER}:${DB_PASS}@db:5432/${DB_NAME}
      PGHOST: db
      PGPORT: 5432
      PGUSER: ${DB_USER}
      PGPASSWORD: ${DB_PASS}
    ports:
      - "4000:4000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/api/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:
```

#### 6. Deploy

```bash
# Build and start services
docker compose -f docker-compose.prod.yml up -d --build

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Check health
curl http://localhost:4000/api/health
```

#### 7. Setup Nginx (Optional but Recommended)

If you want to serve on port 80/443 with SSL:

```bash
# Install Nginx
sudo apt-get install nginx certbot python3-certbot-nginx

# Create Nginx config
sudo nano /etc/nginx/sites-available/ledger-bank-api
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Enable site:**
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/ledger-bank-api /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com

# Auto-renewal
sudo certbot renew --dry-run
```

#### 8. Setup Firewall

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow SSH (if not already)
sudo ufw allow 22

# Enable firewall
sudo ufw enable
```

#### 9. Seed Database (Optional)

```bash
# Exec into container
docker compose -f docker-compose.prod.yml exec web bash

# Run seeds
/app/ledger_bank_api/bin/ledger_bank_api eval "Mix.Tasks.Run.run(['priv/repo/seeds.exs'])"

# Exit
exit
```

#### 10. Verify

```bash
# Health check
curl https://yourdomain.com/api/health

# API docs
open https://yourdomain.com/api/docs
```

### Self-Hosted Notes

**Pros:**
- ✅ Full control over infrastructure
- ✅ Learn server administration
- ✅ No vendor lock-in
- ✅ Can scale as needed

**Cons:**
- ⚠️ You manage updates and security patches
- ⚠️ Need to monitor server health
- ⚠️ More complex setup
- ⚠️ Costs money ($5-12/month for VPS)

---

## 🔐 Environment Variables

### Required Variables

| Variable | Description | Example | How to Generate |
|----------|-------------|---------|-----------------|
| `MIX_ENV` | Elixir environment | `prod` | Set to `prod` |
| `PHX_SERVER` | Start HTTP server | `true` | Set to `true` |
| `DATABASE_URL` | PostgreSQL connection | `ecto://user:pass@host:5432/db` | Provided by hosting platform |
| `SECRET_KEY_BASE` | Phoenix secret | 64+ character string | `mix phx.gen.secret` |
| `JWT_SECRET` | JWT signing secret | 64+ character string | `mix phx.gen.secret 64` |

### Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PHX_HOST` | Public hostname | `localhost` | `yourdomain.com` |
| `PORT` | HTTP port | `4000` | `4000` |
| `POOL_SIZE` | Database connection pool | `10` | `20` |
| `OBAN_QUEUES` | Oban queue configuration | See config.exs | `banking:3,payments:2` |

### External API Variables (Optional)

| Variable | Description | Required For |
|----------|-------------|--------------|
| `MONZO_CLIENT_ID` | Monzo API client ID | Monzo integration |
| `MONZO_CLIENT_SECRET` | Monzo API client secret | Monzo integration |
| `MONZO_API_URL` | Monzo API URL | Monzo integration (defaults to production) |

---

## ⚙️ Oban Configuration

### Configuration Precedence

Oban configuration follows this precedence order (later overrides earlier):

1. **Base Configuration** (`config/config.exs`) - Conservative defaults
2. **Environment Overrides** (`config/dev.exs`, `config/test.exs`) - Environment-specific settings
3. **Runtime Overrides** (`config/runtime.exs`) - Production environment variables

### Queue Configuration

#### **Base Queues** (config/config.exs)
```elixir
queues: [
  banking: 3,      # Bank API calls (external, rate-limited)
  payments: 2,     # Payment processing (critical)
  notifications: 3, # Email/SMS notifications
  default: 1       # Miscellaneous tasks
]
```

#### **Environment-Specific Overrides**

**Development** (`config/dev.exs`):
- `testing: :manual` - Manual job execution for debugging
- Reduced concurrency for development

**Testing** (`config/test.exs`):
- `testing: :inline` - Synchronous execution for faster tests
- Higher concurrency for test performance

**Production** (`config/runtime.exs`):
- Environment-driven via `OBAN_QUEUES` variable
- Format: `"banking:3,payments:2,notifications:3,default:1"`

### Environment Variable Configuration

#### **OBAN_QUEUES** (Production)
```bash
# Format: "queue_name:concurrency,queue_name:concurrency"
OBAN_QUEUES="banking:5,payments:3,notifications:2,default:1"
```

#### **Queue Concurrency Guidelines**

| Queue | Purpose | Recommended Concurrency | Rationale |
|-------|---------|------------------------|-----------|
| `banking` | External bank API calls | 3-5 | Rate-limited by external APIs |
| `payments` | Payment processing | 2-3 | Critical, requires careful handling |
| `notifications` | Email/SMS | 3-5 | External service rate limits |
| `default` | General tasks | 1-2 | Low priority, resource conservation |

### Production Optimization

#### **High-Volume Scenarios**
```bash
# For high-volume deployments
OBAN_QUEUES="banking:10,payments:5,notifications:8,default:3"
```

#### **Resource-Constrained Scenarios**
```bash
# For limited resources
OBAN_QUEUES="banking:2,payments:1,notifications:2,default:1"
```

### Monitoring and Maintenance

#### **Job Cleanup**
- Automatic cleanup after 7 days (configured in all environments)
- Prevents database bloat from old job records

#### **Queue Health Monitoring**
```bash
# Check queue status
curl https://your-api.com/api/health/ready

# Monitor job processing
# (Use your monitoring platform to track Oban metrics)
```

---

## 🔐 JWT Configuration

### Configuration Precedence

JWT configuration follows this precedence order (later overrides earlier):

1. **Base Configuration** (`config/config.exs`) - Default JWT settings
2. **Environment Overrides** (`config/dev.exs`, `config/test.exs`) - Environment-specific settings
3. **Runtime Overrides** (`config/runtime.exs`) - Production environment variables

### JWT Configuration Structure

#### **Base JWT Settings** (config/config.exs)
```elixir
# JWT Configuration
config :ledger_bank_api, :jwt,
  algorithm: "HS256",
  issuer: "ledger-bank-api",
  audience: "ledger-bank-api",
  access_token_expiry: 3600,  # 1 hour
  refresh_token_expiry: 7 * 24 * 3600  # 7 days

# JWT Secret (must be 64+ characters)
config :ledger_bank_api, :jwt_secret, System.get_env("JWT_SECRET")
```

#### **Environment-Specific Overrides**

**Development** (`config/dev.exs`):
- Uses development-specific JWT secret
- Shorter token expiry for development

**Testing** (`config/test.exs`):
- Uses test-specific JWT secret
- Very short token expiry for testing

**Production** (`config/runtime.exs`):
- Uses environment variable for JWT secret
- Production-optimized settings

### JWT Secret Configuration

#### **Secret Requirements**
- **Minimum Length**: 32 characters (enforced by application)
- **Recommended Length**: 64 characters
- **Generation**: `mix phx.gen.secret 64`

#### **Environment Variable Configuration**

**Development**:
```bash
# Generate a strong secret
JWT_SECRET=$(mix phx.gen.secret 64)
export JWT_SECRET
```

**Production**:
```bash
# Use a strong, unique secret
JWT_SECRET="your-production-secret-here-64-chars-minimum"
```

### JWT Token Configuration

#### **Access Token Settings**
- **Expiry**: 1 hour (3600 seconds)
- **Algorithm**: HS256
- **Issuer**: "ledger-bank-api"
- **Audience**: "ledger-bank-api"

#### **Refresh Token Settings**
- **Expiry**: 7 days (604800 seconds)
- **Algorithm**: HS256
- **Issuer**: "ledger-bank-api"
- **Audience**: "ledger-bank-api"

### Security Considerations

#### **Token Security**
- **Short Access Token TTL**: 1 hour reduces exposure window
- **Refresh Token Rotation**: New refresh token issued on use
- **Secure Storage**: Tokens stored in HTTP-only cookies
- **HTTPS Only**: Tokens only transmitted over HTTPS in production

#### **Secret Management**
- **Environment Variables**: Never hardcode secrets
- **Secret Rotation**: Regular rotation of JWT secrets
- **Length Validation**: Application enforces minimum 32 characters
- **Production Secrets**: Use strong, unique secrets in production

### Configuration Validation

The application validates JWT configuration at startup:

```elixir
# This will fail fast if JWT_SECRET is not configured or too short
LedgerBankApi.Accounts.Token.ensure_jwt_secret!()
```

### Troubleshooting JWT Issues

#### **Common JWT Errors**

| Error | Cause | Solution |
|-------|-------|----------|
| `JWT_SECRET not configured` | Missing environment variable | Set `JWT_SECRET` environment variable |
| `JWT_SECRET must be at least 32 characters` | Secret too short | Use `mix phx.gen.secret 64` |
| `Invalid token` | Token expired or malformed | Check token expiry and format |
| `Token verification failed` | Secret mismatch | Ensure same secret for signing/verification |

#### **JWT Debugging**

```bash
# Check JWT secret is set
echo $JWT_SECRET

# Verify secret length
echo $JWT_SECRET | wc -c

# Test JWT generation (development only)
iex -S mix
LedgerBankApi.Accounts.Token.ensure_jwt_secret!()
```

---

## 🩺 Health Checks

All platforms should configure health checks:

### **Liveness Probe**
```
GET /api/health/live
```

**Use for:** Kubernetes `livenessProbe`, Docker health checks

**Purpose:** "Is the container alive?" (restarts if unhealthy)

### **Readiness Probe**
```
GET /api/health/ready
```

**Use for:** Kubernetes `readinessProbe`, load balancer health checks

**Purpose:** "Can it accept traffic?" (checks database connectivity)

### **Detailed Health**
```
GET /api/health/detailed
```

**Use for:** Monitoring dashboards, debugging

**Returns:** Database, memory, disk status

---

## 🔧 Troubleshooting

### **Container Won't Start**

**Symptom:** Container exits immediately or crashes

**Check:**
```bash
# View logs
docker compose logs web

# Common issues:
# - Missing JWT_SECRET → Check environment variables
# - Database not ready → Wait for healthcheck to pass
# - Port already in use → Change PORT variable
```

**Fix:**
```bash
# Rebuild with fresh image
docker compose down
docker compose build --no-cache
docker compose up -d
```

### **Database Connection Errors**

**Symptom:** `connection refused` or `could not connect to server`

**Check:**
```bash
# Verify database is running
docker compose ps db

# Check database logs
docker compose logs db

# Test connection manually
docker compose exec db psql -U postgres -d ledger_bank_api_prod
```

**Fix:**
```bash
# Restart database
docker compose restart db

# Or recreate
docker compose down db
docker compose up -d db
```

### **Migrations Not Running**

**Symptom:** API returns errors about missing tables

**Check:**
```bash
# View migration logs
docker compose logs web | grep migration

# Check if migrations ran
docker compose exec web /app/ledger_bank_api/bin/ledger_bank_api eval "Ecto.Migrator.status(LedgerBankApi.Repo)"
```

**Fix:**
```bash
# Manually run migrations
docker compose exec web /app/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Release.migrate()"
```

### **JWT Errors**

**Symptom:** `JWT_SECRET not configured` or token validation fails

**Check:**
```bash
# Verify environment variable is set
docker compose exec web printenv | grep JWT_SECRET
```

**Fix:**
```bash
# Regenerate and set
JWT_SECRET=$(mix phx.gen.secret 64)
docker compose down
# Update .env.production or docker-compose.yml
docker compose up -d
```

### **API Returns 503 (Service Unavailable)**

**Symptom:** All endpoints return 503

**Check:**
```bash
# Check health endpoint
curl http://localhost:4000/api/health/detailed

# Check database connectivity
docker compose exec web /app/ledger_bank_api/bin/ledger_bank_api eval "LedgerBankApi.Repo.query(\"SELECT 1\")"
```

**Fix:**
```bash
# Restart services
docker compose restart
```

### **Out of Memory**

**Symptom:** Container killed, OOM in logs

**Fix:**
```bash
# Increase Docker memory limit
# In docker-compose.yml, add under 'web':
services:
  web:
    mem_limit: 512m
    mem_reservation: 256m
```

### **Cold Starts on Render/Fly**

**Symptom:** First request after inactivity takes 20-30 seconds

**Normal behavior** for free tiers. To keep warm:

```bash
# Setup a cron job to ping health endpoint every 10 minutes
*/10 * * * * curl https://your-app.onrender.com/api/health > /dev/null 2>&1
```

Or use services like:
- UptimeRobot (free, pings every 5 minutes)
- Cron-job.org (free, scheduled health checks)

---

## 📊 Monitoring Your Deployed App

### **Render.com Monitoring**

Built-in metrics dashboard shows:
- CPU usage
- Memory usage
- Request count
- Response times
- Error rates

### **Custom Monitoring**

Use these endpoints for external monitoring:

```bash
# Basic health (uptime monitoring)
curl https://your-app.com/api/health

# Detailed health (service-specific checks)
curl https://your-app.com/api/health/detailed

# Returns:
# {
#   "status": "ok",
#   "checks": {
#     "database": "ok",
#     "memory": "ok",
#     "disk": "ok"
#   }
# }
```

### **Recommended Monitoring Services**

**Free Tiers:**
- [UptimeRobot](https://uptimerobot.com) - 50 monitors free
- [Pingdom](https://www.pingdom.com) - 1 monitor free
- [Better Uptime](https://betteruptime.com) - 10 monitors free

**What to Monitor:**
- ✅ `/api/health/ready` every 60 seconds
- ✅ Response time < 500ms
- ✅ Uptime > 99%
- ✅ SSL certificate expiration

---

## 🔄 Continuous Deployment

### **GitHub Actions → Render (Automatic)**

Render automatically deploys on git push to `main` branch.

**No configuration needed!** Every commit triggers:
1. Build Docker image
2. Run database migrations
3. Start new container
4. Health check validation
5. Route traffic to new version

### **GitHub Actions → Fly.io**

Add to `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Fly.io

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: superfly/flyctl-actions/setup-flyctl@master
      
      - run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

**Setup:**
```bash
# Get your Fly API token
flyctl auth token

# Add to GitHub repository secrets:
# Settings → Secrets and variables → Actions → New repository secret
# Name: FLY_API_TOKEN
# Value: <paste_your_token>
```

---

## 🎉 Post-Deployment Checklist

After successful deployment:

- [ ] ✅ Health endpoints return 200 OK
- [ ] ✅ API docs accessible at `/api/docs`
- [ ] ✅ Can create users via `/api/users`
- [ ] ✅ Can login and get JWT tokens
- [ ] ✅ Protected endpoints require authentication
- [ ] ✅ SSL/HTTPS working (padlock in browser)
- [ ] ✅ Monitoring/uptime check configured
- [ ] ✅ README updated with live demo link
- [ ] ✅ Portfolio website links to deployed API
- [ ] ✅ GitHub repository description includes live URL

---

## 📝 Next Steps After Deployment

### **For Your Portfolio:**

1. **Update README** with live demo link:
   ```markdown
   ## 🌐 Live Demo
   
   **API:** https://your-app.onrender.com/api
   **Docs:** https://your-app.onrender.com/api/docs
   
   Try it:
   ```bash
   curl https://your-app.onrender.com/api/health
   ```
   ```

2. **Add to Portfolio Website:**
   ```html
   <h3>LedgerBank API - Financial Services Platform</h3>
   <p>Production-grade Elixir/Phoenix API with JWT auth, background jobs, and OpenAPI docs.</p>
   <a href="https://your-app.onrender.com/api/docs">Live Demo</a> |
   <a href="https://github.com/rafaelRojasVi/ledger-bank-api">Source Code</a>
   ```

3. **Add to LinkedIn:**
   ```
   📦 New Project: LedgerBank API
   
   Built a financial services API in Elixir/Phoenix demonstrating:
   • Clean architecture with behaviors
   • Error catalog system (40+ error reasons)
   • JWT authentication with token rotation
   • Oban background jobs with intelligent retry
   • 1000+ tests including security and performance
   
   Live demo: https://your-app.onrender.com/api/docs
   Source: https://github.com/rafaelRojasVi/ledger-bank-api
   
   #Elixir #Phoenix #BackendDevelopment #Portfolio
   ```

### **For Interviews:**

Prepare to discuss:
- ✅ Why you chose Elixir for financial services
- ✅ How you implemented constant-time authentication
- ✅ Your error handling strategy (Error Catalog)
- ✅ Worker retry logic based on error categories
- ✅ How you'd scale this (Redis cache, multi-node clustering)
- ✅ Security considerations (JWT rotation, RBAC, audit logs)

---

## 🆘 Getting Help

**Deployment Issues:**
- Check platform documentation (Render, Fly.io have great docs)
- Use `docker compose logs` to debug
- Verify environment variables are set correctly

**Application Issues:**
- Check `/api/health/detailed` for service status
- Review structured logs for correlation IDs
- Use Phoenix LiveDashboard (if accessible)

**Questions about the Project:**
- Open a GitHub issue
- Email: rafarojasv6@gmail.com

---

<div align="center">

**🚀 Ready to Deploy?**

Start with Render.com (10 minutes, free tier)

[Deploy to Render](https://render.com) • 
[Deploy to Fly.io](https://fly.io) •
[Deploy to Railway](https://railway.app)

</div>


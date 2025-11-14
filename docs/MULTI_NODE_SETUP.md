# 🔄 Multi-Node Setup Guide

Complete guide to setting up and testing horizontal scaling with multiple server instances.

## 📚 Table of Contents

- [Why Multiple Servers?](#-why-multiple-servers)
- [Why 3 Servers?](#-why-3-servers)
- [Implementation Steps](#-implementation-steps)
- [Testing the Setup](#-testing-the-setup)
- [How It Works](#-how-it-works)

---

## 🤔 Why Multiple Servers?

### **The Problem: Single Server Bottleneck**

```
User Request → Server → Database → Response
     ↑                              ↓
     └─────────── 500ms ────────────┘

If 100 users hit at once:
- Server can handle ~20 requests/second
- Others wait in queue → Slow responses ❌
```

### **The Solution: Multiple Servers**

```
Load Balancer
    ├─→ Server 1 (handles 20 req/sec)
    ├─→ Server 2 (handles 20 req/sec)
    └─→ Server 3 (handles 20 req/sec)

Total: 60 requests/second! ✅
```

**Benefits:**
- ✅ **Higher capacity** - 3x more requests/second
- ✅ **Fault tolerance** - If one server crashes, others keep working
- ✅ **Zero downtime** - Can update servers one at a time
- ✅ **Better performance** - Requests distributed evenly

---

## 🎯 Why 3 Servers?

### **Common Choices:**

| Number | Why? | Use Case |
|--------|------|----------|
| **1** | Starting point, simple | Development, testing |
| **3** | **Sweet spot** - Good balance | **Most production apps** |
| 5 | Higher capacity needed | High traffic apps |
| 10+ | Very high traffic | Enterprise scale |

### **Why 3 is the Sweet Spot:**

#### **1. Fault Tolerance (Quorum)**
```
3 servers = Can lose 1, still have 2 working
If 1 crashes → 66% capacity remaining ✅

2 servers = Can lose 1, only 50% remaining
If 1 crashes → 50% capacity (risky!) ⚠️

5 servers = Overkill for most apps
More expensive, more to manage ❌
```

#### **2. Cost vs. Performance**
```
1 server:  $50/month  → 20 req/sec
3 servers: $150/month → 60 req/sec (3x capacity)
5 servers: $250/month → 100 req/sec (only 1.6x vs 3)

Diminishing returns after 3! 📉
```

#### **3. Odd Numbers for Consensus**
- **3 servers** = Easy to decide "majority" (2 out of 3)
- **4 servers** = What's majority? 2? 3? Confusing! ❌
- **5 servers** = 3 out of 5 = clear majority

#### **4. Kubernetes Standard**
- Most Kubernetes deployments default to **3 replicas**
- Industry best practice for redundancy

### **When to Use Different Numbers:**

#### **Use 1 Server:**
- ✅ Development
- ✅ Testing
- ✅ Small side projects (< 1000 users/day)

#### **Use 3 Servers:**
- ✅ **Production (recommended)**
- ✅ Small to medium apps
- ✅ Most SaaS applications
- ✅ Portfolio projects

#### **Use 5+ Servers:**
- ✅ High traffic (millions of requests/day)
- ✅ Enterprise applications
- ✅ Global applications (geographic distribution)

### **TL;DR:**
**3 servers = Best balance of:**
- Cost 💰
- Performance ⚡
- Reliability 🛡️
- Simplicity 🎯

---

## 🚀 Implementation Steps

### **Step 1: Setup Docker Compose for Multi-Node**

```bash
# Use the multi-node compose file
docker compose -f docker-compose.multi-node.yml up -d
```

This creates:
- ✅ **3 web servers** (web1, web2, web3)
- ✅ **1 load balancer** (nginx)
- ✅ **1 database** (shared)
- ✅ **1 Redis** (for future cache adapter)

### **Step 2: Wait for Services to Start**

```bash
# Check status
docker compose -f docker-compose.multi-node.yml ps

# Watch logs
docker compose -f docker-compose.multi-node.yml logs -f
```

Wait until all services show "healthy" status.

### **Step 3: Verify Setup**

```bash
# Run test script
chmod +x scripts/test_multi_node.sh
./scripts/test_multi_node.sh
```

This will test:
- ✅ Load balancer connectivity
- ✅ Server health checks
- ✅ Load balancing distribution
- ✅ Database connectivity
- ✅ Stateless authentication
- ✅ Background jobs

---

## 🧪 Testing the Setup

### **Test 1: Basic Health Check**

```bash
# All requests go through load balancer
curl http://localhost:4000/api/health

# Should return:
# {"status":"ok","timestamp":"...","version":"1.0.0","uptime":...}
```

### **Test 2: Verify Load Balancing**

```bash
# Make multiple requests - each might hit different server
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://localhost:4000/api/health | jq .uptime
  sleep 0.5
done

# Different uptime values = different servers responding! ✅
```

### **Test 3: Test Under Load**

```bash
# Install Apache Bench (if not installed)
# macOS: brew install httpd
# Linux: sudo apt-get install apache2-utils

# Send 100 requests, 10 at a time
ab -n 100 -c 10 http://localhost:4000/api/health

# Results show:
# - Requests per second (should be ~3x single server)
# - Average response time
# - Distribution across servers
```

### **Test 4: Test Fault Tolerance**

```bash
# Stop one server
docker compose -f docker-compose.multi-node.yml stop web1

# Verify app still works (should route to web2/web3)
curl http://localhost:4000/api/health

# Restart the server
docker compose -f docker-compose.multi-node.yml start web1
```

### **Test 5: Test Stateless Authentication**

```bash
# Create user
curl -X POST http://localhost:4000/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","full_name":"Test","password":"password123","password_confirmation":"password123"}'

# Login
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  | jq -r '.data.access_token')

# Make 10 requests with token (should work on any server)
for i in {1..10}; do
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:4000/api/auth/me \
    | jq .data.email
done

# All should return "test@example.com" ✅
```

---

## 🔍 How It Works

### **Architecture Diagram**

```
                    ┌──────────────┐
                    │   Users      │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Load Balancer│
                    │   (Nginx)    │
                    │   Port 4000  │
                    └──┬───────┬───┘
                       │       │
          ┌────────────┼───────┼────────────┐
          │            │       │            │
    ┌─────▼───┐  ┌────▼───┐  ┌▼──────┐
    │ Server 1│  │Server 2│  │Server 3│
    │ :4000   │  │ :4000  │  │ :4000  │
    └────┬────┘  └───┬────┘  └───┬────┘
         │           │           │
         └───────────┼───────────┘
                     │
            ┌────────▼────────┐
            │   PostgreSQL    │
            │   (Shared DB)   │
            └─────────────────┘
```

### **Request Flow:**

1. **User makes request** → `GET /api/users`
2. **Load balancer receives it** → Routes to available server (round-robin)
3. **Server processes request:**
   - Checks JWT token (in database) ✅
   - Queries database ✅
   - Returns response ✅
4. **Response goes back through load balancer** → User receives it

**Key Point:** Each request can hit a different server, but it doesn't matter because:
- ✅ JWT tokens work on any server (stateless)
- ✅ Database is shared (all servers see same data)
- ✅ Cache (when using Redis) is shared

### **Oban Job Distribution:**

```
Server 1: "I'll process payment job #123"
Server 2: "I'll process payment job #124"
Server 3: "I'll process payment job #125"

All servers read from same PostgreSQL job queue!
```

---

## 📊 Performance Comparison

### **Single Server:**
```
Requests/second: ~20
Response time:   50-100ms
Capacity:        Low
Fault tolerance: None (if crashes, everything down)
```

### **3 Servers:**
```
Requests/second: ~60 (3x)
Response time:   50-100ms (same)
Capacity:        Medium
Fault tolerance: High (can lose 1 server)
```

### **5 Servers:**
```
Requests/second: ~100 (5x)
Response time:   50-100ms (same)
Capacity:        High
Fault tolerance: Very high (can lose 2 servers)
Cost:            $$$ (2.5x vs 3 servers)
```

---

## 🎓 Learning Points

### **What You'll Learn:**

1. **Load Balancing** - How to distribute traffic
2. **Health Checks** - How to ensure servers are healthy
3. **Stateless Design** - Why it's important for scaling
4. **Shared Resources** - Database, cache, job queues
5. **Fault Tolerance** - System continues working if one server fails

### **Real-World Scenarios:**

#### **Scenario 1: Traffic Spike**
```
Normal: 10 requests/second (1 server is fine)
Spike:   50 requests/second (need 3 servers!)
```

#### **Scenario 2: Server Maintenance**
```
Old way: Take down server → App is down ❌
New way: Update server 1, servers 2&3 keep serving ✅
```

#### **Scenario 3: Server Crash**
```
Old way: Server crashes → App is down ❌
New way: Server 1 crashes, servers 2&3 keep serving ✅
```

---

## 🚨 Common Issues

### **Issue: "Connection refused"**
```bash
# Check if services are running
docker compose -f docker-compose.multi-node.yml ps

# Check logs
docker compose -f docker-compose.multi-node.yml logs nginx
```

### **Issue: "All requests hitting one server"**
```bash
# Check nginx config
cat docker/nginx.conf

# Restart nginx
docker compose -f docker-compose.multi-node.yml restart nginx
```

### **Issue: "Database connection pool exhausted"**
```bash
# Increase pool size in config
# config/dev.exs
pool_size: 10  # Per server
# 3 servers × 10 = 30 connections total

# PostgreSQL default max_connections = 100
# So 3 servers is safe! ✅
```

---

## 📝 Summary

### **Why 3 Servers?**
- ✅ Best balance of cost, performance, reliability
- ✅ Can lose 1 server and keep running
- ✅ Industry standard (Kubernetes default)
- ✅ Easy to manage and understand

### **How to Test:**
1. Run `docker compose -f docker-compose.multi-node.yml up`
2. Run `./scripts/test_multi_node.sh`
3. Verify load balancing with multiple requests
4. Test fault tolerance by stopping one server

### **What Works Already:**
- ✅ Stateless JWT authentication
- ✅ Shared database
- ✅ Oban job distribution
- ✅ Health checks

### **What You'll Add:**
- ✅ Load balancer (nginx) - **Already in docker-compose!**
- ✅ Redis cache adapter (future)
- ✅ Monitoring/logging

---

**You're ready to scale! 🚀**

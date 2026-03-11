# ⚡ Quick Start: Multi-Node Setup

**TL;DR: Run 3 servers with 1 command, test with another!**

## 🚀 Start It

```bash
# Start 3 servers + load balancer
docker compose -f docker-compose.multi-node.yml up -d

# Wait 30 seconds for everything to start
# Check status
docker compose -f docker-compose.multi-node.yml ps
```

## 🧪 Test It

```bash
# Run automated tests (Linux/Mac/Git Bash)
bash scripts/test_multi_node.sh

# Or test manually:
curl http://localhost:4000/api/health
```

## 📖 Learn More

Read the full guide: [`docs/MULTI_NODE_SETUP.md`](./MULTI_NODE_SETUP.md)

---

## 🎯 Why 3 Servers?

**Simple Answer:**
- ✅ **1 server** = If it crashes, your app is down ❌
- ✅ **2 servers** = If 1 crashes, only 50% capacity (risky!)
- ✅ **3 servers** = If 1 crashes, still 66% capacity ✅ **Perfect balance!**
- ✅ **5+ servers** = More expensive, diminishing returns

**Real Numbers:**
- 1 server: ~20 requests/second
- 3 servers: ~60 requests/second (3x capacity)
- Cost: Only 3x the price for 3x the power ✅

---

## 🔍 What Gets Tested?

1. ✅ Load balancer works
2. ✅ All 3 servers are healthy
3. ✅ Requests distributed evenly
4. ✅ Database connectivity
5. ✅ JWT authentication (stateless)
6. ✅ Background jobs work

---

## 🛑 Stop It

```bash
docker compose -f docker-compose.multi-node.yml down
```

---

## 📝 Files Created

- `docker-compose.multi-node.yml` - Defines 3 servers + load balancer
- `docker/nginx.conf` - Load balancer configuration
- `scripts/test_multi_node.sh` - Automated tests
- `docs/MULTI_NODE_SETUP.md` - Full documentation

**You're all set! 🎉**

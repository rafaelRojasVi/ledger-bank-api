# 🧪 Testing Multi-Node Setup

Complete guide to test your 3-server horizontal scaling setup.

## ✅ Quick Tests

### **1. Basic Health Check**

```bash
curl http://localhost:4000/api/health
```

**Expected:** `{"status":"ok","timestamp":"...","uptime":...,"version":"1.0.0"}`

---

### **2. Load Balancing Test**

Make multiple requests to see if traffic is distributed:

```bash
# Make 10 requests
for i in {1..10}; do 
  echo "Request $i:" 
  curl -s http://localhost:4000/api/health | jq -r '.uptime'
  sleep 0.2
done
```

**What to check:**
- Each request should succeed ✅
- Uptime values will differ (each server has different uptime)

---

### **3. Check Which Server Handled Each Request**

```bash
# Watch logs in real-time
docker compose -f docker-compose.multi-node.yml logs -f web1 web2 web3 | grep "GET /api/health"
```

**What you'll see:**
- Requests distributed across web1, web2, web3
- Round-robin distribution (1 → 2 → 3 → 1 → 2...)

**Example output:**
```
web1-1  | 13:49:18.875 [info] GET /api/health
web2-1  | 13:49:19.120 [info] GET /api/health  
web3-1  | 13:49:19.340 [info] GET /api/health
web1-1  | 13:49:19.560 [info] GET /api/health
```

---

### **4. Failover Test (High Availability)**

**Test that if one server crashes, others still work:**

```bash
# Stop one server
docker compose -f docker-compose.multi-node.yml stop web3

# Keep making requests - should still work!
for i in {1..5}; do
  echo "Request $i:"
  curl -s http://localhost:4000/api/health && echo " ✅"
  sleep 0.5
done

# Restart the server
docker compose -f docker-compose.multi-node.yml start web3
```

**Expected:**
- ✅ API still responds (traffic goes to web1 and web2)
- ✅ No errors in user-facing requests
- ✅ web3 comes back online and starts receiving traffic again

---

### **5. Concurrent Load Test**

Test with multiple simultaneous requests:

```bash
# Make 20 concurrent requests
for i in {1..20}; do
  curl -s http://localhost:4000/api/health > /dev/null &
done
wait

echo "All requests completed!"
```

**What to check:**
- All requests complete successfully
- No timeouts or errors
- Check logs to see all 3 servers handled requests

---

### **6. Check Server Status**

```bash
# View all containers
docker compose -f docker-compose.multi-node.yml ps

# Check individual server health
docker compose -f docker-compose.multi-node.yml ps web1
docker compose -f docker-compose.multi-node.yml ps web2
docker compose -f docker-compose.multi-node.yml ps web3
```

**Expected:** All show `(healthy)` status

---

### **7. Test Real API Endpoints**

```bash
# Test authentication endpoint
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123!"}'

# Test with authentication
TOKEN="your_jwt_token_here"
curl http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

**What to check:**
- Requests work regardless of which server handles them
- Sessions/tokens work across all servers (they all share the same database)

---

## 📊 Advanced Testing

### **Monitor Request Distribution**

```bash
# Count requests per server in logs
docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 | \
  grep "GET /api/health" | \
  awk '{print $1}' | \
  sort | uniq -c
```

**Expected output:**
```
  5 web1-1
  5 web2-1
  5 web3-1
```

### **Test Database Consistency**

All servers share the same database, so writes should be consistent:

```bash
# Create a user on server 1 (via load balancer)
curl -X POST http://localhost:4000/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Read it back - could be served by any server
curl http://localhost:4000/api/users/test@example.com
```

**What to check:**
- ✅ Data written through one server is readable from any server
- ✅ No data inconsistency issues

---

## 🎯 Success Criteria

Your multi-node setup is working correctly if:

1. ✅ **Load Balancing:** Requests are distributed across all 3 servers
2. ✅ **High Availability:** API works even when 1 server is down
3. ✅ **No Errors:** All requests return 200 OK
4. ✅ **Consistency:** All servers read/write to the same database
5. ✅ **Health Checks:** All servers show as "healthy"

---

## 🐛 Troubleshooting

### **All requests go to one server**

Check nginx configuration:
```bash
docker compose -f docker-compose.multi-node.yml exec nginx cat /etc/nginx/nginx.conf
```

### **Servers not receiving traffic**

Check if servers are healthy:
```bash
docker compose -f docker-compose.multi-node.yml ps
```

All should show `(healthy)` not `(unhealthy)`

### **API not responding**

Check logs:
```bash
docker compose -f docker-compose.multi-node.yml logs nginx
docker compose -f docker-compose.multi-node.yml logs web1 --tail 50
```

---

## 🚀 Next Steps

Once basic tests pass:

1. **Load Testing:** Use tools like `ab` or `wrk` for stress testing
2. **Monitoring:** Set up Prometheus/Grafana to monitor server metrics
3. **Logging:** Aggregate logs from all servers (ELK stack)
4. **Auto-scaling:** Configure to add more servers under load

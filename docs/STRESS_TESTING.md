# 🔥 Stress Testing Guide

How to stress test your multi-node setup to verify it can handle high load.

## 🚀 Quick Start

### **Simple Stress Test (Recommended)**

```bash
# Test with 200 requests, 50 concurrent
bash scripts/stress_test_simple.sh 200 50

# Test with 1000 requests, 100 concurrent (more intense)
bash scripts/stress_test_simple.sh 1000 100
```

### **Full Stress Test (Comprehensive)**

```bash
# Full test with multiple endpoints
bash scripts/stress_test.sh 500 50
```

---

## 📊 What Gets Tested

### **1. Throughput Test**
- Sends many concurrent requests
- Measures requests/second (RPS)
- **Goal:** >100 RPS with 3 servers

### **2. Response Time Test**
- Measures average, min, max response times
- **Goal:** <50ms average response time

### **3. Multiple Endpoints Test**
- Tests different endpoints simultaneously
- Verifies load balancing works for all routes

### **4. Sustained Load Test**
- Sends requests continuously for 30 seconds
- Simulates real-world traffic patterns

### **5. Server Distribution**
- Verifies requests are distributed evenly across all 3 servers
- **Goal:** ~33% per server (even distribution)

---

## 🎯 Expected Results

### **Good Performance:**
- ✅ RPS: >100 requests/second
- ✅ Response Time: <50ms average
- ✅ Error Rate: <1%
- ✅ Even distribution across servers

### **Excellent Performance:**
- ✅ RPS: >500 requests/second
- ✅ Response Time: <20ms average
- ✅ Error Rate: 0%
- ✅ Perfect 33%/33%/33% distribution

---

## 🔧 Using External Tools

### **Apache Bench (ab)**

```bash
# Install (if not installed)
# Ubuntu/Debian: sudo apt-get install apache2-utils
# macOS: brew install httpd

# Test with 1000 requests, 50 concurrent
ab -n 1000 -c 50 http://localhost:4000/api/health
```

### **wrk (High Performance)**

```bash
# Install: https://github.com/wg/wrk

# Test for 30 seconds, 50 threads, 50 connections
wrk -t50 -c50 -d30s http://localhost:4000/api/health
```

### **Hey (Modern Alternative)**

```bash
# Install: go install github.com/rakyll/hey@latest

# Test with 1000 requests, 50 concurrent
hey -n 1000 -c 50 http://localhost:4000/api/health
```

---

## 📈 Monitoring During Stress Test

### **Watch Server Logs**

```bash
# Terminal 1: Watch all servers
docker compose -f docker-compose.multi-node.yml logs -f web1 web2 web3
```

### **Check Server Resources**

```bash
# Check CPU/Memory usage
docker stats ledger-bank-api-web1-1 ledger-bank-api-web2-1 ledger-bank-api-web3-1
```

### **Monitor Database**

```bash
# Check database connections
docker compose -f docker-compose.multi-node.yml exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

---

## 🎯 Stress Test Scenarios

### **Scenario 1: Light Load**
```bash
bash scripts/stress_test_simple.sh 100 10
```
**Good for:** Testing basic functionality

### **Scenario 2: Medium Load**
```bash
bash scripts/stress_test_simple.sh 500 50
```
**Good for:** Testing normal traffic patterns

### **Scenario 3: Heavy Load**
```bash
bash scripts/stress_test_simple.sh 2000 100
```
**Good for:** Testing peak traffic

### **Scenario 4: Extreme Load**
```bash
bash scripts/stress_test_simple.sh 5000 200
```
**Good for:** Finding breaking points

---

## 🐛 Troubleshooting

### **High Error Rate**

**Problem:** Many requests failing
**Solutions:**
- Check database connection pool size
- Increase server resources (CPU/RAM)
- Add more servers

### **Slow Response Times**

**Problem:** Response times >100ms
**Solutions:**
- Check database query performance
- Optimize slow endpoints
- Add caching (Redis)

### **Uneven Distribution**

**Problem:** One server handling most requests
**Solutions:**
- Check nginx configuration
- Verify all servers are healthy
- Check network connectivity

### **Database Connection Errors**

**Problem:** "Too many connections" errors
**Solutions:**
- Increase database connection pool
- Add connection pooling (PgBouncer)
- Optimize query performance

---

## 📊 Example Output

```
🔥 STRESS TEST - Multi-Node Setup
==================================

Configuration:
  Total Requests: 500
  Concurrent: 50
  Endpoints: health health/ready

1️⃣  Single Endpoint Stress Test (/api/health)
   Sending 500 requests with 50 concurrent connections...

✅ Results:
   Total Time: 2.45s
   Successful: 500 / 500
   Failed: 0
   Requests/Second: 204.08
   Avg Response Time: 12ms
   Min Response Time: 5ms
   Max Response Time: 45ms

2️⃣  Multiple Endpoints Concurrent Test
   Testing multiple endpoints simultaneously...
   ✅ /api/health: 50 success, 0 failed, avg: 11ms
   ✅ /api/health/ready: 50 success, 0 failed, avg: 13ms

3️⃣  Sustained Load Test
   Sending requests for 30 seconds at maximum rate...

✅ Sustained Load Results:
   Duration: 30s
   Successful: 6120
   Failed: 0
   Requests/Second: 204.00

4️⃣  Checking Request Distribution Across Servers
   Recent requests in logs: 500
   Distribution:
   web1-1: 167 requests (33.4%)
   web2-1: 166 requests (33.2%)
   web3-1: 167 requests (33.4%)

==================================
📊 STRESS TEST SUMMARY
==================================

✅ All stress tests completed!

What this means:
  • Your multi-node setup handled 500+ requests
  • Average response time: ~12ms
  • Throughput: ~204 requests/second
  • All 3 servers are sharing the load
```

---

## 🎉 Success Criteria

Your multi-node setup is production-ready if:

1. ✅ **High Throughput:** >100 RPS
2. ✅ **Fast Response:** <50ms average
3. ✅ **Low Errors:** <1% error rate
4. ✅ **Even Distribution:** ~33% per server
5. ✅ **No Failures:** All servers stay healthy

**Congratulations! Your setup can handle production traffic! 🚀**


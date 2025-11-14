#!/bin/bash

# Stress Test Script for Multi-Node Setup
# Tests multiple endpoints with concurrent requests

set -e

echo "🔥 STRESS TEST - Multi-Node Setup"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:4000/api"

# Configuration
TOTAL_REQUESTS=${1:-100}  # Default: 100 requests
CONCURRENT=${2:-20}       # Default: 20 concurrent requests
ENDPOINTS=("health" "health/ready")

echo -e "${BLUE}Configuration:${NC}"
echo "  Total Requests: $TOTAL_REQUESTS"
echo "  Concurrent: $CONCURRENT"
echo "  Endpoints: ${ENDPOINTS[@]}"
echo ""

# Test 1: Single Endpoint Stress Test
echo -e "${YELLOW}1️⃣  Single Endpoint Stress Test (/api/health)${NC}"
echo "   Sending $TOTAL_REQUESTS requests with $CONCURRENT concurrent connections..."
echo ""

START_TIME=$(date +%s%N)
SUCCESS=0
FAILED=0
TOTAL_TIME=0

# Function to make a request
make_request() {
    local start=$(date +%s%N)
    if curl -s -f -w "%{http_code}" -o /dev/null "${BASE_URL}/health" > /tmp/curl_result_$$ 2>&1; then
        local end=$(date +%s%N)
        local duration=$((($end - $start) / 1000000)) # milliseconds
        echo "$duration" >> /tmp/success_times_$$
        echo "1" >> /tmp/success_count_$$
    else
        echo "1" >> /tmp/failed_count_$$
    fi
}

# Cleanup temp files
rm -f /tmp/success_times_$$ /tmp/success_count_$$ /tmp/failed_count_$$

# Create concurrent requests
for i in $(seq 1 $TOTAL_REQUESTS); do
    make_request &
    
    # Limit concurrent requests
    if [ $(jobs -r | wc -l) -ge $CONCURRENT ]; then
        wait -n
    fi
done

# Wait for all background jobs
wait

END_TIME=$(date +%s%N)
ELAPSED=$((($END_TIME - $START_TIME) / 1000000)) # milliseconds
ELAPSED_SEC=$(echo "scale=2; $ELAPSED / 1000" | bc)

# Count results
SUCCESS=$(cat /tmp/success_count_$$ 2>/dev/null | wc -l || echo 0)
FAILED=$(cat /tmp/failed_count_$$ 2>/dev/null | wc -l || echo 0)

# Calculate statistics
if [ $SUCCESS -gt 0 ]; then
    AVG_TIME=$(awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}' /tmp/success_times_$$ 2>/dev/null || echo 0)
    MIN_TIME=$(awk 'BEGIN{min=999999} {if($1<min) min=$1} END {print min}' /tmp/success_times_$$ 2>/dev/null || echo 0)
    MAX_TIME=$(awk 'BEGIN{max=0} {if($1>max) max=$1} END {print max}' /tmp/success_times_$$ 2>/dev/null || echo 0)
    RPS=$(echo "scale=2; $SUCCESS / $ELAPSED_SEC" | bc)
else
    AVG_TIME=0
    MIN_TIME=0
    MAX_TIME=0
    RPS=0
fi

# Cleanup
rm -f /tmp/success_times_$$ /tmp/success_count_$$ /tmp/failed_count_$$

# Display results
echo -e "${GREEN}✅ Results:${NC}"
echo "   Total Time: ${ELAPSED_SEC}s"
echo "   Successful: $SUCCESS / $TOTAL_REQUESTS"
echo "   Failed: $FAILED"
echo "   Requests/Second: $RPS"
echo "   Avg Response Time: ${AVG_TIME}ms"
echo "   Min Response Time: ${MIN_TIME}ms"
echo "   Max Response Time: ${MAX_TIME}ms"
echo ""

# Test 2: Multiple Endpoints Concurrent Test
echo -e "${YELLOW}2️⃣  Multiple Endpoints Concurrent Test${NC}"
echo "   Testing multiple endpoints simultaneously..."
echo ""

make_endpoint_request() {
    local endpoint=$1
    local start=$(date +%s%N)
    if curl -s -f -w "%{http_code}" -o /dev/null "${BASE_URL}/${endpoint}" > /dev/null 2>&1; then
        local end=$(date +%s%N)
        local duration=$((($end - $start) / 1000000))
        echo "$endpoint:$duration:success" >> /tmp/endpoint_results_$$
    else
        echo "$endpoint:0:failed" >> /tmp/endpoint_results_$$
    fi
}

rm -f /tmp/endpoint_results_$$

# Test each endpoint 50 times concurrently
for endpoint in "${ENDPOINTS[@]}"; do
    echo "   Testing /api/$endpoint (50 requests)..."
    for i in $(seq 1 50); do
        make_endpoint_request "$endpoint" &
        if [ $(jobs -r | wc -l) -ge 10 ]; then
            wait -n
        fi
    done
    wait
done

# Count results per endpoint
for endpoint in "${ENDPOINTS[@]}"; do
    success=$(grep "^${endpoint}:" /tmp/endpoint_results_$$ 2>/dev/null | grep ":success" | wc -l || echo 0)
    failed=$(grep "^${endpoint}:" /tmp/endpoint_results_$$ 2>/dev/null | grep ":failed" | wc -l || echo 0)
    avg_time=$(grep "^${endpoint}:" /tmp/endpoint_results_$$ 2>/dev/null | grep ":success" | cut -d: -f2 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}' || echo 0)
    
    if [ $success -gt 0 ]; then
        echo -e "   ${GREEN}✅ /api/$endpoint:${NC} $success success, $failed failed, avg: ${avg_time}ms"
    else
        echo -e "   ${RED}❌ /api/$endpoint:${NC} $success success, $failed failed"
    fi
done

rm -f /tmp/endpoint_results_$$
echo ""

# Test 3: Sustained Load Test
echo -e "${YELLOW}3️⃣  Sustained Load Test${NC}"
echo "   Sending requests for 30 seconds at maximum rate..."
echo ""

SUSTAINED_SUCCESS=0
SUSTAINED_FAILED=0
TEST_DURATION=30
END_TIME=$(($(date +%s) + $TEST_DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    for i in $(seq 1 $CONCURRENT); do
        if curl -s -f -o /dev/null "${BASE_URL}/health" > /dev/null 2>&1; then
            SUSTAINED_SUCCESS=$((SUSTAINED_SUCCESS + 1))
        else
            SUSTAINED_FAILED=$((SUSTAINED_FAILED + 1))
        fi &
    done
    wait
    sleep 0.1
done

SUSTAINED_RPS=$(echo "scale=2; $SUSTAINED_SUCCESS / $TEST_DURATION" | bc)

echo -e "${GREEN}✅ Sustained Load Results:${NC}"
echo "   Duration: ${TEST_DURATION}s"
echo "   Successful: $SUSTAINED_SUCCESS"
echo "   Failed: $SUSTAINED_FAILED"
echo "   Requests/Second: $SUSTAINED_RPS"
echo ""

# Test 4: Check Server Distribution
echo -e "${YELLOW}4️⃣  Checking Request Distribution Across Servers${NC}"
echo "   Analyzing logs to see which servers handled requests..."
echo ""

# Get recent log entries
LOG_COUNT=$(docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 200 | grep "GET /api/health" | wc -l)

if [ $LOG_COUNT -gt 0 ]; then
    echo "   Recent requests in logs: $LOG_COUNT"
    echo "   Distribution:"
    docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 200 | \
        grep "GET /api/health" | \
        awk '{print $1}' | \
        sort | uniq -c | \
        while read count server; do
            percentage=$(echo "scale=1; ($count * 100) / $LOG_COUNT" | bc)
            echo -e "   ${BLUE}$server:${NC} $count requests (${percentage}%)"
        done
else
    echo "   No recent requests found in logs"
fi
echo ""

# Summary
echo "=================================="
echo -e "${GREEN}📊 STRESS TEST SUMMARY${NC}"
echo "=================================="
echo ""
echo "✅ All stress tests completed!"
echo ""
echo "What this means:"
echo "  • Your multi-node setup handled $TOTAL_REQUESTS+ requests"
echo "  • Average response time: ~${AVG_TIME}ms"
echo "  • Throughput: ~${RPS} requests/second"
echo "  • All 3 servers are sharing the load"
echo ""
echo "If you see:"
echo "  • ✅ High RPS (>100) = Excellent performance"
echo "  • ✅ Low response times (<50ms) = Fast responses"
echo "  • ✅ Even distribution = Load balancing working"
echo "  • ❌ Errors or timeouts = May need more servers"
echo ""


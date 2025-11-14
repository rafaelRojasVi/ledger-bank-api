#!/bin/bash

# Improved Stress Test - More reliable version
# Usage: bash scripts/stress_test_v2.sh [requests] [concurrent]

BASE_URL="http://localhost:4000/api"
REQUESTS=${1:-200}
CONCURRENT=${2:-50}

echo "🔥 Stress Test v2"
echo "================="
echo "Requests: $REQUESTS"
echo "Concurrent: $CONCURRENT"
echo ""
echo "Starting test..."
echo ""

# Track start time
start_seconds=$(date +%s)
start_nanoseconds=$(date +%s%N)

# Function to make a request
make_request() {
    local result
    if curl -s -f -w "%{http_code}" -o /dev/null "${BASE_URL}/health" 2>/dev/null | grep -q "200"; then
        echo "1"
    else
        echo "0"
    fi
}

# Export function for parallel execution
export -f make_request
export BASE_URL

# Run requests in parallel using xargs (more reliable than background jobs)
success=$(seq 1 $REQUESTS | xargs -P $CONCURRENT -I {} bash -c 'make_request' | grep -c "1" || echo 0)
failed=$(seq 1 $REQUESTS | xargs -P $CONCURRENT -I {} bash -c 'make_request' | grep -c "0" || echo 0)

# Calculate time
end_seconds=$(date +%s)
end_nanoseconds=$(date +%s%N)
elapsed_seconds=$((end_seconds - start_seconds))
elapsed_ns=$((end_nanoseconds - start_nanoseconds))

# Calculate RPS
if [ $elapsed_seconds -gt 0 ]; then
    rps=$(echo "scale=2; $success / $elapsed_seconds" | bc 2>/dev/null || echo "0.00")
else
    # If less than 1 second, use nanoseconds for precision
    elapsed_seconds_precise=$(echo "scale=3; $elapsed_ns / 1000000000" | bc 2>/dev/null || echo "0.001")
    rps=$(echo "scale=2; $success / $elapsed_seconds_precise" | bc 2>/dev/null || echo "0.00")
fi

echo "Results:"
echo "  ✅ Success: $success"
echo "  ❌ Failed: $failed"
echo "  ⏱️  Time: ${elapsed_seconds}s"
if [ $elapsed_seconds -eq 0 ]; then
    echo "  ⏱️  Time (precise): ${elapsed_seconds_precise}s"
fi
echo "  📈 RPS: $rps"
echo ""

# Check server distribution
echo "Checking server distribution..."
recent_logs=$(docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 500 2>/dev/null | grep "GET /api/health$" || true)

if [ -n "$recent_logs" ]; then
    echo "$recent_logs" | awk '{print $1}' | sort | uniq -c | awk '{printf "   %s: %d requests\n", $2, $1}'
else
    echo "   No recent requests found in logs"
fi

echo ""
echo "✅ Stress test completed!"


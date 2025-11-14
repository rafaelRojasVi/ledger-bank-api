#!/bin/bash

# Simple Stress Test - Easy to use version
# Usage: bash scripts/stress_test_simple.sh [requests] [concurrent]

BASE_URL="http://localhost:4000/api"
REQUESTS=${1:-200}
CONCURRENT=${2:-50}

echo "🔥 Simple Stress Test"
echo "===================="
echo "Requests: $REQUESTS"
echo "Concurrent: $CONCURRENT"
echo ""

# Create temp files upfront (avoid race conditions)
TMP_SUCCESS="/tmp/stress_success_$$"
TMP_FAILED="/tmp/stress_failed_$$"
touch "$TMP_SUCCESS" "$TMP_FAILED"
trap "rm -f $TMP_SUCCESS $TMP_FAILED" EXIT

# Make requests and count results
start_time=$(date +%s%N)

for i in $(seq 1 $REQUESTS); do
    (
        if curl -s -f -o /dev/null "${BASE_URL}/health" 2>/dev/null; then
            echo "1" >> "$TMP_SUCCESS" 2>/dev/null || true
        else
            echo "1" >> "$TMP_FAILED" 2>/dev/null || true
        fi
    ) &
    
    # Limit concurrent
    while [ $(jobs -r | wc -l) -ge $CONCURRENT ]; do
        sleep 0.01
    done
done

wait

end_time=$(date +%s%N)

# Count results (ensure files exist)
if [ -f "$TMP_SUCCESS" ]; then
    success=$(wc -l < "$TMP_SUCCESS" 2>/dev/null | tr -d ' ' || echo 0)
else
    success=0
fi

if [ -f "$TMP_FAILED" ]; then
    failed=$(wc -l < "$TMP_FAILED" 2>/dev/null | tr -d ' ' || echo 0)
else
    failed=0
fi

# If no results but we see requests in logs, requests likely succeeded
if [ $success -eq 0 ] && [ $failed -eq 0 ]; then
    # Give a moment for all writes to complete
    sleep 0.5
    if [ -f "$TMP_SUCCESS" ]; then
        success=$(wc -l < "$TMP_SUCCESS" 2>/dev/null | tr -d ' ' || echo 0)
    fi
    if [ -f "$TMP_FAILED" ]; then
        failed=$(wc -l < "$TMP_FAILED" 2>/dev/null | tr -d ' ' || echo 0)
    fi
fi

# Calculate elapsed time (convert nanoseconds to seconds)
elapsed_ns=$((end_time - start_time))
elapsed=$(echo "scale=2; $elapsed_ns / 1000000000" | bc)

# Calculate RPS (avoid divide by zero)
if [ $(echo "$elapsed > 0" | bc) -eq 1 ] && [ $success -gt 0 ]; then
    rps=$(echo "scale=2; $success / $elapsed" | bc)
else
    rps="0.00"
    elapsed="0.00"
fi

echo "Results:"
echo "  ✅ Success: $success"
echo "  ❌ Failed: $failed"
echo "  ⏱️  Time: ${elapsed}s"
echo "  📈 RPS: $rps"
echo ""

# Cleanup happens via trap

# Check which servers handled requests
echo "Checking server distribution..."
docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 200 | \
    grep "GET /api/health$" | \
    awk '{print $1}' | \
    sort | uniq -c | \
    awk '{printf "   %s: %d requests\n", $2, $1}'


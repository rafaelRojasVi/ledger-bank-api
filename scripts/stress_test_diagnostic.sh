#!/bin/bash

# Diagnostic Stress Test - Shows what's actually happening
# Usage: bash scripts/stress_test_diagnostic.sh [requests] [concurrent]

BASE_URL="http://localhost:4000/api"
REQUESTS=${1:-100}
CONCURRENT=${2:-20}

echo "🔍 Diagnostic Stress Test"
echo "========================="
echo "Requests: $REQUESTS"
echo "Concurrent: $CONCURRENT"
echo ""

# Test a single request first
echo "1️⃣  Testing single request..."
if curl -s -f -o /dev/null -w "HTTP Status: %{http_code}\n" "${BASE_URL}/health" 2>&1; then
    echo "   ✅ Single request works"
else
    echo "   ❌ Single request failed!"
    echo "   Check if servers are running: docker compose -f docker-compose.multi-node.yml ps"
    exit 1
fi
echo ""

# Create temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Make requests with detailed error tracking
echo "2️⃣  Running stress test with error tracking..."
start_time=$(date +%s%N)

seq 1 $REQUESTS | xargs -P $CONCURRENT -I {} sh -c "
    response=\$(curl -s -f -w '%{http_code}|%{time_total}' -o /dev/null '${BASE_URL}/health' 2>&1)
    exit_code=\$?
    
    if [ \$exit_code -eq 0 ]; then
        echo 'success' > '$TMPDIR/result_{}'
    else
        echo \"failed:\$response:\$exit_code\" > '$TMPDIR/result_{}'
    fi
"

wait

end_time=$(date +%s%N)

# Analyze results
success=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^success$" 2>/dev/null | wc -l)
failed=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^failed" 2>/dev/null | wc -l)

# Show error details
echo ""
echo "3️⃣  Error Analysis:"
if [ $failed -gt 0 ]; then
    echo "   Sample errors:"
    ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep "^failed" 2>/dev/null | head -5 | \
        while read line; do
            echo "   - $line"
        done
else
    echo "   ✅ No errors found!"
fi
echo ""

# Calculate stats
elapsed_ns=$((end_time - start_time))
elapsed=$(echo "scale=2; $elapsed_ns / 1000000000" | bc)

if [ $(echo "$elapsed > 0" | bc) -eq 1 ] && [ $success -gt 0 ]; then
    rps=$(echo "scale=2; $success / $elapsed" | bc)
else
    rps="0.00"
fi

echo "Results:"
echo "  ✅ Success: $success"
echo "  ❌ Failed: $failed"
echo "  ⏱️  Time: ${elapsed}s"
echo "  📈 RPS: $rps"
echo ""

# Check server distribution
echo "4️⃣  Server Distribution:"
recent_logs=$(docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 500 2>/dev/null | grep "GET /api/health$" || true)
if [ -n "$recent_logs" ]; then
    total_logged=$(echo "$recent_logs" | wc -l)
    echo "   Requests logged in servers: $total_logged"
    echo "$recent_logs" | tail -50 | awk '{print $1}' | sort | uniq -c | \
        awk '{printf "   %s: %d requests\n", $2, $1}'
else
    echo "   ⚠️  No requests found in server logs"
fi
echo ""

# Check nginx status
echo "5️⃣  Nginx Status:"
nginx_errors=$(docker compose -f docker-compose.multi-node.yml logs nginx --tail 100 2>/dev/null | grep -i "error\|timeout\|connection" | wc -l)
if [ $nginx_errors -gt 0 ]; then
    echo "   ⚠️  Found $nginx_errors potential errors in nginx logs"
    docker compose -f docker-compose.multi-node.yml logs nginx --tail 20 2>/dev/null | grep -i "error\|timeout" | head -3
else
    echo "   ✅ No errors in nginx logs"
fi
echo ""

echo "✅ Diagnostic complete!"


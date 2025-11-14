#!/bin/bash

# Stress Test that respects rate limits (100 requests/minute per IP)
# Usage: bash scripts/stress_test_with_rate_limit.sh

BASE_URL="http://localhost:4000/api"

echo "🔥 Stress Test (Rate Limit Aware)"
echo "=================================="
echo "Rate limit: 100 requests/minute per IP"
echo "This test respects the rate limit"
echo ""

# Test 1: Within rate limit (100 requests)
echo "1️⃣  Testing within rate limit (100 requests)..."
echo "   Sending 100 requests over 1 minute..."

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

start_time=$(date +%s%N)

# Send 100 requests (within limit)
seq 1 100 | xargs -P 10 -I {} sh -c "
    if curl -s -f -o /dev/null -w '%{http_code}' '${BASE_URL}/health' 2>/dev/null | grep -q '200'; then
        echo 'success' > '$TMPDIR/result_{}'
    else
        echo 'failed' > '$TMPDIR/result_{}'
    fi
"

wait

end_time=$(date +%s%N)
success=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^success$" 2>/dev/null | wc -l)
failed=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^failed$" 2>/dev/null | wc -l)

elapsed_ns=$((end_time - start_time))
elapsed=$(echo "scale=2; $elapsed_ns / 1000000000" | bc)

if [ $(echo "$elapsed > 0" | bc) -eq 1 ] && [ $success -gt 0 ]; then
    rps=$(echo "scale=2; $success / $elapsed" | bc)
else
    rps="0.00"
fi

echo "   ✅ Success: $success"
echo "   ❌ Failed: $failed"
echo "   ⏱️  Time: ${elapsed}s"
echo "   📈 RPS: $rps"
echo ""

# Test 2: Wait for rate limit reset, then test again
echo "2️⃣  Waiting 10 seconds, then testing again..."
sleep 10

rm -f "$TMPDIR"/result_*

start_time=$(date +%s%N)

# Send 50 more requests
seq 1 50 | xargs -P 10 -I {} sh -c "
    if curl -s -f -o /dev/null -w '%{http_code}' '${BASE_URL}/health' 2>/dev/null | grep -q '200'; then
        echo 'success' > '$TMPDIR/result_{}'
    else
        echo 'failed' > '$TMPDIR/result_{}'
    fi
"

wait

end_time=$(date +%s%N)
success2=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^success$" 2>/dev/null | wc -l)
failed2=$(ls -1 "$TMPDIR"/result_* 2>/dev/null | xargs grep -l "^failed$" 2>/dev/null | wc -l)

elapsed_ns=$((end_time - start_time))
elapsed2=$(echo "scale=2; $elapsed_ns / 1000000000" | bc)

if [ $(echo "$elapsed2 > 0" | bc) -eq 1 ] && [ $success2 -gt 0 ]; then
    rps2=$(echo "scale=2; $success2 / $elapsed2" | bc)
else
    rps2="0.00"
fi

echo "   ✅ Success: $success2"
echo "   ❌ Failed: $failed2"
echo "   ⏱️  Time: ${elapsed2}s"
echo "   📈 RPS: $rps2"
echo ""

echo "✅ Test complete!"
echo ""
echo "Note: To test without rate limits, temporarily disable rate limiting in router.ex"
echo "      Or test from multiple IPs to get 100 requests/IP"


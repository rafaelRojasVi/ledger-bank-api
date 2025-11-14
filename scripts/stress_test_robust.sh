#!/bin/bash

# Robust Stress Test - Handles high concurrency better
# Usage: bash scripts/stress_test_robust.sh [requests] [concurrent]

BASE_URL="http://localhost:4000/api"
REQUESTS=${1:-200}
CONCURRENT=${2:-50}

echo "🔥 Robust Stress Test"
echo "===================="
echo "Requests: $REQUESTS"
echo "Concurrent: $CONCURRENT"
echo ""

# Create temp directory for results
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Start timer
start_time=$(date +%s%N)

# Make requests - each writes to its own file
seq 1 $REQUESTS | xargs -P $CONCURRENT -I {} sh -c "
    if curl -s -f -o /dev/null '${BASE_URL}/health' 2>/dev/null; then
        touch '$TMPDIR/success_{}'
    else
        touch '$TMPDIR/failed_{}'
    fi
"

# Wait for all to complete
wait

# End timer
end_time=$(date +%s%N)

# Count results
success=$(ls -1 "$TMPDIR"/success_* 2>/dev/null | wc -l)
failed=$(ls -1 "$TMPDIR"/failed_* 2>/dev/null | wc -l)

# Calculate elapsed time
elapsed_ns=$((end_time - start_time))
elapsed=$(echo "scale=2; $elapsed_ns / 1000000000" | bc)

# Calculate RPS
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

# Show server distribution
echo "Server distribution (last 100 requests):"
docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 500 2>/dev/null | \
    grep "GET /api/health$" | \
    tail -100 | \
    awk '{print $1}' | \
    sort | uniq -c | \
    awk '{total+=$1} END {for (i=1; i<=NR; i++) {if (i==1) lines[NR]=$0; if (i==NR) {split($0,arr," "); printf "   %s: %d requests (%.1f%%)\n", arr[2], arr[1], (arr[1]*100)/total}}}'

echo ""
echo "✅ Test complete!"


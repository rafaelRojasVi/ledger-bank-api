#!/bin/bash

# Quick Stress Test - Simplest and most reliable version
# Usage: bash scripts/stress_test_quick.sh [requests] [concurrent]

BASE_URL="http://localhost:4000/api"
REQUESTS=${1:-200}
CONCURRENT=${2:-50}

echo "🔥 Quick Stress Test"
echo "==================="
echo "Requests: $REQUESTS"
echo "Concurrent: $CONCURRENT"
echo ""

# Start timer
start=$(date +%s.%N)

# Create temp directory for results
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Make requests
seq 1 $REQUESTS | xargs -P $CONCURRENT -I {} sh -c "
    if curl -s -f -o /dev/null '${BASE_URL}/health' 2>/dev/null; then
        echo 'success' >> '$TMPDIR/results'
    else
        echo 'fail' >> '$TMPDIR/results'
    fi
"

# End timer
end=$(date +%s.%N)

# Count results
success=$(grep -c 'success' "$TMPDIR/results" 2>/dev/null || echo 0)
failed=$(grep -c 'fail' "$TMPDIR/results" 2>/dev/null || echo 0)

# Calculate time and RPS
elapsed=$(echo "$end - $start" | bc)
if [ $(echo "$elapsed > 0" | bc) -eq 1 ]; then
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
docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 --tail 300 2>/dev/null | \
    grep "GET /api/health$" | \
    tail -100 | \
    awk '{print $1}' | \
    sort | uniq -c | \
    awk '{printf "   %s: %d requests (%.1f%%)\n", $2, $1, ($1*100)/100}'

echo ""
echo "✅ Test complete!"


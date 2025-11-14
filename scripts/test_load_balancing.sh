#!/bin/bash

# Test script to verify load balancing is working
# Shows which server handles each request

echo "🧪 Testing Load Balancing"
echo "========================"
echo ""
echo "Making 10 requests to see load distribution..."
echo ""

BASE_URL="http://localhost:4000/api/health"

for i in {1..10}; do
    echo -n "Request $i: "
    # Get the response and extract server info if available
    response=$(curl -s "$BASE_URL")
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$status" == "ok" ]; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    sleep 0.5
done

echo ""
echo "📊 Checking server logs to see distribution..."
echo "Run this command to see which server handled each request:"
echo "  docker compose -f docker-compose.multi-node.yml logs web1 web2 web3 | grep 'GET /api/health'"
echo ""

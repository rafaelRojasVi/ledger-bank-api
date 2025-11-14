#!/bin/bash

# Test script to verify failover works
# Stops one server and verifies others continue serving

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:4000/api/health"

echo "🔄 Testing Failover (High Availability)"
echo "========================================"
echo ""

# Test 1: Verify all servers are up
echo "1️⃣  Checking initial state..."
for i in 1 2 3; do
    status=$(docker compose -f docker-compose.multi-node.yml ps web$i --format json | jq -r '.State')
    if [ "$status" == "running" ]; then
        echo -e "   ${GREEN}✅ web$i is running${NC}"
    else
        echo -e "   ${RED}❌ web$i is not running${NC}"
        exit 1
    fi
done

echo ""
echo "2️⃣  Testing API while all servers are up..."
response=$(curl -s -f "$BASE_URL" || echo "FAILED")
if [[ "$response" == *"status"* ]]; then
    echo -e "   ${GREEN}✅ API is responding${NC}"
else
    echo -e "   ${RED}❌ API is not responding${NC}"
    exit 1
fi

echo ""
echo "3️⃣  Stopping web3 to test failover..."
docker compose -f docker-compose.multi-node.yml stop web3
sleep 3

echo ""
echo "4️⃣  Verifying API still works with 2 servers..."
for i in {1..5}; do
    response=$(curl -s -f "$BASE_URL" || echo "FAILED")
    if [[ "$response" == *"status"* ]]; then
        echo -e "   ${GREEN}✅ Request $i: OK${NC}"
    else
        echo -e "   ${RED}❌ Request $i: FAILED${NC}"
        docker compose -f docker-compose.multi-node.yml start web3
        exit 1
    fi
    sleep 0.5
done

echo ""
echo "5️⃣  Restarting web3..."
docker compose -f docker-compose.multi-node.yml start web3
sleep 5

echo ""
echo "6️⃣  Verifying all 3 servers are back online..."
for i in {1..3}; do
    status=$(docker compose -f docker-compose.multi-node.yml ps web$i --format json | jq -r '.State')
    if [ "$status" == "running" ]; then
        echo -e "   ${GREEN}✅ web$i is running${NC}"
    else
        echo -e "   ${YELLOW}⚠️  web$i is starting...${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Failover test completed successfully!${NC}"
echo "   The load balancer automatically routed traffic to healthy servers."

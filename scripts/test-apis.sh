#!/bin/bash
# Tessera API Testing Script

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Tessera API Testing${NC}"
echo "==============================="

# Function to test an endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="$3"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/curl_response "$url" 2>/dev/null)
    http_code="${response: -3}"
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ OK (${http_code})${NC}"
        if [ -f /tmp/curl_response ] && [ -s /tmp/curl_response ]; then
            # Show first line of response if it exists
            head -1 /tmp/curl_response | cut -c1-80
        fi
    else
        echo -e "${RED}❌ FAILED (${http_code})${NC}"
        if [ -f /tmp/curl_response ]; then
            echo "Response: $(cat /tmp/curl_response)"
        fi
    fi
    echo ""
}

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 3

echo -e "${BLUE}Testing Health Endpoints:${NC}"
test_endpoint "Perl API Server Health" "http://127.0.0.1:3000/health" "200"
test_endpoint "Gemini Service Health" "http://127.0.0.1:8001/health" "200"
test_endpoint "Embedding Service Health" "http://127.0.0.1:8002/health" "200"

echo -e "${BLUE}Testing API Documentation:${NC}"
test_endpoint "Gemini Service Docs" "http://127.0.0.1:8001/docs" "200"
test_endpoint "Embedding Service Docs" "http://127.0.0.1:8002/docs" "200"

echo -e "${BLUE}Testing Main API Endpoints:${NC}"
test_endpoint "Perl API Root" "http://127.0.0.1:3000/" "200"
test_endpoint "Stats Endpoint" "http://127.0.0.1:3000/stats" "200"

echo -e "${BLUE}Testing Service-Specific Endpoints:${NC}"
test_endpoint "Gemini Conversations" "http://127.0.0.1:8001/conversations" "200"
test_endpoint "Embedding Stats" "http://127.0.0.1:8002/stats" "200"

# Test a simple chat if API key is available
if [ ! -z "$GEMINI_API_KEY" ] || [ -f "../backend/python-backend/.env" ]; then
    echo -e "${BLUE}Testing Chat Functionality:${NC}"
    
    # Create a simple chat request
    chat_payload='{"conversation_id": "test_conv", "message": "Hello, what can you tell me about this knowledge base?"}'
    
    echo -n "Testing Gemini Chat... "
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$chat_payload" \
        -o /tmp/chat_response \
        "http://127.0.0.1:8001/chat" 2>/dev/null)
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Chat OK${NC}"
        if [ -f /tmp/chat_response ]; then
            echo "Response preview: $(jq -r '.message' /tmp/chat_response 2>/dev/null | cut -c1-100)..."
        fi
    else
        echo -e "${YELLOW}⚠️  Chat endpoint responded with ${http_code}${NC}"
        echo "This might be expected if no API key is configured"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping chat test - no GEMINI_API_KEY found${NC}"
fi

echo ""
echo -e "${BLUE}🏁 API Testing Complete${NC}"
echo -e "View full API documentation at:"
echo -e "  ${YELLOW}• Gemini Service: http://127.0.0.1:8001/docs${NC}"
echo -e "  ${YELLOW}• Embedding Service: http://127.0.0.1:8002/docs${NC}"

# Cleanup
rm -f /tmp/curl_response /tmp/chat_response

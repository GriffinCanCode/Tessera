#!/bin/bash
# Tessera Modern Gemini Service Startup Script

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Tessera Modern Gemini Service v2.0${NC}"
echo "=============================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Error: Virtual environment not found${NC}"
    echo "Please run setup.py first"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Check for API key
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${YELLOW}Warning: GEMINI_API_KEY environment variable not set${NC}"
    echo "Please set it with: export GEMINI_API_KEY='your-key-here'"
    echo "Or create a .env file in this directory"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if .env file exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Found .env file for configuration${NC}"
fi

# Start the modern service
echo -e "${GREEN}Starting Tessera Modern Gemini Service...${NC}"
echo "Features: Pydantic v2, DI, Structured Logging, RAG-Ready"
echo "Press Ctrl+C to stop"
echo ""

python gemini_service.py

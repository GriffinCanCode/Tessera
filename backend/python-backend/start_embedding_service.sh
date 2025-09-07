#!/bin/bash
# Tessera Embedding Service Startup Script

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m' 
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Tessera Embedding Service v1.0${NC}"
echo "============================================"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Error: Virtual environment not found${NC}"
    echo "Please run setup.py first"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Check database exists
DB_PATH="../data/tessera_knowledge.db"
if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}Warning: Database not found at $DB_PATH${NC}"
    echo "The embedding service will start but won't find articles to process"
    echo "Make sure to crawl some articles first"
    echo ""
fi

# Check if .env file exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Found .env file for configuration${NC}"
fi

echo -e "${GREEN}Starting Tessera Embedding Service...${NC}"
echo "Features: Sentence Transformers, Background Processing, SQLite Integration"
echo "API Docs: http://127.0.0.1:8002/docs"
echo "Press Ctrl+C to stop"
echo ""

python embedding_service.py

#!/bin/bash
# Tessera Data Ingestion Service Startup Script

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Tessera Data Ingestion Service${NC}"
echo "=================================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}❌ Error: Virtual environment not found${NC}"
    echo "Please run: python3 setup.py"
    exit 1
fi

# Check database exists
DB_PATH="../data/tessera_knowledge.db"
if [ ! -f "$DB_PATH" ]; then
    echo -e "${BLUE}ℹ️  Note: Database not found at $DB_PATH${NC}"
    echo "The service will start but won't have data until you crawl articles"
    echo ""
fi

echo -e "${GREEN}🔄 Starting Data Ingestion Service...${NC}"
echo ""

# Activate virtual environment
source venv/bin/activate

# Install additional dependencies if needed
echo -e "${BLUE}📦 Checking dependencies...${NC}"
pip install -q yt-dlp youtube-transcript-api PyPDF2 python-docx ebooklib beautifulsoup4 readability-lxml aiofiles nltk spacy

# Download spaCy model if not present
python -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null || {
    echo -e "${YELLOW}📥 Downloading spaCy English model...${NC}"
    python -m spacy download en_core_web_sm
}

# Start the service
echo -e "${BLUE}🔧 Starting Data Ingestion Service (Port 8003)...${NC}"
python data_ingestion_service.py

echo -e "${GREEN}✅ Data Ingestion Service started successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Available endpoints:${NC}"
echo "  - POST /ingest/youtube - Ingest YouTube video transcripts"
echo "  - POST /ingest/article - Ingest web articles"
echo "  - POST /ingest/book - Upload and ingest books/documents"
echo "  - POST /ingest/poetry - Ingest poetry and creative writing"
echo "  - GET /health - Service health check"
echo ""
echo -e "${YELLOW}💡 Access the service at: http://127.0.0.1:8003${NC}"

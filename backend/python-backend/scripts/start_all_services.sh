#!/bin/bash
# Tessera Complete RAG System Startup Script

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Tessera RAG System - Complete Setup${NC}"
echo "=================================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${RED}❌ Error: Virtual environment not found${NC}"
    echo "Please run: python3 setup.py"
    exit 1
fi

# Check for API key
if [ -z "$GEMINI_API_KEY" ] && [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Warning: No GEMINI_API_KEY found${NC}"
    echo "Set it with: export GEMINI_API_KEY='your-key-here'"
    echo "Or create a .env file in this directory"
    echo ""
fi

# Check database exists
DB_PATH="../data/tessera_knowledge.db"
if [ ! -f "$DB_PATH" ]; then
    echo -e "${BLUE}ℹ️  Note: Database not found at $DB_PATH${NC}"
    echo "The services will start but won't have data until you crawl articles"
    echo ""
fi

echo -e "${GREEN}🔄 Starting Services in Background...${NC}"
echo ""

# Activate virtual environment
source venv/bin/activate

# Start embedding service in background
echo -e "${BLUE}📊 Starting Embedding Service (Port 8002)...${NC}"
nohup python -m src.services.embedding_service > embedding_service.log 2>&1 &
EMBEDDING_PID=$!
echo "   - PID: $EMBEDDING_PID"
echo "   - Log: embedding_service.log"

# Wait a moment for embedding service to start
sleep 3

# Start Gemini service in background  
echo -e "${BLUE}🤖 Starting Modern Gemini Service (Port 8001)...${NC}"
nohup python -m src.services.gemini_service > gemini_service.log 2>&1 &
GEMINI_PID=$!
echo "   - PID: $GEMINI_PID"
echo "   - Log: gemini_service.log"

# Wait a moment for Gemini service to start
sleep 3

# Start Data Ingestion service in background
echo -e "${BLUE}🔧 Starting Data Ingestion Service (Port 8003)...${NC}"
nohup python -m src.services.data_ingestion_service > data_ingestion_service.log 2>&1 &
INGESTION_PID=$!
echo "   - PID: $INGESTION_PID"
echo "   - Log: data_ingestion_service.log"

# Wait for services to fully start
echo ""
echo -e "${YELLOW}⏳ Waiting for services to initialize...${NC}"
sleep 5

# Check if services are running
echo ""
echo -e "${GREEN}🔍 Service Status Check:${NC}"

# Check embedding service
if curl -s http://127.0.0.1:8002/health > /dev/null; then
    echo -e "   ✅ Embedding Service: ${GREEN}Running${NC}"
    echo -e "      📖 API Docs: http://127.0.0.1:8002/docs"
else
    echo -e "   ❌ Embedding Service: ${RED}Not responding${NC}"
fi

# Check Gemini service
if curl -s http://127.0.0.1:8001/health > /dev/null; then
    echo -e "   ✅ Gemini Service: ${GREEN}Running${NC}" 
    echo -e "      📖 API Docs: http://127.0.0.1:8001/docs"
else
    echo -e "   ❌ Gemini Service: ${RED}Not responding${NC}"
fi

# Check Data Ingestion service
if curl -s http://127.0.0.1:8003/health > /dev/null; then
    echo -e "   ✅ Data Ingestion Service: ${GREEN}Running${NC}"
    echo -e "      📖 API Docs: http://127.0.0.1:8003/docs"
else
    echo -e "   ❌ Data Ingestion Service: ${RED}Not responding${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Optimized RAG System Ready!${NC}"
echo ""
echo -e "${BLUE}📚 What's Running:${NC}"
echo "   • Embedding Service: Sentence Transformers + SQLite Vector Search + Connection Pool"
echo "   • Gemini Service: Modern LLM with RAG Integration + Async Processing"
echo "   • Data Ingestion Service: YouTube, Books, Articles, Poetry + Optimized DB Pool"
echo "   • Background Processing: Auto-embedding new article chunks"
echo "   • Unified Database: Single SQLite DB with WAL mode and connection pooling"
echo ""
echo -e "${BLUE}🚀 Performance Optimizations Active:${NC}"
echo "   • Database Connection Pooling (15 connections per service)"
echo "   • SQLite WAL mode with memory mapping"
echo "   • Query result caching with TTL"
echo "   • Async HTTP client connections"
echo "   • Service health monitoring"
echo ""
echo -e "${BLUE}📊 Monitor Performance:${NC}"
echo "   • Data Ingestion: curl http://127.0.0.1:8003/health/detailed"
echo "   • Embedding Service: curl http://127.0.0.1:8002/health/detailed"
echo "   • Gemini Service: curl http://127.0.0.1:8001/health/detailed"
echo "   • All services have DB connection pooling and caching active"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "   1. Start the optimized Perl API server: cd ../perl-backend/script && perl api_server.pl"
echo "   2. Use the frontend to crawl articles and chat"
echo "   3. Monitor logs: tail -f *.log"
echo ""
echo -e "${BLUE}🛑 To Stop Services:${NC}"
echo "   kill $EMBEDDING_PID $GEMINI_PID $INGESTION_PID"
echo "   Or run: pkill -f 'python.*service.py'"
echo ""

# Save PIDs for easy cleanup
echo "$EMBEDDING_PID $GEMINI_PID $INGESTION_PID" > service_pids.txt
echo -e "${YELLOW}📝 Service PIDs saved to: service_pids.txt${NC}"

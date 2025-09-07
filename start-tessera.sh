#!/bin/bash
# Tessera Complete Startup Script
# Builds Zig libraries and starts all backend services

set -e

echo "🚀 Starting Tessera Knowledge System"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${2}[$(date +'%H:%M:%S')] $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "backend" ]; then
    log "❌ Please run this script from the Tessera project root" $RED
    exit 1
fi

# Step 1: Check system requirements
log "🔍 Checking system requirements..." $BLUE

check_command() {
    if command -v $1 &> /dev/null; then
        log "✅ $1: $(command -v $1)" $GREEN
        return 0
    else
        if [ "$2" = "required" ]; then
            log "❌ $1 is required but not found" $RED
            exit 1
        else
            log "⚠️  $1: Not available (optional)" $YELLOW
            return 1
        fi
    fi
}

check_command "node" "required"
check_command "npm" "required"
check_command "perl" "required"
check_command "python3" "required"
check_command "R" "optional"
ZIG_AVAILABLE=false
if check_command "zig" "optional"; then
    ZIG_AVAILABLE=true
fi

# Step 2: Build Zig libraries if available
if [ "$ZIG_AVAILABLE" = true ]; then
    log "🔨 Building Zig performance libraries..." $BLUE
    
    if [ -d "backend/zig-backend" ]; then
        cd backend/zig-backend
        
        if ./scripts/build.sh; then
            log "✅ Zig libraries built successfully" $GREEN
            ZIG_BUILT=true
        else
            log "❌ Zig build failed, continuing with fallbacks" $YELLOW
            ZIG_BUILT=false
        fi
        
        cd ../..
    else
        log "⚠️  Zig backend directory not found" $YELLOW
        ZIG_BUILT=false
    fi
else
    log "⚠️  Zig not available, using fallback implementations" $YELLOW
    log "💡 Install Zig from https://ziglang.org/ for 10-100x performance boost" $BLUE
    ZIG_BUILT=false
fi

# Step 3: Install frontend dependencies
log "📦 Installing frontend dependencies..." $BLUE
if [ -f "package-lock.json" ]; then
    npm ci
else
    npm install
fi

# Step 4: Setup Python backend
log "🐍 Setting up Python backend..." $BLUE
cd backend/python-backend

if [ ! -d "venv" ]; then
    log "Creating Python virtual environment..." $BLUE
    python3 -m venv venv
fi

log "Installing Python dependencies..." $BLUE
source venv/bin/activate
pip install -r requirements.txt

# Check for API key
if [ ! -f ".env" ]; then
    log "⚠️  No .env file found. Creating template..." $YELLOW
    echo "# Tessera Configuration" > .env
    echo "GEMINI_API_KEY=your_api_key_here" >> .env
    echo "# Get your API key from: https://aistudio.google.com/app/apikey" >> .env
    log "📝 Please edit backend/python-backend/.env with your Gemini API key" $YELLOW
fi

cd ../..

# Step 5: Test integrations
if [ "$ZIG_BUILT" = true ]; then
    log "🧪 Testing Zig integrations..." $BLUE
    cd backend/zig-backend
    if python3 examples/test_integration.py; then
        log "✅ All integrations working" $GREEN
    else
        log "⚠️  Some integration tests failed, but continuing..." $YELLOW
    fi
    cd ../..
fi

# Step 6: Start backend services
log "🚀 Starting backend services..." $BLUE
node scripts/start-backend.js &
BACKEND_PID=$!

# Wait a moment for services to start
sleep 3

# Step 7: Start frontend (optional)
read -p "Start frontend development server? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "🌐 Starting frontend..." $BLUE
    npm run dev &
    FRONTEND_PID=$!
fi

# Summary
echo ""
log "🎉 Tessera startup complete!" $GREEN
echo "=================================="
log "🔗 API Gateway: http://localhost:3000" $GREEN
log "🤖 Gemini Chat: http://localhost:8001" $GREEN  
log "🔍 Embedding Search: http://localhost:8002" $GREEN
log "📊 Data Ingestion: http://localhost:8003" $GREEN

if [ "$ZIG_BUILT" = true ]; then
    log "⚡ Zig acceleration: ENABLED (10-100x faster vector operations)" $GREEN
else
    log "🔄 Zig acceleration: DISABLED (using fallback implementations)" $YELLOW
fi

if [ ! -z "$FRONTEND_PID" ]; then
    log "🌐 Frontend: http://localhost:5173" $GREEN
fi

echo ""
log "💡 Tips:" $BLUE
log "   - Check logs/ directory for detailed service logs" $BLUE
log "   - Use Ctrl+C to stop all services" $BLUE
if [ "$ZIG_BUILT" = false ] && [ "$ZIG_AVAILABLE" = false ]; then
    log "   - Install Zig for massive performance improvements" $BLUE
fi

# Cleanup function
cleanup() {
    log "🛑 Shutting down services..." $YELLOW
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    log "👋 Tessera stopped" $GREEN
    exit 0
}

# Handle Ctrl+C
trap cleanup SIGINT SIGTERM

# Wait for user to stop
log "✨ Tessera is running! Press Ctrl+C to stop." $GREEN
wait

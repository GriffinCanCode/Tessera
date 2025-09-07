#!/bin/bash

# Tessera Logging Dependencies Installation Script
# Installs logging libraries for all languages in the stack

set -e

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Installing Tessera Logging Dependencies..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "backend" ]; then
    log_error "Please run this script from the project root directory"
    exit 1
fi

# Install Python dependencies
log_step "Installing Python logging dependencies..."
cd backend/python-backend

if [ -d "venv" ]; then
    log_info "Activating Python virtual environment..."
    source venv/bin/activate
else
    log_warn "No virtual environment found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
fi

log_info "Installing Python packages..."
pip install --upgrade pip
pip install rich==13.9.4 colorlog==6.8.2

if [ $? -eq 0 ]; then
    log_info "✅ Python logging dependencies installed successfully"
else
    log_error "❌ Failed to install Python dependencies"
    exit 1
fi

cd ../..

# Install Perl dependencies
log_step "Installing Perl logging dependencies..."
cd backend/perl-backend

log_info "Installing Perl modules..."
if command -v cpanm &> /dev/null; then
    cpanm --installdeps .
    cpanm Log::Log4perl::Appender::ScreenColoredLevels Term::ANSIColor
else
    log_warn "cpanm not found, using cpan..."
    cpan Log::Log4perl::Appender::ScreenColoredLevels Term::ANSIColor
fi

if [ $? -eq 0 ]; then
    log_info "✅ Perl logging dependencies installed successfully"
else
    log_error "❌ Failed to install Perl dependencies"
    exit 1
fi

cd ../..

# Install Node.js dependencies
log_step "Installing Node.js logging dependencies..."
cd frontend

log_info "Installing npm packages..."
npm install loglevel@1.9.2 loglevel-plugin-prefix@0.8.4

if [ $? -eq 0 ]; then
    log_info "✅ Node.js logging dependencies installed successfully"
else
    log_error "❌ Failed to install Node.js dependencies"
    exit 1
fi

cd ..

# Install R dependencies
log_step "Installing R logging dependencies..."
cd backend/r-backend

log_info "Installing R packages..."
Rscript -e "
required_packages <- c('futile.logger', 'jsonlite', 'crayon')
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,'Package'])]

if(length(missing_packages) > 0) {
    cat('Installing missing R packages:', paste(missing_packages, collapse=', '), '\n')
    install.packages(missing_packages, repos = 'https://cran.r-project.org')
    cat('R packages installed successfully\n')
} else {
    cat('All R packages already installed\n')
}
"

if [ $? -eq 0 ]; then
    log_info "✅ R logging dependencies installed successfully"
else
    log_error "❌ Failed to install R dependencies"
    exit 1
fi

cd ../..

# Create logs directory structure
log_step "Creating log directory structure..."
mkdir -p logs
mkdir -p backend/python-backend/logs
mkdir -p backend/perl-backend/logs
mkdir -p backend/r-backend/logs

log_info "✅ Log directories created"

# Set up log rotation (if logrotate is available)
if command -v logrotate &> /dev/null; then
    log_step "Setting up log rotation..."
    
    cat > /tmp/tessera-logrotate << EOF
$PROJECT_ROOT/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}

$PROJECT_ROOT/backend/*/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
    
    log_info "Log rotation configuration created at /tmp/tessera-logrotate"
    log_info "To enable, copy to /etc/logrotate.d/ (requires sudo)"
else
    log_warn "logrotate not found, skipping log rotation setup"
fi

# Create a simple log viewer script
log_step "Creating log viewer utility..."
cat > scripts/view-logs.sh << 'EOF'
#!/bin/bash

# Tessera Log Viewer
# Simple utility to view and tail logs with colors

LOGS_DIR="logs"
BACKEND_LOGS="backend/*/logs"

show_help() {
    echo "Tessera Log Viewer"
    echo ""
    echo "Usage: $0 [OPTIONS] [SERVICE]"
    echo ""
    echo "Options:"
    echo "  -f, --follow     Follow log output (like tail -f)"
    echo "  -l, --list       List available log files"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Services:"
    echo "  api              API server logs"
    echo "  data             Data ingestion logs"
    echo "  embedding        Embedding service logs"
    echo "  gemini           Gemini service logs"
    echo "  graph            Knowledge graph logs"
    echo "  all              All logs combined"
    echo ""
    echo "Examples:"
    echo "  $0 -l            List all log files"
    echo "  $0 api           Show API server logs"
    echo "  $0 -f data       Follow data ingestion logs"
    echo "  $0 all           Show all logs"
}

list_logs() {
    echo "Available log files:"
    find $LOGS_DIR $BACKEND_LOGS -name "*.log" 2>/dev/null | sort
}

view_logs() {
    local service="$1"
    local follow="$2"
    
    case "$service" in
        "api")
            files="backend/perl-backend/logs/api_server.log"
            ;;
        "data")
            files="backend/python-backend/logs/data_ingestion.log"
            ;;
        "embedding")
            files="backend/python-backend/logs/embedding_service.log"
            ;;
        "gemini")
            files="backend/python-backend/logs/gemini_service.log"
            ;;
        "graph")
            files="backend/perl-backend/logs/knowledge_graph.log"
            ;;
        "all")
            files=$(find $LOGS_DIR $BACKEND_LOGS -name "*.log" 2>/dev/null | tr '\n' ' ')
            ;;
        *)
            echo "Unknown service: $service"
            show_help
            exit 1
            ;;
    esac
    
    if [ "$follow" = "true" ]; then
        tail -f $files
    else
        cat $files | tail -100
    fi
}

# Parse command line arguments
FOLLOW=false
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -l|--list)
            list_logs
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

if [ -z "$SERVICE" ]; then
    show_help
    exit 1
fi

view_logs "$SERVICE" "$FOLLOW"
EOF

chmod +x scripts/view-logs.sh
log_info "✅ Log viewer utility created at scripts/view-logs.sh"

# Summary
echo ""
log_info "🎉 Tessera Logging System Installation Complete!"
echo ""
echo "📋 Summary:"
echo "  ✅ Python logging: rich, colorlog, structlog"
echo "  ✅ Perl logging: Log::Log4perl with colors"
echo "  ✅ Node.js logging: loglevel with prefixes"
echo "  ✅ R logging: futile.logger with colors"
echo "  ✅ Log directories created"
echo "  ✅ Log viewer utility installed"
echo ""
echo "🚀 Next steps:"
echo "  1. Restart your services to use the new logging"
echo "  2. Use 'scripts/view-logs.sh -l' to see available logs"
echo "  3. Use 'scripts/view-logs.sh -f api' to follow API logs"
echo "  4. Check logging-config.yaml for configuration options"
echo ""
echo "📚 Documentation:"
echo "  - Python: Use get_logger('service_name') from logging_config.py"
echo "  - Perl: Use Tessera::Logger->get_logger('service_name')"
echo "  - Frontend: Use getLogger('component_name') from utils/logger.ts"
echo "  - R: Source tessera_logger.R and use tessera_logger$info()"
echo ""
log_info "Happy logging! 🎯"

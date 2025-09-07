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

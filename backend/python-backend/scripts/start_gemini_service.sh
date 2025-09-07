#!/bin/bash
# Tessera Gemini Service Startup Script

# Activate virtual environment
source venv/bin/activate

# Check for API key
if [ -z "$GEMINI_API_KEY" ]; then
    echo "Error: GEMINI_API_KEY environment variable not set"
    echo "Please set it with: export GEMINI_API_KEY='your-key-here'"
    exit 1
fi

# Start the service
echo "Starting Tessera Gemini Service..."
python -m src.services.gemini_service

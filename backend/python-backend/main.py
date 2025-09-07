#!/usr/bin/env python3
"""
Main entry point for Tessera Python Backend services
Usage: python main.py [service_name]
Services: gemini, embedding, data_ingestion, all
"""

import sys
import os
import subprocess
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: python main.py [service_name]")
        print("Services: gemini, embedding, data_ingestion, all")
        sys.exit(1)
    
    service = sys.argv[1].lower()
    
    # Change to the python-backend directory
    backend_dir = Path(__file__).parent
    os.chdir(backend_dir)
    
    if service == "gemini":
        subprocess.run([sys.executable, "-m", "src.services.gemini_service"])
    elif service == "embedding":
        subprocess.run([sys.executable, "-m", "src.services.embedding_service"])
    elif service == "data_ingestion" or service == "ingestion":
        subprocess.run([sys.executable, "-m", "src.services.data_ingestion_service"])
    elif service == "all":
        print("Starting all services...")
        subprocess.run(["bash", "scripts/start_all_services.sh"])
    else:
        print(f"Unknown service: {service}")
        print("Available services: gemini, embedding, data_ingestion, all")
        sys.exit(1)

if __name__ == "__main__":
    main()

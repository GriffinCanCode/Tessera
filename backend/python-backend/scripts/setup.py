#!/usr/bin/env python3
"""
Setup script for Tessera Gemini Bot service
"""

import os
import subprocess
import sys
from pathlib import Path

def run_command(command, description=""):
    """Run a command and handle errors"""
    print(f"\n{'='*50}")
    print(f"Running: {description or command}")
    print(f"{'='*50}")
    
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        if e.stdout:
            print(f"Stdout: {e.stdout}")
        if e.stderr:
            print(f"Stderr: {e.stderr}")
        return False

def check_python_version():
    """Check if Python version is adequate"""
    if sys.version_info < (3, 8):
        print("Error: Python 3.8 or higher is required")
        sys.exit(1)
    print(f"✓ Python version: {sys.version}")

def setup_virtual_environment():
    """Set up Python virtual environment"""
    venv_path = Path("venv")
    
    if venv_path.exists():
        print("✓ Virtual environment already exists")
        return True
    
    print("Creating virtual environment...")
    if not run_command(f"{sys.executable} -m venv venv", "Creating virtual environment"):
        return False
    
    print("✓ Virtual environment created")
    return True

def install_dependencies():
    """Install Python dependencies"""
    pip_command = "venv/bin/pip" if os.name != 'nt' else "venv\\Scripts\\pip"
    
    print("Installing dependencies...")
    if not run_command(f"{pip_command} install --upgrade pip", "Upgrading pip"):
        return False
    
    if not run_command(f"{pip_command} install -r requirements.txt", "Installing requirements"):
        return False
    
    print("✓ Dependencies installed")
    return True

def check_gemini_api_key():
    """Check if Gemini API key is set"""
    api_key = os.getenv('GEMINI_API_KEY')
    
    if not api_key:
        print("\n⚠️  WARNING: GEMINI_API_KEY environment variable not set!")
        print("\nTo set your API key:")
        print("1. Get your API key from: https://aistudio.google.com/app/apikey")
        print("2. Set the environment variable:")
        print("   export GEMINI_API_KEY='your-api-key-here'")
        print("3. Add it to your ~/.bashrc or ~/.zshrc for persistence")
        return False
    
    print("✓ GEMINI_API_KEY is set")
    return True

def create_startup_script():
    """Create convenience startup script"""
    script_content = """#!/bin/bash
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
"""
    
    with open("start_gemini_service.sh", "w") as f:
        f.write(script_content)
    
    os.chmod("start_gemini_service.sh", 0o755)
    print("✓ Startup script created: start_gemini_service.sh")

def main():
    """Main setup function"""
    print("Tessera Gemini Bot Setup")
    print("=" * 40)
    
    # Change to python-backend directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    # Check Python version
    check_python_version()
    
    # Setup virtual environment
    if not setup_virtual_environment():
        print("❌ Failed to set up virtual environment")
        sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        print("❌ Failed to install dependencies")
        sys.exit(1)
    
    # Check API key
    api_key_ok = check_gemini_api_key()
    
    # Create startup script
    create_startup_script()
    
    print("\n" + "=" * 50)
    print("✅ Setup completed successfully!")
    print("=" * 50)
    
    if not api_key_ok:
        print("\n⚠️  Don't forget to set your GEMINI_API_KEY!")
    
    print("\nTo start the Gemini service:")
    print("  ./start_gemini_service.sh")
    print("\nOr manually:")
    print("  source venv/bin/activate")
    print("  python gemini_service.py")
    
    print("\nThe service will run on http://127.0.0.1:8001")
    print("Make sure to start it before using the knowledge bot features.")
    print("\nFeatures in v2.0:")
    print("- Modern Pydantic v2 patterns with validation")
    print("- Dependency injection and async context managers") 
    print("- Structured logging with better observability")
    print("- Configuration management via environment variables")
    print("- Retry logic and proper error handling")
    print("- Ready for RAG integration")
    print("\nTo use the modern service:")
    print("  python main.py gemini")
    print("  # or python -m src.services.gemini_service")

if __name__ == "__main__":
    main()

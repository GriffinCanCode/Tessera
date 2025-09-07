#!/usr/bin/env python3
"""
Gemini Service Issue Fix Script
Addresses the identified performance and API key issues
"""

import os
import asyncio
import aiohttp
from pathlib import Path


def check_and_fix_env_file():
    """Check and provide guidance for fixing the .env file"""
    print("🔧 FIXING GEMINI SERVICE ISSUES")
    print("=" * 50)
    
    env_file = Path(".env")
    if not env_file.exists():
        print("❌ .env file not found!")
        create_env_template()
        return False
    
    # Read current .env
    with open(env_file, 'r') as f:
        content = f.read()
    
    print("📋 Current .env file analysis:")
    
    # Check for GEMINI_API_KEY
    gemini_key_line = None
    for line in content.split('\n'):
        if line.startswith('GEMINI_API_KEY='):
            gemini_key_line = line
            break
    
    if not gemini_key_line:
        print("❌ GEMINI_API_KEY not found in .env file")
        print("🔧 Add this line to your .env file:")
        print("   GEMINI_API_KEY=your_actual_api_key_here")
        return False
    
    # Extract the key value
    key_value = gemini_key_line.split('=', 1)[1].strip().strip('"\'')
    
    print(f"🔑 Found GEMINI_API_KEY: {key_value[:20]}...")
    
    # Check for common issues
    issues_found = []
    
    if len(key_value) < 30:
        issues_found.append("API key appears too short")
    
    if key_value.endswith('%'):
        issues_found.append("API key ends with '%' - likely truncated")
    
    if 'your_api_key' in key_value.lower():
        issues_found.append("API key appears to be a placeholder")
    
    if not key_value.startswith('AIza'):
        issues_found.append("Gemini API keys typically start with 'AIza'")
    
    if issues_found:
        print("❌ Issues found with API key:")
        for issue in issues_found:
            print(f"   - {issue}")
        
        print("\n🔧 TO FIX:")
        print("1. Go to https://aistudio.google.com/app/apikey")
        print("2. Create a new API key")
        print("3. Replace the GEMINI_API_KEY value in .env file")
        print("4. Restart the services: npm run backend")
        return False
    
    print("✅ API key format looks correct")
    return True


def create_env_template():
    """Create a template .env file"""
    template = """# Tessera API Keys
GEMINI_API_KEY=your_gemini_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Service Configuration
GEMINI_MODEL=gemini-2.0-flash-exp
GEMINI_TEMPERATURE=0.7
GEMINI_MAX_TOKENS=8192
"""
    
    with open('.env', 'w') as f:
        f.write(template)
    
    print("📝 Created .env template file")
    print("🔧 Please edit .env and add your actual API keys")


async def test_fixed_service():
    """Test the service after fixes"""
    print("\n🧪 Testing Fixed Service...")
    
    async with aiohttp.ClientSession() as session:
        
        # Test health
        try:
            async with session.get("http://127.0.0.1:8001/health", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                if resp.status == 200:
                    print("✅ Health endpoint working")
                else:
                    print(f"❌ Health endpoint returned {resp.status}")
                    return False
        except Exception as e:
            print(f"❌ Health endpoint failed: {e}")
            return False
        
        # Test simple chat
        print("🗣️  Testing simple chat...")
        try:
            payload = {
                "conversation_id": f"test-fix-{int(asyncio.get_event_loop().time())}",
                "message": "Say 'Hello' back"
            }
            
            async with session.post(
                "http://127.0.0.1:8001/chat",
                json=payload,
                timeout=aiohttp.ClientTimeout(total=15)
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print(f"✅ Chat working! Response: {data.get('message', '')[:50]}...")
                    return True
                else:
                    error_text = await resp.text()
                    print(f"❌ Chat failed: {resp.status} - {error_text}")
                    return False
        except Exception as e:
            print(f"❌ Chat test failed: {e}")
            return False


def create_optimized_gemini_config():
    """Create an optimized configuration for better performance"""
    config = """# Optimized Gemini Service Configuration
# Add these to your .env file for better performance

# Use faster model variant
GEMINI_MODEL=gemini-1.5-flash

# Reduce response time
GEMINI_TEMPERATURE=0.3
GEMINI_MAX_TOKENS=2048
GEMINI_TOP_P=0.8
GEMINI_TOP_K=40

# Service timeouts
GEMINI_REQUEST_TIMEOUT=15.0
GEMINI_MAX_CONCURRENT_REQUESTS=5

# Disable features that might cause delays
ENABLE_CONVERSATION_PERSISTENCE=false
ENABLE_CONVERSATION_EMBEDDING=false
LOG_CONVERSATION_CONTENT=false
"""
    
    with open('gemini_optimized.env', 'w') as f:
        f.write(config)
    
    print("📝 Created gemini_optimized.env with performance settings")
    print("🔧 You can merge these settings into your .env file")


def print_service_restart_instructions():
    """Print instructions for restarting services"""
    print("\n🔄 SERVICE RESTART INSTRUCTIONS")
    print("=" * 50)
    print("After fixing the API key:")
    print()
    print("1. Stop current services (Ctrl+C in terminal running npm run backend)")
    print("2. Restart services:")
    print("   cd /Users/griffinstrier/projects/Tessera")
    print("   npm run backend")
    print()
    print("3. Test the fix:")
    print("   cd backend/python-backend")
    print("   python3 diagnose_gemini_performance.py")
    print()
    print("4. If still slow, try the optimized config:")
    print("   - Copy settings from gemini_optimized.env to .env")
    print("   - Restart services again")


def main():
    """Main fix routine"""
    print("🚀 Tessera Gemini Service Fix")
    print("Identified issue: Invalid/truncated API key causing timeouts")
    print()
    
    # Check and fix .env
    env_ok = check_and_fix_env_file()
    
    # Create optimized config
    create_optimized_gemini_config()
    
    # Print restart instructions
    print_service_restart_instructions()
    
    if env_ok:
        print("\n🧪 Testing current service...")
        try:
            asyncio.run(test_fixed_service())
        except Exception as e:
            print(f"❌ Test failed: {e}")
    
    print("\n✅ Fix script completed!")
    print("📋 Summary of issues found:")
    print("   - Invalid/truncated Gemini API key")
    print("   - Service timing out on all chat requests")
    print("   - RAG system working but blocked by API issue")
    print()
    print("🔧 Next steps:")
    print("   1. Get valid Gemini API key from https://aistudio.google.com/app/apikey")
    print("   2. Update .env file")
    print("   3. Restart services")
    print("   4. Test with: python3 diagnose_gemini_performance.py")


if __name__ == "__main__":
    main()

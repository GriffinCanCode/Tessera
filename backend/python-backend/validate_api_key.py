#!/usr/bin/env python3
"""
Simple API Key Validator for Gemini
Tests the API key directly without the service layer
"""

import os
import time


def test_api_key():
    """Test the Gemini API key directly"""
    print("🔑 GEMINI API KEY VALIDATOR")
    print("=" * 40)
    
    # Read API key from .env
    api_key = None
    try:
        with open('.env', 'r') as f:
            for line in f:
                if line.startswith('GEMINI_API_KEY='):
                    api_key = line.split('=', 1)[1].strip().strip('"\'')
                    break
    except FileNotFoundError:
        print("❌ .env file not found")
        return False
    
    if not api_key:
        print("❌ GEMINI_API_KEY not found in .env")
        return False
    
    print(f"🔍 Testing API key: {api_key[:15]}...")
    
    try:
        import google.generativeai as genai
        
        # Configure with the API key
        genai.configure(api_key=api_key)
        
        # Test with a simple request
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        print("⏱️  Making test request...")
        start_time = time.time()
        
        response = model.generate_content("Say 'API key works!'")
        
        end_time = time.time()
        
        print(f"✅ SUCCESS! Response time: {end_time - start_time:.2f}s")
        print(f"📝 Response: {response.text}")
        
        return True
        
    except ImportError:
        print("❌ google-generativeai package not installed")
        print("🔧 Install with: pip install google-generativeai")
        return False
        
    except Exception as e:
        error_str = str(e)
        print(f"❌ API Key Test Failed: {error_str}")
        
        if "API_KEY_INVALID" in error_str:
            print("🚨 The API key is invalid or expired")
            print("🔧 Get a new key from: https://aistudio.google.com/app/apikey")
        elif "PERMISSION_DENIED" in error_str:
            print("🚨 API key doesn't have permission for Gemini API")
        elif "QUOTA_EXCEEDED" in error_str:
            print("🚨 API quota exceeded")
        else:
            print("🚨 Unknown API error")
        
        return False


def show_api_key_setup_instructions():
    """Show instructions for getting a valid API key"""
    print("\n📋 HOW TO GET A VALID GEMINI API KEY")
    print("=" * 40)
    print("1. Go to: https://aistudio.google.com/app/apikey")
    print("2. Sign in with your Google account")
    print("3. Click 'Create API Key'")
    print("4. Copy the generated key")
    print("5. Update your .env file:")
    print("   GEMINI_API_KEY=your_actual_key_here")
    print("6. Restart the services")
    print()
    print("💡 Tips:")
    print("   - API keys are free with usage limits")
    print("   - Keep your key secure and don't commit to git")
    print("   - The key should start with 'AIza' and be ~40 characters")


if __name__ == "__main__":
    success = test_api_key()
    
    if not success:
        show_api_key_setup_instructions()
    else:
        print("\n🎉 Your API key is working!")
        print("🔄 Now restart your Gemini service to apply the fix")

#!/usr/bin/env python3
"""
Debug API Key Issues - Advanced Diagnostics
Tests various potential issues with the Gemini API key
"""

import os
import requests
import json
from urllib.parse import urlparse


def test_api_key_format():
    """Test API key format and common issues"""
    print("🔍 API KEY FORMAT ANALYSIS")
    print("=" * 40)
    
    # Read API key
    try:
        with open('.env', 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ .env file not found")
        return False
    
    # Extract key
    api_key = None
    for line in content.split('\n'):
        if line.startswith('GEMINI_API_KEY='):
            api_key = line.split('=', 1)[1].strip().strip('"\'')
            break
    
    if not api_key:
        print("❌ GEMINI_API_KEY not found in .env")
        return False
    
    print(f"📝 Key found: {api_key[:15]}...{api_key[-5:]}")
    print(f"📏 Length: {len(api_key)} characters")
    
    # Check format issues
    issues = []
    
    if len(api_key) < 35:
        issues.append(f"Too short ({len(api_key)} chars) - should be ~39 chars")
    
    if not api_key.startswith('AIza'):
        issues.append("Should start with 'AIza'")
    
    if api_key.endswith('%'):
        issues.append("Ends with '%' - likely truncated during copy/paste")
    
    if ' ' in api_key:
        issues.append("Contains spaces - should be continuous")
    
    if '\n' in api_key or '\r' in api_key:
        issues.append("Contains newlines - check for copy/paste issues")
    
    # Check for common copy/paste artifacts
    artifacts = ['...', '…', '\t', '\x00']
    for artifact in artifacts:
        if artifact in api_key:
            issues.append(f"Contains '{artifact}' - copy/paste artifact")
    
    if issues:
        print("❌ Format issues found:")
        for issue in issues:
            print(f"   - {issue}")
        return False
    else:
        print("✅ Format looks correct")
        return True


def test_network_connectivity():
    """Test network connectivity to Google APIs"""
    print("\n🌐 NETWORK CONNECTIVITY TEST")
    print("=" * 40)
    
    endpoints = [
        "https://generativelanguage.googleapis.com",
        "https://ai.google.dev",
        "https://aistudio.google.com"
    ]
    
    for endpoint in endpoints:
        try:
            response = requests.get(endpoint, timeout=10)
            print(f"✅ {endpoint}: {response.status_code}")
        except requests.exceptions.Timeout:
            print(f"⏰ {endpoint}: Timeout")
        except requests.exceptions.ConnectionError:
            print(f"❌ {endpoint}: Connection failed")
        except Exception as e:
            print(f"❌ {endpoint}: {e}")


def test_api_with_different_models():
    """Test API key with different Gemini models"""
    print("\n🤖 MODEL COMPATIBILITY TEST")
    print("=" * 40)
    
    # Read API key
    api_key = None
    try:
        with open('.env', 'r') as f:
            for line in f:
                if line.startswith('GEMINI_API_KEY='):
                    api_key = line.split('=', 1)[1].strip().strip('"\'')
                    break
    except:
        print("❌ Could not read API key")
        return
    
    if not api_key:
        print("❌ No API key found")
        return
    
    models_to_test = [
        "gemini-1.5-flash",
        "gemini-1.5-pro", 
        "gemini-pro",
        "gemini-2.0-flash-exp"
    ]
    
    for model in models_to_test:
        try:
            import google.generativeai as genai
            genai.configure(api_key=api_key)
            
            # Try to create model instance
            test_model = genai.GenerativeModel(model)
            
            # Try a simple generation
            response = test_model.generate_content("Say 'test'")
            print(f"✅ {model}: Working")
            
        except ImportError:
            print(f"❌ {model}: google-generativeai not installed")
            break
        except Exception as e:
            error_str = str(e)
            if "API_KEY_INVALID" in error_str:
                print(f"❌ {model}: Invalid API key")
            elif "not found" in error_str.lower():
                print(f"⚠️  {model}: Model not available")
            elif "quota" in error_str.lower():
                print(f"⚠️  {model}: Quota exceeded")
            else:
                print(f"❌ {model}: {error_str[:50]}...")


def test_api_permissions():
    """Test API key permissions and quotas"""
    print("\n🔐 API PERMISSIONS TEST")
    print("=" * 40)
    
    # Read API key
    api_key = None
    try:
        with open('.env', 'r') as f:
            for line in f:
                if line.startswith('GEMINI_API_KEY='):
                    api_key = line.split('=', 1)[1].strip().strip('"\'')
                    break
    except:
        print("❌ Could not read API key")
        return
    
    # Test with direct HTTP request to get more detailed error info
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": api_key
    }
    
    payload = {
        "contents": [{
            "parts": [{"text": "Hello"}]
        }]
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=15)
        
        print(f"📡 HTTP Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ API key is working!")
            data = response.json()
            if 'candidates' in data:
                print(f"📝 Response: {data['candidates'][0]['content']['parts'][0]['text']}")
        else:
            print(f"❌ API request failed")
            try:
                error_data = response.json()
                print(f"📄 Error details: {json.dumps(error_data, indent=2)}")
            except:
                print(f"📄 Raw response: {response.text}")
                
    except Exception as e:
        print(f"❌ Request failed: {e}")


def suggest_fixes():
    """Suggest potential fixes based on findings"""
    print("\n🔧 SUGGESTED FIXES")
    print("=" * 40)
    
    print("1. **API Key Issues:**")
    print("   - Get a fresh API key from https://aistudio.google.com/app/apikey")
    print("   - Copy the ENTIRE key (usually 39+ characters)")
    print("   - Paste directly without any formatting")
    print()
    
    print("2. **Copy/Paste Issues:**")
    print("   - Use a plain text editor to avoid formatting")
    print("   - Copy key in one selection (don't copy in parts)")
    print("   - Check for invisible characters")
    print()
    
    print("3. **Environment Issues:**")
    print("   - Make sure .env file is in correct directory")
    print("   - Restart services after updating .env")
    print("   - Check file permissions")
    print()
    
    print("4. **Network Issues:**")
    print("   - Check firewall/proxy settings")
    print("   - Try from different network")
    print("   - Verify internet connectivity to Google services")


def main():
    """Run all diagnostic tests"""
    print("🔬 ADVANCED GEMINI API KEY DIAGNOSTICS")
    print("=" * 50)
    
    format_ok = test_api_key_format()
    test_network_connectivity()
    
    if format_ok:
        test_api_with_different_models()
        test_api_permissions()
    
    suggest_fixes()


if __name__ == "__main__":
    main()

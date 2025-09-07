#!/usr/bin/env python3
"""
Frontend Integration Test for Gemini Service
Tests the complete flow: Frontend -> Perl API -> Gemini Service
"""

import asyncio
import aiohttp
import json
import time
from typing import Dict, Any


class FrontendIntegrationTester:
    """Test the complete frontend integration flow"""
    
    def __init__(self):
        self.perl_api_url = "http://127.0.0.1:3000"
        self.gemini_service_url = "http://127.0.0.1:8001"
        self.embedding_service_url = "http://127.0.0.1:8002"
        self.session = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30)
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def test_service_availability(self):
        """Test if all required services are running"""
        print("🔍 Testing Service Availability...")
        
        services = [
            ("Perl API Server", f"{self.perl_api_url}/"),
            ("Gemini Service", f"{self.gemini_service_url}/health"),
            ("Embedding Service", f"{self.embedding_service_url}/health"),
        ]
        
        results = {}
        
        for service_name, url in services:
            try:
                async with self.session.get(url) as response:
                    if response.status == 200:
                        print(f"   ✅ {service_name}: Running")
                        results[service_name] = True
                    else:
                        print(f"   ❌ {service_name}: HTTP {response.status}")
                        results[service_name] = False
            except Exception as e:
                print(f"   ❌ {service_name}: {e}")
                results[service_name] = False
        
        return results
    
    async def test_perl_api_bot_endpoints(self):
        """Test Perl API bot endpoints directly"""
        print("\n🤖 Testing Perl API Bot Endpoints...")
        
        # Test new conversation
        try:
            async with self.session.get(f"{self.perl_api_url}/bot/new-conversation") as response:
                if response.status == 200:
                    data = await response.json()
                    if data.get('success') and data.get('data', {}).get('conversation_id'):
                        conversation_id = data['data']['conversation_id']
                        print(f"   ✅ New conversation: {conversation_id}")
                        return conversation_id
                    else:
                        print(f"   ❌ New conversation failed: {data}")
                        return None
                else:
                    error_text = await response.text()
                    print(f"   ❌ New conversation HTTP {response.status}: {error_text}")
                    return None
        except Exception as e:
            print(f"   ❌ New conversation error: {e}")
            return None
    
    async def test_perl_api_chat(self, conversation_id: str):
        """Test chat through Perl API"""
        print(f"\n💬 Testing Chat via Perl API (conversation: {conversation_id})...")
        
        chat_payload = {
            "conversation_id": conversation_id,
            "message": "Hello! Please respond with just 'Hi back!' to test the connection.",
            "temperature": 0.3,
            "max_tokens": 50
        }
        
        start_time = time.time()
        
        try:
            async with self.session.post(
                f"{self.perl_api_url}/bot/chat",
                json=chat_payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    if data.get('success') and data.get('data', {}).get('message'):
                        message = data['data']['message']
                        print(f"   ✅ Chat successful ({response_time:.2f}s)")
                        print(f"   📝 Response: {message[:100]}...")
                        return True
                    else:
                        print(f"   ❌ Chat failed: {data}")
                        return False
                else:
                    error_text = await response.text()
                    print(f"   ❌ Chat HTTP {response.status} ({response_time:.2f}s): {error_text}")
                    return False
        except Exception as e:
            response_time = time.time() - start_time
            print(f"   ❌ Chat error ({response_time:.2f}s): {e}")
            return False
    
    async def test_direct_gemini_service(self):
        """Test Gemini service directly (bypass Perl API)"""
        print("\n🎯 Testing Direct Gemini Service...")
        
        # Test health
        try:
            async with self.session.get(f"{self.gemini_service_url}/health") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"   ✅ Health: {data.get('status', 'unknown')}")
                else:
                    print(f"   ❌ Health check failed: {response.status}")
                    return False
        except Exception as e:
            print(f"   ❌ Health check error: {e}")
            return False
        
        # Test direct chat
        chat_payload = {
            "conversation_id": f"direct-test-{int(time.time())}",
            "message": "Say 'Direct connection works!'"
        }
        
        start_time = time.time()
        
        try:
            async with self.session.post(
                f"{self.gemini_service_url}/chat",
                json=chat_payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    message = data.get('message', '')
                    print(f"   ✅ Direct chat successful ({response_time:.2f}s)")
                    print(f"   📝 Response: {message[:100]}...")
                    return True
                else:
                    error_text = await response.text()
                    print(f"   ❌ Direct chat HTTP {response.status} ({response_time:.2f}s): {error_text}")
                    return False
        except Exception as e:
            response_time = time.time() - start_time
            print(f"   ❌ Direct chat error ({response_time:.2f}s): {e}")
            return False
    
    async def test_conversations_list(self):
        """Test conversation listing"""
        print("\n📋 Testing Conversation Listing...")
        
        # Test via Perl API
        try:
            async with self.session.get(f"{self.perl_api_url}/bot/conversations") as response:
                if response.status == 200:
                    data = await response.json()
                    if data.get('success'):
                        conversations = data.get('data', {}).get('conversations', [])
                        print(f"   ✅ Perl API conversations: {len(conversations)} found")
                    else:
                        print(f"   ❌ Perl API conversations failed: {data}")
                else:
                    error_text = await response.text()
                    print(f"   ❌ Perl API conversations HTTP {response.status}: {error_text}")
        except Exception as e:
            print(f"   ❌ Perl API conversations error: {e}")
        
        # Test direct Gemini service
        try:
            async with self.session.get(f"{self.gemini_service_url}/conversations") as response:
                if response.status == 200:
                    data = await response.json()
                    conversations = data.get('conversations', [])
                    print(f"   ✅ Direct Gemini conversations: {len(conversations)} found")
                else:
                    error_text = await response.text()
                    print(f"   ❌ Direct Gemini conversations HTTP {response.status}: {error_text}")
        except Exception as e:
            print(f"   ❌ Direct Gemini conversations error: {e}")
    
    async def diagnose_integration_issues(self):
        """Diagnose common integration issues"""
        print("\n🔧 DIAGNOSING INTEGRATION ISSUES...")
        
        issues_found = []
        
        # Check if services are running
        services = await self.test_service_availability()
        
        if not services.get("Perl API Server"):
            issues_found.append("Perl API Server is not running - start with 'npm run backend'")
        
        if not services.get("Gemini Service"):
            issues_found.append("Gemini Service is not running - check backend startup")
        
        if not services.get("Embedding Service"):
            issues_found.append("Embedding Service is not running - may cause RAG failures")
        
        # Test direct Gemini if available
        if services.get("Gemini Service"):
            gemini_works = await self.test_direct_gemini_service()
            if not gemini_works:
                issues_found.append("Direct Gemini service is not working - check API key")
        
        # Test Perl API if available
        if services.get("Perl API Server"):
            conversation_id = await self.test_perl_api_bot_endpoints()
            if conversation_id:
                chat_works = await self.test_perl_api_chat(conversation_id)
                if not chat_works:
                    issues_found.append("Perl API chat is not working - check Gemini integration")
            else:
                issues_found.append("Perl API bot endpoints are not working")
        
        # Test conversations
        await self.test_conversations_list()
        
        return issues_found
    
    def print_fix_instructions(self, issues: list):
        """Print fix instructions based on issues found"""
        print("\n🛠️  FIX INSTRUCTIONS")
        print("=" * 50)
        
        if not issues:
            print("✅ No issues found! Frontend chat should be working.")
            return
        
        print("Issues found:")
        for i, issue in enumerate(issues, 1):
            print(f"{i}. {issue}")
        
        print("\n🔧 Steps to fix:")
        
        if any("not running" in issue for issue in issues):
            print("1. Start all services:")
            print("   cd <project_root>")
            print("   npm run backend")
            print()
        
        if any("API key" in issue for issue in issues):
            print("2. Fix API key:")
            print("   cd backend/python-backend")
            print("   python3 validate_api_key.py")
            print("   # Follow instructions to get valid API key")
            print()
        
        if any("Perl API" in issue for issue in issues):
            print("3. Check Perl API logs:")
            print("   # Look for errors in the terminal running 'npm run backend'")
            print("   # Check if GeminiBot.pm can connect to Gemini service")
            print()
        
        print("4. Test the fix:")
        print("   python3 test_frontend_integration.py")
        print()
        print("5. Test in frontend:")
        print("   - Open browser to frontend URL")
        print("   - Go to Notebook/Learning Dashboard")
        print("   - Try sending a message")


async def main():
    """Run complete frontend integration test"""
    print("🧪 FRONTEND INTEGRATION TEST")
    print("=" * 50)
    print("Testing complete flow: Frontend -> Perl API -> Gemini Service")
    print()
    
    async with FrontendIntegrationTester() as tester:
        issues = await tester.diagnose_integration_issues()
        tester.print_fix_instructions(issues)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Test interrupted")
    except Exception as e:
        print(f"\n💥 Test failed: {e}")

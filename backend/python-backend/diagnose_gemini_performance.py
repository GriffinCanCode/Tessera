#!/usr/bin/env python3
"""
Gemini Service Performance Diagnostics
Identifies the exact bottleneck causing 60+ second response times
"""

import asyncio
import aiohttp
import time
import json
from typing import Dict, Any
import sys

GEMINI_BASE_URL = "http://127.0.0.1:8001"
EMBEDDING_BASE_URL = "http://127.0.0.1:8002"


async def diagnose_bottleneck():
    """Step-by-step diagnosis of the performance issue"""
    
    print("🔍 GEMINI SERVICE PERFORMANCE DIAGNOSIS")
    print("=" * 50)
    
    async with aiohttp.ClientSession() as session:
        
        # Step 1: Test basic connectivity
        print("\n1️⃣ Testing Basic Connectivity...")
        start = time.time()
        try:
            async with session.get(f"{GEMINI_BASE_URL}/health", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                health_time = time.time() - start
                health_data = await resp.json()
                print(f"   ✅ Health endpoint: {health_time:.2f}s - {resp.status}")
                print(f"   Model: {health_data.get('model', 'unknown')}")
        except Exception as e:
            print(f"   ❌ Health check failed: {e}")
            return
        
        # Step 2: Test embedding service (RAG dependency)
        print("\n2️⃣ Testing Embedding Service (RAG dependency)...")
        start = time.time()
        try:
            payload = {"query": "test", "limit": 1}
            async with session.post(
                f"{EMBEDDING_BASE_URL}/search", 
                json=payload,
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                embed_time = time.time() - start
                embed_data = await resp.json()
                print(f"   ✅ Embedding search: {embed_time:.2f}s - {resp.status}")
                print(f"   Chunks returned: {len(embed_data.get('chunks', []))}")
        except Exception as e:
            print(f"   ❌ Embedding service failed: {e}")
            print("   🚨 This could be causing RAG timeouts in chat!")
        
        # Step 3: Test chat with minimal payload and short timeout
        print("\n3️⃣ Testing Chat with Short Timeout...")
        chat_payload = {
            "conversation_id": f"diag-{int(time.time())}",
            "message": "Hi"
        }
        
        for timeout_seconds in [5, 10, 15, 30]:
            print(f"\n   Testing {timeout_seconds}s timeout...")
            start = time.time()
            try:
                async with session.post(
                    f"{GEMINI_BASE_URL}/chat",
                    json=chat_payload,
                    timeout=aiohttp.ClientTimeout(total=timeout_seconds)
                ) as resp:
                    chat_time = time.time() - start
                    if resp.status == 200:
                        data = await resp.json()
                        print(f"   ✅ Chat succeeded: {chat_time:.2f}s")
                        print(f"   Response length: {len(data.get('message', ''))}")
                        break
                    else:
                        error_text = await resp.text()
                        print(f"   ❌ Chat failed: {resp.status} - {error_text[:100]}")
            except asyncio.TimeoutError:
                print(f"   ⏰ Chat timed out after {timeout_seconds}s")
            except Exception as e:
                print(f"   ❌ Chat error: {e}")
        
        # Step 4: Test chat without RAG context
        print("\n4️⃣ Testing Chat Performance Factors...")
        
        # Test with temperature override (faster generation)
        print("   Testing with low temperature...")
        start = time.time()
        try:
            fast_payload = {
                "conversation_id": f"diag-fast-{int(time.time())}",
                "message": "Say 'OK'",
                "temperature": 0.1,
                "max_tokens": 10
            }
            async with session.post(
                f"{GEMINI_BASE_URL}/chat",
                json=fast_payload,
                timeout=aiohttp.ClientTimeout(total=15)
            ) as resp:
                fast_time = time.time() - start
                if resp.status == 200:
                    print(f"   ✅ Fast chat: {fast_time:.2f}s")
                else:
                    print(f"   ❌ Fast chat failed: {resp.status}")
        except Exception as e:
            print(f"   ❌ Fast chat error: {e}")


async def test_gemini_api_directly():
    """Test Google Gemini API directly to isolate service issues"""
    print("\n5️⃣ Testing Google Gemini API Directly...")
    
    try:
        import google.generativeai as genai
        import os
        
        # Try to get API key from environment
        api_key = None
        env_file = "/Users/griffinstrier/projects/Tessera/backend/python-backend/.env"
        try:
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith('GEMINI_API_KEY='):
                        api_key = line.split('=', 1)[1].strip().strip('"\'')
                        break
        except:
            pass
        
        if not api_key:
            print("   ❌ No API key found in .env file")
            return
        
        print("   🔑 Found API key, testing direct Gemini API...")
        genai.configure(api_key=api_key)
        
        model = genai.GenerativeModel('gemini-2.0-flash-exp')
        
        start = time.time()
        response = model.generate_content("Say 'Hello'")
        direct_time = time.time() - start
        
        print(f"   ✅ Direct Gemini API: {direct_time:.2f}s")
        print(f"   Response: {response.text[:100]}")
        
        if direct_time > 10:
            print("   🚨 Direct API is also slow - could be API key/quota issue")
        elif direct_time < 3:
            print("   🚨 Direct API is fast - bottleneck is in our service")
        
    except ImportError:
        print("   ❌ google-generativeai not available for direct testing")
    except Exception as e:
        print(f"   ❌ Direct API test failed: {e}")


async def check_service_logs():
    """Check if we can identify issues from service behavior"""
    print("\n6️⃣ Service Behavior Analysis...")
    
    async with aiohttp.ClientSession() as session:
        
        # Check if conversations are accumulating (memory leak?)
        try:
            async with session.get(f"{GEMINI_BASE_URL}/conversations") as resp:
                if resp.status == 200:
                    data = await resp.json()
                    conv_count = data.get('total', 0)
                    print(f"   Active conversations: {conv_count}")
                    
                    if conv_count > 100:
                        print("   🚨 Many active conversations - possible memory issue")
        except Exception as e:
            print(f"   ❌ Conversation check failed: {e}")
        
        # Test multiple quick requests to see if it's a concurrency issue
        print("   Testing concurrent quick requests...")
        tasks = []
        for i in range(3):
            task = session.get(f"{GEMINI_BASE_URL}/health")
            tasks.append(task)
        
        start = time.time()
        try:
            responses = await asyncio.gather(*tasks)
            concurrent_time = time.time() - start
            print(f"   ✅ 3 concurrent health checks: {concurrent_time:.2f}s")
            
            if concurrent_time > 1:
                print("   🚨 Even health checks are slow under concurrency")
        except Exception as e:
            print(f"   ❌ Concurrent test failed: {e}")


def print_recommendations():
    """Print diagnostic recommendations"""
    print("\n🔧 DIAGNOSTIC RECOMMENDATIONS")
    print("=" * 50)
    print("Based on the test results above:")
    print()
    print("1. If embedding service fails:")
    print("   - RAG context retrieval will timeout")
    print("   - Each chat request waits for embedding search")
    print("   - Fix: Restart embedding service or disable RAG temporarily")
    print()
    print("2. If direct Gemini API is slow:")
    print("   - Check API key quotas/limits")
    print("   - Try different model (gemini-pro vs gemini-2.0-flash-exp)")
    print("   - Check network connectivity to Google APIs")
    print()
    print("3. If service has many conversations:")
    print("   - Memory leak in conversation storage")
    print("   - Fix: Restart service or implement cleanup")
    print()
    print("4. If concurrent requests are slow:")
    print("   - Blocking operations in async code")
    print("   - Fix: Check for synchronous operations in async functions")
    print()
    print("5. Common fixes to try:")
    print("   - Restart all services: npm run backend")
    print("   - Check .env file has valid GEMINI_API_KEY")
    print("   - Reduce model temperature and max_tokens")
    print("   - Disable RAG temporarily by commenting out _retrieve_rag_context")


async def main():
    """Run complete diagnosis"""
    try:
        await diagnose_bottleneck()
        await test_gemini_api_directly()
        await check_service_logs()
        print_recommendations()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnosis interrupted")
    except Exception as e:
        print(f"\n💥 Diagnosis failed: {e}")


if __name__ == "__main__":
    asyncio.run(main())

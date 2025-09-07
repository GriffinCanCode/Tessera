#!/usr/bin/env python3
"""
Comprehensive Test Suite for Gemini Service
Tests performance, reliability, and identifies bottlenecks
"""

import asyncio
import json
import time
from typing import Dict, List, Any
from datetime import datetime
import aiohttp
import pytest
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor
import statistics

# Test Configuration
GEMINI_BASE_URL = "http://127.0.0.1:8001"
EMBEDDING_BASE_URL = "http://127.0.0.1:8002"
TEST_TIMEOUT = 60  # seconds
PERFORMANCE_THRESHOLD = 10.0  # seconds - acceptable response time


@dataclass
class TestResult:
    """Test result with timing and status information"""
    test_name: str
    success: bool
    response_time: float
    status_code: int = None
    error_message: str = None
    response_data: Dict[str, Any] = None


class GeminiServiceTester:
    """Comprehensive tester for Gemini service"""
    
    def __init__(self):
        self.session: aiohttp.ClientSession = None
        self.results: List[TestResult] = []
    
    async def __aenter__(self):
        """Async context manager entry"""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=TEST_TIMEOUT)
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self.session:
            await self.session.close()
    
    async def test_health_endpoint(self) -> TestResult:
        """Test health endpoint performance and response"""
        start_time = time.time()
        
        try:
            async with self.session.get(f"{GEMINI_BASE_URL}/health") as response:
                response_time = time.time() - start_time
                data = await response.json()
                
                return TestResult(
                    test_name="health_endpoint",
                    success=response.status == 200,
                    response_time=response_time,
                    status_code=response.status,
                    response_data=data
                )
        except Exception as e:
            return TestResult(
                test_name="health_endpoint",
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_conversations_endpoint(self) -> TestResult:
        """Test conversations listing endpoint"""
        start_time = time.time()
        
        try:
            async with self.session.get(f"{GEMINI_BASE_URL}/conversations") as response:
                response_time = time.time() - start_time
                data = await response.json()
                
                return TestResult(
                    test_name="conversations_endpoint",
                    success=response.status == 200,
                    response_time=response_time,
                    status_code=response.status,
                    response_data=data
                )
        except Exception as e:
            return TestResult(
                test_name="conversations_endpoint",
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_simple_chat(self) -> TestResult:
        """Test simple chat without context"""
        start_time = time.time()
        
        payload = {
            "conversation_id": f"test-simple-{int(time.time())}",
            "message": "Hello! Just say 'Hi' back."
        }
        
        try:
            async with self.session.post(
                f"{GEMINI_BASE_URL}/chat",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return TestResult(
                        test_name="simple_chat",
                        success=True,
                        response_time=response_time,
                        status_code=response.status,
                        response_data=data
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        test_name="simple_chat",
                        success=False,
                        response_time=response_time,
                        status_code=response.status,
                        error_message=error_text
                    )
        except Exception as e:
            return TestResult(
                test_name="simple_chat",
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_chat_with_context(self) -> TestResult:
        """Test chat with knowledge context"""
        start_time = time.time()
        
        payload = {
            "conversation_id": f"test-context-{int(time.time())}",
            "message": "What is artificial intelligence?",
            "context": {
                "articles": [
                    {
                        "title": "Artificial Intelligence",
                        "summary": "AI is intelligence demonstrated by machines"
                    }
                ],
                "project_id": 1
            }
        }
        
        try:
            async with self.session.post(
                f"{GEMINI_BASE_URL}/chat",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return TestResult(
                        test_name="chat_with_context",
                        success=True,
                        response_time=response_time,
                        status_code=response.status,
                        response_data=data
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        test_name="chat_with_context",
                        success=False,
                        response_time=response_time,
                        status_code=response.status,
                        error_message=error_text
                    )
        except Exception as e:
            return TestResult(
                test_name="chat_with_context",
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_embedding_service_dependency(self) -> TestResult:
        """Test if embedding service is working (Gemini depends on it for RAG)"""
        start_time = time.time()
        
        payload = {
            "query": "artificial intelligence",
            "limit": 3
        }
        
        try:
            async with self.session.post(
                f"{EMBEDDING_BASE_URL}/search",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return TestResult(
                        test_name="embedding_service_dependency",
                        success=True,
                        response_time=response_time,
                        status_code=response.status,
                        response_data=data
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        test_name="embedding_service_dependency",
                        success=False,
                        response_time=response_time,
                        status_code=response.status,
                        error_message=error_text
                    )
        except Exception as e:
            return TestResult(
                test_name="embedding_service_dependency",
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_concurrent_requests(self, num_requests: int = 3) -> List[TestResult]:
        """Test concurrent chat requests to identify bottlenecks"""
        tasks = []
        
        for i in range(num_requests):
            payload = {
                "conversation_id": f"test-concurrent-{i}-{int(time.time())}",
                "message": f"Hello from request {i}. Please respond briefly."
            }
            
            task = self._make_chat_request(payload, f"concurrent_chat_{i}")
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Convert exceptions to TestResult objects
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                processed_results.append(TestResult(
                    test_name=f"concurrent_chat_{i}",
                    success=False,
                    response_time=0.0,
                    error_message=str(result)
                ))
            else:
                processed_results.append(result)
        
        return processed_results
    
    async def _make_chat_request(self, payload: Dict, test_name: str) -> TestResult:
        """Helper method to make a chat request"""
        start_time = time.time()
        
        try:
            async with self.session.post(
                f"{GEMINI_BASE_URL}/chat",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return TestResult(
                        test_name=test_name,
                        success=True,
                        response_time=response_time,
                        status_code=response.status,
                        response_data=data
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        test_name=test_name,
                        success=False,
                        response_time=response_time,
                        status_code=response.status,
                        error_message=error_text
                    )
        except Exception as e:
            return TestResult(
                test_name=test_name,
                success=False,
                response_time=time.time() - start_time,
                error_message=str(e)
            )
    
    async def test_conversation_persistence(self) -> TestResult:
        """Test if conversations are properly maintained"""
        conversation_id = f"test-persistence-{int(time.time())}"
        
        # Send first message
        payload1 = {
            "conversation_id": conversation_id,
            "message": "My name is Alice. Remember this."
        }
        
        result1 = await self._make_chat_request(payload1, "persistence_msg1")
        if not result1.success:
            return result1
        
        # Wait a moment
        await asyncio.sleep(1)
        
        # Send second message referencing first
        payload2 = {
            "conversation_id": conversation_id,
            "message": "What is my name?"
        }
        
        start_time = time.time()
        result2 = await self._make_chat_request(payload2, "persistence_msg2")
        
        # Check if the service remembered the name
        success = result2.success
        if success and result2.response_data:
            response_text = result2.response_data.get("message", "").lower()
            success = "alice" in response_text
        
        return TestResult(
            test_name="conversation_persistence",
            success=success,
            response_time=result2.response_time,
            status_code=result2.status_code,
            response_data=result2.response_data,
            error_message=result2.error_message if not success else None
        )
    
    def analyze_results(self) -> Dict[str, Any]:
        """Analyze test results and provide insights"""
        if not self.results:
            return {"error": "No test results to analyze"}
        
        successful_tests = [r for r in self.results if r.success]
        failed_tests = [r for r in self.results if not r.success]
        
        response_times = [r.response_time for r in successful_tests if r.response_time > 0]
        
        analysis = {
            "summary": {
                "total_tests": len(self.results),
                "successful": len(successful_tests),
                "failed": len(failed_tests),
                "success_rate": len(successful_tests) / len(self.results) * 100
            },
            "performance": {
                "avg_response_time": statistics.mean(response_times) if response_times else 0,
                "min_response_time": min(response_times) if response_times else 0,
                "max_response_time": max(response_times) if response_times else 0,
                "median_response_time": statistics.median(response_times) if response_times else 0,
                "slow_requests": len([t for t in response_times if t > PERFORMANCE_THRESHOLD])
            },
            "failures": [
                {
                    "test": r.test_name,
                    "error": r.error_message,
                    "status_code": r.status_code,
                    "response_time": r.response_time
                }
                for r in failed_tests
            ],
            "recommendations": []
        }
        
        # Add recommendations based on results
        if analysis["performance"]["avg_response_time"] > PERFORMANCE_THRESHOLD:
            analysis["recommendations"].append(
                f"Average response time ({analysis['performance']['avg_response_time']:.2f}s) "
                f"exceeds threshold ({PERFORMANCE_THRESHOLD}s). Consider optimizing."
            )
        
        if analysis["summary"]["success_rate"] < 80:
            analysis["recommendations"].append(
                f"Success rate ({analysis['summary']['success_rate']:.1f}%) is low. "
                "Check service health and dependencies."
            )
        
        embedding_test = next((r for r in self.results if r.test_name == "embedding_service_dependency"), None)
        if embedding_test and not embedding_test.success:
            analysis["recommendations"].append(
                "Embedding service is not responding. This will cause RAG failures in chat requests."
            )
        
        return analysis


async def run_comprehensive_tests():
    """Run all tests and generate report"""
    print("🧪 Starting Comprehensive Gemini Service Tests")
    print("=" * 60)
    
    async with GeminiServiceTester() as tester:
        # Basic endpoint tests
        print("📋 Testing basic endpoints...")
        tester.results.append(await tester.test_health_endpoint())
        tester.results.append(await tester.test_conversations_endpoint())
        tester.results.append(await tester.test_embedding_service_dependency())
        
        # Chat functionality tests
        print("💬 Testing chat functionality...")
        tester.results.append(await tester.test_simple_chat())
        tester.results.append(await tester.test_chat_with_context())
        tester.results.append(await tester.test_conversation_persistence())
        
        # Concurrent request tests
        print("🔄 Testing concurrent requests...")
        concurrent_results = await tester.test_concurrent_requests(3)
        tester.results.extend(concurrent_results)
        
        # Analyze results
        analysis = tester.analyze_results()
        
        # Print detailed results
        print("\n📊 TEST RESULTS")
        print("=" * 60)
        
        for result in tester.results:
            status = "✅ PASS" if result.success else "❌ FAIL"
            print(f"{status} {result.test_name:<25} {result.response_time:>8.2f}s")
            if not result.success and result.error_message:
                print(f"     Error: {result.error_message}")
            if result.status_code:
                print(f"     Status: {result.status_code}")
        
        # Print analysis
        print(f"\n📈 ANALYSIS")
        print("=" * 60)
        print(f"Success Rate: {analysis['summary']['success_rate']:.1f}% "
              f"({analysis['summary']['successful']}/{analysis['summary']['total']})")
        print(f"Avg Response Time: {analysis['performance']['avg_response_time']:.2f}s")
        print(f"Max Response Time: {analysis['performance']['max_response_time']:.2f}s")
        print(f"Slow Requests: {analysis['performance']['slow_requests']}")
        
        if analysis['recommendations']:
            print(f"\n🔧 RECOMMENDATIONS")
            print("=" * 60)
            for i, rec in enumerate(analysis['recommendations'], 1):
                print(f"{i}. {rec}")
        
        # Print detailed failures
        if analysis['failures']:
            print(f"\n❌ FAILURE DETAILS")
            print("=" * 60)
            for failure in analysis['failures']:
                print(f"Test: {failure['test']}")
                print(f"Error: {failure['error']}")
                if failure['status_code']:
                    print(f"Status: {failure['status_code']}")
                print(f"Time: {failure['response_time']:.2f}s")
                print("-" * 40)
        
        return analysis


def run_quick_curl_tests():
    """Run quick curl-based tests for immediate feedback"""
    import subprocess
    import json
    
    print("🚀 Quick Curl Tests")
    print("=" * 40)
    
    tests = [
        {
            "name": "Health Check",
            "cmd": ["curl", "-s", "-w", "%{http_code},%{time_total}", 
                   f"{GEMINI_BASE_URL}/health"]
        },
        {
            "name": "Conversations List", 
            "cmd": ["curl", "-s", "-w", "%{http_code},%{time_total}",
                   f"{GEMINI_BASE_URL}/conversations"]
        },
        {
            "name": "Simple Chat (10s timeout)",
            "cmd": ["curl", "-s", "-w", "%{http_code},%{time_total}", 
                   "--max-time", "10",
                   "-X", "POST", f"{GEMINI_BASE_URL}/chat",
                   "-H", "Content-Type: application/json",
                   "-d", '{"conversation_id": "curl-test", "message": "Hi"}']
        }
    ]
    
    for test in tests:
        print(f"\n🔍 {test['name']}")
        try:
            result = subprocess.run(
                test['cmd'], 
                capture_output=True, 
                text=True, 
                timeout=15
            )
            
            output = result.stdout
            if "," in output:
                # Split response and timing info
                parts = output.rsplit(",", 1)
                if len(parts) == 2:
                    response_body = parts[0]
                    timing_info = parts[1]
                    timing_parts = timing_info.split(",")
                    if len(timing_parts) >= 2:
                        status_code, time_total = timing_parts[0], timing_parts[1]
                    else:
                        status_code, time_total = timing_parts[0], "0"
                    
                    print(f"   Status: {status_code}")
                    print(f"   Time: {float(time_total):.2f}s")
                    
                    # Try to parse JSON response
                    try:
                        if response_body.strip():
                            json_data = json.loads(response_body)
                            if isinstance(json_data, dict) and len(json_data) < 5:
                                print(f"   Response: {json_data}")
                    except json.JSONDecodeError:
                        if len(response_body) < 100:
                            print(f"   Response: {response_body}")
                        else:
                            print(f"   Response: {response_body[:100]}...")
            else:
                print(f"   Output: {output}")
                
        except subprocess.TimeoutExpired:
            print("   ⏰ TIMEOUT (>15s)")
        except Exception as e:
            print(f"   ❌ ERROR: {e}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "quick":
        # Run quick curl tests
        run_quick_curl_tests()
    else:
        # Run comprehensive async tests
        try:
            asyncio.run(run_comprehensive_tests())
        except KeyboardInterrupt:
            print("\n🛑 Tests interrupted by user")
        except Exception as e:
            print(f"\n💥 Test suite failed: {e}")

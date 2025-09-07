# Gemini Service Testing & Diagnostics

## 🚨 Issue Identified: Invalid API Key

The comprehensive testing revealed that **the Gemini API key is invalid**, causing all chat requests to timeout after 60+ seconds.

## 🔍 Root Cause Analysis

### What We Found:
1. **Health endpoint**: ✅ Working (0.00s response time)
2. **Conversations endpoint**: ✅ Working (0.00s response time) 
3. **Embedding service**: ✅ Working (0.02s response time)
4. **Chat requests**: ❌ All timeout after 60s
5. **Direct API test**: ❌ "API key not valid" error

### The Problem:
- Current API key: `AIzaSyBcCQlPAtfE3SI1PQ_HoBHoQ1Y8219R13Eve%`
- Status: **INVALID** - returns 400 error from Google API
- Impact: Every chat request waits indefinitely for Gemini API response

## 🧪 Test Scripts Created

### 1. `test_gemini_service.py`
Comprehensive async test suite that tests:
- Health endpoints
- Chat functionality with/without context
- Concurrent request handling
- Conversation persistence
- Performance analysis

**Usage:**
```bash
python3 test_gemini_service.py
```

### 2. `diagnose_gemini_performance.py`
Step-by-step diagnostic tool that:
- Tests basic connectivity
- Checks embedding service dependency
- Tests chat with various timeouts
- Tests direct Gemini API
- Analyzes service behavior

**Usage:**
```bash
python3 diagnose_gemini_performance.py
```

### 3. `validate_api_key.py`
Simple API key validator that:
- Reads key from .env file
- Tests directly with Google Gemini API
- Provides specific error diagnosis

**Usage:**
```bash
python3 validate_api_key.py
```

### 4. `fix_gemini_issues.py`
Automated fix script that:
- Analyzes .env file issues
- Creates optimized configuration
- Provides step-by-step fix instructions

**Usage:**
```bash
python3 fix_gemini_issues.py
```

## 🔧 How to Fix

### Step 1: Get Valid API Key
1. Go to: https://aistudio.google.com/app/apikey
2. Sign in with Google account
3. Click "Create API Key"
4. Copy the generated key (should be ~40 characters starting with "AIza")

### Step 2: Update .env File
```bash
# Edit backend/python-backend/.env
GEMINI_API_KEY=your_new_valid_key_here
```

### Step 3: Restart Services
```bash
cd /Users/griffinstrier/projects/Tessera
# Stop current services (Ctrl+C)
npm run backend
```

### Step 4: Verify Fix
```bash
cd backend/python-backend
python3 validate_api_key.py
python3 diagnose_gemini_performance.py
```

## 📊 Performance Expectations

After fixing the API key, you should see:
- **Health endpoint**: < 0.1s
- **Simple chat**: < 5s
- **Chat with context**: < 10s
- **Success rate**: > 95%

## 🚀 Optimization Tips

For better performance, add these to your .env:
```bash
# Use faster model
GEMINI_MODEL=gemini-1.5-flash

# Reduce response time
GEMINI_TEMPERATURE=0.3
GEMINI_MAX_TOKENS=2048
GEMINI_REQUEST_TIMEOUT=15.0
```

## 🔄 Continuous Testing

Run these commands regularly to monitor service health:

```bash
# Quick health check
curl http://127.0.0.1:8001/health

# Performance test
python3 test_gemini_service.py quick

# Full diagnostic
python3 diagnose_gemini_performance.py
```

## 📋 Test Results Summary

**Before Fix:**
- Chat success rate: 0%
- Average response time: 60s+ (timeout)
- Error: API_KEY_INVALID

**Expected After Fix:**
- Chat success rate: 95%+
- Average response time: 3-8s
- All endpoints functional

## 🛠️ Troubleshooting

If issues persist after API key fix:

1. **Still slow responses**: Check network connectivity to googleapis.com
2. **Quota exceeded**: Wait or upgrade API limits
3. **Model errors**: Try different model (gemini-1.5-flash vs gemini-2.0-flash-exp)
4. **Memory issues**: Restart services to clear conversation cache

## 📁 Files Created

- `test_gemini_service.py` - Comprehensive test suite
- `diagnose_gemini_performance.py` - Performance diagnostics
- `validate_api_key.py` - API key validator
- `fix_gemini_issues.py` - Automated fix script
- `gemini_optimized.env` - Performance configuration template
- `README_GEMINI_TESTS.md` - This documentation

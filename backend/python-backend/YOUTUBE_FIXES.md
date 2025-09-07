# YouTube Processing Fixes

This document outlines the fixes implemented to resolve YouTube transcript extraction issues.

## Issues Fixed

### 1. IP Blocking Issues
- **Problem**: YouTube was blocking requests due to too many requests from the same IP
- **Solution**: 
  - Added exponential backoff retry logic
  - Added proxy support via `INGESTION_YOUTUBE_USE_PROXY` and `INGESTION_YOUTUBE_PROXY_URL`
  - Configurable retry attempts via `INGESTION_YOUTUBE_MAX_RETRIES`

### 2. yt-dlp Format Selection Errors
- **Problem**: yt-dlp was failing with "Requested format is not available" errors
- **Solution**:
  - Added fallback format selection (starts with low quality, falls back to worst/bestaudio)
  - Added proper user agent to avoid detection
  - Added retry logic with different format options
  - Skip download mode to only extract metadata

### 3. Rate Limiting
- **Problem**: YouTube was rate limiting requests
- **Solution**:
  - Added specific handling for rate limiting errors
  - Longer wait times for rate limit retries
  - Better error messages for users

### 4. Enhanced Error Handling
- **Problem**: Generic error messages didn't help users understand the issue
- **Solution**:
  - Specific error messages for different failure types
  - User-friendly explanations for IP blocking, rate limiting, etc.
  - Proper exception handling for different error types

## Configuration Options

Add these to your `.env` file to customize YouTube processing:

```bash
# Enable proxy for YouTube requests (helps with IP blocking)
INGESTION_YOUTUBE_USE_PROXY=false
INGESTION_YOUTUBE_PROXY_URL=http://your-proxy:port

# Retry configuration
INGESTION_YOUTUBE_MAX_RETRIES=5
INGESTION_YOUTUBE_RETRY_DELAY=10

# Cookie support (for accessing age-restricted content)
INGESTION_YOUTUBE_USE_COOKIES=false
INGESTION_YOUTUBE_COOKIES_FILE=/path/to/cookies.txt
```

## Usage Tips

1. **For IP Blocking**: 
   - Wait a few hours before retrying
   - Consider using a proxy or VPN
   - Reduce the frequency of requests

2. **For Rate Limiting**:
   - The service will automatically retry with exponential backoff
   - Wait times increase with each retry attempt

3. **For Restricted Videos**:
   - Some videos may require cookies from a logged-in session
   - Export cookies from your browser and configure the cookies file path

## Testing

The fixes include comprehensive error handling and retry logic. The service will now:
- Automatically retry failed requests up to 5 times (configurable)
- Use different video quality formats if the preferred one fails
- Provide clear error messages to help diagnose issues
- Handle IP blocking and rate limiting gracefully

## Monitoring

Check the logs for detailed information about retry attempts and failure reasons:
- IP blocking attempts will be logged with wait times
- Format fallbacks will be logged
- Final failure reasons will include user-friendly explanations

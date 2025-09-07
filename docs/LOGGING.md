# Tessera Unified Logging System

A comprehensive, modern logging solution for the multi-language Tessera stack with colors, organization, and strategic placement.

## 🎯 Features

- **Multi-language support**: Python, Perl, JavaScript/TypeScript, R
- **Structured logging** with contextual data
- **Colored console output** with emoji indicators
- **Performance monitoring** and metrics
- **Centralized configuration** via YAML
- **Strategic log placement** at critical points
- **Error tracking** with stack traces
- **Log rotation** and management
- **Development-friendly** with rich formatting

## 🚀 Quick Start

### Installation

```bash
# Install all logging dependencies
./scripts/install-logging-deps.sh

# Or install manually for each language:

# Python (in virtual environment)
pip install rich colorlog structlog

# Perl
cpanm Log::Log4perl::Appender::ScreenColoredLevels Term::ANSIColor

# Node.js
npm install loglevel loglevel-plugin-prefix

# R
Rscript -e "install.packages(c('futile.logger', 'jsonlite', 'crayon'))"
```

### Basic Usage

#### Python
```python
from logging_config import get_logger, log_api_request, log_error

logger = get_logger("my_service")
logger.info("🚀 Service starting", port=8000)

# API logging
log_api_request("GET", "/api/search", query="test")

# Error logging
try:
    risky_operation()
except Exception as e:
    log_error(e, "Failed to process request", user_id=123)
```

#### Perl
```perl
use Tessera::Logger;

my $logger = Tessera::Logger->get_logger('MyService');
$logger->log_service_start(port => 3000);
$logger->log_api_request('GET', '/search', query => 'test');
$logger->log_error($@, "Database connection failed", id => 123);
```

#### TypeScript/React
```typescript
import { getLogger, apiLogger, brainLogger } from '../utils/logger';

const logger = getLogger('MyComponent');
logger.logComponentMount('SearchComponent');
logger.logUserAction('search_submitted', { query: 'test' });

// API logging
apiLogger.logApiRequest('GET', '/api/search');
apiLogger.logApiResponse('GET', '/api/search', 200, 150);

// Domain-specific logging
brainLogger.logBrainVisualization('data_loaded', { nodes: 100 });
```

#### R
```r
source("tessera_logger.R")

tessera_logger$log_analysis_start("Graph Analysis")
tessera_logger$log_performance_metric("processing_time", 45.2, "ms")
tessera_logger$log_analysis_complete("Graph Analysis", 1250)
```

## 📊 Log Categories

### Service Lifecycle
- 🚀 **Service startup** - When services begin
- ✅ **Service ready** - When services are operational  
- 🛑 **Service shutdown** - When services stop

### API Operations
- 🌐 **API requests** - Incoming HTTP requests
- ✅/⚠️/❌ **API responses** - HTTP responses with status codes
- 🔗 **External API calls** - Outbound API requests

### Data Processing
- ⚙️ **Processing start** - Beginning of operations
- ✅ **Processing complete** - Successful completion
- 📊 **Performance metrics** - Timing and resource usage

### Database Operations
- 🗄️ **Database queries** - SQL operations
- 💾 **Cache operations** - Cache hits/misses/sets

### User Interactions
- 👤 **User actions** - Button clicks, form submissions
- 🧭 **Navigation** - Route changes
- 📦 **Store actions** - State management operations

### Domain-Specific
- 🧠 **Brain visualization** - 3D brain rendering operations
- 🔍 **Search operations** - Search queries and results
- 🕸️ **Knowledge graph** - Graph analysis and rendering
- 📚 **Learning progress** - Educational content tracking
- 📝 **Notebook operations** - Note-taking functionality

## 🎨 Log Levels and Colors

| Level | Color | Usage |
|-------|-------|-------|
| **TRACE** | Silver | Detailed debugging information |
| **DEBUG** | Blue | Development debugging |
| **INFO** | Green | General information |
| **WARN** | Yellow | Warning conditions |
| **ERROR** | Red | Error conditions |
| **FATAL** | Magenta | Critical failures |

## 📁 Log Organization

```
logs/
├── tessera_YYYYMMDD.log          # Main application log
├── api_server.log                # Perl API server
├── data_ingestion.log            # Python data service
├── embedding_service.log         # Python embedding service
├── gemini_service.log           # Python Gemini service
├── knowledge_graph.log          # Perl graph processing
├── r_graph_analysis.log         # R analytics
└── frontend/                    # Browser console only
```

## 🔧 Configuration

Edit `logging-config.yaml` to customize:

```yaml
global:
  level: INFO
  colors: true
  emojis: true
  format: structured

services:
  python:
    data_ingestion:
      level: INFO
      file: "logs/data_ingestion.log"
      
environments:
  development:
    global:
      level: DEBUG
      colors: true
  production:
    global:
      level: INFO
      colors: false
```

## 📈 Performance Monitoring

### Automatic Performance Logging
```python
# Python
from logging_config import measureAsyncPerformance

result = await measureAsyncPerformance(
    "database_query", 
    lambda: fetch_data_from_db()
)
```

```typescript
// TypeScript
import { measureAsyncPerformance } from '../utils/logger';

const result = await measureAsyncPerformance(
    'API call',
    () => api.searchArticles(query)
);
```

```r
# R
result <- measure_performance("graph_analysis", {
    analyze_network(graph_data)
})
```

### Performance Metrics Tracked
- API response times
- Database query duration
- Processing task completion time
- Memory usage (where available)
- Cache hit/miss rates

## 🛠 Utilities

### Log Viewer
```bash
# List all log files
./scripts/view-logs.sh -l

# View specific service logs
./scripts/view-logs.sh api
./scripts/view-logs.sh data
./scripts/view-logs.sh embedding

# Follow logs in real-time
./scripts/view-logs.sh -f api
./scripts/view-logs.sh -f all
```

### Log Analysis
```bash
# Search for errors in the last hour
grep -r "ERROR" logs/ | grep "$(date -d '1 hour ago' '+%Y-%m-%d %H')"

# Count API requests by endpoint
grep "API request" logs/api_server.log | awk '{print $NF}' | sort | uniq -c

# Find slow operations (>1000ms)
grep -r "ms)" logs/ | awk -F'(' '{print $2}' | awk -F'ms' '{if($1>1000) print}'
```

## 🔍 Strategic Log Placement

### Critical Points for Logging

1. **Service Boundaries**
   - Service startup/shutdown
   - API request/response
   - External service calls

2. **Data Flow**
   - Data ingestion start/complete
   - Database operations
   - Cache operations

3. **User Interactions**
   - Authentication events
   - User actions
   - Navigation events

4. **Error Conditions**
   - Exception handling
   - Validation failures
   - Resource exhaustion

5. **Performance Bottlenecks**
   - Slow database queries
   - Large data processing
   - Complex calculations

## 🚨 Error Handling

### Structured Error Logging
```python
# Python - Automatic context capture
try:
    process_user_data(user_id, data)
except Exception as e:
    log_error(e, "Failed to process user data", 
              user_id=user_id, data_size=len(data))
```

```perl
# Perl - Error with context
eval {
    $self->process_graph($graph_data);
};
if ($@) {
    $logger->log_error($@, "Graph processing failed", 
                      nodes => scalar(@nodes));
}
```

```typescript
// TypeScript - Error boundary integration
export function logErrorBoundary(error: Error, errorInfo: any) {
    appLogger.error('React Error Boundary', error, {
        componentStack: errorInfo.componentStack
    });
}
```

## 📊 Monitoring and Alerting

### Key Metrics to Monitor
- Error rate > 5%
- Response time > 1000ms
- Log volume > 1000 logs/minute
- Memory usage > 80%
- Disk space for logs

### Integration Points
- **Prometheus** metrics endpoint
- **Grafana** dashboards
- **Elasticsearch** log aggregation
- **Jaeger** distributed tracing

## 🔒 Security Considerations

### Sensitive Data Redaction
Automatically redacted fields:
- `password`
- `api_key`
- `token`
- `secret`
- `authorization`
- `cookie`

### Log File Security
- Log rotation after 100MB
- Maximum 10 log files retained
- Compressed historical logs
- Restricted file permissions

## 🧪 Testing

### Log Testing Utilities
```python
# Python - Test log output
from logging_config import get_logger
import logging
from io import StringIO

def test_logging():
    log_stream = StringIO()
    handler = logging.StreamHandler(log_stream)
    logger = get_logger("test")
    logger.logger.addHandler(handler)
    
    logger.info("Test message", user_id=123)
    
    log_output = log_stream.getvalue()
    assert "Test message" in log_output
    assert "user_id=123" in log_output
```

## 📚 Best Practices

### Do's ✅
- Use structured logging with context
- Log at appropriate levels
- Include relevant context data
- Use consistent message formats
- Monitor log volume and performance
- Rotate logs regularly

### Don'ts ❌
- Don't log sensitive information
- Don't log in tight loops without throttling
- Don't use only string concatenation
- Don't ignore log configuration
- Don't forget to handle log rotation

## 🔄 Migration Guide

### From Console.log to Structured Logging
```typescript
// Before
console.log('User logged in:', userId);

// After
userLogger.logUserAction('login', { userId, timestamp: Date.now() });
```

### From Basic Perl Logging
```perl
# Before
print "Processing started\n";

# After
$logger->log_processing_start("Data Processing", 
                             input_size => $data_size);
```

## 🤝 Contributing

When adding new logging:

1. **Choose appropriate level** (DEBUG/INFO/WARN/ERROR)
2. **Add relevant context** data
3. **Use existing patterns** for consistency
4. **Test log output** in development
5. **Update documentation** if needed

## 📞 Support

For logging system issues:
1. Check `logs/` directory for error messages
2. Verify configuration in `logging-config.yaml`
3. Use `./scripts/view-logs.sh -l` to list available logs
4. Check service-specific documentation

---

**Happy Logging!** 🎯 The Tessera logging system provides comprehensive visibility into your application's behavior while maintaining performance and security.

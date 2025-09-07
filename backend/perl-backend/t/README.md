# Tessera Backend Test Suite

This directory contains comprehensive tests for the Tessera backend system.

## Test Files

### Unit Tests

- **01-storage.t** - Tests for Tessera::Storage database operations
  - Database schema initialization
  - Article storage and retrieval
  - Link storage and queries
  - Search functionality
  - Statistics generation

- **02-parser.t** - Tests for Tessera::Parser HTML parsing
  - Title extraction
  - Content and summary extraction
  - Infobox parsing
  - Category extraction
  - Link extraction
  - Section and coordinate parsing

- **03-crawler.t** - Tests for Tessera::Crawler web crawling
  - Rate limiting functionality
  - URL validation and utility methods
  - HTTP request handling (mocked)
  - Title/URL conversion utilities

- **04-linkanalyzer.t** - Tests for Tessera::LinkAnalyzer relevance analysis
  - Interest-based relevance scoring
  - Link filtering and ranking
  - Boost keyword functionality
  - Recommendation generation

- **05-knowledgegraph.t** - Tests for Tessera::KnowledgeGraph
  - Graph construction (complete and centered)
  - Node classification and importance
  - Path finding algorithms
  - Graph metrics calculation

- **06-tessera-main.t** - Tests for main Tessera orchestration
  - Component initialization
  - Configuration loading
  - High-level workflow methods
  - Statistics and cleanup

- **07-api-server.t** - Tests for the REST API server
  - All endpoint testing
  - Error handling
  - CORS functionality
  - Response format validation

### Integration Tests

- **08-integration.t** - End-to-end workflow testing
  - Complete data flow from storage to graph building
  - Multi-component interaction
  - Search and retrieval workflows

## Test Configuration

- **test_config.yaml** - Test-specific configuration
  - In-memory SQLite database
  - Reduced rate limiting for faster tests
  - Error-level logging only

- **lib/TestHelper.pm** - Test utilities and fixtures
  - Mock data generators
  - Test configuration helpers
  - Sample HTML content

## Running Tests

### Run All Tests
```bash
cd backend/t
perl run_tests.pl
```

### Run Individual Test Files
```bash
cd backend
prove -l t/01-storage.t
prove -l t/02-parser.t
# ... etc
```

### Run Tests with Verbose Output
```bash
prove -lv t/
```

### Run Tests in Parallel
```bash
prove -j4 -l t/
```

## Test Dependencies

The tests require the following Perl modules:
- Test::More (core)
- Test::Exception
- Test::MockObject
- Test::Mojo (for API tests)

## Coverage

The test suite covers:

- **Storage Layer**: 100% of public methods
- **Parser**: All parsing functions with real Wikipedia HTML
- **Crawler**: URL handling, rate limiting, mocked HTTP requests
- **Link Analyzer**: Relevance algorithms and filtering
- **Knowledge Graph**: Graph building and analysis algorithms
- **Main Module**: Component orchestration and high-level methods
- **API Server**: All endpoints with various input conditions
- **Integration**: Complete workflows across all components

## Mocking Strategy

Tests use mocking for:
- HTTP requests (to avoid hitting Wikipedia during tests)
- External dependencies
- Time-sensitive operations

Real functionality tested:
- Database operations (using in-memory SQLite)
- HTML parsing (using real Wikipedia HTML samples)
- Algorithm implementations
- Data structures and transformations

## Test Data

Test fixtures include:
- Sample Wikipedia HTML pages
- Mock article data structures
- Test link relationships
- Category and metadata examples

## Continuous Testing

For development, you can run tests continuously:

```bash
# Watch for file changes and re-run tests
find ../lib -name "*.pm" | entr prove -l t/
```

## Performance Notes

- Tests use in-memory databases for speed
- HTTP requests are mocked to avoid network dependencies
- Rate limiting is reduced in test configuration
- Test data is kept minimal but realistic

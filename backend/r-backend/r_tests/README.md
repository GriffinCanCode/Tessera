# Tessera R Scripts Test Suite

Comprehensive test suite for the R analysis scripts in the Tessera project.

## Overview

This test suite provides thorough testing for all R scripts used in the Tessera system:

- **graph_analysis.R** - Graph metrics, centrality measures, community detection, and cluster analysis
- **layout_algorithms.R** - Advanced graph layout calculations and quality evaluation
- **temporal_analysis.R** - Temporal pattern analysis, growth tracking, and learning phase identification

## Test Structure

```
r_tests/
├── run_r_tests.R              # Main test runner script
├── README.md                  # This file
├── helpers/
│   └── test_helpers.R         # Test utilities and mock data generators
└── testthat/
    ├── test_graph_analysis.R      # Tests for graph analysis functions
    ├── test_layout_algorithms.R   # Tests for layout algorithms
    ├── test_temporal_analysis.R   # Tests for temporal analysis
    └── test_integration.R         # Integration tests across all scripts
```

## Dependencies

The test suite requires the following R packages:

- `testthat` - Testing framework
- `jsonlite` - JSON parsing and generation
- `igraph` - Graph analysis library (used by the scripts under test)

These will be automatically installed when running the test suite if not already present.

## Running Tests

### Quick Start

```bash
cd backend/r-backend/r_tests
Rscript run_r_tests.R
```

### Command Line Options

```bash
# Run all tests with coverage report
Rscript run_r_tests.R --coverage

# Run with verbose output
Rscript run_r_tests.R --verbose

# Use manual test runner (fallback mode)
Rscript run_r_tests.R --manual

# Show help
Rscript run_r_tests.R --help
```

### Running Individual Test Files

```bash
# Run specific test file
cd backend/r-backend/r_tests
Rscript testthat/test_graph_analysis.R

# Or using testthat directly
R -e "testthat::test_file('testthat/test_graph_analysis.R')"
```

## Test Coverage

### Graph Analysis Tests (`test_graph_analysis.R`)

- **JSON Input/Output**: Validates JSON parsing and error handling
- **Graph Creation**: Tests igraph object creation from JSON data
- **Metrics Calculation**: Verifies all graph metrics (density, diameter, transitivity, etc.)
- **Centrality Measures**: Tests PageRank, betweenness, closeness, eigenvector centrality
- **Community Detection**: Validates multiple community detection algorithms
- **Layout Calculation**: Tests various graph layout algorithms
- **Cluster Analysis**: Verifies k-core decomposition and clique analysis
- **Performance**: Tests with larger graphs up to 50+ nodes
- **Error Handling**: Comprehensive error condition testing

### Layout Algorithms Tests (`test_layout_algorithms.R`)

- **Force-Directed Layouts**: Tests Fruchterman-Reingold, Kamada-Kawai, GEM
- **Hierarchical Layouts**: Validates Sugiyama and tree layouts for DAGs
- **Large Graph Layouts**: Tests LGL and grid-force algorithms
- **Physics Simulation**: Verifies custom physics-based layout
- **Bipartite Layouts**: Tests layout for graphs with different node types
- **Clustered Layouts**: Validates community-based positioning
- **Layout Quality**: Tests quality metrics and evaluation functions
- **Recommendations**: Verifies layout recommendation system
- **Edge Cases**: Handles single nodes, disconnected components
- **Scalability**: Performance testing with graphs up to 50+ nodes

### Temporal Analysis Tests (`test_temporal_analysis.R`)

- **Growth Patterns**: Tests cumulative growth tracking and velocity calculation
- **Discovery Timeline**: Validates milestone detection and category evolution
- **Knowledge Evolution**: Tests structural complexity over time
- **Learning Phases**: Verifies automatic phase detection
- **Temporal Metrics**: Tests summary statistics calculation
- **Date Parsing**: Handles various date formats and invalid dates
- **Pattern Detection**: Tests burst vs. steady vs. sparse patterns
- **Large Datasets**: Performance testing with 100+ articles over 90+ days
- **Error Handling**: Comprehensive input validation

### Integration Tests (`test_integration.R`)

- **Cross-Script Compatibility**: Tests data format compatibility between scripts
- **Workflow Simulation**: Simulates knowledge graph evolution over time
- **Error Handling Consistency**: Validates consistent error responses
- **JSON Serialization**: Tests round-trip JSON compatibility
- **Performance Characteristics**: Load testing with multiple graph sizes
- **Perl Integration**: Tests compatibility with Perl backend data formats
- **Concurrent Execution**: Basic concurrency safety testing

## Test Data and Mocking

### Mock Data Generators

The test suite includes sophisticated mock data generators:

- **`generate_mock_graph_data()`** - Creates realistic graph structures
- **`generate_mock_temporal_data()`** - Generates temporal datasets with timestamps
- **`create_simple_test_graph()`** - Small 3-node triangle for basic testing
- **`create_complex_test_graph()`** - Complex 5-node complete graph
- **`create_dag_test_graph()`** - Hierarchical DAG for tree layout testing

### Test Fixtures

- Sample graph data in various formats (list, data.frame)
- Temporal data with different activity patterns
- Edge cases (empty graphs, single nodes, disconnected components)
- Error conditions (invalid JSON, missing data, malformed input)

## Validation Functions

The test suite includes comprehensive validation functions:

- **`validate_json_output()`** - JSON structure validation
- **`validate_graph_metrics()`** - Graph metrics validation
- **`validate_centrality_measures()`** - Centrality measures validation
- **`validate_layout_coordinates()`** - Layout coordinate validation
- **`validate_temporal_analysis()`** - Temporal analysis structure validation

## Performance Testing

The test suite includes performance benchmarks:

- **Scalability Testing**: Tests with graphs from 10 to 50+ nodes
- **Time Limits**: All tests must complete within reasonable time (30s max)
- **Memory Usage**: Efficient data handling validation
- **Growth Patterns**: Performance scaling analysis

## Error Handling

Comprehensive error testing covers:

- **Invalid JSON Input**: Malformed JSON, null values, wrong structure
- **Missing Data**: Missing nodes, edges, or required fields
- **Invalid Dates**: Malformed timestamps in temporal data
- **Edge Cases**: Empty graphs, single nodes, disconnected components
- **Type Validation**: Incorrect data types and formats

## Integration with Main Project

### Perl Integration

Tests include validation for:

- Data formats compatible with Perl backend
- JSON structures matching Perl output
- Category and node type handling
- Edge weight and link type processing

### API Compatibility

Tests ensure R script outputs are compatible with:

- Frontend consumption via API
- JSON serialization/deserialization
- Error message formatting
- Result structure consistency

## Continuous Testing

### Development Workflow

```bash
# Run tests after making changes
Rscript run_r_tests.R

# Run with coverage to see what's tested
Rscript run_r_tests.R --coverage

# Test specific functionality
Rscript testthat/test_graph_analysis.R
```

### Integration with CI/CD

The test runner returns appropriate exit codes:
- `0` - All tests passed
- `1` - Some tests failed or error occurred

Example integration:

```bash
# In CI/CD pipeline
cd backend/r-backend/r_tests
Rscript run_r_tests.R --coverage
if [ $? -eq 0 ]; then
    echo "✅ All R tests passed"
else
    echo "❌ R tests failed"
    exit 1
fi
```

## Output and Reporting

### Console Output

The test runner provides colorized output with:
- ✅ Success indicators
- ❌ Failure markers  
- ⚠️ Warning messages
- ℹ️ Informational text
- Execution timing
- Success rate percentage

### JSON Results

Test results are saved to `test_results.json` with:
- Timestamp and R version
- Individual test results
- Coverage information  
- Performance metrics
- Summary statistics

### Coverage Report

When run with `--coverage`, generates:
- Function count per script
- Line count analysis
- Test coverage assessment

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```
   Error: package 'testthat' not found
   ```
   Solution: The test runner will auto-install missing packages

2. **Script Path Issues**
   ```
   Error: Script not found: ../graph_analysis.R
   ```
   Solution: Ensure you're running from the `r_tests` directory

3. **Memory Issues with Large Graphs**
   ```
   Error: cannot allocate vector of size X
   ```
   Solution: Reduce test graph sizes or increase available memory

### Debug Mode

For detailed debugging:

```R
# Run in interactive mode
setwd("r_tests")
source("run_r_tests.R")
# Then call main() with debugging
```

## Contributing

When adding new functionality to R scripts:

1. Add corresponding tests to appropriate test files
2. Update mock data generators if needed
3. Add validation functions for new output structures
4. Update integration tests for cross-script compatibility
5. Run full test suite: `Rscript run_r_tests.R --coverage`

### Test Writing Guidelines

- Each major function should have dedicated tests
- Include both positive and negative test cases
- Test edge cases and error conditions
- Validate output structure and data types
- Include performance considerations for large inputs
- Use descriptive test names and informative error messages

## Maintenance

### Regular Tasks

- Update test data when script requirements change
- Review performance benchmarks as functionality grows
- Update integration tests when adding new scripts
- Refresh mock data generators for realistic testing
- Review and update error handling tests

### Version Compatibility

Tests are designed to work with:
- R 4.0+
- testthat 3.0+
- igraph 1.2+
- jsonlite 1.7+

The test runner will check R version and package compatibility at startup.

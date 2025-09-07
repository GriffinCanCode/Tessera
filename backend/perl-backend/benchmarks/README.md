# Tessera Perl Calculation Benchmarks

This directory contains comprehensive benchmarks for testing the performance of Perl calculations in the Tessera backend system.

## Overview

The benchmark suite tests performance across four main areas:

1. **KnowledgeGraph Calculations** - Graph building, metrics, centrality measures
2. **LinkAnalyzer Calculations** - Relevance scoring, interest matching, filtering
3. **Parser Calculations** - HTML parsing, content extraction, semantic chunking
4. **API Server Calculations** - Content weighting, learning analytics, brain statistics

## Quick Start

### Run All Benchmarks
```bash
cd backend/perl-backend
perl benchmarks/run_benchmarks.pl
```

### Run Specific Benchmark Suite
```bash
# Run only KnowledgeGraph benchmarks
perl benchmarks/run_benchmarks.pl -s knowledgegraph

# Run multiple specific suites
perl benchmarks/run_benchmarks.pl -s knowledgegraph,parser
```

### Generate HTML Report
```bash
perl benchmarks/run_benchmarks.pl -o report.html -f html
```

### Compare with Previous Results
```bash
# Save current results
perl benchmarks/run_benchmarks.pl -o current.json -f json

# Later, compare new results with saved ones
perl benchmarks/run_benchmarks.pl --compare current.json
```

## Benchmark Suites

### 1. KnowledgeGraph Benchmarks (`01-knowledgegraph-bench.pl`)

Tests performance of graph operations:

- **Graph Building**: Complete and centered graph construction
- **Graph Metrics**: Density, degree distribution, connected components
- **Centrality Measures**: PageRank, betweenness (requires R)
- **Community Detection**: Louvain, Walktrap algorithms (requires R)
- **Path Finding**: Shortest path, neighbor discovery
- **Cache Performance**: Cache hit/miss scenarios

**Dataset Sizes:**
- Small: 50 articles, ~500 links
- Medium: 200 articles, ~3000 links  
- Large: 500 articles, ~10000 links

### 2. LinkAnalyzer Benchmarks (`02-linkanalyzer-bench.pl`)

Tests relevance calculation performance:

- **Relevance Calculation**: Core scoring algorithm
- **Interest Matching**: Title and anchor text matching
- **Boost Keywords**: Keyword-based boosting
- **Context Scoring**: Contextual relevance calculation
- **Link Filtering**: Filtering and sorting operations
- **Adaptive Learning**: Interest extraction from content
- **Recommendations**: End-to-end recommendation generation

**Dataset Sizes:**
- Small: 100 links, 5 interests
- Medium: 500 links, 10 interests
- Large: 2000 links, 20 interests

### 3. Parser Benchmarks (`03-parser-bench.pl`)

Tests HTML parsing and content processing:

- **Complete Parsing**: Full page parsing with all features
- **Extraction Methods**: Individual extraction functions
- **Content Processing**: HTML cleaning and text extraction
- **Semantic Chunking**: RAG-style content chunking
- **Link Extraction**: Wikipedia link and image extraction
- **Metadata Extraction**: Categories, coordinates, infobox parsing

**Complexity Levels:**
- Simple: Basic structure, minimal content
- Medium: Infobox, categories, multiple sections
- Complex: Large content, many sections, extensive metadata

### 4. API Server Benchmarks (`04-api-server-bench.pl`)

Tests API server calculation performance:

- **Content Weight**: Core content weighting algorithm
- **Learning Analytics**: Subject-based analytics computation
- **Brain Statistics**: Comprehensive brain statistics
- **Weighted Knowledge**: Subject and global weighting
- **Balance Score**: Balance score calculations with variance
- **RKD Calculations**: Relative Knowledge Depth metrics

**Dataset Sizes:**
- Small: 50 content items, 5 subjects
- Medium: 200 content items, 10 subjects
- Large: 1000 content items, 25 subjects

## Configuration

### Benchmark Configuration (`benchmark_config.yaml`)

The configuration file controls:

- **Global Settings**: Iterations, runtime limits, output precision
- **Database Settings**: Connection parameters for test database
- **Suite-Specific Settings**: Dataset sizes, algorithm parameters
- **Performance Thresholds**: Regression detection limits
- **Reporting Options**: Output formats, notifications

### Key Configuration Sections

```yaml
global:
  default_iterations: 3
  min_runtime: 2
  max_runtime: 30

performance_thresholds:
  warning_threshold: 10.0    # % performance degradation
  failure_threshold: 25.0
  
knowledgegraph:
  r_integration:
    skip_on_failure: true    # Skip R tests if unavailable
    timeout: 60
```

## Running Individual Benchmarks

Each benchmark can be run independently:

```bash
# KnowledgeGraph benchmarks
perl benchmarks/01-knowledgegraph-bench.pl

# LinkAnalyzer benchmarks  
perl benchmarks/02-linkanalyzer-bench.pl

# Parser benchmarks
perl benchmarks/03-parser-bench.pl

# API Server benchmarks
perl benchmarks/04-api-server-bench.pl
```

## Output Formats

### Text Format (Default)
Human-readable console output with timing results.

### JSON Format
```bash
perl benchmarks/run_benchmarks.pl -f json -o results.json
```
Machine-readable format for automated processing.

### YAML Format
```bash
perl benchmarks/run_benchmarks.pl -f yaml -o results.yaml
```
Configuration-friendly format.

### HTML Format
```bash
perl benchmarks/run_benchmarks.pl -f html -o report.html
```
Web-viewable report with tables and styling.

## Performance Analysis

### Benchmark Runner Options

```bash
# Verbose output with raw benchmark data
perl benchmarks/run_benchmarks.pl -v

# Performance profiling (top fastest/slowest operations)
perl benchmarks/run_benchmarks.pl -p

# Custom number of iterations
perl benchmarks/run_benchmarks.pl -i 5

# Load custom configuration
perl benchmarks/run_benchmarks.pl -c custom_config.yaml
```

### Interpreting Results

**Operations per Second (ops/sec)**: Higher is better
- Measures how many operations can be completed per second
- Good for comparing relative performance

**Time per Operation**: Lower is better  
- Measures average time for a single operation
- Useful for understanding absolute performance

**Memory Usage**: Lower is better
- Some benchmarks include memory profiling
- Helps identify memory-intensive operations

## Performance Baselines

### Expected Performance Ranges

| Operation Category | Expected Range (ops/sec) |
|-------------------|---------------------------|
| Content Weight Calculation | 1000+ |
| Basic Relevance Calculation | 500+ |
| Graph Building (small) | 10+ |
| Complete Page Parsing | 50+ |
| Interest Matching | 2000+ |
| Link Filtering | 1000+ |

### Performance Regression Detection

The benchmark runner can detect performance regressions:

- **Warning Threshold**: 10% performance degradation
- **Failure Threshold**: 25% performance degradation
- **Comparison**: Against previous benchmark results

## Dependencies

### Required Perl Modules
- `Benchmark` (core)
- `Time::HiRes` (core)
- `YAML::XS`
- `JSON::XS`
- `Term::ANSIColor`
- `Getopt::Long` (core)
- `Pod::Usage` (core)

### Optional Dependencies
- **R Integration**: `Statistics::R` + R packages (`igraph`, `networkD3`, `visNetwork`)
- **Memory Profiling**: System-specific tools
- **Advanced Analysis**: `Statistics::Descriptive`

### Installing Dependencies
```bash
# Install required Perl modules
cpanm YAML::XS JSON::XS Term::ANSIColor

# Install R packages (if using R integration)
R -e "install.packages(c('igraph', 'networkD3', 'visNetwork', 'jsonlite'))"
```

## Continuous Integration

### CI/CD Integration

The benchmarks can be integrated into CI/CD pipelines:

```bash
# Quick CI benchmarks (reduced iterations)
perl benchmarks/run_benchmarks.pl -c ci_config.yaml -o ci_results.json

# Performance regression check
perl benchmarks/run_benchmarks.pl --compare baseline.json || exit 1
```

### Environment-Specific Configuration

Use environment-specific settings in `benchmark_config.yaml`:

```yaml
environments:
  ci:
    global:
      default_iterations: 2
      max_runtime: 10
  production:
    global:
      default_iterations: 5
    performance_thresholds:
      warning_threshold: 5.0
```

## Troubleshooting

### Common Issues

1. **R Integration Failures**
   - Set `r_integration.skip_on_failure: true` in config
   - Install required R packages
   - Check R installation path

2. **Memory Issues with Large Datasets**
   - Reduce dataset sizes in configuration
   - Use smaller test iterations
   - Monitor system memory usage

3. **Slow Performance**
   - Check system load during benchmarks
   - Reduce `max_runtime` in configuration
   - Use smaller datasets for development

### Debug Mode

Enable verbose output for debugging:

```bash
perl benchmarks/run_benchmarks.pl -v -s knowledgegraph
```

## Contributing

### Adding New Benchmarks

1. Create new benchmark script: `05-newmodule-bench.pl`
2. Follow existing patterns for structure and output
3. Add suite definition to `run_benchmarks.pl`
4. Update configuration in `benchmark_config.yaml`
5. Document in this README

### Benchmark Script Structure

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);

# Setup test data
sub setup_test_data { ... }

# Individual benchmark functions
sub benchmark_operation_name {
    my $results = timethese(-3, {
        'test_name' => sub { ... },
    });
    print_benchmark_results($results, "Category Name");
}

# Results formatting
sub print_benchmark_results { ... }
```

## License

This benchmark suite is part of the Tessera project and follows the same licensing terms.

## Support

For issues or questions about the benchmark suite:

1. Check this README for common solutions
2. Review the configuration options
3. Run with verbose output for debugging
4. Check system requirements and dependencies

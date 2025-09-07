# Tessera - Personal Wikipedia Knowledge Graph Builder

A modern Perl-based backend for crawling Wikipedia, following personalized interests, and building knowledge graphs.

## Features

- Web crawling with intelligent rate limiting
- HTML parsing and content extraction
- Topic-based link analysis
- Knowledge graph construction
- SQLite database storage
- REST API server with Mojolicious
- Configurable interest profiles

## Installation

```bash
# Install dependencies
cpanm --installdeps .

# Initialize database
perl script/setup_database.pl

# Start the crawler
perl bin/tessera
```

## Architecture

- `lib/Tessera/` - Core modules
- `bin/` - Executable scripts
- `script/` - Utility scripts
- `t/` - Tests
- `config/` - Configuration files
- `data/` - SQLite database and cache

## Usage

```bash
# Start API server
perl script/api_server.pl

# Run crawler with interests
perl bin/tessera --interests="artificial intelligence,machine learning"
```

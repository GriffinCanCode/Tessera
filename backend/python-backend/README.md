# Tessera Python Backend

Modern, organized Python backend for Tessera's AI and RAG services.

## Directory Structure

```
backend/python-backend/
├── src/                    # Source code
│   ├── services/          # Core AI services
│   │   ├── gemini_service.py
│   │   ├── embedding_service.py
│   │   └── data_ingestion_service.py
│   └── utils/             # Utility modules
│       ├── database_pool.py
│       └── logging_config.py
├── tests/                 # Test files
├── scripts/               # Setup and startup scripts
├── docs/                  # Documentation
├── config/                # Configuration files
├── logs/                  # Log files
├── venv/                  # Virtual environment
├── main.py               # Main entry point
└── requirements.txt      # Dependencies
```

## Quick Start

### 1. Setup
```bash
cd backend/python-backend
python3 scripts/setup.py
```

### 2. Start Services

#### Individual Services
```bash
# Start Gemini service (port 8001)
python main.py gemini

# Start Embedding service (port 8002)
python main.py embedding

# Start Data Ingestion service (port 8003)
python main.py data_ingestion
```

#### All Services
```bash
python main.py all
# or
bash scripts/start_all_services.sh
```

### 3. Alternative Module Execution
```bash
# From python-backend directory
python -m src.services.gemini_service
python -m src.services.embedding_service
python -m src.services.data_ingestion_service
```

## Services

- **Gemini Service** (8001): Modern LLM API with RAG integration
- **Embedding Service** (8002): Sentence transformers with vector search
- **Data Ingestion Service** (8003): YouTube, books, articles processing

## API Documentation

When services are running:
- Gemini: http://127.0.0.1:8001/docs
- Embedding: http://127.0.0.1:8002/docs
- Data Ingestion: http://127.0.0.1:8003/docs

## Configuration

Create a `.env` file in the python-backend directory:
```
GEMINI_API_KEY=your_api_key_here
```

Get your API key from: https://aistudio.google.com/app/apikey
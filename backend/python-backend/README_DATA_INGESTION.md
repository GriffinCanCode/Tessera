# Tessera Data Ingestion System

A comprehensive data ingestion service that processes multiple content types including YouTube videos, books, articles, and poetry. The system integrates with the existing Tessera knowledge graph and provides advanced content processing capabilities.

## 🚀 Features

### Content Types Supported

1. **YouTube Videos** 📺
   - Automatic transcript extraction using `youtube-transcript-api`
   - Metadata extraction (title, description, duration, uploader, view count)
   - Multi-language transcript support with fallback
   - Handles various YouTube URL formats

2. **Books & Documents** 📚
   - **PDF**: Text extraction using PyPDF2
   - **DOCX**: Microsoft Word document processing
   - **EPUB**: E-book format support
   - **TXT/MD**: Plain text and Markdown files
   - File size validation and content cleaning

3. **Web Articles** 📰
   - Smart content extraction using Readability algorithm
   - Metadata extraction (author, publish date, description)
   - Clean text processing with HTML removal
   - Domain-based categorization

4. **Poetry & Creative Writing** ✍️
   - Literary structure analysis (stanzas, lines)
   - NLP-powered feature extraction using spaCy
   - Sentiment analysis and POS tagging
   - Entity recognition and noun phrase extraction

### Advanced Processing

- **Semantic Chunking**: Intelligent text segmentation for optimal embedding
- **Background Processing**: Asynchronous embedding generation
- **Database Integration**: Seamless storage in existing Tessera SQLite database
- **Error Handling**: Robust retry mechanisms and graceful failure handling
- **Structured Logging**: Comprehensive logging with structured output

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │───▶│   Perl API       │───▶│   Python Data   │
│   (React)       │    │   Server         │    │   Ingestion     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Tessera   │    │   Content       │
                       │   SQLite DB     │◀───│   Processors    │
                       └─────────────────┘    └─────────────────┘
```

### Service Communication

- **Perl API Server** (Port 3000): Main API gateway, handles frontend requests
- **Python Data Ingestion** (Port 8003): Specialized content processing service
- **Embedding Service** (Port 8002): Vector embedding generation
- **Gemini Service** (Port 8001): AI chat and knowledge queries

## 📋 API Endpoints

### YouTube Ingestion
```bash
POST /ingest/youtube
Content-Type: application/x-www-form-urlencoded

url=https://www.youtube.com/watch?v=VIDEO_ID
title=Optional Custom Title
description=Optional description
project_id=123
```

### Article Ingestion
```bash
POST /ingest/article
Content-Type: application/x-www-form-urlencoded

url=https://example.com/article
title=Optional Custom Title
description=Optional description
project_id=123
```

### Book Upload
```bash
POST /ingest/book
Content-Type: multipart/form-data

file=@book.pdf
title=Optional Custom Title
description=Optional description
project_id=123
```

### Poetry Ingestion
```bash
POST /ingest/poetry
Content-Type: application/x-www-form-urlencoded

text=Your poem or creative writing here...
title=Optional Custom Title
description=Optional description
project_id=123
```

### Health Check
```bash
GET /health
```

## 🛠️ Setup & Installation

### Prerequisites

- Python 3.8+
- Virtual environment (recommended)
- spaCy English model: `python -m spacy download en_core_web_sm`

### Quick Start

1. **Install Dependencies**
   ```bash
   cd backend/python-backend
   source venv/bin/activate
   pip install -r requirements.txt
   python -m spacy download en_core_web_sm
   ```

2. **Start Individual Service**
   ```bash
   ./start_data_ingestion_service.sh
   ```

3. **Start All Services**
   ```bash
   ./start_all_services.sh
   ```

### Dependencies

#### Core Libraries
- `fastapi` - Modern web framework
- `uvicorn` - ASGI server
- `pydantic` - Data validation
- `aiohttp` - Async HTTP client
- `structlog` - Structured logging

#### Content Processing
- `yt-dlp` - YouTube video processing
- `youtube-transcript-api` - Transcript extraction
- `PyPDF2` - PDF text extraction
- `python-docx` - Word document processing
- `ebooklib` - EPUB e-book processing
- `beautifulsoup4` - HTML parsing
- `readability-lxml` - Article content extraction

#### NLP & Analysis
- `nltk` - Natural language processing
- `spacy` - Advanced NLP features
- `sentence-transformers` - Text embeddings

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the `python-backend` directory:

```env
# Data Ingestion Service Configuration
INGESTION_HOST=127.0.0.1
INGESTION_PORT=8003
INGESTION_DATABASE_PATH=../data/tessera_knowledge.db

# Processing Limits
INGESTION_MAX_FILE_SIZE_MB=50
INGESTION_MAX_TEXT_LENGTH=1000000
INGESTION_CHUNK_SIZE=1000

# YouTube Settings
INGESTION_YOUTUBE_LANGUAGE_PREFERENCE=["en", "en-US", "en-GB"]

# Web Scraping
INGESTION_USER_AGENT=Tessera Data Ingestion Bot 1.0
INGESTION_REQUEST_TIMEOUT=30
```

### Database Schema

The service integrates with the existing Tessera database schema:

```sql
-- Content stored in existing articles table
INSERT INTO articles (
    title, url, content, summary, categories,
    links, images, sections, infobox, coordinates,
    parsed_at, content_type, metadata, project_id
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
```

## 📊 Processing Pipeline

### 1. Content Reception
- Validate input parameters
- Check file size limits (for uploads)
- Determine content type

### 2. Content Processing
- **YouTube**: Extract transcript and metadata
- **Books**: Extract text based on file type
- **Articles**: Use readability algorithm for clean extraction
- **Poetry**: Analyze literary structure and features

### 3. Text Cleaning
- Remove control characters
- Normalize whitespace
- Preserve formatting where appropriate

### 4. Database Storage
- Store in Tessera articles table
- Include metadata and content type
- Associate with projects if specified

### 5. Background Processing
- Generate semantic embeddings
- Create searchable chunks
- Update knowledge graph connections

## 🔍 Content Analysis Features

### YouTube Processing
- Multi-language transcript support
- Video metadata extraction
- Duration and engagement metrics
- Automatic title and description extraction

### Book Processing
- Support for multiple formats (PDF, DOCX, EPUB, TXT)
- Text extraction with formatting preservation
- File metadata and statistics
- Content validation and cleaning

### Article Processing
- Smart content extraction (removes ads, navigation)
- Author and publication date detection
- Meta description extraction
- Domain-based categorization

### Poetry Analysis
- Stanza and line structure detection
- Literary feature extraction using NLP
- Sentiment analysis
- Entity recognition and noun phrase extraction
- POS tagging and linguistic analysis

## 🚨 Error Handling

### Retry Mechanisms
- Automatic retry for network requests
- Exponential backoff for failed operations
- Graceful degradation for optional features

### Validation
- Input parameter validation
- File type and size validation
- Content length limits
- URL format validation

### Logging
- Structured logging with context
- Error tracking and debugging info
- Performance metrics
- Request/response logging

## 🔗 Integration

### With Perl API Server
The Perl API server acts as a proxy, forwarding requests to the Python service:

```perl
# Example Perl integration
sub call_python_ingestion_service {
    my ($endpoint, $form_data) = @_;
    my $python_service_url = 'http://127.0.0.1:8003';
    my $response = $ua->post("$python_service_url$endpoint", $form_data);
    return decode_json($response->content);
}
```

### With Embedding Service
Automatic background embedding generation for processed content:

```python
async def create_embeddings_for_content(content_id: int, text: str):
    # Calls embedding service to generate vectors
    # Stores embeddings for semantic search
```

### With Knowledge Graph
Processed content automatically integrates with the existing knowledge graph:
- Articles become nodes in the graph
- Relationships are established based on content similarity
- Semantic connections enhance search and discovery

## 📈 Performance Considerations

### Optimization Features
- Async processing for I/O operations
- Background task processing
- Connection pooling for database operations
- Caching for frequently accessed data

### Scalability
- Horizontal scaling support
- Load balancing capabilities
- Resource usage monitoring
- Configurable processing limits

## 🧪 Testing

### Manual Testing
```bash
# Test YouTube ingestion
curl -X POST "http://127.0.0.1:8003/ingest/youtube" \
     -F "url=https://www.youtube.com/watch?v=dQw4w9WgXcQ" \
     -F "title=Test Video"

# Test article ingestion
curl -X POST "http://127.0.0.1:8003/ingest/article" \
     -F "url=https://en.wikipedia.org/wiki/Artificial_intelligence"

# Test book upload
curl -X POST "http://127.0.0.1:8003/ingest/book" \
     -F "file=@sample.pdf" \
     -F "title=Sample Book"

# Test poetry ingestion
curl -X POST "http://127.0.0.1:8003/ingest/poetry" \
     -F "text=Roses are red, Violets are blue..." \
     -F "title=Simple Poem"
```

### Health Check
```bash
curl http://127.0.0.1:8003/health
```

## 🔮 Future Enhancements

### Planned Features
- **Audio Processing**: Podcast and audio file transcription
- **Image Analysis**: OCR and image content extraction
- **Social Media**: Twitter, Reddit, and other platform integration
- **Real-time Processing**: WebSocket-based live ingestion
- **Batch Processing**: Bulk upload and processing capabilities

### Advanced Analytics
- Content similarity analysis
- Topic modeling and categorization
- Trend analysis across ingested content
- Quality scoring and content ranking

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Install development dependencies
4. Run tests and linting
5. Submit a pull request

### Code Style
- Follow PEP 8 for Python code
- Use type hints for all functions
- Include docstrings for public methods
- Write comprehensive tests

## 📄 License

This project is part of the Tessera system and follows the same licensing terms.

---

**Need Help?** Check the logs in `data_ingestion_service.log` or run the health check endpoint for service status.

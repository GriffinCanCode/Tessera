# WikiCrawler Knowledge Bot

A sophisticated AI-powered knowledge bot with **Retrieval-Augmented Generation (RAG)** that integrates Google's Gemini 2.0 Flash with your personal Wikipedia knowledge graph. The bot provides intelligent, context-aware conversations and knowledge queries based on your crawled Wikipedia data, enhanced with semantic search capabilities.

## Architecture

- **Python + Google GenerativeAI**: Gemini API integration with conversation management
- **Python + RAG**: Sentence Transformers for semantic embeddings and vector search
- **Perl**: Coordinates with existing WikiCrawler system, handles Wikipedia processing and intelligent chunking
- **R**: Data visualization and mathematical operations (existing integration)
- **FastAPI**: Clean HTTP interfaces for both Gemini and embedding services
- **SQLite**: Unified database for articles, chunks, embeddings, and knowledge graph

## Features

- 🤖 **Conversational AI**: Chat with Gemini 2.0 Flash about your knowledge base
- 🔍 **RAG-Powered Search**: Semantic search using sentence transformers finds the most relevant content
- 📚 **Intelligent Chunking**: Perl-powered text processing creates optimal chunks from Wikipedia articles  
- 🧠 **Context Integration**: Combines semantic search with knowledge graph connections
- 💬 **Conversation Memory**: Maintains chat history and context
- 🎛️ **Configurable**: Adjustable creativity, similarity thresholds, and more
- 📊 **Source Citations**: Transparent references to your crawled articles with similarity scores
- 🚀 **Latest AI**: Uses Google's most advanced Gemini 2.0 Flash model
- ⚡ **Background Processing**: Automatic embedding generation for new articles
- 🗃️ **Unified Database**: Single SQLite database for all data (no duplicate storage)

## Setup

### 1. Prerequisites

- Python 3.8+
- Google Gemini API key ([get one here](https://aistudio.google.com/app/apikey))
- Existing WikiCrawler system

### 2. Automatic Setup

Run the setup script from the `backend/knowledge_bot/` directory:

```bash
cd backend/knowledge_bot/
python3 setup.py
```

This will:
- Create a virtual environment
- Install all dependencies
- Check your configuration
- Create startup scripts

### 3. Manual Setup

If you prefer manual setup:

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 4. API Key Configuration

Set your Google Gemini API key:

```bash
export GEMINI_API_KEY='your-api-key-here'

# For persistence, add to your ~/.bashrc or ~/.zshrc:
echo 'export GEMINI_API_KEY="your-api-key-here"' >> ~/.bashrc
```

## Usage

### Starting the Service

```bash
# Start both RAG services (recommended)
./start_all_services.sh

# Or start services individually:
./start_embedding_service.sh  # Port 8002
./start_modern_service.sh     # Port 8001

# Or manually:
source venv/bin/activate
python embedding_service.py &     # Background embedding processing
python gemini_service.py   # Main Gemini service
```

The services will start on:
- **Gemini Service**: `http://127.0.0.1:8001` (Main chat interface)
- **Embedding Service**: `http://127.0.0.1:8002` (RAG/semantic search)

### Using the Bot

1. **Start the main WikiCrawler API server** (if not already running):
   ```bash
   cd ../script/
   perl api_server.pl
   ```

2. **Access the Knowledge Bot** via the frontend:
   - Navigate to the "Knowledge Bot" tab
   - Start a new conversation
   - Choose between Chat and Knowledge modes

### Chat Modes

#### Chat Mode
- Natural conversation about your knowledge base
- Context-aware responses
- Personalized insights and connections

#### Knowledge Mode
- Fact-based queries with high accuracy
- Source citations from your articles
- Confidence scoring
- Comprehensive research-style answers

## API Endpoints

The Gemini service provides these endpoints:

- `POST /chat` - Conversational chat
- `POST /knowledge-query` - Fact-based queries
- `GET /conversations` - List active conversations
- `GET /conversation/{id}/history` - Get conversation history
- `DELETE /conversation/{id}` - Delete conversation
- `GET /` - Health check

## Integration with WikiCrawler

The system integrates seamlessly with your existing WikiCrawler:

### Perl Layer (`WikiCrawler::GeminiBot`)
- Clean interface to Python service
- Automatic context gathering from knowledge graph
- Error handling and fallbacks
- Conversation management

### API Integration
- New bot endpoints in existing API server
- Graceful fallback if Gemini service unavailable
- Consistent JSON response format

### Frontend Integration
- NotebookLM-style interface
- Conversation management
- Settings and customization
- Mobile-responsive design

## Configuration

### Bot Settings

Adjust bot behavior through the frontend settings:

- **Creativity** (0.0-1.0): Controls response randomness
- **Include Insights**: Whether to include knowledge graph insights
- **Context Mode**: Chat vs Knowledge query behavior

### Service Configuration

Modify `gemini_service.py` for advanced configuration:

```python
# Model selection (in initialize_gemini function)
model_name="gemini-2.0-flash-exp"  # Latest and most capable
# model_name="gemini-1.5-pro"      # Previous generation
# model_name="gemini-1.5-flash"    # Faster responses

# Default parameters
temperature=0.7          # Creativity level (0.0-2.0)
max_output_tokens=8192   # Response length
top_p=0.95              # Nucleus sampling
top_k=64                # Top-k sampling
```

## Development

### Project Structure

```
backend/knowledge_bot/
├── gemini_service.py      # Main FastAPI service
├── requirements.txt       # Python dependencies
├── setup.py              # Setup automation
├── start_gemini_service.sh # Startup script
└── README.md             # This file

backend/lib/WikiCrawler/
├── GeminiBot.pm          # Perl interface layer

backend/script/
├── api_server.pl         # Extended with bot endpoints

frontend/src/components/
├── Notebook/            # NotebookLM-style UI
```

### Extending the Bot

#### Adding New Conversation Types

1. Extend the Python service with new endpoints
2. Add corresponding methods to `WikiCrawler::GeminiBot`
3. Update the Perl API server endpoints
4. Enhance the frontend UI

#### Custom System Instructions

Modify system instructions in `gemini_service.py`:

```python
# In initialize_gemini function
system_instruction="""Your custom system instruction here...

You are a helpful AI assistant that...
- Follows these guidelines
- Uses this specific tone
- Formats responses this way
"""

gemini_model = genai.GenerativeModel(
    model_name="gemini-2.0-flash-exp",
    system_instruction=system_instruction
)
```

## Troubleshooting

### Common Issues

**Service won't start:**
- Check Python version (3.8+ required)
- Verify API key is set: `echo $GEMINI_API_KEY`
- Check port 8001 is available

**No responses from bot:**
- Ensure Gemini service is running
- Check service logs for errors
- Verify API key permissions and quota

**Frontend shows "service unavailable":**
- Confirm Gemini service is running on port 8001
- Check main API server includes bot endpoints
- Review browser console for errors

### Debug Mode

Enable verbose logging:

```python
# In gemini_service.py
import logging
logging.basicConfig(level=logging.DEBUG)

# Run service with debug
uvicorn.run(app, host="127.0.0.1", port=8001, log_level="debug")
```

### Performance Tuning

For better performance:
- Use faster models (gemini-1.5-flash vs gemini-2.0-flash-exp)
- Reduce context size and conversation history
- Implement response caching
- Optimize database queries in context gathering
- Adjust temperature and top_k/top_p for speed vs quality

## Privacy & Data Handling

**What Gets Processed:**
- ✅ **Wikipedia Articles**: Crawled articles are chunked, embedded, and stored for knowledge queries
- ✅ **Article Metadata**: Titles, URLs, relationships stored in database for search and connections

**What Does NOT Get Processed:**
- ❌ **Your Conversations**: Chat messages are stored only in RAM, never saved to database
- ❌ **Your Queries**: Questions you ask are not embedded or indexed for search
- ❌ **Personal Data**: No conversation content is logged to files or persistent storage

**Privacy Architecture:**
- **Memory-Only Conversations**: All chat history exists only in RAM while services run
- **Automatic Cleanup**: Conversations auto-delete after TTL period (default: 24 hours)
- **No Cross-Contamination**: Embedding service only processes Wikipedia content, never chat data
- **Privacy Validation**: Service startup validates that conversation persistence is disabled
- **Content-Free Logging**: System logs message metadata (length, timestamps) but never actual content

## Security Considerations

- API key stored as environment variable (not in code)
- Service runs on localhost only by default
- **PRIVACY GUARANTEE: No persistent storage of conversations (memory only)**
- **PRIVACY GUARANTEE: Conversations are NEVER embedded or indexed for search**
- **PRIVACY GUARANTEE: Conversation content is NEVER logged to files**
- Input validation on all endpoints
- Automatic conversation cleanup based on TTL (default: 24 hours)
- Built-in privacy validation prevents accidental conversation persistence

For production deployment:
- Add authentication/authorization
- Use HTTPS
- Implement rate limiting
- Add conversation persistence with encryption

## License

Same as WikiCrawler project.

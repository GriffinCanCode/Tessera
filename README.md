# Tessera

**Your Personal Learning Journey Tracker**

Transform how you learn by tracking everything you consume—YouTube videos, books, articles, courses, and more—while discovering hidden connections across your knowledge. Tessera builds a comprehensive learning profile that evolves with you, using AI to reveal patterns, suggest next steps, and help you master any subject.

## What Makes Tessera Special

**Complete Learning Content Tracking**  
Track your progress across every type of content: YouTube videos (with full transcript analysis), PDF books, web articles, EPUB files, documentation, and even poetry. Each piece gets intelligent difficulty assessment, time estimation, and completion tracking.

**AI-Powered Learning Analytics**  
R-based statistical analysis reveals your learning patterns, clusters related topics, identifies knowledge gaps, and calculates mastery levels across subjects. Discover how different topics connect in your personal learning graph.

**Intelligent Subject Clustering**  
Watch as Tessera automatically groups your learning content into subjects, detects relationships between topics, and builds a knowledge graph that shows how everything you've learned connects together.

**Learning Progress Intelligence**  
Track not just what you've consumed, but how well you've learned it. Session-based progress tracking, comprehension scoring, learning velocity analysis, and streak tracking keep you motivated and aware of your growth.

**Multi-Source Knowledge Chat**  
Ask questions about anything you've learned using Google's Gemini 2.0 Flash. The AI searches across all your content—that YouTube video from last month, the book chapter you read, the article you bookmarked—and provides insights with source citations.

**Visual Learning Insights**  
Interactive 3D knowledge graphs, learning velocity charts, subject mastery dashboards, and temporal analysis show your learning journey visually. See how your knowledge has grown over time and where to focus next.

## Tech Stack

### Backend Services

**Perl Learning Engine**
- **Framework**: Mojolicious web framework
- **Purpose**: Learning content management, progress tracking, session management
- **Features**: Multi-format content ingestion, learning progress APIs, subject clustering
- **Database**: Comprehensive SQLite schema for learning content, progress, and sessions
- **Key Libraries**: LWP::UserAgent, HTML::TreeBuilder, JSON::XS

**Python AI Services**
- **Framework**: FastAPI with async/await
- **Gemini Service** (Port 8001): Conversational AI for learning content queries
- **Embedding Service** (Port 8002): Semantic search across all learning materials
- **Data Ingestion Service** (Port 8003): YouTube transcripts, PDF extraction, article processing
- **Key Libraries**: google-generativeai, sentence-transformers, PyPDF2, youtube-transcript-api

**R Learning Analytics Engine**
- **Purpose**: Learning pattern analysis, subject clustering, mastery level calculation
- **Features**: Content clustering by TF-IDF similarity, learning velocity tracking, knowledge gap identification
- **Analytics**: Progress trend analysis, learning streak calculation, subject relationship detection
- **Key Libraries**: igraph, cluster, jsonlite
- **Integration**: Processes learning data to generate insights and recommendations

**Zig Performance Layer**
- **Purpose**: SIMD-optimized vector operations for embedding similarity
- **Features**: 10-100x faster cosine similarity calculations
- **Integration**: FFI bindings for Python, Perl, and R
- **Target**: 384D vectors with batch processing support

### Frontend Stack

**React 19 + TypeScript**
- **Build Tool**: Vite 6.0 for lightning-fast development
- **State Management**: Zustand for learning progress and subject state
- **Styling**: Tailwind CSS 4.1 with custom design system
- **Data Fetching**: TanStack Query for learning analytics and progress data

**Learning Visualization Libraries**
- **3D Knowledge Graphs**: Three.js with React Three Fiber for subject relationship visualization
- **Learning Analytics**: D3.js for progress charts, mastery dashboards, and temporal learning analysis
- **Progress Components**: Custom learning dashboard, subject progress trackers, completion indicators
- **UI Components**: Lucide React icons, custom Tailwind components
- **Animations**: Anime.js for smooth learning progress transitions

**Desktop Integration**
- **Framework**: Tauri 2.8 for native desktop applications
- **Backend**: Rust-based native layer with web frontend
- **Features**: Native file system access, system integration, cross-platform support

### Infrastructure

**Learning Database**
- **Primary**: SQLite with WAL mode for concurrent access
- **Schema**: Learning content, progress tracking, subject clustering, session management
- **Tables**: `learning_content`, `learning_progress`, `content_subjects`, `learning_sessions`
- **Features**: Completion percentage tracking, time spent analytics, difficulty assessment
- **Caching**: In-memory LRU cache with configurable TTL

**Service Architecture**
- **Gateway**: Perl API server (Port 3000) with CORS support
- **Microservices**: Python FastAPI services with health checks
- **Communication**: HTTP/JSON APIs with service registry
- **Logging**: Structured logging across all services with centralized configuration

**Development Tools**
- **Package Management**: npm (Node.js), cpanm (Perl), pip (Python), zig build
- **Process Management**: Concurrent service startup with health monitoring
- **Testing**: Comprehensive test suites in each language
- **Documentation**: Auto-generated API docs via FastAPI

### Key Integrations

**Learning Content APIs**
- Google Gemini 2.0 Flash for learning content queries and insights
- YouTube Transcript API for video learning content extraction
- Web scraping APIs for article and documentation processing
- File processing APIs for PDF, EPUB, and document analysis

**Performance Optimizations**
- Zig SIMD acceleration for vector operations
- SQLite connection pooling across services
- Async/await patterns in Python services
- Intelligent caching at multiple layers

**Cross-Language Communication**
- JSON-based message passing between services
- RESTful API design with OpenAPI specifications
- Health check endpoints for service monitoring
- Graceful error handling and fallback mechanisms

---

*Built for lifelong learners who want to track their growth, understand their learning patterns, and discover connections across everything they study. Transform scattered learning into organized knowledge mastery.*
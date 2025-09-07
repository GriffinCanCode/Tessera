#!/usr/bin/env python3
"""
Modern Gemini API Service - 2025 Best Practices
Features: Pydantic v2 patterns, DI, async context managers, structured logging
"""

import os
import asyncio
from contextlib import asynccontextmanager
from typing import Dict, List, Optional, Any, AsyncGenerator
from datetime import datetime
from enum import Enum
from pathlib import Path
from uuid import uuid4

import aiohttp
import structlog
import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from tenacity import retry, stop_after_attempt, wait_exponential

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


# ========== MODERN CONFIGURATION WITH PYDANTIC SETTINGS ==========

class LogLevel(str, Enum):
    DEBUG = "DEBUG"
    INFO = "INFO" 
    WARNING = "WARNING"
    ERROR = "ERROR"


class Settings(BaseSettings):
    """Modern configuration with Pydantic Settings v2"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8", 
        case_sensitive=False,
        extra="ignore"
    )
    
    # API Configuration
    gemini_api_key: str = Field(..., description="Google Gemini API key")
    host: str = Field(default="127.0.0.1", description="Service host")
    port: int = Field(default=8001, description="Service port")
    
    # Model Configuration  
    model_name: str = Field(default="gemini-2.0-flash-exp", description="Gemini model to use")
    default_temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    max_output_tokens: int = Field(default=8192, gt=0)
    top_p: float = Field(default=0.95, ge=0.0, le=1.0)
    top_k: int = Field(default=64, gt=0)
    
    # Application Settings
    log_level: LogLevel = Field(default=LogLevel.INFO)
    max_conversations: int = Field(default=1000, gt=0)
    conversation_ttl_hours: int = Field(default=24, gt=0)
    
    # Privacy Protection Settings (CRITICAL: Conversations are NEVER persisted to database)
    enable_conversation_persistence: bool = Field(
        default=False, 
        description="PRIVACY: If True, conversations would be saved to database. ALWAYS keep False for privacy."
    )
    enable_conversation_embedding: bool = Field(
        default=False,
        description="PRIVACY: If True, conversations would be embedded for search. ALWAYS keep False for privacy."
    )
    log_conversation_content: bool = Field(
        default=False,
        description="PRIVACY: If True, conversation content would be logged. Keep False for privacy."
    )
    
    # Performance
    max_concurrent_requests: int = Field(default=10, gt=0)
    request_timeout: float = Field(default=30.0, gt=0.0)


# ========== MODERN PYDANTIC V2 MODELS ==========

class MessageRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant" 
    SYSTEM = "system"


class ChatMessage(BaseModel):
    """Modern Pydantic v2 model with ConfigDict"""
    
    model_config = ConfigDict(
        str_strip_whitespace=True,
        validate_assignment=True,
        arbitrary_types_allowed=False,
        frozen=True  # Immutable
    )
    
    role: MessageRole = Field(..., description="Message role")
    content: str = Field(..., min_length=1, description="Message content")
    timestamp: datetime = Field(default_factory=datetime.now)
    metadata: Optional[Dict[str, Any]] = Field(default=None)

    @field_validator('content')
    @classmethod
    def validate_content(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Content cannot be empty")
        return v.strip()


class ConversationContext(BaseModel):
    """Structured context with validation"""
    
    model_config = ConfigDict(validate_assignment=True)
    
    articles: List[Dict[str, Any]] = Field(default_factory=list)
    connections: List[Dict[str, Any]] = Field(default_factory=list) 
    insights: Dict[str, Any] = Field(default_factory=dict)
    semantic_chunks: List[Dict[str, Any]] = Field(default_factory=list)  # New for RAG
    project_id: Optional[int] = Field(default=None, description="Project context for conversation")


class ChatRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    
    conversation_id: str = Field(..., min_length=1, description="Conversation ID")
    message: str = Field(..., min_length=1, description="User message")
    context: Optional[ConversationContext] = None
    temperature: Optional[float] = Field(None, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(None, gt=0, le=8192)


class ChatResponse(BaseModel):
    model_config = ConfigDict(frozen=True)
    
    conversation_id: str
    message: str
    timestamp: datetime = Field(default_factory=datetime.now)
    token_usage: Optional[Dict[str, int]] = None
    context_used: bool = False
    model_used: str


# ========== MODERN ASYNC SERVICES WITH DI ==========

class ConversationService:
    """Service for managing conversations with modern patterns
    
    PRIVACY GUARANTEE: This service stores conversations ONLY in memory.
    Conversations are NEVER persisted to database or embedded for search.
    They are automatically cleaned up based on TTL settings.
    """
    
    def __init__(self, settings: Settings):
        self.settings = settings
        self.conversations: Dict[str, List[ChatMessage]] = {}  # Memory only - never persisted
        self.metadata: Dict[str, Dict[str, Any]] = {}
        self.logger = structlog.get_logger(__name__).bind(service="conversation")
        
        # Privacy validation - ensure conversation persistence is disabled
        if self.settings.enable_conversation_persistence:
            raise RuntimeError("PRIVACY VIOLATION: Conversation persistence must be disabled for privacy")
        if self.settings.enable_conversation_embedding:
            raise RuntimeError("PRIVACY VIOLATION: Conversation embedding must be disabled for privacy")
    
    async def get_or_create(self, conversation_id: str) -> List[ChatMessage]:
        """Get existing conversation or create new one"""
        if conversation_id not in self.conversations:
            self.conversations[conversation_id] = []
            self.metadata[conversation_id] = {
                "created_at": datetime.now(),
                "message_count": 0,
                "last_activity": datetime.now()
            }
            await self.logger.ainfo("Created conversation", conversation_id=conversation_id)
        
        return self.conversations[conversation_id]
    
    async def add_message(self, conversation_id: str, message: ChatMessage) -> None:
        """Add message to conversation (PRIVACY: message content never logged)"""
        conversation = await self.get_or_create(conversation_id)
        conversation.append(message)
        
        self.metadata[conversation_id]["message_count"] += 1
        self.metadata[conversation_id]["last_activity"] = datetime.now()
        
        # Privacy-conscious logging - log metadata only, never message content
        if not self.settings.log_conversation_content:
            await self.logger.ainfo(
                "Message added to conversation",
                conversation_id=conversation_id,
                message_role=message.role.value,
                message_length=len(message.content),
                total_messages=self.metadata[conversation_id]["message_count"]
            )
    
    async def cleanup_old_conversations(self) -> int:
        """Clean up old conversations based on TTL"""
        cutoff = datetime.now().timestamp() - (self.settings.conversation_ttl_hours * 3600)
        removed = 0
        
        for conv_id, meta in list(self.metadata.items()):
            if meta["last_activity"].timestamp() < cutoff:
                del self.conversations[conv_id]
                del self.metadata[conv_id]
                removed += 1
        
        return removed


class GeminiService:
    """Modern Gemini service with retry logic and proper error handling"""
    
    def __init__(self, settings: Settings):
        self.settings = settings
        self.model: Optional[genai.GenerativeModel] = None
        self.logger = structlog.get_logger(__name__).bind(service="gemini")
    
    async def initialize(self) -> None:
        """Initialize Gemini model"""
        genai.configure(api_key=self.settings.gemini_api_key)
        
        generation_config = {
            "temperature": self.settings.default_temperature,
            "top_p": self.settings.top_p,
            "top_k": self.settings.top_k,
            "max_output_tokens": self.settings.max_output_tokens,
        }
        
        safety_settings = [
            {
                "category": category,
                "threshold": HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
            }
            for category in [
                HarmCategory.HARM_CATEGORY_HARASSMENT,
                HarmCategory.HARM_CATEGORY_HATE_SPEECH,
                HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
                HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
            ]
        ]
        
        self.model = genai.GenerativeModel(
            model_name=self.settings.model_name,
            generation_config=generation_config,
            safety_settings=safety_settings,
            system_instruction=self._get_system_instruction()
        )
        
        await self.logger.ainfo("Gemini initialized", model=self.settings.model_name)
    
    async def _retrieve_rag_context(
        self, 
        message: str, 
        project_id: Optional[int] = None, 
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """Retrieve relevant context using RAG"""
        try:
            # Make request to embedding service for semantic search
            async with aiohttp.ClientSession() as session:
                payload = {
                    "query": message,
                    "limit": limit,
                    "min_similarity": 0.4,
                    "project_id": project_id
                }
                
                async with session.post(
                    "http://127.0.0.1:8002/search",
                    json=payload,
                    headers={"Content-Type": "application/json"}
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get("chunks", [])
                    else:
                        await self.logger.awarning(
                            "Failed to retrieve RAG context", 
                            status=response.status
                        )
                        return []
                        
        except Exception as e:
            await self.logger.aerror("RAG retrieval failed", error=str(e))
            return []
    
    def _get_system_instruction(self) -> str:
        """Get system instruction for the model"""
        return """You are an expert knowledge assistant for a personal Wikipedia knowledge graph.

Core capabilities:
- Analyze and synthesize information from crawled articles
- Identify connections and patterns across topics  
- Provide accurate, well-sourced responses
- Suggest related exploration paths
- Maintain conversational context

Guidelines:
1. Be precise and cite sources when available
2. Draw meaningful connections between concepts
3. Ask clarifying questions when context is unclear
4. Suggest related topics for exploration
5. Maintain a helpful, engaging tone"""
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def generate_response(
        self,
        conversation_history: List[ChatMessage],
        new_message: str,
        context: Optional[ConversationContext] = None,
        temperature: Optional[float] = None
    ) -> str:
        """Generate response with retry logic"""
        if not self.model:
            raise RuntimeError("Gemini model not initialized")
        
        # Retrieve RAG context based on the message and project context
        project_id = context.project_id if context else None
        rag_chunks = await self._retrieve_rag_context(new_message, project_id)
        
        # Add RAG chunks to context
        if context is None:
            context = ConversationContext(project_id=project_id)
        
        if rag_chunks:
            context.semantic_chunks = rag_chunks
            await self.logger.ainfo(
                "Retrieved RAG context", 
                chunks_count=len(rag_chunks),
                project_id=project_id
            )
        
        # Format context if provided
        context_str = self._format_context(context) if context else ""
        
        # Prepare full message
        full_message = f"Context:\n{context_str}\n\nUser: {new_message}" if context_str else new_message
        
        # Convert history to Gemini format
        history = [
            {"role": msg.role.value, "parts": [msg.content]}
            for msg in conversation_history[-10:]  # Limit context window
        ]
        
        try:
            chat_session = self.model.start_chat(history=history)
            
            # Run in executor to avoid blocking
            response = await asyncio.get_event_loop().run_in_executor(
                None, chat_session.send_message, full_message
            )
            
            return response.text
            
        except Exception as e:
            await self.logger.aerror("Gemini generation failed", error=str(e))
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Generation failed: {str(e)}"
            )
    
    def _format_context(self, context: ConversationContext) -> str:
        """Format context for model consumption with RAG priority"""
        parts = []
        
        if context.semantic_chunks:  # Prioritize RAG chunks
            parts.append("🔍 Most Relevant Knowledge (Semantic Search):")
            for i, chunk in enumerate(context.semantic_chunks[:5], 1):
                article_title = chunk.get('article_title', 'Unknown')
                section = chunk.get('section_name', '')
                content = chunk.get('content', '')
                similarity = chunk.get('similarity', 0)
                
                # Truncate content intelligently
                if len(content) > 400:
                    sentences = content.split('. ')
                    truncated = '. '.join(sentences[:2])
                    if len(truncated) < 300:
                        truncated += '. ' + sentences[2] if len(sentences) > 2 else ''
                    content = truncated + "..."
                
                section_info = f" ({section})" if section else ""
                parts.append(f"{i}. {article_title}{section_info} [similarity: {similarity:.2f}]")
                parts.append(f"   {content}")
                parts.append("")  # Empty line for readability
        
        if context.articles:
            parts.append("📚 Additional Article Context:")
            for article in context.articles[:3]:
                title = article.get('title', 'Unknown')
                summary = article.get('summary', '')[:200]
                if len(summary) > 200:
                    summary = summary[:200] + "..."
                parts.append(f"- {title}: {summary}")
        
        if context.connections:
            parts.append("\n🔗 Knowledge Connections:")
            for conn in context.connections[:3]:
                from_title = conn.get('from_title', 'Unknown')
                to_title = conn.get('to_title', 'Unknown')
                relevance = conn.get('relevance', 0)
                parts.append(f"- {from_title} → {to_title} (relevance: {relevance:.2f})")
        
        if context.insights:
            parts.append(f"\n📊 Knowledge Base Stats:")
            insights = context.insights
            if 'total_articles' in insights:
                parts.append(f"- Articles: {insights['total_articles']}")
            if 'knowledge_breadth' in insights:
                parts.append(f"- Topics: {insights['knowledge_breadth']}")
        
        return "\n".join(parts) if parts else "No additional context available."


# ========== DEPENDENCY INJECTION SETUP ==========

async def get_settings() -> Settings:
    """DI: Get application settings"""
    return Settings()


async def get_conversation_service(settings: Settings = Depends(get_settings)) -> ConversationService:
    """DI: Get conversation service"""
    return ConversationService(settings)


async def get_gemini_service(settings: Settings = Depends(get_settings)) -> GeminiService:
    """DI: Get Gemini service"""
    service = GeminiService(settings)
    if not service.model:
        await service.initialize()
    return service


# ========== MODERN APP WITH LIFESPAN MANAGEMENT ==========

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Modern lifespan management"""
    logger = structlog.get_logger(__name__)
    
    # Startup
    await logger.ainfo("Starting Tessera Gemini Service")
    
    # Initialize services
    settings = Settings()
    gemini_service = GeminiService(settings)
    await gemini_service.initialize()
    
    # Store in app state for endpoints
    app.state.gemini_service = gemini_service
    app.state.settings = settings
    
    yield
    
    # Shutdown
    await logger.ainfo("Shutting down Tessera Gemini Service")


# Create FastAPI app with modern patterns
app = FastAPI(
    title="Tessera Gemini Service",
    version="2.0.0",
    description="Modern knowledge bot service with RAG capabilities",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ========== MODERN ENDPOINTS WITH DI ==========

@app.get("/health")
async def health_check(settings: Settings = Depends(get_settings)):
    """Modern health check with dependency injection"""
    return {
        "service": "Tessera Gemini Service",
        "version": "2.0.0",
        "status": "healthy",
        "model": settings.model_name,
        "timestamp": datetime.now().isoformat()
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    conversation_service: ConversationService = Depends(get_conversation_service),
    gemini_service: GeminiService = Depends(get_gemini_service),
    settings: Settings = Depends(get_settings)
):
    """Modern chat endpoint with full DI and validation"""
    logger = structlog.get_logger(__name__).bind(
        conversation_id=request.conversation_id,
        endpoint="chat"
    )
    
    try:
        # Get conversation history
        history = await conversation_service.get_or_create(request.conversation_id)
        
        # Generate response
        response_text = await gemini_service.generate_response(
            conversation_history=history,
            new_message=request.message,
            context=request.context,
            temperature=request.temperature
        )
        
        # Store messages
        user_msg = ChatMessage(role=MessageRole.USER, content=request.message)
        assistant_msg = ChatMessage(role=MessageRole.ASSISTANT, content=response_text)
        
        await conversation_service.add_message(request.conversation_id, user_msg)
        await conversation_service.add_message(request.conversation_id, assistant_msg)
        
        await logger.ainfo("Chat response generated", response_length=len(response_text))
        
        return ChatResponse(
            conversation_id=request.conversation_id,
            message=response_text,
            context_used=bool(request.context),
            model_used=settings.model_name
        )
        
    except Exception as e:
        await logger.aerror("Chat processing failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Chat processing failed"
        )


@app.get("/conversations")
async def list_conversations(
    conversation_service: ConversationService = Depends(get_conversation_service)
):
    """List active conversations with metadata"""
    return {
        "conversations": [
            {
                "conversation_id": conv_id,
                "message_count": meta["message_count"],
                "created_at": meta["created_at"].isoformat(),
                "last_activity": meta["last_activity"].isoformat()
            }
            for conv_id, meta in conversation_service.metadata.items()
        ],
        "total": len(conversation_service.conversations)
    }


@app.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    conversation_service: ConversationService = Depends(get_conversation_service)
):
    """Delete specific conversation"""
    if conversation_id in conversation_service.conversations:
        del conversation_service.conversations[conversation_id]
        del conversation_service.metadata[conversation_id]
        return {"message": f"Conversation {conversation_id} deleted"}
    
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Conversation not found"
    )


# ========== MODERN STARTUP ==========

if __name__ == "__main__":
    import uvicorn
    
    # Configure structured logging
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    try:
        settings = Settings()
        
        uvicorn.run(
            "gemini_service:app",
            host=settings.host,
            port=settings.port,
            reload=False,  # Set True for development
            log_level=settings.log_level.value.lower(),
            access_log=True
        )
        
    except Exception as e:
        print(f"Failed to start service: {e}")
        exit(1)

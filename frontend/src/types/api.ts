// WikiCrawler API Types

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface WikiArticle {
  id: number;
  title: string;
  url: string;
  content: string;
  summary: string;
  parsed_at: number;
  links?: WikiLink[];
}

export interface WikiLink {
  id: number;
  source_article_id: number;
  target_article_id: number;
  anchor_text: string;
  relevance_score: number;
  title: string;
  url: string;
}

export interface SearchResult {
  query: string;
  count: number;
  results: WikiArticle[];
}

export interface DatabaseStats {
  total_articles: number;
  total_links: number;
  avg_links_per_article: number;
  articles_last_24h?: number;
  links_last_24h?: number;
  network_density?: number;
  session_stats?: SessionStats;
}

export interface KnowledgeHub {
  id: number;
  title: string;
  url: string;
  summary: string;
  categories: string[];
  total_connections: number;
  outbound_links: number;
  inbound_links: number;
}

export interface Discovery {
  id: number;
  from_title: string;
  to_title: string;
  from_url: string;
  to_url: string;
  anchor_text: string;
  relevance_score: number;
  created_at: number;
  time_ago: string;
  strength: string;
  from_categories: string[];
  to_categories: string[];
}

export interface SessionStats {
  start_time: number;
  end_time?: number;
  duration?: number;
  articles_crawled: number;
  articles_processed: number;
  links_analyzed: number;
  start_url: string;
  max_depth: number;
  max_articles: number;
}

export interface CrawlRequest {
  start_url: string;
  interests: string[];
  max_depth?: number;
  max_articles?: number;
}

export interface KnowledgeGraphNode {
  id: number;
  title: string;
  url: string;
  summary: string;
  depth: number;
  categories?: string[];
  coordinates?: Record<string, number | string | null>;
  node_type: 'person' | 'place' | 'concept' | 'organization' | 'event' | 'technology' | 'general';
  importance: number;
  relevance_score?: number;
  x?: number;
  y?: number;
}

export interface KnowledgeGraphEdge {
  from: number;
  to: number;
  weight: number;
  anchor_text: string;
}

export interface KnowledgeGraph {
  nodes: Record<string, KnowledgeGraphNode>;
  edges: KnowledgeGraphEdge[];
  metadata?: {
    created_at: number;
    min_relevance: number;
    max_depth: number;
    center_article?: number;
    type?: 'centered' | 'complete';
  };
  metrics?: {
    node_count: number;
    edge_count: number;
    density: number;
    avg_out_degree: number;
    avg_in_degree: number;
    max_out_degree: number;
    max_in_degree: number;
    node_types: Record<string, number>;
    avg_edge_weight: number;
    connected_components: number;
  };
}

export interface GraphOptions {
  min_relevance?: number;
  max_depth?: number;
  center_article_id?: number;
  format?: 'json' | 'graphml' | 'dot';
}

export interface ExportOptions {
  format: 'json' | 'graphml' | 'dot';
  filename?: string;
  min_relevance?: number;
}

export interface ExportResult {
  format: string;
  filename: string;
  path: string;
  size: number;
}

export interface HealthCheck {
  status: 'ok' | 'error';
  timestamp: number;
  uptime: number;
}

export interface ApiInfo {
  name: string;
  version: string;
  description: string;
  endpoints: Record<string, string>;
  stats: DatabaseStats;
}

// Claude Bot Types
export interface BotMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp?: string;
}

export interface ChatRequest {
  conversation_id: string;
  message: string;
  max_tokens?: number;
  temperature?: number;
  include_insights?: boolean;
}

export interface ChatResponse {
  conversation_id: string;
  message: string;
  timestamp: string;
  context_used: boolean;
}

export interface KnowledgeQueryRequest {
  query: string;
  conversation_id?: string;
  min_relevance?: number;
  include_recent?: boolean;
}

export interface KnowledgeQueryResponse {
  query: string;
  answer: string;
  sources: string[];
  confidence: number;
  reasoning?: string;
}

export interface ConversationMetadata {
  created_at: string;
  message_count: number;
  last_activity: string;
}

export interface ConversationInfo {
  conversation_id: string;
  created_at: string;
  message_count: number;
  last_activity: string;
}

export interface ConversationHistory {
  conversation_id: string;
  messages: BotMessage[];
  metadata: ConversationMetadata;
}

// Project Management Types
export interface Project {
  id: number;
  name: string;
  description?: string;
  color: string;
  settings?: Record<string, unknown>;
  is_default: boolean;
  created_at: number;
  updated_at: number;
  article_count?: number;
  link_count?: number;
  chunk_count?: number;
  last_activity?: number;
}

export interface ProjectCreateRequest {
  name: string;
  description?: string;
  color?: string;
  settings?: Record<string, unknown>;
}

export interface ProjectUpdateRequest {
  name?: string;
  description?: string;
  color?: string;
  settings?: Record<string, unknown>;
}

export interface ProjectListResponse {
  projects: Project[];
  count: number;
}

export interface ProjectArticlesResponse {
  articles: WikiArticle[];
  count: number;
  project_id: number;
}

import axios from 'axios';
import { apiLogger, measureAsyncPerformance } from '../utils/logger';
import type {
  ApiResponse,
  WikiArticle,
  SearchResult,
  DatabaseStats,
  CrawlRequest,
  KnowledgeGraph,
  GraphOptions,
  ExportOptions,
  ExportResult,
  HealthCheck,
  ApiInfo,
  SessionStats,
  KnowledgeHub,
  Discovery,
  ChatRequest,
  ChatResponse,
  KnowledgeQueryRequest,
  KnowledgeQueryResponse,
  ConversationInfo,
  ConversationHistory,
  Project,
  ProjectCreateRequest,
  ProjectUpdateRequest,
  ProjectListResponse,
  ProjectArticlesResponse,
} from '../types/api';

// Data Ingestion Types
export interface IngestionResult {
  success: boolean;
  content_id?: number;
  title: string;
  content_type: string;
  word_count: number;
  chunk_count: number;
  processing_time_seconds: number;
  error?: string;
  metadata?: Record<string, unknown>;
}

// Configure axios instance
const api = axios.create({
  baseURL: '/api',  // Use /api prefix to route through Vite proxy to Perl backend
  timeout: 120000, // 2 minutes timeout for crawl operations
  headers: {
    'Content-Type': 'application/json',
  },
});

// Response interceptor to handle API responses
api.interceptors.response.use(
  response => response,
  error => {
    console.error('API Error:', error);
    throw error;
  }
);

export class TesseraAPI {
  // Get API information and stats
  static async getInfo(): Promise<ApiResponse<ApiInfo>> {
    const response = await api.get('/');
    return response.data;
  }

  // Get database statistics
  static async getStats(): Promise<ApiResponse<DatabaseStats>> {
    const response = await api.get('/stats');
    return response.data;
  }

  // Search for articles
  static async searchArticles(query: string, limit = 20): Promise<ApiResponse<SearchResult>> {
    return measureAsyncPerformance('API Search Articles', async () => {
      apiLogger.logApiRequest('GET', '/search', { query, limit });
      
      const response = await api.get('/search', {
        params: { q: query, limit },
      });
      
      apiLogger.logApiResponse('GET', '/search', response.status, undefined, {
        results: response.data.data?.length || 0
      });
      
      return response.data;
    }, apiLogger);
  }

  // Get article by title
  static async getArticle(title: string): Promise<ApiResponse<WikiArticle>> {
    const response = await api.get(`/article/${encodeURIComponent(title)}`);
    return response.data;
  }

  // Start crawling
  static async startCrawl(request: CrawlRequest): Promise<ApiResponse<SessionStats>> {
    console.log('TesseraAPI.startCrawl called with:', JSON.stringify(request, null, 2));
    console.log('Making POST request to /crawl...');
    
    try {
      const response = await api.post('/crawl', request);
      console.log('TesseraAPI.startCrawl SUCCESS - Response received:', response);
      console.log('Response status:', response.status);
      console.log('Response data:', response.data);
      return response.data;
    } catch (error: unknown) {
      console.error('TesseraAPI.startCrawl FAILED:', error);
      if (axios.isAxiosError(error)) {
        if (error.response) {
          console.error('Error response data:', error.response.data);
          console.error('Error response status:', error.response.status);
          console.error('Error response headers:', error.response.headers);
        } else if (error.request) {
          console.error('No response received. Request details:', error.request);
        } else {
          console.error('Request setup error:', error.message);
        }
      } else {
        console.error('Unknown error:', error);
      }
      throw error;
    }
  }

  // Build knowledge graph
  static async buildGraph(options: GraphOptions = {}): Promise<ApiResponse<KnowledgeGraph>> {
    const response = await api.get('/graph', {
      params: options,
    });
    return response.data;
  }

  // Export knowledge graph
  static async exportGraph(options: ExportOptions): Promise<ApiResponse<ExportResult>> {
    const response = await api.get('/export', {
      params: options,
    });
    return response.data;
  }

  // Clean up old data
  static async cleanup(
    keepDays: number
  ): Promise<ApiResponse<{ deleted_articles: number; keep_days: number }>> {
    const response = await api.delete('/cleanup', {
      params: { keep_days: keepDays },
    });
    return response.data;
  }

  // Get knowledge hubs
  static async getKnowledgeHubs(limit = 10): Promise<ApiResponse<{ hubs: KnowledgeHub[]; count: number }>> {
    const response = await api.get('/hubs', {
      params: { limit },
    });
    return response.data;
  }

  // Get recent discoveries
  static async getRecentDiscoveries(limit = 10): Promise<ApiResponse<{ discoveries: Discovery[]; count: number }>> {
    const response = await api.get('/discoveries', {
      params: { limit },
    });
    return response.data;
  }

  // Get personal knowledge insights
  static async getKnowledgeInsights(minRelevance = 0.3): Promise<ApiResponse<unknown>> {
    const response = await api.get('/insights', {
      params: { min_relevance: minRelevance },
    });
    return response.data;
  }

  // Get temporal analysis
  static async getTemporalAnalysis(minRelevance = 0.3): Promise<ApiResponse<unknown>> {
    const response = await api.get('/temporal', {
      params: { min_relevance: minRelevance },
    });
    return response.data;
  }

  // Get advanced graph layouts
  static async getGraphLayouts(options: GraphOptions = {}): Promise<ApiResponse<unknown>> {
    const response = await api.get('/layouts', {
      params: options,
    });
    return response.data;
  }

  // Health check
  static async healthCheck(): Promise<ApiResponse<HealthCheck>> {
    const response = await api.get('/health');
    return response.data;
  }

  // Get article content as formatted text (utility method)
  static formatArticleContent(article: WikiArticle): string {
    if (!article.summary && !article.content) return 'No content available.';

    const content = article.summary || article.content;
    // Basic formatting - remove excessive whitespace and format paragraphs
    return content.replace(/\s+/g, ' ').replace(/\. /g, '.\n\n').trim();
  }

  // Calculate reading time estimate
  static estimateReadingTime(content: string): number {
    const wordsPerMinute = 200;
    const wordCount = content.split(/\s+/).length;
    return Math.ceil(wordCount / wordsPerMinute);
  }

  // Format relevance score as percentage
  static formatRelevanceScore(score: number): string {
    return `${Math.round(score * 100)}%`;
  }

  // Generate article URL for external viewing
  static getWikipediaUrl(title: string): string {
    const encodedTitle = encodeURIComponent(title.replace(/ /g, '_'));
    return `https://en.wikipedia.org/wiki/${encodedTitle}`;
  }

  // Parse Wikipedia title from URL
  static getTitleFromUrl(url: string): string {
    const match = url.match(/\/wiki\/([^#?]+)/);
    if (match) {
      return decodeURIComponent(match[1]).replace(/_/g, ' ');
    }
    return url;
  }

  // Claude Bot API Methods

  // Generate new conversation ID
  static async createConversation(): Promise<ApiResponse<{ conversation_id: string }>> {
    const response = await api.get('/bot/new-conversation');
    return response.data;
  }

  // Chat with bot
  static async chatWithBot(request: ChatRequest): Promise<ApiResponse<ChatResponse>> {
    const response = await api.post('/bot/chat', request);
    return response.data;
  }

  // Knowledge query
  static async knowledgeQuery(request: KnowledgeQueryRequest): Promise<ApiResponse<KnowledgeQueryResponse>> {
    const response = await api.post('/bot/knowledge-query', request);
    return response.data;
  }

  // List conversations
  static async listConversations(): Promise<ApiResponse<{ conversations: ConversationInfo[]; total: number }>> {
    const response = await api.get('/bot/conversations');
    return response.data;
  }

  // Get conversation history
  static async getConversationHistory(conversationId: string): Promise<ApiResponse<ConversationHistory>> {
    const response = await api.get(`/bot/conversation/${encodeURIComponent(conversationId)}/history`);
    return response.data;
  }

  // Delete conversation
  static async deleteConversation(conversationId: string): Promise<ApiResponse<{ message: string }>> {
    const response = await api.delete(`/bot/conversation/${encodeURIComponent(conversationId)}`);
    return response.data;
  }

  // Project Management API Methods

  // List all projects
  static async listProjects(): Promise<ApiResponse<ProjectListResponse>> {
    const response = await api.get('/projects');
    return response.data;
  }

  // Create new project
  static async createProject(projectData: Partial<ProjectCreateRequest>): Promise<ApiResponse<{ project: Project }>> {
    const response = await api.post('/projects', projectData);
    return response.data;
  }

  // Get project by ID
  static async getProject(projectId: number): Promise<ApiResponse<Project>> {
    const response = await api.get(`/project/${projectId}`);
    return response.data;
  }

  // Update project
  static async updateProject(projectId: number, updateData: ProjectUpdateRequest): Promise<ApiResponse<{ project: Project }>> {
    const response = await api.put(`/project/${projectId}`, updateData);
    return response.data;
  }

  // Delete project
  static async deleteProject(projectId: number): Promise<ApiResponse<{ message: string }>> {
    const response = await api.delete(`/project/${projectId}`);
    return response.data;
  }

  // Get project articles
  static async getProjectArticles(projectId: number, limit = 50, offset = 0): Promise<ApiResponse<ProjectArticlesResponse>> {
    const response = await api.get(`/project/${projectId}/articles`, {
      params: { limit, offset }
    });
    return response.data;
  }

  // Search within project
  static async searchProjectArticles(projectId: number, query: string, limit = 20): Promise<ApiResponse<SearchResult & { project_id: number }>> {
    const response = await api.get(`/project/${projectId}/search`, {
      params: { q: query, limit }
    });
    return response.data;
  }

  // Search articles with optional project context
  static async searchArticlesWithProject(query: string, limit = 20, projectId?: number): Promise<ApiResponse<SearchResult & { project_id?: number }>> {
    const params: Record<string, unknown> = { q: query, limit };
    if (projectId) params.project_id = projectId;
    
    const response = await api.get('/search', { params });
    return response.data;
  }

  // Chat with bot with project context
  static async chatWithBotProject(request: ChatRequest & { project_id?: number }): Promise<ApiResponse<ChatResponse>> {
    const response = await api.post('/bot/chat', request);
    return response.data;
  }

  // Start crawling with project context
  static async startCrawlProject(request: CrawlRequest & { project_id?: number }): Promise<ApiResponse<SessionStats>> {
    console.log('TesseraAPI.startCrawlProject called with:', JSON.stringify(request, null, 2));
    
    try {
      const response = await api.post('/crawl', request);
      console.log('TesseraAPI.startCrawlProject SUCCESS - Response received:', response);
      return response.data;
    } catch (error: unknown) {
      console.error('TesseraAPI.startCrawlProject FAILED:', error);
      throw error;
    }
  }

  // Learning system endpoints
  static async getLearningSubjects(): Promise<ApiResponse<{ subjects: Record<string, unknown>[]; count: number }>> {
    const response = await api.get('/learning/subjects');
    return response.data;
  }

  static async getLearningAnalytics(): Promise<ApiResponse<{ 
    subjects: Record<string, unknown>[]; 
    brain_stats: {
      total_knowledge_points: number;
      dominant_area: string;
      balance_score: number;
      growth_rate: number;
      total_time_minutes: number;
      knowledge_velocity: number;
    };
    count: number;
  }>> {
    const response = await api.get('/learning/analytics');
    return response.data;
  }

  // Brain visualization data - transforms learning analytics into brain visualization format
  static async getBrainData(): Promise<ApiResponse<{
    areas: Array<{
      id: string;
      name: string;
      percentage: number;
      color: string;
      timeSpent: number;
      totalContent: number;
      completedContent: number;
      region: 'frontal' | 'parietal' | 'temporal' | 'occipital' | 'cerebellum' | 'brainstem' | 'limbic';
      position3D: { x: number; y: number; z: number };
      scale: number;
      connections: string[];
    }>;
    stats: {
      totalKnowledgePoints: number;
      dominantArea: string;
      balanceScore: number;
      growthRate: number;
    };
  }>> {
    return measureAsyncPerformance('API Get Brain Data', async () => {
      apiLogger.logApiRequest('GET', '/learning/analytics', {});
      
      const response = await api.get('/learning/analytics');
      
      apiLogger.logApiResponse('GET', '/learning/analytics', response.status, undefined, {
        subjects: response.data.data?.subjects?.length || 0
      });
      
      // Transform the learning analytics data into brain visualization format
      const analyticsData = response.data.data;
      
      if (!analyticsData || !analyticsData.subjects) {
        throw new Error('No learning analytics data available');
      }

      // Define brain region mappings and 3D positions
      const brainRegions = [
        { region: 'frontal' as const, position: { x: 0.8, y: 0.3, z: 1.4 } },
        { region: 'parietal' as const, position: { x: -0.6, y: 1.2, z: 0.2 } },
        { region: 'temporal' as const, position: { x: 1.4, y: -0.2, z: 0.6 } },
        { region: 'occipital' as const, position: { x: -0.4, y: 0.6, z: -1.3 } },
        { region: 'limbic' as const, position: { x: 0.3, y: -0.6, z: 0.8 } },
        { region: 'cerebellum' as const, position: { x: -0.2, y: -1.4, z: -0.6 } },
        { region: 'brainstem' as const, position: { x: 0.0, y: -1.8, z: 0.0 } }
      ];

      // Default colors for subjects
      const defaultColors = [
        '#3b82f6', '#10b981', '#8b5cf6', '#f59e0b', 
        '#ef4444', '#06b6d4', '#84cc16', '#f97316',
        '#ec4899', '#6366f1', '#14b8a6', '#eab308'
      ];

      // Transform subjects into knowledge areas
      const areas = analyticsData.subjects.map((subject: Record<string, unknown>, index: number) => {
        const regionIndex = index % brainRegions.length;
        const region = brainRegions[regionIndex];
        
        // Calculate activity percentage based on completion
        const activityPercentage = Math.min(100, Math.max(10, (subject.avg_completion as number) || 0));
        
        // Use subject color if available, otherwise use default
        const color = (subject.color as string) || defaultColors[index % defaultColors.length];
        
        // Calculate connections (simple algorithm based on subject similarity)
        const connections: string[] = [];
        if (index > 0) connections.push((index - 1).toString());
        if (index < analyticsData.subjects.length - 1) connections.push((index + 1).toString());
        
        return {
          id: subject.id?.toString() || index.toString(),
          name: (subject.name as string) || `Subject ${index + 1}`,
          percentage: Math.round(activityPercentage),
          color: color,
          timeSpent: Math.round(((subject.total_time as number) || 0) / 60), // Convert minutes to hours
          totalContent: (subject.total_content as number) || 0,
          completedContent: (subject.completed_content as number) || 0,
          region: region.region,
          position3D: {
            x: region.position.x + (Math.random() - 0.5) * 0.3, // Add slight randomization
            y: region.position.y + (Math.random() - 0.5) * 0.3,
            z: region.position.z + (Math.random() - 0.5) * 0.3
          },
          scale: 1.0,
          connections: connections
        };
      });

      // Transform brain stats
      const stats = {
        totalKnowledgePoints: analyticsData.brain_stats?.total_knowledge_points || 0,
        dominantArea: analyticsData.brain_stats?.dominant_area || '',
        balanceScore: analyticsData.brain_stats?.balance_score || 0,
        growthRate: analyticsData.brain_stats?.growth_rate || 0
      };

      return {
        success: true,
        data: {
          areas,
          stats
        }
      };
    }, apiLogger);
  }

  static async getLearningContent(subjectId?: number, limit = 50): Promise<ApiResponse<{ content: Record<string, unknown>[]; count: number }>> {
    const params: Record<string, unknown> = { limit };
    if (subjectId) {
      params.subject_id = subjectId;
    }
    const response = await api.get('/learning/content', { params });
    return response.data;
  }

  static async addLearningContent(content: {
    title: string;
    content_type: string;
    content?: string;
    url?: string;
    subjects?: number[];
    difficulty_level?: number;
    estimated_time_minutes?: number;
  }): Promise<ApiResponse<{ content_id: number; message: string }>> {
    const response = await api.post('/learning/content', content);
    return response.data;
  }

  // Data Ingestion Methods
  static async ingestYoutube(
    url: string,
    title?: string,
    description?: string,
    project_id?: number
  ): Promise<IngestionResult> {
    const formData = new FormData();
    formData.append('url', url);
    if (title) formData.append('title', title);
    if (description) formData.append('description', description);
    if (project_id) formData.append('project_id', project_id.toString());

    const response = await api.post('/ingest/youtube', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data.data; // Return the nested data object
  }

  static async ingestArticle(
    url: string,
    title?: string,
    description?: string,
    project_id?: number
  ): Promise<IngestionResult> {
    const formData = new FormData();
    formData.append('url', url);
    if (title) formData.append('title', title);
    if (description) formData.append('description', description);
    if (project_id) formData.append('project_id', project_id.toString());

    const response = await api.post('/ingest/article', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data.data;
  }

  static async ingestBook(
    file: File,
    title?: string,
    description?: string,
    project_id?: number
  ): Promise<IngestionResult> {
    const formData = new FormData();
    formData.append('file', file);
    if (title) formData.append('title', title);
    if (description) formData.append('description', description);
    if (project_id) formData.append('project_id', project_id.toString());

    const response = await api.post('/ingest/book', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data.data;
  }

  static async ingestPoetry(
    text: string,
    title?: string,
    description?: string,
    project_id?: number
  ): Promise<IngestionResult> {
    const formData = new FormData();
    formData.append('text', text);
    if (title) formData.append('title', title);
    if (description) formData.append('description', description);
    if (project_id) formData.append('project_id', project_id.toString());

    const response = await api.post('/ingest/poetry', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data.data;
  }
}

export default TesseraAPI;

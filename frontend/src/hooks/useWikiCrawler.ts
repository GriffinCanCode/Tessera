import React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import WikiCrawlerAPI from '../services/api';
import type { CrawlRequest, GraphOptions, ExportOptions } from '../types/api';

// Query keys
export const QUERY_KEYS = {
  info: ['info'] as const,
  stats: ['stats'] as const,
  search: (query: string) => ['search', query] as const,
  article: (title: string) => ['article', title] as const,
  graph: (options: GraphOptions) => ['graph', options] as const,
  health: ['health'] as const,
  hubs: (limit: number) => ['hubs', limit] as const,
  discoveries: (limit: number) => ['discoveries', limit] as const,
} as const;

// Hook for API info
export function useApiInfo() {
  return useQuery({
    queryKey: QUERY_KEYS.info,
    queryFn: WikiCrawlerAPI.getInfo,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Hook for database stats
export function useStats() {
  return useQuery({
    queryKey: QUERY_KEYS.stats,
    queryFn: WikiCrawlerAPI.getStats,
    refetchInterval: 30 * 1000, // Refresh every 30 seconds
  });
}

// Hook for article search
export function useSearchArticles(query: string, limit = 20) {
  const isEnabled = !!query.trim();
  console.log('useSearchArticles Debug:', { query, trimmed: query.trim(), isEnabled, limit });
  
  return useQuery({
    queryKey: [...QUERY_KEYS.search(query), limit],
    queryFn: () => {
      console.log('Making API call with:', { query, limit });
      return WikiCrawlerAPI.searchArticles(query, limit);
    },
    enabled: isEnabled,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

// Hook for getting a specific article
export function useArticle(title: string) {
  return useQuery({
    queryKey: QUERY_KEYS.article(title),
    queryFn: () => WikiCrawlerAPI.getArticle(title),
    enabled: !!title,
    staleTime: 10 * 60 * 1000, // 10 minutes
  });
}

// Hook for building knowledge graph
export function useKnowledgeGraph(options: GraphOptions = {}) {
  return useQuery({
    queryKey: QUERY_KEYS.graph(options),
    queryFn: () => WikiCrawlerAPI.buildGraph(options),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Hook for health check
export function useHealthCheck() {
  return useQuery({
    queryKey: QUERY_KEYS.health,
    queryFn: WikiCrawlerAPI.healthCheck,
    refetchInterval: 60 * 1000, // Check every minute
    retry: 1,
  });
}

// Mutation hook for starting a crawl
export function useCrawlMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (request: CrawlRequest) => WikiCrawlerAPI.startCrawl(request),
    onSuccess: () => {
      // Invalidate and refetch stats after successful crawl
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.stats });
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.info });
    },
  });
}

// Mutation hook for exporting graph
export function useExportMutation() {
  return useMutation({
    mutationFn: (options: ExportOptions) => WikiCrawlerAPI.exportGraph(options),
  });
}

// Mutation hook for cleanup
export function useCleanupMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (keepDays: number) => WikiCrawlerAPI.cleanup(keepDays),
    onSuccess: () => {
      // Invalidate stats after cleanup
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.stats });
    },
  });
}

// Custom hook for search with debouncing
export function useDebouncedSearch(query: string, delay = 300) {
  const [debouncedQuery, setDebouncedQuery] = React.useState(query);

  React.useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(query);
    }, delay);

    return () => clearTimeout(timer);
  }, [query, delay]);

  return useSearchArticles(debouncedQuery);
}

// Hook for managing crawl state
export function useCrawlState() {
  const [crawlState, setCrawlState] = React.useState<{
    isRunning: boolean;
    progress?: number;
    status?: string;
  }>({
    isRunning: false,
  });

  const crawlMutation = useCrawlMutation();

  const startCrawl = React.useCallback(
    (request: CrawlRequest) => {
      setCrawlState({ isRunning: true, status: 'Starting crawl...' });

      return crawlMutation.mutateAsync(request).finally(() => {
        setCrawlState({ isRunning: false });
      });
    },
    [crawlMutation]
  );

  return {
    ...crawlState,
    startCrawl,
    error: crawlMutation.error,
    isLoading: crawlMutation.isPending,
  };
}

// Hook for managing graph visualization state
export function useGraphState() {
  const [graphOptions, setGraphOptions] = React.useState<GraphOptions>({
    min_relevance: 0.3,
    max_depth: 3,
    format: 'json',
  });

  const graphQuery = useKnowledgeGraph(graphOptions);

  const updateOptions = React.useCallback((newOptions: Partial<GraphOptions>) => {
    setGraphOptions(prev => ({ ...prev, ...newOptions }));
  }, []);

  return {
    options: graphOptions,
    updateOptions,
    ...graphQuery,
  };
}

// Hook for knowledge hubs
export function useKnowledgeHubs(limit = 10) {
  return useQuery({
    queryKey: QUERY_KEYS.hubs(limit),
    queryFn: () => WikiCrawlerAPI.getKnowledgeHubs(limit),
    refetchInterval: 60 * 1000, // Refresh every minute
    staleTime: 30 * 1000, // 30 seconds
  });
}

// Hook for recent discoveries
export function useRecentDiscoveries(limit = 10) {
  return useQuery({
    queryKey: QUERY_KEYS.discoveries(limit),
    queryFn: () => WikiCrawlerAPI.getRecentDiscoveries(limit),
    refetchInterval: 30 * 1000, // Refresh every 30 seconds
    staleTime: 15 * 1000, // 15 seconds
  });
}

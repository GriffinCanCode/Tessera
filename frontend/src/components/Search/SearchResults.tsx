import { ExternalLink, AlertCircle, FileText, Loader2 } from 'lucide-react';
import TesseraAPI from '../../services/api';
import type { SearchResult, WikiArticle } from '../../types/api';

interface SearchResultsProps {
  query: string;
  data?: SearchResult;
  isLoading: boolean;
  error: Error | null;
}

export function SearchResults({ query, data, isLoading, error }: SearchResultsProps) {
  // Debug logging to see what data structure we receive
  console.log('SearchResults Debug:', { query, data, isLoading, error });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="flex items-center gap-3 text-gray-500">
          <Loader2 className="h-6 w-6 animate-spin text-purple-500" />
          <span>Searching for "{query}"...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-16">
        <div className="bg-white rounded-xl p-8 max-w-md mx-auto border border-gray-200 shadow-sm">
          <AlertCircle className="h-12 w-12 text-red-500 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-red-600 mb-2">Search Error</h3>
          <p className="text-gray-600 mb-4">Failed to search articles. Please try again.</p>
          <button 
            onClick={() => window.location.reload()} 
            className="inline-flex items-center justify-center px-4 py-2 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 transition-colors"
          >
            Retry Search
          </button>
        </div>
      </div>
    );
  }

  if (!data || data.count === 0) {
    return (
      <div className="text-center py-16">
        <FileText className="h-16 w-16 text-gray-400 mx-auto mb-6" />
        <h3 className="text-xl font-semibold text-gray-900 mb-3">No Results Found</h3>
        <p className="text-gray-600 max-w-md mx-auto">
          No articles found matching "{query}". Try different keywords or start a new crawl.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between pb-4 border-b border-gray-200">
        <p className="text-gray-600">
          Found <span className="font-semibold text-gray-900">{data.count}</span> articles matching
          " <span className="font-semibold text-gray-900">{query}</span>"
        </p>
      </div>

      <div className="space-y-4">
        {data.results.map(article => (
          <ArticleCard key={article.id} article={article} />
        ))}
      </div>
    </div>
  );
}

function ArticleCard({ article }: { article: WikiArticle }) {
  const readingTime = TesseraAPI.estimateReadingTime(article.summary || article.content || '');
  const wikipediaUrl = TesseraAPI.getWikipediaUrl(article.title);

  const truncateSummary = (text: string, maxLength = 300): string => {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength).replace(/\s+\S*$/, '') + '...';
  };

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-6 transition-all duration-200 hover:shadow-lg hover:border-purple-300 hover:-translate-y-1 cursor-pointer">
      <h3 className="text-xl font-semibold text-gray-900 mb-3 hover:text-purple-600 transition-colors">
        {article.title}
      </h3>

      {article.summary && (
        <p className="text-gray-600 text-sm leading-relaxed mb-4">
          {truncateSummary(article.summary)}
        </p>
      )}

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4 text-xs text-gray-500">
          {readingTime > 0 && <span>{readingTime} min read</span>}
          <span>
            {new Date(article.parsed_at * 1000).toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric',
            })}
          </span>
        </div>

        <a
          href={wikipediaUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-700 transition-colors"
          onClick={e => e.stopPropagation()}
        >
          <ExternalLink className="h-3 w-3" />
          Wikipedia
        </a>
      </div>
    </div>
  );
}

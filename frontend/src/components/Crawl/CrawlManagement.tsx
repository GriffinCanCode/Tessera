import React, { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Rocket, Check, AlertTriangle, Bug, Lightbulb } from 'lucide-react';
import TesseraAPI from '../../services/api';
import type { CrawlRequest } from '../../types/api';

interface CrawlFormProps {
  onSubmit: (request: CrawlRequest) => void;
  isLoading: boolean;
}

function CrawlForm({ onSubmit, isLoading }: CrawlFormProps) {
  const [startUrl, setStartUrl] = useState('');
  const [interests, setInterests] = useState<string[]>([]);
  const [newInterest, setNewInterest] = useState('');
  const [maxDepth, setMaxDepth] = useState(3);
  const [maxArticles, setMaxArticles] = useState(50);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!startUrl.trim()) return;

    onSubmit({
      start_url: startUrl.trim(),
      interests,
      max_depth: maxDepth,
      max_articles: maxArticles
    });
  };

  const addInterest = () => {
    if (newInterest.trim() && !interests.includes(newInterest.trim())) {
      setInterests([...interests, newInterest.trim()]);
      setNewInterest('');
    }
  };

  const removeInterest = (interest: string) => {
    setInterests(interests.filter(i => i !== interest));
  };

  const commonStartUrls = [
    'https://en.wikipedia.org/wiki/Artificial_intelligence',
    'https://en.wikipedia.org/wiki/Machine_learning',
    'https://en.wikipedia.org/wiki/Computer_science',
    'https://en.wikipedia.org/wiki/Physics',
    'https://en.wikipedia.org/wiki/Biology',
    'https://en.wikipedia.org/wiki/Chemistry',
    'https://en.wikipedia.org/wiki/Mathematics'
  ];

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Start URL */}
      <div className="space-y-3">
        <label className="block text-sm font-semibold text-slate-800">
          Starting Wikipedia Article URL
        </label>
        <input
          type="url"
          value={startUrl}
          onChange={(e) => setStartUrl(e.target.value)}
          placeholder="https://en.wikipedia.org/wiki/..."
          className="w-full px-4 py-3 rounded-xl border border-slate-200 bg-white/80 backdrop-blur-sm
                   focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 focus:outline-none
                   transition-all duration-200 text-slate-800 placeholder-slate-400"
          required
        />
        
        {/* Quick Start Options */}
        <div className="space-y-2">
          <p className="text-xs text-slate-600 font-medium">Quick Start Options:</p>
          <div className="flex flex-wrap gap-2">
            {commonStartUrls.map((url, index) => (
              <button
                key={index}
                type="button"
                onClick={() => setStartUrl(url)}
                className="px-3 py-1 text-xs rounded-full bg-gradient-to-r from-blue-100 to-purple-100
                         hover:from-blue-200 hover:to-purple-200 text-slate-700 font-medium
                         transition-all duration-200 transform hover:scale-105"
              >
                {url.split('/').pop()?.replace(/_/g, ' ')}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Interests */}
      <div className="space-y-3">
        <label className="block text-sm font-semibold text-slate-800">
          Interest Keywords (Optional)
        </label>
        <div className="flex space-x-2">
          <input
            type="text"
            value={newInterest}
            onChange={(e) => setNewInterest(e.target.value)}
            placeholder="e.g., machine learning, neural networks..."
            className="flex-1 px-4 py-2 rounded-lg border border-slate-200 bg-white/80 backdrop-blur-sm
                     focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 focus:outline-none
                     transition-all duration-200 text-slate-800 placeholder-slate-400"
            onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addInterest())}
          />
          <button
            type="button"
            onClick={addInterest}
            className="px-4 py-2 bg-gradient-to-r from-teal-500 to-cyan-500 text-white rounded-lg
                     font-medium hover:from-teal-600 hover:to-cyan-600 transition-all duration-200
                     transform hover:scale-105 shadow-md hover:shadow-lg"
          >
            Add
          </button>
        </div>
        
        {/* Interest Tags */}
        {interests.length > 0 && (
          <div className="flex flex-wrap gap-2 mt-3">
            {interests.map((interest) => (
              <span
                key={interest}
                className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium
                         bg-gradient-to-r from-purple-100 to-pink-100 text-purple-800 border border-purple-200"
              >
                {interest}
                <button
                  type="button"
                  onClick={() => removeInterest(interest)}
                  className="ml-2 text-purple-600 hover:text-purple-800 transition-colors"
                >
                  ×
                </button>
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Advanced Settings */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <label className="block text-sm font-semibold text-slate-800">
            Max Crawl Depth: {maxDepth}
          </label>
          <input
            type="range"
            min="1"
            max="5"
            value={maxDepth}
            onChange={(e) => setMaxDepth(Number(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer
                     slider:bg-gradient-to-r slider:from-blue-500 slider:to-purple-500"
          />
          <p className="text-xs text-slate-600">
            Higher depth explores more connections but takes longer
          </p>
        </div>

        <div className="space-y-2">
          <label className="block text-sm font-semibold text-slate-800">
            Max Articles: {maxArticles}
          </label>
          <input
            type="range"
            min="10"
            max="200"
            step="10"
            value={maxArticles}
            onChange={(e) => setMaxArticles(Number(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer
                     slider:bg-gradient-to-r slider:from-green-500 slider:to-blue-500"
          />
          <p className="text-xs text-slate-600">
            More articles create richer graphs but use more resources
          </p>
        </div>
      </div>

      {/* Submit Button */}
      <button
        type="submit"
        disabled={isLoading || !startUrl.trim()}
        className="w-full px-6 py-4 bg-gradient-to-r from-purple-600 via-blue-600 to-teal-600
                 text-white font-bold rounded-xl hover:from-purple-700 hover:via-blue-700 hover:to-teal-700
                 disabled:from-slate-400 disabled:via-slate-500 disabled:to-slate-600
                 transition-all duration-300 transform hover:scale-[1.02] hover:shadow-2xl
                 disabled:transform-none disabled:shadow-none relative overflow-hidden"
      >
        {isLoading ? (
          <div className="flex items-center justify-center space-x-2">
            <div className="animate-spin w-5 h-5 border-2 border-white/30 border-t-white rounded-full"></div>
            <span>Starting Crawl...</span>
          </div>
        ) : (
          <div className="flex items-center justify-center space-x-2">
            <Rocket className="w-5 h-5" />
            <span>Start Crawling</span>
          </div>
        )}
        
        {/* Animated background effect */}
        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent
                      transform -skew-x-12 -translate-x-full animate-shimmer"></div>
      </button>
    </form>
  );
}

interface CrawlResultProps {
  result: any;
}

function CrawlResult({ result }: CrawlResultProps) {
  return (
    <div className="bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl p-6 border border-green-200">
      <div className="flex items-center space-x-3 mb-4">
        <div className="w-10 h-10 bg-gradient-to-r from-green-500 to-emerald-500 rounded-full flex-center">
          <Check className="w-6 h-6 text-white" />
        </div>
        <div>
          <h3 className="font-bold text-green-800">Crawl Completed Successfully!</h3>
          <p className="text-sm text-green-600">Your knowledge graph has been built</p>
        </div>
      </div>
      
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="text-center">
          <div className="text-2xl font-bold text-green-800">{result.articles_crawled || 0}</div>
          <div className="text-xs text-green-600">Articles</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-green-800">{result.links_analyzed || 0}</div>
          <div className="text-xs text-green-600">Links</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-green-800">
            {result.duration ? Math.round(result.duration / 60) : 0}m
          </div>
          <div className="text-xs text-green-600">Duration</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-green-800">
            {result.start_url ? new URL(result.start_url).pathname.split('/').pop()?.slice(0, 8) + '...' : 'N/A'}
          </div>
          <div className="text-xs text-green-600">Starting Point</div>
        </div>
      </div>
    </div>
  );
}

export function CrawlManagement() {
  const [crawlResult, setCrawlResult] = useState<any>(null);
  
  // Query current stats
  const { data: stats } = useQuery({
    queryKey: ['stats'],
    queryFn: TesseraAPI.getStats,
    refetchInterval: 5000 // Refresh every 5 seconds
  });

  // Crawl mutation
  const crawlMutation = useMutation({
    mutationFn: TesseraAPI.startCrawl,
    onSuccess: (data) => {
      setCrawlResult(data.data);
    },
    onError: (error) => {
      console.error('Crawl failed:', error);
    }
  });

  const handleStartCrawl = (request: CrawlRequest) => {
    console.log('handleStartCrawl called with:', JSON.stringify(request, null, 2));
    setCrawlResult(null);
    crawlMutation.mutate(request);
  };

  return (
    <div className="container-page">
      <div className="max-w-4xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-4xl font-bold text-gradient bg-gradient-to-r from-purple-600 via-blue-600 to-teal-600">
            Wikipedia Crawler
          </h1>
          <p className="text-lg text-slate-600 max-w-2xl mx-auto">
            Build your personal knowledge graph by crawling Wikipedia articles. 
            Start with any topic and let the system discover connections automatically.
          </p>
        </div>

        {/* Current Database Stats */}
        {stats?.data && (
          <div className="bg-white/80 backdrop-blur-md rounded-xl border border-white/20 shadow-lg p-6">
            <h2 className="text-lg font-semibold text-slate-800 mb-4">Current Knowledge Base</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="text-center p-4 rounded-lg bg-gradient-to-br from-blue-50 to-indigo-50">
                <div className="text-2xl font-bold text-blue-700">{stats.data.total_articles}</div>
                <div className="text-sm text-blue-600">Articles</div>
              </div>
              <div className="text-center p-4 rounded-lg bg-gradient-to-br from-purple-50 to-pink-50">
                <div className="text-2xl font-bold text-purple-700">{stats.data.total_links}</div>
                <div className="text-sm text-purple-600">Links</div>
              </div>
              <div className="text-center p-4 rounded-lg bg-gradient-to-br from-teal-50 to-cyan-50">
                <div className="text-2xl font-bold text-teal-700">
                  {Math.round(stats.data.avg_links_per_article || 0)}
                </div>
                <div className="text-sm text-teal-600">Avg Links/Article</div>
              </div>
              <div className="text-center p-4 rounded-lg bg-gradient-to-br from-amber-50 to-orange-50">
                <div className="text-2xl font-bold text-amber-700">{stats.data.articles_last_24h || 0}</div>
                <div className="text-sm text-amber-600">Recent (24h)</div>
              </div>
            </div>
          </div>
        )}

        {/* Crawl Result */}
        {crawlResult && <CrawlResult result={crawlResult} />}

        {/* Error Display */}
        {crawlMutation.isError && (
          <div className="bg-gradient-to-br from-red-50 to-pink-50 rounded-xl p-6 border border-red-200">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-r from-red-500 to-pink-500 rounded-full flex-center">
                <AlertTriangle className="w-6 h-6 text-white" />
              </div>
              <div>
                <h3 className="font-bold text-red-800">Crawl Failed</h3>
                <p className="text-sm text-red-600">
                  {crawlMutation.error?.message || 'An unexpected error occurred'}
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Crawl Form */}
        <div className="bg-white/90 backdrop-blur-md rounded-2xl border border-white/30 shadow-xl p-8">
          <h2 className="text-2xl font-bold text-slate-800 mb-6 flex items-center space-x-2">
            <Bug className="w-8 h-8 text-slate-700" />
            <span>New Crawl Session</span>
          </h2>
          
          <CrawlForm
            onSubmit={handleStartCrawl}
            isLoading={crawlMutation.isPending}
          />
        </div>

        {/* Help Section */}
        <div className="bg-gradient-to-br from-slate-50 to-blue-50 rounded-xl p-6 border border-slate-200">
          <h3 className="font-semibold text-slate-800 mb-3 flex items-center space-x-2">
            <Lightbulb className="w-5 h-5 text-amber-500" />
            <span>Pro Tips</span>
          </h3>
          <ul className="space-y-2 text-sm text-slate-600">
            <li className="flex items-start space-x-2">
              <span className="text-blue-500 mt-1">•</span>
              <span>Start with broad topics like "Artificial Intelligence" or "Physics" for rich knowledge graphs</span>
            </li>
            <li className="flex items-start space-x-2">
              <span className="text-purple-500 mt-1">•</span>
              <span>Use interest keywords to focus crawling on specific subtopics</span>
            </li>
            <li className="flex items-start space-x-2">
              <span className="text-teal-500 mt-1">•</span>
              <span>Higher depth creates more comprehensive graphs but takes longer to process</span>
            </li>
            <li className="flex items-start space-x-2">
              <span className="text-pink-500 mt-1">•</span>
              <span>You can run multiple crawls to expand your knowledge base over time</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

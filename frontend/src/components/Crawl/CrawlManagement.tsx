import React, { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Rocket, Check, AlertTriangle, Bug, Lightbulb, Sparkles, Zap, Globe, Target, Settings, Play } from 'lucide-react';
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
      {/* Enhanced Start URL */}
      <div className="space-y-4">
        <div className="flex items-center space-x-2">
          <Globe className="w-5 h-5 text-emerald-600" />
          <label className="block text-sm font-bold text-slate-800">
            Starting Wikipedia Article URL
          </label>
          {startUrl.trim() && (
            <div className="flex items-center space-x-1 px-2 py-1 bg-emerald-100 rounded-full">
              <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
              <span className="text-xs font-semibold text-emerald-700">Valid URL</span>
            </div>
          )}
        </div>
        
        <div className="relative group">
          <input
            type="url"
            value={startUrl}
            onChange={(e) => setStartUrl(e.target.value)}
            placeholder="https://en.wikipedia.org/wiki/..."
            className="w-full px-4 py-4 rounded-xl border-2 border-slate-200 bg-white/90 backdrop-blur-sm
                     focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/20 focus:outline-none
                     transition-all duration-300 text-slate-800 placeholder-slate-400 font-medium
                     group-hover:border-emerald-300"
            required
          />
          {startUrl.trim() && (
            <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
              <Target className="w-5 h-5 text-emerald-500 animate-pulse" />
            </div>
          )}
        </div>
        
        {/* Enhanced Quick Start Options */}
        <div className="space-y-3">
          <div className="flex items-center space-x-2">
            <Zap className="w-4 h-4 text-teal-500" />
            <p className="text-sm text-slate-700 font-semibold">Quick Start Options:</p>
          </div>
          <div className="flex flex-wrap gap-2">
            {commonStartUrls.map((url, index) => (
              <button
                key={index}
                type="button"
                onClick={() => setStartUrl(url)}
                className="group px-4 py-2 text-sm rounded-xl bg-gradient-to-r from-emerald-100 via-teal-100 to-cyan-100
                         hover:from-emerald-200 hover:via-teal-200 hover:to-cyan-200 text-slate-700 font-semibold
                         transition-all duration-300 transform hover:scale-105 hover:shadow-md
                         border border-emerald-200/50 hover:border-emerald-300"
              >
                <span className="group-hover:tracking-wide transition-all duration-200">
                  {url.split('/').pop()?.replace(/_/g, ' ')}
                </span>
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

      {/* Enhanced Submit Button */}
      <div className="relative">
        <button
          type="submit"
          disabled={isLoading || !startUrl.trim()}
          className="group w-full px-8 py-5 bg-gradient-to-r from-emerald-500 via-teal-500 to-green-500
                   text-white font-bold rounded-2xl hover:from-emerald-600 hover:via-teal-600 hover:to-green-600
                   disabled:from-slate-400 disabled:via-slate-500 disabled:to-slate-600
                   transition-all duration-500 transform hover:scale-[1.02] hover:shadow-2xl hover:-translate-y-1
                   disabled:transform-none disabled:shadow-none relative overflow-hidden
                   border border-emerald-400/30 shadow-xl"
        >
          {/* Button glow effect */}
          <div className="absolute inset-0 bg-gradient-to-r from-emerald-400/40 to-green-400/40 rounded-2xl blur-lg opacity-0 group-hover:opacity-100 transition-all duration-500"></div>
          
          {isLoading ? (
            <div className="relative z-10 flex items-center justify-center space-x-3">
              <div className="flex space-x-1">
                <div className="w-2 h-2 bg-white rounded-full animate-bounce" style={{animationDelay: '0ms'}}></div>
                <div className="w-2 h-2 bg-white rounded-full animate-bounce" style={{animationDelay: '150ms'}}></div>
                <div className="w-2 h-2 bg-white rounded-full animate-bounce" style={{animationDelay: '300ms'}}></div>
              </div>
              <span className="text-lg">Launching Crawler...</span>
              <Zap className="w-5 h-5 animate-pulse" />
            </div>
          ) : (
            <div className="relative z-10 flex items-center justify-center space-x-3">
              <div className="transform group-hover:rotate-12 group-hover:scale-110 transition-all duration-300">
                <Rocket className="w-6 h-6 group-hover:animate-bounce" />
              </div>
              <span className="text-lg group-hover:tracking-wider transition-all duration-300">Launch Crawler</span>
              <div className="opacity-0 group-hover:opacity-100 transition-all duration-300">
                <Sparkles className="w-5 h-5 animate-pulse" />
              </div>
            </div>
          )}
          
          {/* Enhanced shimmer effect */}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent
                        transform -skew-x-12 -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
        </button>
        
        {/* Floating action indicator */}
        {!isLoading && startUrl.trim() && (
          <div className="absolute -top-2 -right-2 w-6 h-6 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full flex items-center justify-center animate-bounce">
            <Play className="w-3 h-3 text-white" />
          </div>
        )}
      </div>
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

        {/* Enhanced Crawl Form */}
        <div className="relative group">
          {/* Animated background glow */}
          <div className="absolute -inset-2 bg-gradient-to-r from-emerald-400/20 via-teal-400/20 to-green-400/20 rounded-3xl blur-xl opacity-0 group-hover:opacity-100 transition-all duration-700"></div>
          
          <div className="relative bg-white/95 backdrop-blur-md rounded-3xl border border-white/40 shadow-2xl p-8 overflow-hidden">
            {/* Background pattern */}
            <div className="absolute inset-0 opacity-[0.02]">
              <div className="absolute inset-0" style={{
                backgroundImage: `radial-gradient(circle at 2px 2px, rgba(16, 185, 129, 0.6) 1px, transparent 0)`,
                backgroundSize: '30px 30px'
              }}></div>
            </div>
            
            <div className="relative z-10">
              {/* Enhanced Header */}
              <div className="text-center mb-8">
                <div className="inline-flex items-center space-x-2 px-4 py-2 bg-emerald-100/80 rounded-full border border-emerald-200/50 mb-4">
                  <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
                  <span className="text-sm font-semibold text-emerald-700">Crawler Configuration</span>
                </div>
                
                <h2 className="text-3xl font-bold text-slate-800 mb-2 flex items-center justify-center space-x-3">
                  <div className="relative">
                    <Settings className="w-8 h-8 text-emerald-600 animate-spin" style={{animationDuration: '8s'}} />
                    <div className="absolute inset-0 w-8 h-8 bg-emerald-400/20 rounded-full animate-ping"></div>
                  </div>
                  <span>New Crawl Session</span>
                  <Sparkles className="w-6 h-6 text-teal-500 animate-pulse" />
                </h2>
                
                <p className="text-slate-600 max-w-2xl mx-auto">
                  Configure your Wikipedia exploration parameters and launch an intelligent crawling session 
                  to discover new knowledge connections.
                </p>
              </div>
              
              <CrawlForm
                onSubmit={handleStartCrawl}
                isLoading={crawlMutation.isPending}
              />
            </div>
          </div>
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

import React, { useState } from 'react';
import { useSearchArticles } from '../../hooks/useTessera';
import { SearchInput } from './SearchInput';
import { SearchResults } from './SearchResults';
import { useAppStore } from '../../stores';
import { BookOpen, Sparkles, Zap, Bot, Brain, Atom, Network, BarChart3, RefreshCw, Rocket } from 'lucide-react';

export function Search() {
  const [query, setQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const { setCurrentView } = useAppStore();

  console.log('Search component render:', { query, debouncedQuery });

  const handleQueryChange = (newQuery: string) => {
    console.log('Search handleQueryChange called:', { oldQuery: query, newQuery });
    setQuery(newQuery);
  };

  // Debounce search query
  React.useEffect(() => {
    console.log('Debounce effect triggered:', { query });
    const timer = setTimeout(() => {
      console.log('Setting debouncedQuery to:', query);
      setDebouncedQuery(query);
    }, 300);

    return () => clearTimeout(timer);
  }, [query]);

  const { data, isLoading, error } = useSearchArticles(debouncedQuery);

  return (
    <div className="container-page">
      <div className="max-w-6xl mx-auto space-y-12">
        {/* Enhanced Header with Floating Elements */}
        <div className="text-center space-y-6 relative">
          <div className="absolute -top-8 -left-8 w-32 h-32 bg-gradient-to-br from-purple-400/20 to-pink-400/20 rounded-full blur-3xl animate-float"></div>
          <div className="absolute -top-4 -right-12 w-24 h-24 bg-gradient-to-br from-blue-400/20 to-teal-400/20 rounded-full blur-2xl animate-float" style={{animationDelay: '1s'}}></div>
          
          <div className="relative">
            <h1 className="text-5xl sm:text-6xl font-bold text-gradient-electric mb-4">
              Search Articles
            </h1>
            <div className="flex items-center justify-center space-x-2 mb-6">
              <Sparkles className="w-6 h-6 text-purple-500 animate-pulse" />
              <p className="text-xl text-slate-600 max-w-3xl">
                Discover knowledge connections across your personal Wikipedia collection
              </p>
              <Zap className="w-6 h-6 text-teal-500 animate-pulse" />
            </div>
          </div>
        </div>

        {/* Enhanced Search Input with Cyber Styling */}
        <div className="max-w-3xl mx-auto">
          <div className="relative group">
            <div className="absolute -inset-2 bg-gradient-to-r from-purple-500/20 via-blue-500/20 to-teal-500/20 rounded-3xl blur opacity-0 group-hover:opacity-100 transition-all duration-500 pointer-events-none"></div>
            <div className="relative bg-white/90 backdrop-blur-md rounded-2xl border border-white/30 shadow-xl p-2">
              <SearchInput
                value={query}
                onChange={handleQueryChange}
                placeholder="Search articles by title, content, or keywords..."
                isLoading={isLoading}
              />
            </div>
          </div>
        </div>

        {/* Enhanced Wikipedia Crawler Card */}
        <div className="max-w-4xl mx-auto">
          <div className="relative group">
            {/* Animated background glow */}
            <div className="absolute -inset-4 bg-gradient-to-r from-emerald-400/20 via-teal-400/20 to-green-400/20 rounded-3xl blur-2xl opacity-0 group-hover:opacity-100 transition-all duration-700"></div>
            
            <div className="relative bg-white/95 backdrop-blur-md rounded-3xl border border-white/40 shadow-2xl p-8 overflow-hidden">
              {/* Background pattern */}
              <div className="absolute inset-0 opacity-[0.03]">
                <div className="absolute inset-0" style={{
                  backgroundImage: `radial-gradient(circle at 2px 2px, rgba(16, 185, 129, 0.8) 1px, transparent 0)`,
                  backgroundSize: '40px 40px'
                }}></div>
              </div>
              
              {/* Content */}
              <div className="relative z-10 text-center space-y-6">
                {/* Header */}
                <div className="space-y-3">
                  <div className="inline-flex items-center space-x-2 px-4 py-2 bg-emerald-100/80 rounded-full border border-emerald-200/50">
                    <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
                    <span className="text-sm font-semibold text-emerald-700">Knowledge Expansion</span>
                  </div>
                  
                  <h3 className="text-2xl font-bold text-slate-800">
                    Discover New Connections
                  </h3>
                  <p className="text-slate-600 max-w-2xl mx-auto">
                    Can't find what you're looking for? Launch our intelligent Wikipedia crawler to discover 
                    new articles and expand your personal knowledge universe.
                  </p>
                </div>

                {/* Interactive Crawler Button */}
                <div className="relative">
                  <button
                    onClick={() => setCurrentView('crawl')}
                    className="group/btn relative inline-flex items-center space-x-4 px-10 py-5 text-lg font-bold
                             bg-gradient-to-r from-emerald-500 via-teal-500 to-green-500 text-white rounded-2xl
                             hover:from-emerald-600 hover:via-teal-600 hover:to-green-600 
                             transition-all duration-500 shadow-xl hover:shadow-2xl 
                             transform hover:scale-105 hover:-translate-y-2 active:scale-95
                             border border-emerald-400/30"
                  >
                    {/* Button glow effect */}
                    <div className="absolute inset-0 bg-gradient-to-r from-emerald-400/40 to-green-400/40 rounded-2xl blur-lg opacity-0 group-hover/btn:opacity-100 transition-all duration-500"></div>
                    
                    {/* Animated rocket icon */}
                    <div className="relative z-10 transform group-hover/btn:rotate-12 group-hover/btn:scale-110 transition-all duration-300">
                      <Rocket className="w-7 h-7 group-hover/btn:animate-bounce" />
                    </div>
                    
                    <span className="relative z-10 group-hover/btn:tracking-wider transition-all duration-300">
                      Launch Crawler
                    </span>
                    
                    {/* Sparkle effects */}
                    <div className="relative z-10 opacity-0 group-hover/btn:opacity-100 transition-all duration-300">
                      <Sparkles className="w-6 h-6 animate-pulse" />
                    </div>
                    
                    {/* Shimmer effect */}
                    <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent transform -skew-x-12 -translate-x-full group-hover/btn:translate-x-full transition-transform duration-1000"></div>
                  </button>
                  
                  {/* Floating action indicators */}
                  <div className="absolute -top-2 -right-2 w-6 h-6 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-300 animate-bounce">
                    <Zap className="w-3 h-3 text-white" />
                  </div>
                </div>

                {/* Feature highlights */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-4">
                  <div className="flex items-center space-x-3 p-3 rounded-xl bg-gradient-to-r from-emerald-50 to-teal-50 border border-emerald-100">
                    <div className="w-8 h-8 bg-gradient-to-r from-emerald-500 to-teal-500 rounded-lg flex items-center justify-center">
                      <Brain className="w-4 h-4 text-white" />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-semibold text-emerald-700">Smart Discovery</p>
                      <p className="text-xs text-emerald-600">AI-guided exploration</p>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-3 p-3 rounded-xl bg-gradient-to-r from-teal-50 to-cyan-50 border border-teal-100">
                    <div className="w-8 h-8 bg-gradient-to-r from-teal-500 to-cyan-500 rounded-lg flex items-center justify-center">
                      <Network className="w-4 h-4 text-white" />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-semibold text-teal-700">Deep Connections</p>
                      <p className="text-xs text-teal-600">Link analysis & mapping</p>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-3 p-3 rounded-xl bg-gradient-to-r from-cyan-50 to-blue-50 border border-cyan-100">
                    <div className="w-8 h-8 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-lg flex items-center justify-center">
                      <BarChart3 className="w-4 h-4 text-white" />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-semibold text-cyan-700">Rich Insights</p>
                      <p className="text-xs text-cyan-600">Knowledge analytics</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Search Results */}
        {debouncedQuery ? (
          <SearchResults
            query={debouncedQuery}
            data={data?.data}
            isLoading={isLoading}
            error={error}
          />
        ) : (
          <EmptySearchState onSuggestionClick={handleQueryChange} />
        )}
      </div>
    </div>
  );
}

function EmptySearchState({ onSuggestionClick }: { onSuggestionClick: (query: string) => void }) {
  const suggestions = [
    { text: 'artificial intelligence', icon: Bot, color: 'from-purple-500 to-pink-500' },
    { text: 'machine learning', icon: Brain, color: 'from-blue-500 to-cyan-500' },
    { text: 'quantum computing', icon: Atom, color: 'from-teal-500 to-green-500' },
    { text: 'neural networks', icon: Network, color: 'from-indigo-500 to-purple-500' },
    { text: 'data science', icon: BarChart3, color: 'from-orange-500 to-red-500' },
    { text: 'algorithms', icon: RefreshCw, color: 'from-emerald-500 to-teal-500' },
  ];

  return (
    <div className="relative overflow-hidden">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-[0.02]">
        <div className="absolute inset-0" style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, rgba(99, 102, 241, 0.5) 1px, transparent 0)`,
          backgroundSize: '50px 50px'
        }}></div>
      </div>

      <div className="relative text-center py-20 space-y-12">
        {/* Animated Icon */}
        <div className="relative">
          <div className="w-32 h-32 mx-auto mb-8 relative">
            <div className="absolute inset-0 bg-gradient-to-r from-purple-500/20 to-teal-500/20 rounded-full blur-xl animate-pulse"></div>
            <div className="relative w-full h-full bg-gradient-to-br from-white to-slate-50 rounded-full flex-center shadow-2xl border border-white/50">
              <BookOpen className="h-16 w-16 text-gradient bg-gradient-to-r from-purple-600 to-teal-600" />
            </div>
          </div>
        </div>

        {/* Title */}
        <div className="space-y-4">
          <h3 className="text-3xl font-bold text-gradient-laser">Discover Your Knowledge Universe</h3>
          <p className="text-lg text-slate-600 max-w-2xl mx-auto leading-relaxed">
            Start your journey through interconnected Wikipedia articles. 
            Type to explore relationships, patterns, and hidden connections in your knowledge graph.
          </p>
        </div>

        {/* Enhanced Suggestion Pills */}
        <div className="space-y-6">
          <div className="flex items-center justify-center space-x-2">
            <Sparkles className="w-5 h-5 text-purple-500" />
            <p className="text-sm font-semibold text-slate-700">Try these popular topics:</p>
            <Sparkles className="w-5 h-5 text-teal-500" />
          </div>
          
          <div className="flex flex-wrap justify-center gap-3 max-w-4xl mx-auto">
            {suggestions.map((suggestion, index) => (
              <button
                key={suggestion.text}
                className="group relative px-6 py-3 text-sm font-medium text-slate-700 
                         bg-white/80 backdrop-blur-sm border border-white/30 rounded-2xl 
                         hover-plasma hover:text-white transition-all duration-300
                         shadow-md hover:shadow-xl transform hover:scale-105"
                onClick={() => onSuggestionClick(suggestion.text)}
                style={{
                  animationDelay: `${index * 100}ms`
                }}
              >
                <div className={`absolute inset-0 bg-gradient-to-r ${suggestion.color} rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300`}></div>
                <div className="relative flex items-center space-x-2">
                  <suggestion.icon className="w-4 h-4 relative z-10" />
                  <span className="relative z-10">{suggestion.text}</span>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Call to Action */}
        <div className="pt-8">
          <div className="inline-flex items-center space-x-2 px-6 py-3 bg-gradient-to-r from-slate-100 to-slate-50 rounded-full border border-slate-200">
            <div className="w-2 h-2 bg-gradient-to-r from-green-400 to-emerald-400 rounded-full animate-pulse"></div>
            <span className="text-sm font-medium text-slate-600">Ready to explore • Start typing above</span>
          </div>
        </div>
      </div>
    </div>
  );
}

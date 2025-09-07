import React, { useState } from 'react';
import { useSearchArticles } from '../../hooks/useTessera';
import { SearchInput } from './SearchInput';
import { SearchResults } from './SearchResults';
import { BookOpen, Sparkles, Zap, Bot, Brain, Atom, Network, BarChart3, RefreshCw } from 'lucide-react';

export function Search() {
  const [query, setQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');

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

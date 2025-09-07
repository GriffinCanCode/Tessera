import React, { useState } from 'react';
import { Upload, FileText, Feather, Youtube, Globe, BookOpen, Sparkles, Zap, CheckCircle, AlertCircle, Loader2, X } from 'lucide-react';
import TesseraAPI, { type IngestionResult } from '../../services/api';

interface AssimilatorInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  isLoading?: boolean;
  icon?: React.ComponentType<{ className?: string }>;
}

function AssimilatorInput({ value, onChange, placeholder, isLoading, icon: Icon = Upload }: AssimilatorInputProps) {
  const handleChange = (newValue: string) => {
    onChange(newValue);
  };

  return (
    <div className="relative group">
      {/* Enhanced Icon Section */}
      <div className="absolute inset-y-0 left-0 pl-6 flex items-center pointer-events-none">
        {isLoading ? (
          <div className="relative">
            <Loader2 className="h-6 w-6 text-purple-500 animate-spin" />
            <div className="absolute inset-0 h-6 w-6 border-2 border-teal-400/30 rounded-full animate-ping"></div>
          </div>
        ) : (
          <div className="relative">
            <Icon className="h-6 w-6 text-slate-400 group-focus-within:text-purple-500 transition-all duration-300" />
            {!value && (
              <Sparkles className="absolute -top-1 -right-1 h-3 w-3 text-purple-400 opacity-0 group-hover:opacity-100 transition-all duration-300 animate-pulse" />
            )}
          </div>
        )}
      </div>

      {/* Enhanced Input Field */}
      <input
        type="text"
        value={value}
        onChange={e => handleChange(e.target.value)}
        placeholder={placeholder}
        className="block w-full pl-16 pr-16 py-6 text-lg border-2 border-slate-200/50 
                 rounded-2xl bg-white/95 backdrop-blur-sm text-slate-800 placeholder-slate-400 
                 focus:outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-500/20 
                 hover:border-slate-300 hover:bg-white transition-all duration-300 shadow-lg
                 group-hover:shadow-xl font-medium relative z-10"
      />

      {/* Enhanced Clear Button */}
      {value && (
        <button
          onClick={() => handleChange('')}
          className="absolute inset-y-0 right-0 pr-6 flex items-center group/clear"
        >
          <div className="relative p-1 rounded-full hover:bg-slate-100 transition-all duration-200">
            <X className="h-5 w-5 text-slate-400 group-hover/clear:text-slate-600 transition-colors" />
            <div className="absolute inset-0 bg-gradient-to-r from-red-400/20 to-pink-400/20 rounded-full opacity-0 group-hover/clear:opacity-100 transition-opacity duration-300"></div>
          </div>
        </button>
      )}

      {/* Subtle Border Glow Effect */}
      <div className="absolute -inset-1 bg-gradient-to-r from-purple-500/10 via-blue-500/5 to-teal-500/10 rounded-3xl blur opacity-0 group-focus-within:opacity-100 transition-all duration-500 pointer-events-none"></div>
    </div>
  );
}

export function Assimilator() {
  const [activeTab, setActiveTab] = useState<'youtube' | 'article' | 'book' | 'poetry'>('youtube');
  const [isProcessing, setIsProcessing] = useState(false);
  const [results, setResults] = useState<IngestionResult[]>([]);
  
  // Form states
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [articleUrl, setArticleUrl] = useState('');
  const [poetryText, setPoetyText] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');

  // Use TesseraAPI directly for ingestion functions

  const tabs = [
    { 
      id: 'youtube', 
      label: 'YouTube Videos', 
      icon: Youtube, 
      gradient: 'from-red-500 to-pink-600',
      description: 'Extract transcripts from YouTube videos'
    },
    { 
      id: 'article', 
      label: 'Web Articles', 
      icon: Globe, 
      gradient: 'from-blue-500 to-cyan-600',
      description: 'Process articles from news sites and blogs'
    },
    { 
      id: 'book', 
      label: 'Books & Documents', 
      icon: BookOpen, 
      gradient: 'from-green-500 to-emerald-600',
      description: 'Upload PDF, DOCX, EPUB, and text files'
    },
    { 
      id: 'poetry', 
      label: 'Poetry & Writing', 
      icon: Feather, 
      gradient: 'from-purple-500 to-pink-600',
      description: 'Analyze poetry and creative writing'
    },
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsProcessing(true);

    try {
      let result: IngestionResult;

      switch (activeTab) {
        case 'youtube':
          if (!youtubeUrl) throw new Error('YouTube URL is required');
          result = await TesseraAPI.ingestYoutube(youtubeUrl, title, description);
          break;
        case 'article':
          if (!articleUrl) throw new Error('Article URL is required');
          result = await TesseraAPI.ingestArticle(articleUrl, title, description);
          break;
        case 'book':
          if (!selectedFile) throw new Error('File is required');
          result = await TesseraAPI.ingestBook(selectedFile, title, description);
          break;
        case 'poetry':
          if (!poetryText) throw new Error('Poetry text is required');
          result = await TesseraAPI.ingestPoetry(poetryText, title, description);
          break;
        default:
          throw new Error('Invalid tab selected');
      }

      setResults(prev => [result, ...prev]);
      
      // Clear form on success
      if (result.success) {
        setYoutubeUrl('');
        setArticleUrl('');
        setPoetyText('');
        setSelectedFile(null);
        setTitle('');
        setDescription('');
      }

    } catch (error) {
      console.error('Ingestion failed:', error);
      const errorResult: IngestionResult = {
        success: false,
        title: title || 'Failed Ingestion',
        content_type: activeTab,
        word_count: 0,
        chunk_count: 0,
        processing_time_seconds: 0,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
      setResults(prev => [errorResult, ...prev]);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      if (!title) {
        setTitle(file.name.replace(/\.[^/.]+$/, ''));
      }
    }
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case 'youtube':
        return (
          <div className="space-y-6">
            <AssimilatorInput
              value={youtubeUrl}
              onChange={setYoutubeUrl}
              placeholder="Enter YouTube URL (e.g., https://www.youtube.com/watch?v=...)"
              isLoading={isProcessing}
              icon={Youtube}
            />
          </div>
        );
      
      case 'article':
        return (
          <div className="space-y-6">
            <AssimilatorInput
              value={articleUrl}
              onChange={setArticleUrl}
              placeholder="Enter article URL (e.g., https://example.com/article)"
              isLoading={isProcessing}
              icon={Globe}
            />
          </div>
        );
      
      case 'book':
        return (
          <div className="space-y-6">
            <div className="relative group">
              <div className="absolute -inset-2 bg-gradient-to-r from-green-500/20 via-emerald-500/20 to-teal-500/20 rounded-3xl blur opacity-0 group-hover:opacity-100 transition-all duration-500 pointer-events-none"></div>
              <div className="relative bg-white/90 backdrop-blur-md rounded-2xl border border-white/30 shadow-xl p-8">
                <div className="flex items-center justify-center w-full">
                  <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-slate-300 border-dashed rounded-xl cursor-pointer bg-slate-50 hover:bg-slate-100 transition-colors">
                    <div className="flex flex-col items-center justify-center pt-5 pb-6">
                      <Upload className="w-8 h-8 mb-4 text-slate-500" />
                      <p className="mb-2 text-sm text-slate-500">
                        <span className="font-semibold">Click to upload</span> or drag and drop
                      </p>
                      <p className="text-xs text-slate-500">PDF, DOCX, EPUB, TXT (MAX. 50MB)</p>
                    </div>
                    <input
                      type="file"
                      className="hidden"
                      accept=".pdf,.docx,.epub,.txt,.md"
                      onChange={handleFileChange}
                    />
                  </label>
                </div>
                {selectedFile && (
                  <div className="mt-4 p-3 bg-green-50 rounded-lg border border-green-200">
                    <div className="flex items-center space-x-2">
                      <FileText className="w-5 h-5 text-green-600" />
                      <span className="text-sm font-medium text-green-800">{selectedFile.name}</span>
                      <span className="text-xs text-green-600">({(selectedFile.size / 1024 / 1024).toFixed(2)} MB)</span>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        );
      
      case 'poetry':
        return (
          <div className="space-y-6">
            <div className="relative group">
              <div className="absolute -inset-2 bg-gradient-to-r from-purple-500/20 via-pink-500/20 to-rose-500/20 rounded-3xl blur opacity-0 group-hover:opacity-100 transition-all duration-500 pointer-events-none"></div>
              <div className="relative bg-white/90 backdrop-blur-md rounded-2xl border border-white/30 shadow-xl p-2">
                <textarea
                  value={poetryText}
                  onChange={(e) => setPoetyText(e.target.value)}
                  placeholder="Enter your poetry or creative writing here..."
                  rows={8}
                  className="block w-full p-6 text-lg border-2 border-slate-200/50 
                           rounded-xl bg-white/95 backdrop-blur-sm text-slate-800 placeholder-slate-400 
                           focus:outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-500/20 
                           hover:border-slate-300 hover:bg-white transition-all duration-300 shadow-lg
                           font-medium resize-none"
                />
              </div>
            </div>
          </div>
        );
      
      default:
        return null;
    }
  };

  return (
    <div className="container-page">
      <div className="max-w-6xl mx-auto space-y-12">
        {/* Enhanced Header */}
        <div className="text-center space-y-6 relative">
          <div className="absolute -top-8 -left-8 w-32 h-32 bg-gradient-to-br from-purple-400/20 to-pink-400/20 rounded-full blur-3xl animate-float"></div>
          <div className="absolute -top-4 -right-12 w-24 h-24 bg-gradient-to-br from-blue-400/20 to-teal-400/20 rounded-full blur-2xl animate-float" style={{animationDelay: '1s'}}></div>
          
          <div className="relative">
            <h1 className="text-5xl sm:text-6xl font-bold text-gradient-electric mb-4">
              Data Assimilator
            </h1>
            <div className="flex items-center justify-center space-x-2 mb-6">
              <Sparkles className="w-6 h-6 text-purple-500 animate-pulse" />
              <p className="text-xl text-slate-600 max-w-3xl">
                Transform any content into searchable knowledge - YouTube videos, articles, books, and creative writing
              </p>
              <Zap className="w-6 h-6 text-teal-500 animate-pulse" />
            </div>
          </div>
        </div>

        {/* Content Type Tabs */}
        <div className="max-w-4xl mx-auto">
          <div className="flex flex-wrap justify-center gap-3 mb-8">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as 'youtube' | 'article' | 'book' | 'poetry')}
                className={`group relative px-6 py-4 rounded-2xl font-medium transition-all duration-300 transform hover:scale-105 ${
                  activeTab === tab.id
                    ? 'text-white shadow-lg'
                    : 'text-slate-600 hover:text-slate-800 hover:bg-white/80'
                }`}
              >
                {/* Active background */}
                {activeTab === tab.id && (
                  <div className={`absolute inset-0 bg-gradient-to-r ${tab.gradient} rounded-2xl shadow-lg pointer-events-none`}>
                    <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent rounded-2xl pointer-events-none"></div>
                  </div>
                )}
                
                {/* Hover background */}
                {activeTab !== tab.id && (
                  <div className="absolute inset-0 bg-gradient-to-r from-slate-50 to-white rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 shadow-md pointer-events-none"></div>
                )}

                {/* Content */}
                <div className="relative flex flex-col items-center space-y-2">
                  <tab.icon className={`w-6 h-6 ${
                    activeTab === tab.id ? 'text-white' : 'text-slate-500 group-hover:text-slate-700'
                  } transition-colors duration-300`} />
                  <span className="relative z-10 text-sm">{tab.label}</span>
                </div>

                {/* Active indicator dot */}
                {activeTab === tab.id && (
                  <div className="absolute -bottom-1 left-1/2 transform -translate-x-1/2 w-1 h-1 bg-white rounded-full animate-pulse pointer-events-none"></div>
                )}
              </button>
            ))}
          </div>

          {/* Tab Description */}
          <div className="text-center mb-8">
            <p className="text-slate-600 font-medium">
              {tabs.find(tab => tab.id === activeTab)?.description}
            </p>
          </div>
        </div>

        {/* Input Form */}
        <div className="max-w-3xl mx-auto">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Tab Content */}
            <div className="relative group">
              <div className="absolute -inset-2 bg-gradient-to-r from-purple-500/20 via-blue-500/20 to-teal-500/20 rounded-3xl blur opacity-0 group-hover:opacity-100 transition-all duration-500 pointer-events-none"></div>
              <div className="relative bg-white/90 backdrop-blur-md rounded-2xl border border-white/30 shadow-xl p-2">
                {renderTabContent()}
              </div>
            </div>

            {/* Optional Fields */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Title (Optional)
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Custom title for this content"
                  className="block w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all duration-200"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Description (Optional)
                </label>
                <input
                  type="text"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Brief description or notes"
                  className="block w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all duration-200"
                />
              </div>
            </div>

            {/* Submit Button */}
            <div className="text-center">
              <button
                type="submit"
                disabled={isProcessing}
                className="group relative px-8 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-2xl shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                <div className="flex items-center space-x-2">
                  {isProcessing ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    <Upload className="w-5 h-5" />
                  )}
                  <span>
                    {isProcessing ? 'Processing...' : 'Assimilate Content'}
                  </span>
                </div>
                
                {/* Button glow effect */}
                <div className="absolute -inset-1 bg-gradient-to-r from-purple-600 to-pink-600 rounded-2xl blur opacity-0 group-hover:opacity-30 transition-opacity duration-300 pointer-events-none"></div>
              </button>
            </div>
          </form>
        </div>

        {/* Results Section */}
        {results.length > 0 && (
          <div className="max-w-4xl mx-auto">
            <h2 className="text-2xl font-bold text-slate-800 mb-6 text-center">
              Processing Results
            </h2>
            <div className="space-y-4">
              {results.map((result, index) => (
                <div
                  key={index}
                  className={`p-6 rounded-2xl border-2 ${
                    result.success
                      ? 'bg-green-50 border-green-200'
                      : 'bg-red-50 border-red-200'
                  } shadow-lg`}
                >
                  <div className="flex items-start space-x-4">
                    <div className="flex-shrink-0">
                      {result.success ? (
                        <CheckCircle className="w-6 h-6 text-green-600" />
                      ) : (
                        <AlertCircle className="w-6 h-6 text-red-600" />
                      )}
                    </div>
                    <div className="flex-1">
                      <h3 className={`font-semibold ${
                        result.success ? 'text-green-800' : 'text-red-800'
                      }`}>
                        {result.title}
                      </h3>
                      <p className={`text-sm ${
                        result.success ? 'text-green-600' : 'text-red-600'
                      } mb-2`}>
                        {result.success ? 'Successfully processed' : result.error}
                      </p>
                      {result.success && (
                        <div className="flex flex-wrap gap-4 text-xs text-slate-600">
                          <span>Type: {result.content_type}</span>
                          <span>Words: {result.word_count.toLocaleString()}</span>
                          <span>Chunks: {result.chunk_count}</span>
                          <span>Time: {result.processing_time_seconds.toFixed(2)}s</span>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

import { useStats } from '../../hooks/useTessera';
import { KnowledgeInsights, KnowledgeHubs, LiveDiscoveries } from './KnowledgeInsights';
import { QuickActions } from './QuickActions';
import { AlertCircle, Loader2, Download, Sparkles } from 'lucide-react';

interface DashboardProps {
  onViewChange?: (view: string) => void;
}

export function Dashboard({ onViewChange }: DashboardProps) {
  const { data: stats, isLoading: statsLoading, error: statsError } = useStats();

  if (statsLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="flex items-center gap-3 text-gray-500">
            <Loader2 className="h-6 w-6 animate-spin" />
            <span>Loading dashboard...</span>
          </div>
        </div>
      </div>
    );
  }

  if (statsError) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="bg-white rounded-xl p-8 text-center max-w-md border border-gray-200 shadow-sm">
            <AlertCircle className="h-12 w-12 text-red-500 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Unable to Load Dashboard</h3>
            <p className="text-gray-600 mb-4">
              Failed to connect to the Tessera backend. Please ensure the server is running.
            </p>
            <button 
              onClick={() => window.location.reload()} 
              className="inline-flex items-center justify-center px-4 py-2 bg-purple-600 text-white font-medium rounded-lg hover:bg-purple-700 transition-colors"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50/30 to-purple-50/20">
      {/* Background Pattern */}
      <div className="fixed inset-0 opacity-[0.02] pointer-events-none">
        <div className="absolute inset-0 pointer-events-none" style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, rgba(99, 102, 241, 0.4) 1px, transparent 0)`,
          backgroundSize: '60px 60px'
        }}></div>
      </div>

      <div className="relative max-w-7xl mx-auto px-6 py-8 space-y-4">
        {/* Header Section */}
        <div className="text-center space-y-6">
          {/* Status Badge */}
          <div className="inline-flex items-center gap-3 px-4 py-2 bg-white/90 backdrop-blur-sm rounded-full border border-white/50 shadow-lg">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            <span className="text-sm font-semibold text-slate-700">Transform Wikipedia into personalized knowledge webs.</span>
          </div>
          
          {/* Main Title */}
          <div className="space-y-3">
            <h1 className="text-4xl sm:text-5xl font-black leading-[0.85]">
              <span className="block text-slate-900 mb-1">Wiki</span>
              <span className="block text-gradient-electric">Crawler</span>
            </h1>
            <p className="text-lg text-slate-600 max-w-2xl mx-auto">
              Discover connections between ideas that matter to you.
            </p>
          </div>

          {/* Quick Stats */}
          <div className="flex justify-center space-x-6">
            <div className="text-center">
              <div className="text-2xl font-black text-purple-600 mb-1">
                {stats?.data?.total_articles?.toLocaleString() ?? '4'}
              </div>
              <div className="text-sm font-semibold text-slate-600">Articles</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-black text-blue-600 mb-1">
                {stats?.data?.total_links?.toLocaleString() ?? '3'}
              </div>
              <div className="text-sm font-semibold text-slate-600">Connections</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-black text-teal-600 mb-1">
                {stats?.data?.avg_links_per_article?.toFixed(1) ?? '1.0'}
              </div>
              <div className="text-sm font-semibold text-slate-600">avg links <span className="text-slate-400">per article</span></div>
            </div>
          </div>
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:h-auto">
          {/* Left Column - Knowledge Insights */}
          <div className="lg:col-span-2 flex flex-col space-y-4">
            <div className="flex items-center gap-4">
              <div className="h-1 w-12 bg-gradient-to-r from-purple-500 to-blue-500 rounded-full"></div>
              <h2 className="text-2xl font-bold text-slate-900">Knowledge Insights</h2>
              <div className="px-3 py-1 rounded-full bg-gradient-to-r from-purple-100 to-blue-100 border border-purple-200/50">
                <span className="text-xs font-semibold text-purple-700">Live Analysis</span>
              </div>
            </div>
            <div className="flex-1">
              <KnowledgeInsights stats={stats?.data} />
            </div>
          </div>

          {/* Right Column - Actions */}
          <div className="flex flex-col space-y-4">
            <div className="flex items-center gap-4">
              <div className="h-1 w-12 bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full"></div>
              <h2 className="text-2xl font-bold text-slate-900">Actions</h2>
            </div>
            <div className="flex-1">
              <QuickActions onNavigate={onViewChange} />
            </div>
          </div>
        </div>

        {/* Secondary Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:h-64">
          {/* Knowledge Hubs */}
          <div className="h-full">
            <KnowledgeHubs stats={stats?.data} />
          </div>

          {/* Live Discoveries */}
          <div className="h-full">
            <LiveDiscoveries stats={stats?.data} />
          </div>

          {/* Export Data */}
          <div className="h-full">
            <div className="h-full flex flex-col bg-white/80 backdrop-blur-sm rounded-2xl p-4 border border-white/50 shadow-lg hover-plasma cursor-pointer group">
              <div className="flex items-center space-x-3 mb-4">
                <div className="w-8 h-8 bg-gradient-to-r from-orange-500 to-red-600 rounded-xl flex-center group-hover:scale-110 transition-transform duration-300">
                  <Download className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-800">Export Data</h3>
                  <p className="text-xs text-slate-600">Share your knowledge</p>
                </div>
              </div>
              
              <div className="flex-1 flex flex-col justify-center space-y-3">
                <div className="flex items-center justify-between p-3 rounded-xl bg-gradient-to-r from-slate-50 to-white border border-slate-100 hover:shadow-md transition-all duration-200 cursor-pointer">
                  <span className="text-xs font-semibold text-slate-700">JSON Format</span>
                  <Sparkles className="w-3 h-3 text-orange-500" />
                </div>
                <div className="flex items-center justify-between p-3 rounded-xl bg-gradient-to-r from-slate-50 to-white border border-slate-100 hover:shadow-md transition-all duration-200 cursor-pointer">
                  <span className="text-xs font-semibold text-slate-700">Graph Format</span>
                  <Sparkles className="w-3 h-3 text-red-500" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

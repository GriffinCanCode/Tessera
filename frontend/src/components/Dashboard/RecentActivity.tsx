import { Activity, Clock, TrendingUp, Target } from 'lucide-react';
import type { DatabaseStats } from '../../types/api';

interface RecentActivityProps {
  stats?: DatabaseStats;
}

export function RecentActivity({ stats }: RecentActivityProps) {
  const sessionStats = stats?.session_stats;

  const formatDuration = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds.toFixed(0)}s`;
  };

  const formatDate = (timestamp: number): string => {
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  if (!sessionStats) {
    return (
      <div className="relative bg-white rounded-3xl p-12 text-center border border-slate-200/50 shadow-sm overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-slate-50 to-blue-50/30 opacity-60"></div>
        <div className="relative">
          <div className="mx-auto w-20 h-20 rounded-full bg-gradient-to-br from-slate-200 to-slate-300 flex items-center justify-center mb-6">
            <Activity className="h-10 w-10 text-slate-500" />
          </div>
          <h3 className="text-2xl font-bold mb-3 text-slate-900">Ready to Start</h3>
          <p className="text-slate-600 text-lg">Launch your first crawl to see activity insights here.</p>
        </div>
      </div>
    );
  }

  const activityItems = [
    {
      icon: Target,
      label: 'Starting URL',
      value: sessionStats.start_url ? sessionStats.start_url.split('/').pop() : 'N/A',
      description: 'Last crawl starting point',
      gradient: 'from-purple-500 to-indigo-600',
      bgColor: 'from-purple-50 to-indigo-50',
    },
    {
      icon: TrendingUp,
      label: 'Articles Processed',
      value: `${sessionStats.articles_processed}/${sessionStats.articles_crawled}`,
      description: 'Successfully processed articles',
      gradient: 'from-emerald-500 to-green-600',
      bgColor: 'from-emerald-50 to-green-50',
    },
    {
      icon: Clock,
      label: 'Duration',
      value: sessionStats.duration ? formatDuration(sessionStats.duration) : 'In progress',
      description: 'Time taken to complete',
      gradient: 'from-blue-500 to-cyan-600',
      bgColor: 'from-blue-50 to-cyan-50',
    },
  ];

  return (
    <div className="bg-white rounded-3xl p-8 border border-slate-200/50 shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center shadow-lg">
            <Activity className="h-6 w-6 text-white" />
          </div>
          <div>
            <h3 className="text-2xl font-bold text-slate-900">Recent Session</h3>
            {sessionStats.start_time && (
              <p className="text-slate-500 text-sm">{formatDate(sessionStats.start_time)}</p>
            )}
          </div>
        </div>
      </div>

      {/* Activity Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        {activityItems.map(({ icon: Icon, label, value, description, gradient, bgColor }) => (
          <div key={label} className={`group relative p-6 rounded-2xl bg-gradient-to-br ${bgColor} border border-white/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1`}>
            <div className="flex items-start gap-4">
              <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${gradient} flex items-center justify-center shadow-sm group-hover:shadow-lg group-hover:scale-110 transition-all duration-300`}>
                <Icon className="h-6 w-6 text-white" />
              </div>
              <div className="flex-1">
                <p className={`text-2xl font-black bg-gradient-to-r ${gradient} bg-clip-text text-transparent leading-tight`}>
                  {value}
                </p>
                <p className="text-sm font-bold text-slate-800 mt-1">{label}</p>
                <p className="text-xs text-slate-500 mt-1">{description}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Progress indicator if in progress */}
      {!sessionStats.end_time && sessionStats.articles_crawled > 0 && (
        <div className="relative p-6 rounded-2xl bg-gradient-to-br from-blue-50 to-indigo-50 border border-blue-100/50 mb-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-lg font-bold text-slate-900">Crawling in Progress</span>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
              <span className="text-sm font-medium text-slate-600">
                {sessionStats.articles_crawled} / {sessionStats.max_articles}
              </span>
            </div>
          </div>
          <div className="relative w-full bg-white/60 rounded-full h-4 overflow-hidden">
            <div
              className="bg-gradient-to-r from-blue-500 to-indigo-600 h-4 rounded-full transition-all duration-1000 ease-out relative overflow-hidden"
              style={{
                width: `${Math.min(
                  (sessionStats.articles_crawled / sessionStats.max_articles) * 100,
                  100
                )}%`,
              }}
            >
              <div className="absolute inset-0 bg-white/20 animate-pulse"></div>
            </div>
          </div>
        </div>
      )}

      {/* Session parameters */}
      <div className="grid grid-cols-2 gap-6">
        <div className="p-4 rounded-2xl bg-gradient-to-br from-slate-50 to-gray-50 border border-slate-100">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-slate-600">Max Depth</span>
            <span className="text-lg font-bold text-slate-900">{sessionStats.max_depth}</span>
          </div>
        </div>
        <div className="p-4 rounded-2xl bg-gradient-to-br from-slate-50 to-gray-50 border border-slate-100">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-slate-600">Max Articles</span>
            <span className="text-lg font-bold text-slate-900">{sessionStats.max_articles}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

import { Clock, Server } from 'lucide-react';
import type { HealthCheck, ApiInfo } from '../../types/api';

interface SystemStatusProps {
  health?: HealthCheck;
  info?: ApiInfo;
}

export function SystemStatus({ health, info }: SystemStatusProps) {
  const formatUptime = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const isHealthy = health?.status === 'ok';

  return (
    <div className="bg-white rounded-3xl p-8 border border-slate-200/50 shadow-sm relative overflow-hidden">
      {/* Animated background */}
      <div className={`absolute inset-0 bg-gradient-to-br ${isHealthy ? 'from-green-50/50 to-emerald-50/50' : 'from-red-50/50 to-orange-50/50'} opacity-60`}></div>
      
      {/* Header */}
      <div className="relative flex items-center justify-between mb-8">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-slate-600 to-slate-800 flex items-center justify-center shadow-lg">
            <Server className="h-6 w-6 text-white" />
          </div>
          <div>
            <h3 className="text-2xl font-bold text-slate-900">System Status</h3>
            <p className="text-sm text-slate-500">Real-time monitoring</p>
          </div>
        </div>
        
        {/* Main status indicator */}
        <div className={`flex items-center gap-3 px-6 py-3 rounded-2xl ${
          isHealthy 
            ? 'bg-gradient-to-r from-green-100 to-emerald-100 border border-green-200/50' 
            : 'bg-gradient-to-r from-red-100 to-orange-100 border border-red-200/50'
        }`}>
          <div className={`relative w-3 h-3 rounded-full ${
            isHealthy ? 'bg-green-500' : 'bg-red-500'
          }`}>
            <div className={`absolute inset-0 rounded-full ${
              isHealthy ? 'bg-green-500' : 'bg-red-500'
            } animate-ping opacity-75`}></div>
          </div>
          <span className={`font-bold text-sm ${
            isHealthy ? 'text-green-700' : 'text-red-700'
          }`}>
            {isHealthy ? 'System Healthy' : 'Issues Detected'}
          </span>
        </div>
      </div>

      {/* Status Cards */}
      <div className="relative grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Uptime */}
        {health?.uptime && (
          <div className="group p-6 rounded-2xl bg-gradient-to-br from-blue-50 to-indigo-50 border border-blue-100/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center shadow-sm group-hover:shadow-lg group-hover:scale-110 transition-all duration-300">
                <Clock className="h-6 w-6 text-white" />
              </div>
              <div className="flex-1">
                <p className="text-2xl font-black bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent leading-tight">
                  {formatUptime(health.uptime)}
                </p>
                <p className="text-sm font-bold text-slate-800">System Uptime</p>
                <p className="text-xs text-slate-500">Continuous operation</p>
              </div>
            </div>
          </div>
        )}

        {/* Version */}
        {info?.version && (
          <div className="group p-6 rounded-2xl bg-gradient-to-br from-purple-50 to-pink-50 border border-purple-100/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center shadow-sm group-hover:shadow-lg group-hover:scale-110 transition-all duration-300">
                <span className="text-lg font-black text-white">v</span>
              </div>
              <div className="flex-1">
                <p className="text-2xl font-black bg-gradient-to-r from-purple-500 to-pink-600 bg-clip-text text-transparent leading-tight">
                  {info.version}
                </p>
                <p className="text-sm font-bold text-slate-800">API Version</p>
                <p className="text-xs text-slate-500">Current build</p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Description */}
      {info?.description && (
        <div className="relative p-6 rounded-2xl bg-gradient-to-br from-slate-50 to-gray-50 border border-slate-100">
          <div className="flex items-start gap-3">
            <div className="w-2 h-2 bg-gradient-to-r from-blue-500 to-purple-500 rounded-full mt-2 flex-shrink-0"></div>
            <p className="text-slate-700 leading-relaxed">{info.description}</p>
          </div>
        </div>
      )}
    </div>
  );
}

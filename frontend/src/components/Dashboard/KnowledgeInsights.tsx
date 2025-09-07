import React from 'react';
import { Network, Activity, Link, TrendingUp, Laptop, Microscope, BookOpen, User, Globe, Palette, FileText, Sprout, Search } from 'lucide-react';
import type { DatabaseStats } from '../../types/api';
import { useKnowledgeHubs, useRecentDiscoveries } from '../../hooks/useWikiCrawler';

interface KnowledgeInsightsProps {
  stats?: DatabaseStats;
}

export function KnowledgeInsights({ stats }: KnowledgeInsightsProps) {
  // Calculate knowledge depth (average links per article as approximation)
  const knowledgeDepth = stats?.avg_links_per_article || 0;
  const depthDisplay = knowledgeDepth > 0 ? knowledgeDepth.toFixed(1) : '0.0';
  
  // Use actual network density
  const networkDensity = stats?.network_density || 0;
  const densityDisplay = networkDensity > 0 ? networkDensity.toFixed(3) : '0.000';
  
  // Use actual discovery rate (links created in last 24h)
  const discoveryRate = stats?.links_last_24h || 0;
  
  const insights = [
    {
      title: 'Knowledge Depth',
      value: depthDisplay,
      label: 'avg links/article',
      description: 'Average connections per article',
      icon: Network,
      color: 'from-purple-500 to-indigo-600',
      bgColor: 'from-purple-50 to-indigo-50',
      iconBg: 'bg-purple-500',
      emoji: '🧠',
      tag: knowledgeDepth > 2 ? '+good' : 'building'
    },
    {
      title: 'Discovery Rate',
      value: discoveryRate.toString(),
      label: 'new links/day',
      description: 'Connections discovered in last 24h',
      icon: Activity,
      color: 'from-orange-500 to-red-600',
      bgColor: 'from-orange-50 to-red-50',
      iconBg: 'bg-orange-500',
      emoji: '🔄',
      tag: discoveryRate > 10 ? '+active' : 'growing'
    },
    {
      title: 'Network Density',
      value: densityDisplay,
      label: 'connectivity',
      description: 'How interconnected your knowledge is',
      icon: Link,
      color: 'from-teal-500 to-green-600',
      bgColor: 'from-teal-50 to-green-50',
      iconBg: 'bg-teal-500',
      iconComponent: Link,
      tag: networkDensity > 0.1 ? 'dense' : 'sparse'
    }
  ];

  return (
    <div className="h-full flex flex-col space-y-4">
      {/* Insights Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 flex-1">
        {insights.map((insight) => (
          <div key={insight.title} className="group relative h-full">
            <div className={`h-full flex flex-col bg-gradient-to-br ${insight.bgColor} rounded-2xl p-4 border border-white/50 hover:shadow-xl transition-all duration-500 transform hover:-translate-y-1 hover:scale-[1.01]`}>
              {/* Top Section with Icon and Tag */}
              <div className="flex items-start justify-between mb-4">
                <div className="relative">
                  <div className={`w-10 h-10 ${insight.iconBg} rounded-xl flex-center shadow-lg group-hover:shadow-xl group-hover:scale-110 transition-all duration-300`}>
                    <insight.icon className="w-5 h-5 text-white" />
                  </div>
                  <div className="absolute -top-1 -right-1 group-hover:animate-bounce">
                    {insight.iconComponent && React.createElement(insight.iconComponent, { className: "w-4 h-4 text-slate-600" })}
                  </div>
                </div>
                <div className={`px-2 py-1 rounded-full bg-white/60 backdrop-blur-sm border border-white/30`}>
                  <span className={`text-xs font-bold bg-gradient-to-r ${insight.color} bg-clip-text text-transparent`}>
                    {insight.tag}
                  </span>
                </div>
              </div>

              {/* Main Content */}
              <div className="flex-1 flex flex-col justify-center space-y-2">
                <div className="flex items-baseline space-x-2">
                  <span className={`text-3xl font-black bg-gradient-to-r ${insight.color} bg-clip-text text-transparent leading-none`}>
                    {insight.value}
                  </span>
                  <span className="text-sm font-semibold text-slate-600">
                    {insight.label}
                  </span>
                </div>
                
                <h3 className="text-base font-bold text-slate-800">{insight.title}</h3>
                <p className="text-xs text-slate-600 leading-relaxed">{insight.description}</p>
              </div>

              {/* Bottom Progress Line */}
              <div className={`absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r ${insight.color} rounded-b-2xl transform scale-x-0 group-hover:scale-x-100 transition-transform duration-500 origin-left`}></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

interface KnowledgeHubsProps {
  stats?: DatabaseStats;
}

export function KnowledgeHubs(_props: KnowledgeHubsProps) {
  const { data: hubsData, isLoading } = useKnowledgeHubs(5);
  const hubs = hubsData?.data?.hubs || [];
  
  // Helper to get icon based on categories
  const getIconComponent = (categories: string[]) => {
    const categoryText = categories.join(' ').toLowerCase();
    if (categoryText.includes('technology') || categoryText.includes('computer')) return Laptop;
    if (categoryText.includes('science') || categoryText.includes('physics')) return Microscope;
    if (categoryText.includes('history') || categoryText.includes('war')) return BookOpen;
    if (categoryText.includes('people') || categoryText.includes('person')) return User;
    if (categoryText.includes('place') || categoryText.includes('geography')) return Globe;
    if (categoryText.includes('art') || categoryText.includes('music')) return Palette;
    return FileText;
  };
  
  // Helper to get category display
  const getMainCategory = (categories: string[]) => {
    if (categories.length === 0) return 'General';
    const mainCategory = categories[0];
    return mainCategory.charAt(0).toUpperCase() + mainCategory.slice(1);
  };

  return (
    <div className="h-full flex flex-col bg-white/80 backdrop-blur-sm rounded-2xl p-4 border border-white/50 shadow-lg">
      <div className="flex items-center space-x-3 mb-4">
        <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl flex-center">
          <Network className="w-4 h-4 text-white" />
        </div>
        <div>
          <h3 className="text-base font-bold text-slate-800">Knowledge Hubs</h3>
          <p className="text-xs text-slate-600">Most connected articles</p>
        </div>
      </div>

      <div className="flex-1 flex flex-col justify-center space-y-3">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <div className="text-sm text-slate-500">Loading hubs...</div>
          </div>
        ) : hubs.length > 0 ? (
          hubs.map((hub) => (
            <div key={hub.id} className="group flex items-center space-x-3 p-3 rounded-xl bg-gradient-to-r from-slate-50 to-white border border-slate-100 hover:shadow-md transition-all duration-200 cursor-pointer">
              <div className="relative">
                <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                <div className="absolute inset-0 w-2 h-2 bg-blue-500 rounded-full animate-ping opacity-75"></div>
              </div>
              
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-2">
                    {React.createElement(getIconComponent(hub.categories), { 
                      className: "w-3 h-3 text-slate-500"
                    })}
                    <h4 className="text-xs font-semibold bg-gradient-to-r from-blue-500 to-purple-600 bg-clip-text text-transparent">
                      {hub.title}
                    </h4>
                  </div>
                  <TrendingUp className="w-3 h-3 text-slate-400 group-hover:text-green-500 transition-colors" />
                </div>
                <p className="text-xs text-slate-500 mt-1">{getMainCategory(hub.categories)} • {hub.total_connections} links</p>
              </div>
            </div>
          ))
        ) : (
          <div className="flex items-center justify-center py-8">
            <div className="text-center">
              <div className="mb-2">
                <Sprout className="w-8 h-8 text-slate-400 mx-auto" />
              </div>
              <div className="text-sm text-slate-500">No knowledge hubs yet</div>
              <div className="text-xs text-slate-400 mt-1">Start crawling to build your graph</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

interface LiveDiscoveriesProps {
  stats?: DatabaseStats;
}

export function LiveDiscoveries(_props: LiveDiscoveriesProps) {
  const { data: discoveriesData, isLoading } = useRecentDiscoveries(5);
  const discoveries = discoveriesData?.data?.discoveries || [];
  
  // Helper to get color based on strength
  const getStrengthColor = (strength: string) => {
    if (strength.includes('strong')) return 'from-green-500 to-teal-600';
    if (strength.includes('moderate')) return 'from-blue-500 to-indigo-600';
    return 'from-orange-500 to-yellow-600';
  };

  return (
    <div className="h-full flex flex-col bg-white/80 backdrop-blur-sm rounded-2xl p-4 border border-white/50 shadow-lg">
      <div className="flex items-center space-x-3 mb-4">
        <div className="w-8 h-8 bg-gradient-to-r from-green-500 to-teal-600 rounded-xl flex-center">
          <Activity className="w-4 h-4 text-white" />
        </div>
        <div>
          <h3 className="text-base font-bold text-slate-800">Live Discoveries</h3>
          <p className="text-xs text-slate-600">Recently found connections</p>
        </div>
      </div>

      <div className="flex-1 flex flex-col justify-center space-y-3">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <div className="text-sm text-slate-500">Loading discoveries...</div>
          </div>
        ) : discoveries.length > 0 ? (
          discoveries.map((discovery) => (
            <div key={discovery.id} className="group flex items-center space-x-3 p-3 rounded-xl bg-gradient-to-r from-slate-50 to-white border border-slate-100 hover:shadow-md transition-all duration-200">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              
              <div className="flex-1">
                <div className="flex items-center space-x-2">
                  <span className="text-xs font-semibold text-slate-800 truncate" title={discovery.from_title}>
                    {discovery.from_title.length > 15 ? discovery.from_title.substring(0, 15) + '...' : discovery.from_title}
                  </span>
                  <div className="flex-1 border-t border-dashed border-slate-300"></div>
                  <span className="text-xs font-semibold text-slate-800 truncate" title={discovery.to_title}>
                    {discovery.to_title.length > 15 ? discovery.to_title.substring(0, 15) + '...' : discovery.to_title}
                  </span>
                </div>
                <div className="flex items-center justify-between mt-2">
                  <span className={`text-xs font-medium bg-gradient-to-r ${getStrengthColor(discovery.strength)} bg-clip-text text-transparent`}>
                    ◉ {discovery.strength}
                  </span>
                  <span className="text-xs text-slate-500">{discovery.time_ago}</span>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="flex items-center justify-center py-8">
            <div className="text-center">
              <div className="mb-2">
                <Search className="w-8 h-8 text-slate-400 mx-auto" />
              </div>
              <div className="text-sm text-slate-500">No discoveries yet</div>
              <div className="text-xs text-slate-400 mt-1">New connections will appear here</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
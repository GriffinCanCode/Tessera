import { Search, Rocket, Network, Brain, Sparkles, Zap, ArrowRight } from 'lucide-react';

interface QuickActionsProps {
  onNavigate?: (view: string) => void;
}

export function QuickActions({ onNavigate }: QuickActionsProps) {
  const actions = [
    {
      id: 'search',
      title: 'Search Articles',
      description: 'Find insights in your knowledge base',
      icon: Search,
      gradient: 'from-blue-500 to-indigo-600',
      bgColor: 'from-blue-50 to-indigo-50',
      action: () => onNavigate?.('search'),
    },
    {
      id: 'crawl',
      title: 'Start New Crawl',
      description: 'Discover new connections',
      icon: Rocket,
      gradient: 'from-emerald-500 to-green-600',
      bgColor: 'from-emerald-50 to-green-50',
      action: () => onNavigate?.('crawl'),
    },
    {
      id: 'graph',
      title: 'Knowledge Graph',
      description: 'Visualize your data network',
      icon: Network,
      gradient: 'from-purple-500 to-pink-600',
      bgColor: 'from-purple-50 to-pink-50',
      action: () => onNavigate?.('graph'),
    },
    {
      id: 'insights',
      title: 'Personal Insights',
      description: 'Deep dive into learning patterns',
      icon: Brain,
      gradient: 'from-indigo-500 to-purple-600',
      bgColor: 'from-indigo-50 to-purple-50',
      action: () => onNavigate?.('insights'),
    }
  ];

  return (
    <div className="flex flex-col h-full space-y-3">
        {actions.map(({ id, title, description, icon: Icon, gradient, action }) => {
          // Special enhanced styling for the crawler action
          if (id === 'crawl') {
            return (
              <button 
                key={id} 
                onClick={action}
                className="group relative w-full flex-1 bg-gradient-to-br from-emerald-50/90 via-teal-50/90 to-green-50/90 backdrop-blur-sm rounded-2xl p-5 border border-emerald-200/60 shadow-lg hover:shadow-2xl hover:-translate-y-2 hover:scale-[1.02] transition-all duration-500 text-left overflow-hidden"
              >
                {/* Enhanced background effects */}
                <div className="absolute inset-0 bg-gradient-to-r from-emerald-400/10 via-teal-400/10 to-green-400/10 opacity-0 group-hover:opacity-100 transition-all duration-500"></div>
                <div className="absolute -top-2 -right-2 w-20 h-20 bg-gradient-to-br from-emerald-300/20 to-teal-300/20 rounded-full blur-xl opacity-0 group-hover:opacity-100 transition-all duration-700"></div>
                
                <div className="relative flex items-center space-x-4 h-full">
                  {/* Enhanced icon with special effects */}
                  <div className="relative">
                    <div className={`w-12 h-12 bg-gradient-to-r ${gradient} rounded-xl flex-center shadow-xl group-hover:scale-110 group-hover:rotate-12 transition-all duration-500`}>
                      <Icon className="w-6 h-6 text-white group-hover:animate-bounce" />
                    </div>
                    {/* Floating sparkle */}
                    <div className="absolute -top-1 -right-1 w-4 h-4 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-300 animate-pulse">
                      <Sparkles className="w-2 h-2 text-white" />
                    </div>
                  </div>
                  
                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <h3 className={`text-lg font-bold bg-gradient-to-r ${gradient} bg-clip-text text-transparent group-hover:tracking-wide transition-all duration-300`}>
                        {title}
                      </h3>
                      <div className="opacity-0 group-hover:opacity-100 transition-all duration-300">
                        <Zap className="w-4 h-4 text-emerald-500 animate-pulse" />
                      </div>
                    </div>
                    <p className="text-sm text-slate-700 font-medium group-hover:text-emerald-700 transition-colors duration-300">{description}</p>
                    
                    {/* Progress indicator */}
                    <div className="mt-2 opacity-0 group-hover:opacity-100 transition-all duration-500">
                      <div className="flex items-center space-x-2 text-xs text-emerald-600">
                        <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
                        <span className="font-semibold">Ready to launch</span>
                      </div>
                    </div>
                  </div>

                  {/* Enhanced arrow with animation */}
                  <div className="w-8 h-8 bg-gradient-to-r from-emerald-500 to-teal-500 rounded-full flex-center group-hover:bg-gradient-to-r group-hover:from-emerald-600 group-hover:to-teal-600 transition-all duration-300 shadow-lg">
                    <ArrowRight className="w-4 h-4 text-white group-hover:translate-x-1 transition-transform duration-300" />
                  </div>
                </div>
                
                {/* Shimmer effect */}
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
              </button>
            );
          }
          
          // Default styling for other actions
          return (
            <button 
              key={id} 
              onClick={action}
              className="group w-full flex-1 bg-white/80 backdrop-blur-sm rounded-2xl p-4 border border-white/50 shadow-lg hover:shadow-xl hover:-translate-y-1 hover:scale-[1.01] transition-all duration-300 text-left"
            >
              <div className="flex items-center space-x-3 h-full">
                <div className={`w-10 h-10 bg-gradient-to-r ${gradient} rounded-xl flex-center shadow-lg group-hover:scale-110 transition-transform duration-300`}>
                  <Icon className="w-5 h-5 text-white" />
                </div>
                
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-1">
                    <h3 className={`text-base font-bold bg-gradient-to-r ${gradient} bg-clip-text text-transparent`}>
                      {title}
                    </h3>
                  </div>
                  <p className="text-xs text-slate-600">{description}</p>
                </div>

                <div className="w-7 h-7 bg-slate-100 rounded-full flex-center group-hover:bg-slate-200 transition-colors">
                  <ArrowRight className="w-3 h-3 text-slate-600" />
                </div>
              </div>
            </button>
          );
        })}
    </div>
  );
}

import { Search, Rocket, Network, Brain } from 'lucide-react';

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
        {actions.map(({ id, title, description, icon: Icon, gradient, action }) => (
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
              <svg className="w-3 h-3 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}

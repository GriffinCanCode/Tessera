import { TrendingUp, Search, Upload, GraduationCap, Brain, Network, Lightbulb } from 'lucide-react';

interface SubNavigationProps {
  currentView: string;
  onViewChange: (view: string) => void;
}

export function SubNavigation({ currentView, onViewChange }: SubNavigationProps) {
  const getWorkflowFromView = (view: string) => {
    const workflows = {
      'dashboard': 'discover',
      'search': 'discover',
      'assimilator': 'create', 
      'notebook': 'create',
      'brain': 'analyze',
      'graph': 'analyze',
      'insights': 'analyze'
    };
    return workflows[view as keyof typeof workflows] || 'discover';
  };

  const currentWorkflow = getWorkflowFromView(currentView);

  const subNavItems = {
    discover: [
      { id: 'dashboard', label: 'Dashboard', icon: TrendingUp, description: 'Overview & Stats' },
      { id: 'search', label: 'Search', icon: Search, description: 'Find Content' }
    ],
    create: [
      { id: 'assimilator', label: 'Assimilator', icon: Upload, description: 'Import Data' },
      { id: 'notebook', label: 'Notebook', icon: GraduationCap, description: 'Chat & Notes' }
    ],
    analyze: [
      { id: 'brain', label: 'Brain', icon: Brain, description: '3D Visualization' },
      { id: 'graph', label: 'Graph', icon: Network, description: 'Network View' },
      { id: 'insights', label: 'Insights', icon: Lightbulb, description: 'Analytics' }
    ]
  };

  const currentItems = subNavItems[currentWorkflow as keyof typeof subNavItems] || [];

  if (currentItems.length <= 1) {
    return null; // Don't show sub-nav if there's only one item
  }

  const workflowColors = {
    discover: {
      gradient: 'from-blue-500 to-indigo-600',
      bg: 'from-blue-50 to-indigo-50',
      border: 'border-blue-200',
      text: 'text-blue-700',
      activeText: 'text-blue-800'
    },
    create: {
      gradient: 'from-emerald-500 to-green-600',
      bg: 'from-emerald-50 to-green-50',
      border: 'border-emerald-200',
      text: 'text-emerald-700',
      activeText: 'text-emerald-800'
    },
    analyze: {
      gradient: 'from-purple-500 to-pink-600',
      bg: 'from-purple-50 to-pink-50',
      border: 'border-purple-200',
      text: 'text-purple-700',
      activeText: 'text-purple-800'
    }
  };

  const colors = workflowColors[currentWorkflow as keyof typeof workflowColors];

  return (
    <div className={`bg-gradient-to-r ${colors.bg} border-b ${colors.border} shadow-sm backdrop-blur-sm`}>
      <div className="container mx-auto px-6 py-4">
        <nav className="flex items-center justify-center space-x-2">
          {currentItems.map(({ id, label, icon: Icon, description }) => (
            <button
              key={id}
              onClick={() => onViewChange(id)}
              className={`group relative overflow-hidden transition-all duration-300 transform hover:scale-105 ${
                currentView === id
                  ? 'shadow-lg'
                  : 'hover:shadow-md'
              }`}
            >
              {/* Button container */}
              <div className={`relative px-6 py-3 rounded-2xl border transition-all duration-300 backdrop-blur-md ${
                currentView === id
                  ? 'border-transparent bg-white/95 shadow-lg'
                  : 'border-white/40 hover:border-white/60 bg-white/60 hover:bg-white/90'
              }`}>
                
                {/* Active glow effect */}
                {currentView === id && (
                  <div className={`absolute -inset-1 bg-gradient-to-r ${colors.gradient} rounded-2xl opacity-20 blur-sm pointer-events-none`}></div>
                )}
                
                {/* Hover glow effect for inactive buttons */}
                {currentView !== id && (
                  <div className={`absolute -inset-1 bg-gradient-to-r ${colors.gradient} rounded-2xl 
                                opacity-0 group-hover:opacity-10 transition-opacity duration-300 blur-sm pointer-events-none`}></div>
                )}

                <div className="relative flex items-center space-x-3">
                  {/* Enhanced icon */}
                  <div className={`relative transition-all duration-300 ${
                    currentView === id ? 'scale-110' : 'group-hover:scale-105'
                  }`}>
                    <Icon className={`w-5 h-5 ${
                      currentView === id ? colors.activeText : colors.text
                    } transition-all duration-300 ${
                      currentView === id ? 'drop-shadow-sm' : ''
                    }`} />
                    
                    {/* Icon glow for active state */}
                    {currentView === id && (
                      <div className={`absolute inset-0 bg-gradient-to-r ${colors.gradient} opacity-30 rounded-full blur-md animate-pulse pointer-events-none`}></div>
                    )}
                  </div>
                  
                  <span className={`relative font-semibold tracking-wide transition-all duration-300 ${
                    currentView === id ? colors.activeText : colors.text
                  } ${currentView === id ? 'drop-shadow-sm' : ''}`}>
                    {label}
                  </span>
                </div>

                {/* Enhanced tooltip */}
                <div className="absolute -bottom-12 left-1/2 transform -translate-x-1/2 px-3 py-2 bg-gray-900/95 backdrop-blur-md 
                              text-white text-xs rounded-xl opacity-0 group-hover:opacity-100 transition-all duration-300 
                              pointer-events-none whitespace-nowrap z-50 border border-gray-700/50 shadow-xl">
                  {description}
                  {/* Tooltip arrow */}
                  <div className="absolute -top-1 left-1/2 transform -translate-x-1/2 w-2 h-2 bg-gray-900/95 
                               rotate-45 border-l border-t border-gray-700/50"></div>
                </div>

                {/* Active indicator */}
                {currentView === id && (
                  <div className={`absolute -bottom-2 left-1/2 transform -translate-x-1/2 w-2 h-2 bg-gradient-to-r ${colors.gradient} 
                                rounded-full shadow-lg animate-pulse pointer-events-none`}></div>
                )}

                {/* Subtle corner accent */}
                <div className={`absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full transition-all duration-300 ${
                  currentView === id 
                    ? `bg-gradient-to-r ${colors.gradient} opacity-60` 
                    : 'bg-transparent group-hover:bg-slate-400/50'
                }`}></div>
              </div>
            </button>
          ))}
        </nav>
      </div>
    </div>
  );
}

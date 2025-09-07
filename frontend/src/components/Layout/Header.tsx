import { Network, Sparkles, Zap, Settings, Eye, PenTool, BarChart3 } from 'lucide-react';

interface HeaderProps {
  currentView: string;
  onViewChange: (view: string) => void;
}

export function Header({ currentView, onViewChange }: HeaderProps) {
  // Map individual views to workflows
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

  const workflowItems = [
    { 
      id: 'discover', 
      label: 'Discover', 
      icon: Eye, 
      gradient: 'from-blue-500 to-indigo-600',
      description: 'Dashboard & Search',
      subItems: ['dashboard', 'search']
    },
    { 
      id: 'create', 
      label: 'Create', 
      icon: PenTool, 
      gradient: 'from-emerald-500 to-green-600',
      description: 'Assimilator & Notebook',
      subItems: ['assimilator', 'notebook']
    },
    { 
      id: 'analyze', 
      label: 'Analyze', 
      icon: BarChart3, 
      gradient: 'from-purple-500 to-pink-600',
      description: 'Brain, Graph & Insights',
      subItems: ['brain', 'graph', 'insights']
    }
  ];

  const handleWorkflowClick = (workflowId: string, subItems: string[]) => {
    // If clicking the current workflow, cycle through its sub-items
    if (workflowId === currentWorkflow) {
      const currentIndex = subItems.indexOf(currentView);
      const nextIndex = (currentIndex + 1) % subItems.length;
      onViewChange(subItems[nextIndex]);
    } else {
      // Switch to the first item of the new workflow
      onViewChange(subItems[0]);
    }
  };

  return (
    <header className="relative bg-white/95 backdrop-blur-md border-b border-white/20 shadow-lg">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-[0.02]">
        <div className="absolute inset-0" style={{
          backgroundImage: `radial-gradient(circle at 2px 2px, rgba(99, 102, 241, 0.3) 1px, transparent 0)`,
          backgroundSize: '40px 40px'
        }}></div>
      </div>

      <div className="relative container mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Enhanced Logo Section */}
          <div className="group cursor-pointer">
            <div className="flex items-center space-x-4">
              <div className="relative">
                {/* Animated background glow */}
                <div className="absolute -inset-2 bg-gradient-to-r from-purple-500/20 via-blue-500/20 to-teal-500/20 rounded-full blur opacity-0 group-hover:opacity-100 transition-all duration-500 pointer-events-none"></div>
                
                {/* Logo icon with gradient */}
                <div className="relative w-12 h-12 bg-gradient-to-br from-purple-500 to-teal-500 rounded-2xl flex-center shadow-lg transform group-hover:scale-110 transition-all duration-300">
                  <Network className="w-7 h-7 text-white" />
                  
                  {/* Floating sparkles */}
                  <Sparkles className="absolute -top-1 -right-1 w-3 h-3 text-yellow-400 opacity-0 group-hover:opacity-100 transition-all duration-300 animate-pulse pointer-events-none" />
                  <Zap className="absolute -bottom-1 -left-1 w-3 h-3 text-cyan-400 opacity-0 group-hover:opacity-100 transition-all duration-300 animate-pulse pointer-events-none" style={{animationDelay: '0.5s'}} />
                </div>
              </div>
              
              <div className="hidden sm:block">
                <h1 className="text-2xl font-bold text-gradient-electric">
                  Learning Tracker
                </h1>
                <p className="text-sm text-slate-600 font-medium">
                  Personal Learning Journey
                </p>
              </div>
            </div>
          </div>

          {/* Enhanced Desktop Navigation - Workflow Based */}
          <nav className="hidden md:flex items-center space-x-3">
            {workflowItems.map(({ id, label, icon: Icon, gradient, description, subItems }) => (
              <button
                key={id}
                onClick={() => handleWorkflowClick(id, subItems)}
                className={`workflow-button ${currentWorkflow === id ? 'active' : ''}`}
              >
                {/* Main button container with unique shape */}
                <div className={`workflow-button-inner ${
                  currentWorkflow === id ? 'active' : 'inactive'
                }`}>
                  
                  {/* Active animated background */}
                  {currentWorkflow === id && (
                    <>
                      <div className={`workflow-bg-primary bg-gradient-to-br ${gradient}`}></div>
                      <div className="workflow-bg-overlay"></div>
                      <div className="workflow-bg-shimmer"></div>
                    </>
                  )}
                  
                  {/* Hover glow effect */}
                  {currentWorkflow !== id && (
                    <div className={`workflow-glow bg-gradient-to-r ${gradient}`}></div>
                  )}

                  {/* Content */}
                  <div className="relative flex flex-col items-center space-y-1.5">
                    {/* Icon with floating animation */}
                    <div className={`workflow-icon ${currentWorkflow === id ? 'active' : ''}`}>
                      <Icon className={`w-5 h-5 ${
                        currentWorkflow === id ? 'text-white drop-shadow-sm' : 'text-slate-600 group-hover:text-slate-800'
                      } transition-all duration-300`} />
                      
                      {/* Icon glow for active state */}
                      {currentWorkflow === id && (
                        <div className="workflow-icon-glow bg-white/20"></div>
                      )}
                    </div>
                    
                    <div className="text-center">
                      <span className={`workflow-text ${currentWorkflow === id ? 'active' : ''} block text-sm font-semibold ${
                        currentWorkflow === id ? 'text-white drop-shadow-sm' : 'text-slate-700 group-hover:text-slate-900'
                      } transition-all duration-300`}>{label}</span>
                      <span className={`workflow-description block text-xs font-medium ${
                        currentWorkflow === id ? 'text-white/80' : 'text-slate-500 group-hover:text-slate-600'
                      } transition-all duration-300`}>{description}</span>
                    </div>
                  </div>

                  {/* Progress dots for sub-items */}
                  <div className="progress-dots">
                    {subItems.map((_, index) => (
                      <div
                        key={index}
                        className={`progress-dot ${
                          currentWorkflow === id && subItems.indexOf(currentView) === index
                            ? 'active bg-white shadow-lg'
                            : currentWorkflow === id
                            ? 'bg-white/50'
                            : 'bg-slate-300/60 group-hover:bg-slate-400/80'
                        }`}
                      ></div>
                    ))}
                  </div>

                  {/* Sub-item counter badge */}
                  {currentWorkflow === id && (
                    <div className="counter-badge">
                      <span className="text-xs font-bold text-white drop-shadow-sm">
                        {subItems.indexOf(currentView) + 1}
                      </span>
                    </div>
                  )}

                  {/* Subtle corner accent */}
                  <div className={`corner-accent top-right ${
                    currentWorkflow === id 
                      ? 'bg-white/30' 
                      : 'bg-transparent group-hover:bg-slate-300/50'
                  }`}></div>
                </div>
              </button>
            ))}
          </nav>

          {/* Enhanced Mobile Menu Button */}
          <div className="md:hidden">
            <button className="group relative overflow-hidden p-3 rounded-2xl bg-white/95 border border-slate-200/60 
                             shadow-md hover:shadow-lg transition-all duration-300 transform hover:scale-105 backdrop-blur-md">
              {/* Hover glow effect */}
              <div className="absolute -inset-1 bg-gradient-to-r from-slate-400 to-slate-500 rounded-2xl 
                            opacity-0 group-hover:opacity-15 transition-opacity duration-300 blur-sm pointer-events-none"></div>
              
              <div className="relative">
                <Settings className="w-5 h-5 text-slate-600 group-hover:text-slate-800 transition-all duration-300 
                                 group-hover:rotate-90" />
              </div>
              
              {/* Active indicator */}
              <div className="absolute top-1 right-1 w-1.5 h-1.5 bg-slate-400/60 rounded-full 
                            opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
            </button>
          </div>
        </div>

        {/* Enhanced Mobile Navigation - Workflow Based */}
        <div className="md:hidden mt-6 pb-4">
          <nav className="grid grid-cols-1 gap-5">
            {workflowItems.map(({ id, label, icon: Icon, gradient, subItems }) => (
              <button
                key={id}
                onClick={() => handleWorkflowClick(id, subItems)}
                className={`group relative overflow-hidden transition-all duration-500 transform hover:scale-[1.02] ${
                  currentWorkflow === id
                    ? 'shadow-2xl'
                    : 'hover:shadow-lg'
                }`}
              >
                {/* Main container with enhanced styling */}
                <div className={`relative p-6 rounded-3xl border-2 transition-all duration-300 ${
                  currentWorkflow === id
                    ? 'border-transparent'
                    : 'border-slate-200/60 hover:border-slate-300/80 bg-white/90 backdrop-blur-sm'
                }`}>
                  
                  {/* Active animated background */}
                  {currentWorkflow === id && (
                    <>
                      <div className={`absolute inset-0 bg-gradient-to-br ${gradient} rounded-3xl`}></div>
                      <div className="absolute inset-0 bg-gradient-to-tr from-white/30 via-transparent to-white/10 rounded-3xl"></div>
                      {/* Animated shimmer effect */}
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent rounded-3xl animate-pulse"></div>
                    </>
                  )}
                  
                  {/* Hover glow effect */}
                  {currentWorkflow !== id && (
                    <div className={`absolute -inset-1 bg-gradient-to-r ${gradient} rounded-3xl opacity-0 group-hover:opacity-15 transition-opacity duration-300 blur-sm pointer-events-none`}></div>
                  )}

                  <div className="relative flex items-center space-x-5">
                    {/* Enhanced icon section */}
                    <div className={`relative transition-all duration-300 ${
                      currentWorkflow === id ? 'animate-pulse' : 'group-hover:scale-110'
                    }`}>
                      <div className={`w-16 h-16 rounded-2xl flex items-center justify-center transition-all duration-300 ${
                        currentWorkflow === id 
                          ? 'bg-white/20 backdrop-blur-sm border border-white/30' 
                          : 'bg-slate-100/80 group-hover:bg-slate-200/80'
                      }`}>
                        <Icon className={`w-8 h-8 ${
                          currentWorkflow === id ? 'text-white drop-shadow-lg' : 'text-slate-600 group-hover:text-slate-800'
                        } transition-all duration-300`} />
                      </div>
                      
                      {/* Icon glow for active state */}
                      {currentWorkflow === id && (
                        <div className="absolute inset-0 bg-white/20 rounded-2xl blur-lg animate-pulse"></div>
                      )}
                    </div>
                    
                    {/* Content section */}
                    <div className="flex-1 text-left">
                      <span className={`text-xl font-bold tracking-wide block ${
                        currentWorkflow === id ? 'text-white drop-shadow-sm' : 'text-slate-700 group-hover:text-slate-900'
                      } transition-all duration-300`}>{label}</span>
                      <span className={`text-sm font-medium block mt-1 ${
                        currentWorkflow === id ? 'text-white/90' : 'text-slate-500 group-hover:text-slate-600'
                      } transition-all duration-300`}>
                        {id === 'discover' && 'Dashboard & Search'}
                        {id === 'create' && 'Assimilator & Notebook'}
                        {id === 'analyze' && 'Brain, Graph & Insights'}
                      </span>
                      
                      {/* Progress dots for mobile */}
                      <div className="flex space-x-1 mt-3">
                        {subItems.map((_, index) => (
                          <div
                            key={index}
                            className={`w-2 h-2 rounded-full transition-all duration-300 ${
                              currentWorkflow === id && subItems.indexOf(currentView) === index
                                ? 'bg-white scale-125 shadow-lg'
                                : currentWorkflow === id
                                ? 'bg-white/50'
                                : 'bg-slate-300/60 group-hover:bg-slate-400/80'
                            }`}
                          ></div>
                        ))}
                      </div>
                    </div>
                    
                    {/* Enhanced indicator section */}
                    {currentWorkflow === id && (
                      <div className="relative text-right">
                        <div className="w-12 h-12 bg-white/20 backdrop-blur-sm rounded-2xl flex items-center justify-center border border-white/30 animate-pulse">
                          <span className="text-lg font-bold text-white drop-shadow-sm">
                            {subItems.indexOf(currentView) + 1}
                          </span>
                        </div>
                        <span className="text-xs text-white/80 mt-2 block font-medium">
                          {currentView.charAt(0).toUpperCase() + currentView.slice(1)}
                        </span>
                      </div>
                    )}
                    
                    {/* Arrow indicator for inactive states */}
                    {currentWorkflow !== id && (
                      <div className="w-8 h-8 rounded-full bg-slate-100/80 group-hover:bg-slate-200/80 flex items-center justify-center transition-all duration-300">
                        <svg className="w-4 h-4 text-slate-500 group-hover:text-slate-700 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                        </svg>
                      </div>
                    )}
                  </div>

                  {/* Subtle corner accents */}
                  <div className={`absolute top-3 right-3 w-2 h-2 rounded-full transition-all duration-300 ${
                    currentWorkflow === id 
                      ? 'bg-white/40' 
                      : 'bg-transparent group-hover:bg-slate-300/60'
                  }`}></div>
                  <div className={`absolute bottom-3 left-3 w-2 h-2 rounded-full transition-all duration-300 ${
                    currentWorkflow === id 
                      ? 'bg-white/30' 
                      : 'bg-transparent group-hover:bg-slate-300/40'
                  }`}></div>
                </div>
              </button>
            ))}
          </nav>
        </div>
      </div>
    </header>
  );
}

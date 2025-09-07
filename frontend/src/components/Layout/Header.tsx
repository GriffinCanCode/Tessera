import { Search, TrendingUp, Network, Sparkles, Zap, Brain, GraduationCap, Settings, Lightbulb, Upload } from 'lucide-react';

interface HeaderProps {
  currentView: string;
  onViewChange: (view: string) => void;
}

export function Header({ currentView, onViewChange }: HeaderProps) {
  const navItems = [
    { 
      id: 'dashboard', 
      label: 'Learning Dashboard', 
      icon: TrendingUp, 
      gradient: 'from-blue-500 to-purple-600',
      hoverColor: 'hover:text-blue-600'
    },
    { 
      id: 'brain', 
      label: 'Knowledge Brain', 
      icon: Brain, 
      gradient: 'from-pink-500 to-purple-600',
      hoverColor: 'hover:text-pink-600'
    },
    { 
      id: 'search', 
      label: 'Search Content', 
      icon: Search, 
      gradient: 'from-purple-500 to-pink-600',
      hoverColor: 'hover:text-purple-600'
    },
    { 
      id: 'assimilator', 
      label: 'Data Assimilator', 
      icon: Upload, 
      gradient: 'from-orange-500 to-red-600',
      hoverColor: 'hover:text-orange-600'
    },
    { 
      id: 'graph', 
      label: 'Learning Graph', 
      icon: Network, 
      gradient: 'from-teal-500 to-cyan-600',
      hoverColor: 'hover:text-teal-600'
    },
    { 
      id: 'insights', 
      label: 'Learning Insights', 
      icon: Lightbulb, 
      gradient: 'from-yellow-500 to-orange-600',
      hoverColor: 'hover:text-yellow-600'
    },
    { 
      id: 'notebook', 
      label: 'Learning Notebook', 
      icon: GraduationCap, 
      gradient: 'from-green-500 to-emerald-600',
      hoverColor: 'hover:text-green-600'
    },
  ];

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

          {/* Enhanced Desktop Navigation */}
          <nav className="hidden md:flex items-center space-x-2">
            {navItems.map(({ id, label, icon: Icon, gradient, hoverColor }) => (
              <button
                key={id}
                onClick={() => onViewChange(id)}
                className={`group relative px-6 py-3 rounded-xl font-medium transition-all duration-300 transform hover:scale-105 ${
                  currentView === id
                    ? 'text-white shadow-lg'
                    : `text-slate-600 ${hoverColor} hover:bg-white/80`
                }`}
              >
                {/* Active background */}
                {currentView === id && (
                  <div className={`absolute inset-0 bg-gradient-to-r ${gradient} rounded-xl shadow-lg pointer-events-none`}>
                    <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent rounded-xl pointer-events-none"></div>
                  </div>
                )}
                
                {/* Hover background */}
                {currentView !== id && (
                  <div className="absolute inset-0 bg-gradient-to-r from-slate-50 to-white rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 shadow-md pointer-events-none"></div>
                )}

                {/* Content */}
                <div className="relative flex items-center space-x-2">
                  <Icon className={`w-5 h-5 ${
                    currentView === id ? 'text-white' : 'text-slate-500 group-hover:text-slate-700'
                  } transition-colors duration-300`} />
                  <span className="relative z-10">{label}</span>
                </div>

                {/* Active indicator dot */}
                {currentView === id && (
                  <div className="absolute -bottom-1 left-1/2 transform -translate-x-1/2 w-1 h-1 bg-white rounded-full animate-pulse pointer-events-none"></div>
                )}
              </button>
            ))}
          </nav>

          {/* Enhanced Mobile Menu Button */}
          <div className="md:hidden">
            <button className="group relative p-3 rounded-xl bg-gradient-to-r from-slate-100 to-white border border-slate-200 shadow-md hover:shadow-lg transition-all duration-300 transform hover:scale-105">
              <Settings className="w-5 h-5 text-slate-600 group-hover:text-slate-800 transition-colors group-hover:rotate-90 duration-300" />
            </button>
          </div>
        </div>

        {/* Enhanced Mobile Navigation */}
        <div className="md:hidden mt-6 pb-4">
          <nav className="grid grid-cols-2 gap-3">
            {navItems.map(({ id, label, icon: Icon, gradient }) => (
              <button
                key={id}
                onClick={() => onViewChange(id)}
                className={`group relative p-4 rounded-xl border transition-all duration-300 transform hover:scale-[1.02] ${
                  currentView === id
                    ? 'border-transparent shadow-lg text-white'
                    : 'border-slate-200 bg-white/80 text-slate-600 hover:border-slate-300 hover:bg-white'
                }`}
              >
                {/* Active background for mobile */}
                {currentView === id && (
                  <div className={`absolute inset-0 bg-gradient-to-r ${gradient} rounded-xl pointer-events-none`}>
                    <div className="absolute inset-0 bg-gradient-to-br from-white/20 to-transparent rounded-xl pointer-events-none"></div>
                  </div>
                )}

                <div className="relative flex flex-col items-center space-y-2">
                  <Icon className={`w-6 h-6 ${
                    currentView === id ? 'text-white' : 'text-slate-500'
                  } transition-colors duration-300`} />
                  <span className="text-sm font-medium relative z-10">{label}</span>
                </div>
              </button>
            ))}
          </nav>
        </div>
      </div>
    </header>
  );
}

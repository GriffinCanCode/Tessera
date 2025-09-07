import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { 
  Brain, 
  Clock, 
  Target, 
  BookOpen, 
  Lightbulb,
  BarChart3,
  Calendar,
  Network,
  Zap,
  ArrowRight,
  Activity
} from 'lucide-react';
import WikiCrawlerAPI from '../../services/api';

interface PersonalInsightsProps {
  onViewChange?: (view: string) => void;
}

export function PersonalInsights({ onViewChange }: PersonalInsightsProps) {
  const [minRelevance, setMinRelevance] = useState(0.3);
  const [activeTab, setActiveTab] = useState<'overview' | 'timeline' | 'recommendations'>('overview');

  // Fetch insights data
  const { data: insightsData, isLoading: insightsLoading } = useQuery({
    queryKey: ['knowledge-insights', minRelevance],
    queryFn: () => WikiCrawlerAPI.getKnowledgeInsights(minRelevance),
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  // Fetch temporal analysis
  const { data: temporalData, isLoading: temporalLoading } = useQuery({
    queryKey: ['temporal-analysis', minRelevance],
    queryFn: () => WikiCrawlerAPI.getTemporalAnalysis(minRelevance),
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  const insights = insightsData?.data as any; // eslint-disable-line @typescript-eslint/no-explicit-any
  const temporal = temporalData?.data as any; // eslint-disable-line @typescript-eslint/no-explicit-any
  const isLoading = insightsLoading || temporalLoading;

  const personalMetrics = insights?.personal_metrics || { knowledge_breadth: 0, knowledge_depth: 0, learning_velocity: 0, knowledge_coherence: 0 };
  const currentState = insights?.current_state || { total_nodes: 0, total_edges: 0, density: 0, average_degree: 0 };
  const recommendations = insights?.recommendations || [];
  const learningPhases = temporal?.learning_phases?.phases || [];
  const growthAnalysis = temporal?.growth_analysis || { dates: [], articles_cumulative: [] };

  const tabs = [
    { id: 'overview', label: 'Overview', icon: Brain },
    { id: 'timeline', label: 'Learning Journey', icon: Calendar },
    { id: 'recommendations', label: 'Recommendations', icon: Lightbulb },
  ];

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center">
          <div className="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-slate-600 text-lg">Analyzing your knowledge universe...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-100">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-md border-b border-white/20 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center">
                <Brain className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold bg-gradient-to-r from-slate-900 to-slate-700 bg-clip-text text-transparent">
                  Personal Knowledge Insights
                </h1>
                <p className="text-slate-600 mt-1">Deep dive into your learning patterns and knowledge growth</p>
              </div>
            </div>
            
            <div className="flex items-center space-x-4">
              {/* Relevance Filter */}
              <div className="flex items-center space-x-2 bg-white/60 backdrop-blur-sm rounded-xl px-4 py-2 border border-white/30">
                <span className="text-sm font-medium text-slate-700">Quality Filter:</span>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.1"
                  value={minRelevance}
                  onChange={(e) => setMinRelevance(Number(e.target.value))}
                  className="w-20"
                />
                <span className="text-sm font-semibold text-purple-600">
                  {Math.round(minRelevance * 100)}%
                </span>
              </div>
            </div>
          </div>

          {/* Tab Navigation */}
          <div className="flex space-x-1 mt-6">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as 'overview' | 'timeline' | 'recommendations')}
                className={`flex items-center space-x-2 px-6 py-3 rounded-xl font-semibold transition-all duration-200 ${
                  activeTab === tab.id
                    ? 'bg-gradient-to-r from-purple-500 to-blue-600 text-white shadow-lg'
                    : 'bg-white/40 text-slate-700 hover:bg-white/60'
                }`}
              >
                <tab.icon className="w-4 h-4" />
                <span>{tab.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        {activeTab === 'overview' && (
          <OverviewTab
            personalMetrics={personalMetrics}
            currentState={currentState}
            growthAnalysis={growthAnalysis}
          />
        )}

        {activeTab === 'timeline' && (
          <TimelineTab
            learningPhases={learningPhases}
            temporal={temporal}
          />
        )}

        {activeTab === 'recommendations' && (
          <RecommendationsTab
            recommendations={recommendations}
            personalMetrics={personalMetrics}
            onViewChange={onViewChange}
          />
        )}
      </div>
    </div>
  );
}

// Overview Tab Component
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function OverviewTab({ personalMetrics, currentState, growthAnalysis }: { personalMetrics: any, currentState: any, growthAnalysis: any }) {
  const metrics = [
    {
      title: 'Knowledge Breadth',
      value: personalMetrics.knowledge_breadth || 0,
      description: 'Different topics explored',
      icon: Network,
      color: 'from-purple-500 to-purple-600',
      bgColor: 'from-purple-50 to-purple-100',
    },
    {
      title: 'Knowledge Depth',
      value: Number(personalMetrics.knowledge_depth || 0).toFixed(1),
      description: 'Average connections per topic',
      icon: Target,
      color: 'from-blue-500 to-blue-600',
      bgColor: 'from-blue-50 to-blue-100',
    },
    {
      title: 'Learning Velocity',
      value: Number(personalMetrics.learning_velocity || 0).toFixed(1),
      description: 'Articles per day recently',
      icon: Zap,
      color: 'from-orange-500 to-orange-600',
      bgColor: 'from-orange-50 to-orange-100',
    },
    {
      title: 'Knowledge Coherence',
      value: Number(personalMetrics.knowledge_coherence || 0).toFixed(3),
      description: 'How interconnected your knowledge is',
      icon: Activity,
      color: 'from-green-500 to-green-600',
      bgColor: 'from-green-50 to-green-100',
    },
  ];

  return (
    <div className="space-y-8">
      {/* Personal Metrics Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {metrics.map((metric, index) => (
          <div key={index} className="group">
            <div className={`h-full bg-gradient-to-br ${metric.bgColor} rounded-2xl p-6 border border-white/50 hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1`}>
              <div className="flex items-start justify-between mb-4">
                <div className={`w-12 h-12 bg-gradient-to-br ${metric.color} rounded-xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform duration-300`}>
                  <metric.icon className="w-6 h-6 text-white" />
                </div>
              </div>
              
              <div className="space-y-2">
                <div className={`text-3xl font-black bg-gradient-to-r ${metric.color} bg-clip-text text-transparent`}>
                  {metric.value}
                </div>
                <h3 className="font-bold text-slate-800">{metric.title}</h3>
                <p className="text-sm text-slate-600">{metric.description}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Growth Chart */}
      {growthAnalysis.dates && (
        <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
          <div className="flex items-center space-x-3 mb-6">
            <BarChart3 className="w-6 h-6 text-purple-600" />
            <h2 className="text-xl font-bold text-slate-800">Knowledge Growth Over Time</h2>
          </div>
          
          <GrowthChart growthData={growthAnalysis} />
        </div>
      )}

      {/* Current State Summary */}
      <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
        <h2 className="text-xl font-bold text-slate-800 mb-6">Current Knowledge State</h2>
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-2xl font-black text-purple-600">{currentState.total_nodes || 0}</div>
            <div className="text-sm text-slate-600">Articles</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-black text-blue-600">{currentState.total_edges || 0}</div>
            <div className="text-sm text-slate-600">Connections</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-black text-orange-600">
              {Number(currentState.density || 0).toFixed(3)}
            </div>
            <div className="text-sm text-slate-600">Density</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-black text-green-600">
              {Number(currentState.average_degree || 0).toFixed(1)}
            </div>
            <div className="text-sm text-slate-600">Avg Connections</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Timeline Tab Component
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function TimelineTab({ learningPhases, temporal }: { learningPhases: any, temporal: any }) {
  return (
    <div className="space-y-8">
      {/* Learning Phases */}
      <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
        <div className="flex items-center space-x-3 mb-6">
          <Clock className="w-6 h-6 text-blue-600" />
          <h2 className="text-xl font-bold text-slate-800">Learning Journey Phases</h2>
        </div>

        <div className="space-y-4">
          {learningPhases.map((phase: any, index: number) => ( // eslint-disable-line @typescript-eslint/no-explicit-any
            <div key={index} className="flex items-center space-x-4 p-4 bg-gradient-to-r from-slate-50 to-white rounded-xl border border-slate-200">
              <div className={`w-4 h-4 rounded-full ${
                phase.activity_level === 'high' ? 'bg-green-500' : 'bg-blue-500'
              }`}></div>
              
              <div className="flex-1">
                <div className="flex items-center space-x-2">
                  <h3 className="font-semibold text-slate-800">{phase.description}</h3>
                  <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                    phase.activity_level === 'high' 
                      ? 'bg-green-100 text-green-700' 
                      : 'bg-blue-100 text-blue-700'
                  }`}>
                    {phase.activity_level} activity
                  </span>
                </div>
                <p className="text-sm text-slate-600 mt-1">
                  {phase.start_date} to {phase.end_date}
                </p>
                {phase.avg_articles_per_week && (
                  <p className="text-xs text-slate-500 mt-1">
                    {phase.avg_articles_per_week} articles per week on average
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Discovery Timeline */}
      {temporal?.discovery_timeline && (
        <DiscoveryTimeline timeline={temporal.discovery_timeline} />
      )}
    </div>
  );
}

// Recommendations Tab Component
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function RecommendationsTab({ recommendations, personalMetrics, onViewChange }: { recommendations: any, personalMetrics: any, onViewChange: any }) {
  const handleRecommendationAction = (action: string) => {
    switch (action) {
      case 'start_new_crawl':
        onViewChange?.('crawl');
        break;
      case 'find_connections':
        onViewChange?.('graph');
        break;
      case 'explore_categories':
        onViewChange?.('search');
        break;
      default:
        break;
    }
  };

  return (
    <div className="space-y-8">
      {/* Active Recommendations */}
      <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
        <div className="flex items-center space-x-3 mb-6">
          <Lightbulb className="w-6 h-6 text-yellow-600" />
          <h2 className="text-xl font-bold text-slate-800">Personalized Recommendations</h2>
        </div>

        {recommendations.length === 0 ? (
          <div className="text-center py-8">
            <BookOpen className="w-16 h-16 text-slate-300 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-slate-600 mb-2">All caught up!</h3>
            <p className="text-slate-500">You're doing great! Keep exploring new topics.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {recommendations.map((rec: any, index: number) => ( // eslint-disable-line @typescript-eslint/no-explicit-any
              <div key={index} className="group p-6 bg-gradient-to-r from-white to-slate-50 rounded-xl border border-slate-200 hover:shadow-lg transition-all duration-200">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <span className={`px-3 py-1 text-xs font-semibold rounded-full ${
                        rec.type === 'motivation' ? 'bg-orange-100 text-orange-700' :
                        rec.type === 'structure' ? 'bg-blue-100 text-blue-700' :
                        'bg-purple-100 text-purple-700'
                      }`}>
                        {rec.type}
                      </span>
                    </div>
                    <h3 className="text-lg font-bold text-slate-800 mb-2">{rec.title}</h3>
                    <p className="text-slate-600 mb-4">{rec.message}</p>
                  </div>
                  
                  <button
                    onClick={() => handleRecommendationAction(rec.action)}
                    className="flex items-center space-x-2 px-4 py-2 bg-gradient-to-r from-purple-500 to-blue-600 text-white rounded-lg hover:shadow-lg transition-all duration-200 group-hover:scale-105"
                  >
                    <span className="text-sm font-medium">Take Action</span>
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Performance Insights */}
      <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
        <h2 className="text-xl font-bold text-slate-800 mb-6">Performance Insights</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-4">
            <h3 className="font-semibold text-slate-700">Strengths</h3>
            <div className="space-y-2">
              {personalMetrics.knowledge_breadth > 3 && (
                <div className="flex items-center space-x-2 text-green-600">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-sm">Good topic diversity</span>
                </div>
              )}
              {personalMetrics.learning_velocity > 1 && (
                <div className="flex items-center space-x-2 text-green-600">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-sm">Consistent learning pace</span>
                </div>
              )}
              {personalMetrics.knowledge_coherence > 0.1 && (
                <div className="flex items-center space-x-2 text-green-600">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-sm">Well-connected knowledge</span>
                </div>
              )}
            </div>
          </div>

          <div className="space-y-4">
            <h3 className="font-semibold text-slate-700">Growth Areas</h3>
            <div className="space-y-2">
              {personalMetrics.knowledge_breadth < 3 && (
                <div className="flex items-center space-x-2 text-orange-600">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span className="text-sm">Explore more diverse topics</span>
                </div>
              )}
              {personalMetrics.knowledge_coherence < 0.1 && (
                <div className="flex items-center space-x-2 text-orange-600">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span className="text-sm">Look for topic connections</span>
                </div>
              )}
              {personalMetrics.learning_velocity < 0.5 && (
                <div className="flex items-center space-x-2 text-orange-600">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span className="text-sm">Increase learning frequency</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Growth Chart Component (simplified version)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function GrowthChart({ growthData }: { growthData: any }) {
  if (!growthData.dates || !growthData.articles_cumulative) {
    return (
      <div className="h-64 flex items-center justify-center text-slate-500">
        <p>Not enough data to display growth chart</p>
      </div>
    );
  }

  const dates = growthData.dates.slice(-30); // Last 30 days
  const articles = growthData.articles_cumulative.slice(-30);
  const maxArticles = Math.max(...articles);

  return (
    <div className="h-64 flex items-end space-x-1">
      {articles.map((count: number, index: number) => (
        <div
          key={index}
          className="flex-1 bg-gradient-to-t from-purple-500 to-purple-400 rounded-t-sm"
          style={{
            height: `${(count / maxArticles) * 100}%`,
            minHeight: '4px'
          }}
          title={`${dates[index]}: ${count} articles`}
        />
      ))}
    </div>
  );
}

// Discovery Timeline Component
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function DiscoveryTimeline({ timeline }: { timeline: any }) {
  const milestones = timeline.discovery_milestones || [];

  return (
    <div className="bg-white/60 backdrop-blur-sm rounded-2xl p-6 border border-white/30">
      <div className="flex items-center space-x-3 mb-6">
        <Calendar className="w-6 h-6 text-purple-600" />
        <h2 className="text-xl font-bold text-slate-800">Discovery Milestones</h2>
      </div>

      <div className="space-y-4">
        {milestones.map((milestone: any, index: number) => ( // eslint-disable-line @typescript-eslint/no-explicit-any
          <div key={index} className="flex items-center space-x-4 p-4 bg-gradient-to-r from-slate-50 to-white rounded-xl border border-slate-200">
            <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
            <div className="flex-1">
              <h3 className="font-semibold text-slate-800 capitalize">{milestone.category}</h3>
              <p className="text-sm text-slate-600">
                First discovered: {milestone.first_discovery} • {milestone.article_count} articles
              </p>
              <p className="text-xs text-slate-500 mt-1">
                Started with: {milestone.representative_article}
              </p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

import React, { useState, useEffect } from 'react';
import { 
  BookOpen, 
  Video, 
  FileText, 
  GraduationCap, 
  TrendingUp, 
  Clock, 
  Target, 
  Plus,
  Brain,
  ChefHat,
  Code,
  Globe,
  BarChart3,
  Users,
  Star,
  Award,
  Sparkles,
  Zap,
  Send,
  X,
  Upload,
  Link,
  Type
} from 'lucide-react';

interface Subject {
  id: number;
  name: string;
  description: string;
  color: string;
  icon: string;
  progress: number;
  totalContent: number;
  completedContent: number;
  timeSpent: number; // in minutes
  recentActivity: boolean;
}

interface LearningContent {
  id: number;
  title: string;
  content_type: 'book' | 'video' | 'article' | 'course' | 'documentation';
  completion_percentage: number;
  difficulty_level: number;
  estimated_time_minutes: number;
  actual_time_minutes: number;
  rating?: number;
  subjects: string[];
}

interface LearningStats {
  totalContent: number;
  totalSubjects: number;
  totalTimeSpent: number;
  averageCompletion: number;
  weeklyProgress: number;
  longestStreak: number;
}

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  'code': Code,
  'chef-hat': ChefHat,
  'brain': Brain,
  'globe': Globe,
  'chart-bar': BarChart3,
  'user': Users,
};

export function LearningDashboard() {
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [recentContent, setRecentContent] = useState<LearningContent[]>([]);
  const [stats, setStats] = useState<LearningStats>({
    totalContent: 0,
    totalSubjects: 0,
    totalTimeSpent: 0,
    averageCompletion: 0,
    weeklyProgress: 0,
    longestStreak: 0
  });
  const [showAddContent, setShowAddContent] = useState(false);
  const [, setSelectedSubject] = useState<number | null>(null);
  const [newKnowledge, setNewKnowledge] = useState({
    content: '',
    source: 'manual' as 'manual' | 'url' | 'file',
    url: '',
    title: '',
    contentType: 'article' as 'book' | 'video' | 'article' | 'course' | 'documentation',
    estimatedTime: 30
  });
  const [isProcessing, setIsProcessing] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      // Load subjects with progress from API
      const analyticsResponse = await fetch('/api/learning/analytics');
      const analyticsData = await analyticsResponse.json();
      
      if (analyticsData.success && analyticsData.data) {
        const apiSubjects = analyticsData.data.subjects;
        
        // Transform API data to component format using weighted completion
        const subjectsData: Subject[] = apiSubjects.map((subject: {
          id: number;
          name: string;
          description: string;
          color: string;
          icon: string;
          weighted_completion?: number;
          avg_completion?: number;
          total_content?: number;
          completed_content?: number;
          total_time?: number;
          started_content?: number;
        }) => ({
          id: subject.id,
          name: subject.name,
          description: subject.description,
          color: subject.color,
          icon: subject.icon,
          progress: Math.round(subject.weighted_completion || subject.avg_completion || 0),
          totalContent: subject.total_content || 0,
          completedContent: subject.completed_content || 0,
          timeSpent: subject.total_time || 0,
          recentActivity: (subject.started_content || 0) > 0
        }));
        
        setSubjects(subjectsData);
        
        // Load recent learning content from API
        const contentResponse = await fetch('/api/learning/content?limit=10');
        const contentData = await contentResponse.json();
        
        let recentContentData: LearningContent[] = [];
        
        if (contentData.success && contentData.data && contentData.data.content) {
          recentContentData = contentData.data.content.map((content: {
            id: number;
            title: string;
            content_type: string;
            completion_percentage?: number;
            difficulty_level?: number;
            estimated_time_minutes?: number;
            actual_time_minutes?: number;
            rating?: number;
          }) => ({
            id: content.id,
            title: content.title,
            content_type: content.content_type,
            completion_percentage: content.completion_percentage || 0,
            difficulty_level: content.difficulty_level || 1,
            estimated_time_minutes: content.estimated_time_minutes || 0,
            actual_time_minutes: content.actual_time_minutes || 0,
            rating: content.rating,
            subjects: [] // We'd need to join with subjects table to get this
          }));
        }
        
        setRecentContent(recentContentData);
        
        // Calculate stats using weighted knowledge metrics
        const totalContent = recentContentData.length;
        const totalSubjects = subjectsData.length;
        const totalTimeSpent = analyticsData.data.brain_stats?.total_time_minutes || 0;
        
        // Use knowledge velocity instead of simple completion average
        const knowledgeVelocity = analyticsData.data.brain_stats?.knowledge_velocity || 0;
        const averageCompletion = knowledgeVelocity * 100; // Convert RKD to percentage for display
        
        setStats({
          totalContent,
          totalSubjects,
          totalTimeSpent,
          averageCompletion,
          weeklyProgress: analyticsData.data.brain_stats?.growth_rate || 0,
          longestStreak: 7 // This would need to be calculated from learning_progress table
        });
      } else {
        console.warn('Failed to load learning analytics:', analyticsData.error);
        // Fall back to empty state
        setSubjects([]);
        setRecentContent([]);
        setStats({
          totalContent: 0,
          totalSubjects: 0,
          totalTimeSpent: 0,
          averageCompletion: 0,
          weeklyProgress: 0,
          longestStreak: 0
        });
      }
      
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      // Fall back to empty state on error
      setSubjects([]);
      setRecentContent([]);
      setStats({
        totalContent: 0,
        totalSubjects: 0,
        totalTimeSpent: 0,
        averageCompletion: 0,
        weeklyProgress: 0,
        longestStreak: 0
      });
    }
  };

  // Intelligent knowledge processing
  const processKnowledge = async () => {
    if (!newKnowledge.content.trim() && !newKnowledge.url.trim()) {
      return;
    }

    setIsProcessing(true);
    
    try {
      let content = newKnowledge.content;
      let title = newKnowledge.title;

      // If URL is provided, fetch content
      if (newKnowledge.source === 'url' && newKnowledge.url.trim()) {
        try {
          const response = await fetch(newKnowledge.url);
          const html = await response.text();
          
          const parser = new DOMParser();
          const doc = parser.parseFromString(html, 'text/html');
          title = title || doc.querySelector('title')?.textContent || 'Untitled Content';
          content = doc.querySelector('body')?.textContent || 'No content extracted';
        } catch (error) {
          console.error('Failed to fetch URL content:', error);
          content = `URL: ${newKnowledge.url}\n\nFailed to fetch content automatically.`;
        }
      }

      // Analyze content to suggest categories
      const suggestedCategories = await analyzeContentForCategories(content, title);
      setSuggestions(suggestedCategories);

      // For demo, we'll just show the suggestions and let user confirm
      // In a real implementation, this would call the backend learning manager
      console.log('Processed knowledge:', {
        title,
        content: content.slice(0, 200) + '...',
        suggestedCategories,
        contentType: newKnowledge.contentType,
        estimatedTime: newKnowledge.estimatedTime
      });

    } catch (error) {
      console.error('Failed to process knowledge:', error);
    } finally {
      setIsProcessing(false);
    }
  };

  // Analyze content to suggest categories using simple heuristics
  const analyzeContentForCategories = async (content: string, title: string): Promise<string[]> => {
    const text = (content + ' ' + title).toLowerCase();
    const suggestions: string[] = [];

    // Programming keywords
    if (text.match(/\b(javascript|python|react|programming|code|function|algorithm|software|development|api|database|frontend|backend|web development)\b/)) {
      suggestions.push('Programming');
    }

    // Machine Learning keywords
    if (text.match(/\b(machine learning|artificial intelligence|neural network|deep learning|data science|model|training|tensorflow|pytorch|ai)\b/)) {
      suggestions.push('Machine Learning');
    }

    // Cooking keywords
    if (text.match(/\b(recipe|cooking|chef|ingredient|kitchen|food|cuisine|baking|culinary|dish|meal)\b/)) {
      suggestions.push('Cooking');
    }

    // Web Development keywords
    if (text.match(/\b(html|css|react|vue|angular|node|express|javascript|typescript|frontend|backend|api|rest|graphql)\b/)) {
      suggestions.push('Web Development');
    }

    // Data Science keywords
    if (text.match(/\b(data|analysis|statistics|visualization|pandas|numpy|sql|database|analytics|insights)\b/)) {
      suggestions.push('Data Science');
    }

    // If no matches, suggest based on content type
    if (suggestions.length === 0) {
      if (newKnowledge.contentType === 'course') {
        suggestions.push('Personal Development');
      } else {
        suggestions.push('General Knowledge');
      }
    }

    return suggestions.slice(0, 3); // Return top 3 suggestions
  };

  const addKnowledgeToSubject = async (subjectName: string) => {
    // In a real implementation, this would call the backend
    console.log('Adding knowledge to subject:', subjectName, newKnowledge);
    
    // Reset form
    setNewKnowledge({
      content: '',
      source: 'manual',
      url: '',
      title: '',
      contentType: 'article',
      estimatedTime: 30
    });
    setSuggestions([]);
    setShowAddContent(false);
    
    // Refresh dashboard data
    await loadDashboardData();
  };

  const getContentTypeIcon = (type: string) => {
    switch (type) {
      case 'book': return BookOpen;
      case 'video': return Video;
      case 'article': return FileText;
      case 'course': return GraduationCap;
      case 'documentation': return FileText;
      default: return FileText;
    }
  };

  const formatTime = (minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  };

  const getDifficultyColor = (level: number) => {
    switch (level) {
      case 1: return 'bg-green-100 text-green-800';
      case 2: return 'bg-yellow-100 text-yellow-800';
      case 3: return 'bg-orange-100 text-orange-800';
      case 4: return 'bg-red-100 text-red-800';
      case 5: return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getDifficultyLabel = (level: number) => {
    switch (level) {
      case 1: return 'Beginner';
      case 2: return 'Easy';
      case 3: return 'Medium';
      case 4: return 'Hard';
      case 5: return 'Expert';
      default: return 'Unknown';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Learning Dashboard</h1>
          <p className="text-gray-600">Track your learning journey across different subjects and content types</p>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center">
              <div className="p-2 bg-blue-100 rounded-lg">
                <BookOpen className="h-6 w-6 text-blue-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Total Content</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalContent}</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center">
              <div className="p-2 bg-green-100 rounded-lg">
                <Target className="h-6 w-6 text-green-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Knowledge Depth</p>
                <p className="text-2xl font-bold text-gray-900">{Math.round(stats.averageCompletion)}%</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center">
              <div className="p-2 bg-purple-100 rounded-lg">
                <Clock className="h-6 w-6 text-purple-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Time Invested</p>
                <p className="text-2xl font-bold text-gray-900">{formatTime(stats.totalTimeSpent)}</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center">
              <div className="p-2 bg-orange-100 rounded-lg">
                <Award className="h-6 w-6 text-orange-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Learning Streak</p>
                <p className="text-2xl font-bold text-gray-900">{stats.longestStreak} days</p>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Subjects Overview */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <div className="flex items-center justify-between">
                  <h2 className="text-lg font-semibold text-gray-900">Learning Subjects</h2>
                  <button
                    onClick={() => setShowAddContent(true)}
                    className="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                  >
                    <Plus className="h-4 w-4 mr-1" />
                    Add Content
                  </button>
                </div>
              </div>
              <div className="p-6">
                <div className="space-y-6">
                  {subjects.map((subject) => {
                    const IconComponent = iconMap[subject.icon] || BookOpen;
                    return (
                      <div 
                        key={subject.id}
                        className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow cursor-pointer"
                        onClick={() => setSelectedSubject(subject.id)}
                      >
                        <div className="flex items-start justify-between">
                          <div className="flex items-start space-x-3">
                            <div 
                              className="p-2 rounded-lg"
                              style={{ backgroundColor: `${subject.color}20`, color: subject.color }}
                            >
                              <IconComponent className="h-6 w-6" />
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center space-x-2">
                                <h3 className="text-lg font-medium text-gray-900">{subject.name}</h3>
                                {subject.recentActivity && (
                                  <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                    Active
                                  </span>
                                )}
                              </div>
                              <p className="text-sm text-gray-600 mt-1">{subject.description}</p>
                              <div className="flex items-center space-x-4 mt-2 text-sm text-gray-500">
                                <span>{subject.completedContent}/{subject.totalContent} completed</span>
                                <span>{formatTime(subject.timeSpent)} invested</span>
                              </div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-2xl font-bold text-gray-900">{subject.progress}%</div>
                            <div className="w-20 bg-gray-200 rounded-full h-2 mt-1">
                              <div
                                className="h-2 rounded-full"
                                style={{ 
                                  width: `${subject.progress}%`,
                                  backgroundColor: subject.color
                                }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>

          {/* Recent Content */}
          <div>
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h2 className="text-lg font-semibold text-gray-900">Recent Content</h2>
              </div>
              <div className="p-6">
                <div className="space-y-4">
                  {recentContent.map((content) => {
                    const IconComponent = getContentTypeIcon(content.content_type);
                    return (
                      <div key={content.id} className="border border-gray-200 rounded-lg p-4">
                        <div className="flex items-start space-x-3">
                          <div className="p-2 bg-gray-100 rounded-lg">
                            <IconComponent className="h-5 w-5 text-gray-600" />
                          </div>
                          <div className="flex-1 min-w-0">
                            <h4 className="text-sm font-medium text-gray-900 truncate">
                              {content.title}
                            </h4>
                            <div className="flex items-center space-x-2 mt-1">
                              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${getDifficultyColor(content.difficulty_level)}`}>
                                {getDifficultyLabel(content.difficulty_level)}
                              </span>
                              {content.rating && (
                                <div className="flex items-center">
                                  {[...Array(5)].map((_, i) => (
                                    <Star
                                      key={i}
                                      className={`h-3 w-3 ${
                                        i < content.rating! ? 'text-yellow-400 fill-current' : 'text-gray-300'
                                      }`}
                                    />
                                  ))}
                                </div>
                              )}
                            </div>
                            <div className="mt-2">
                              <div className="flex items-center justify-between text-xs text-gray-500 mb-1">
                                <span>{content.completion_percentage}% complete</span>
                                <span>{formatTime(content.actual_time_minutes)}/{formatTime(content.estimated_time_minutes)}</span>
                              </div>
                              <div className="w-full bg-gray-200 rounded-full h-1.5">
                                <div
                                  className="bg-blue-600 h-1.5 rounded-full"
                                  style={{ width: `${content.completion_percentage}%` }}
                                />
                              </div>
                            </div>
                            <div className="flex flex-wrap gap-1 mt-2">
                              {content.subjects.map((subject, index) => (
                                <span
                                  key={index}
                                  className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800"
                                >
                                  {subject}
                                </span>
                              ))}
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Weekly Progress Chart Placeholder */}
        <div className="mt-8 bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Weekly Progress</h2>
          </div>
          <div className="p-6">
            <div className="h-64 flex items-center justify-center bg-gray-50 rounded-lg">
              <div className="text-center">
                <TrendingUp className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500">Progress chart will be displayed here</p>
                <p className="text-sm text-gray-400">Connect R visualization scripts for detailed analytics</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Add Knowledge Modal */}
      {showAddContent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-900 flex items-center">
                  <Sparkles className="h-6 w-6 text-purple-600 mr-2" />
                  Add New Knowledge
                </h2>
                <button
                  onClick={() => setShowAddContent(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="h-6 w-6" />
                </button>
              </div>

              {/* Source Selection */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-3">
                  Knowledge Source
                </label>
                <div className="flex space-x-4">
                  <button
                    onClick={() => setNewKnowledge({...newKnowledge, source: 'manual'})}
                    className={`flex items-center px-4 py-2 rounded-lg border-2 transition-all ${
                      newKnowledge.source === 'manual'
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <Type className="h-4 w-4 mr-2" />
                    Manual Entry
                  </button>
                  <button
                    onClick={() => setNewKnowledge({...newKnowledge, source: 'url'})}
                    className={`flex items-center px-4 py-2 rounded-lg border-2 transition-all ${
                      newKnowledge.source === 'url'
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <Link className="h-4 w-4 mr-2" />
                    From URL
                  </button>
                  <button
                    onClick={() => setNewKnowledge({...newKnowledge, source: 'file'})}
                    className={`flex items-center px-4 py-2 rounded-lg border-2 transition-all ${
                      newKnowledge.source === 'file'
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <Upload className="h-4 w-4 mr-2" />
                    Upload File
                  </button>
                </div>
              </div>

              {/* Title Input */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Title
                </label>
                <input
                  type="text"
                  value={newKnowledge.title}
                  onChange={(e) => setNewKnowledge({...newKnowledge, title: e.target.value})}
                  placeholder="Enter a descriptive title..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              {/* URL Input (if URL source selected) */}
              {newKnowledge.source === 'url' && (
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    URL
                  </label>
                  <input
                    type="url"
                    value={newKnowledge.url}
                    onChange={(e) => setNewKnowledge({...newKnowledge, url: e.target.value})}
                    placeholder="https://example.com/article"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              )}

              {/* Content Input (if manual source) */}
              {newKnowledge.source === 'manual' && (
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Content
                  </label>
                  <textarea
                    value={newKnowledge.content}
                    onChange={(e) => setNewKnowledge({...newKnowledge, content: e.target.value})}
                    placeholder="Enter your knowledge content here..."
                    rows={6}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              )}

              {/* Content Type and Time */}
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Content Type
                  </label>
                  <select
                    value={newKnowledge.contentType}
                    onChange={(e) => setNewKnowledge({...newKnowledge, contentType: e.target.value as 'article' | 'book' | 'video' | 'podcast' | 'course' | 'other'})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="article">Article</option>
                    <option value="book">Book</option>
                    <option value="video">Video</option>
                    <option value="course">Course</option>
                    <option value="documentation">Documentation</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Estimated Time (minutes)
                  </label>
                  <input
                    type="number"
                    value={newKnowledge.estimatedTime}
                    onChange={(e) => setNewKnowledge({...newKnowledge, estimatedTime: parseInt(e.target.value) || 0})}
                    min="1"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* Process Button */}
              <div className="mb-6">
                <button
                  onClick={processKnowledge}
                  disabled={isProcessing || (!newKnowledge.content.trim() && !newKnowledge.url.trim())}
                  className="w-full flex items-center justify-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isProcessing ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent mr-2"></div>
                      Analyzing...
                    </>
                  ) : (
                    <>
                      <Zap className="h-4 w-4 mr-2" />
                      Analyze & Categorize
                    </>
                  )}
                </button>
              </div>

              {/* Suggestions */}
              {suggestions.length > 0 && (
                <div className="mb-6">
                  <h3 className="text-sm font-medium text-gray-700 mb-3 flex items-center">
                    <Brain className="h-4 w-4 mr-2 text-purple-600" />
                    Suggested Categories
                  </h3>
                  <div className="space-y-2">
                    {suggestions.map((suggestion, index) => (
                      <button
                        key={index}
                        onClick={() => addKnowledgeToSubject(suggestion)}
                        className="w-full flex items-center justify-between p-3 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition-all"
                      >
                        <div className="flex items-center">
                          <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center mr-3">
                            <Sparkles className="h-4 w-4 text-white" />
                          </div>
                          <div className="text-left">
                            <div className="font-medium text-gray-900">{suggestion}</div>
                            <div className="text-sm text-gray-500">AI suggested category</div>
                          </div>
                        </div>
                        <Send className="h-4 w-4 text-gray-400" />
                      </button>
                    ))}
                  </div>
                  
                  <div className="mt-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
                    <p className="text-sm text-amber-800">
                      💡 Our AI analyzed your content and suggests these categories based on keywords and context. 
                      Click on a category to add your knowledge there!
                    </p>
                  </div>
                </div>
              )}

              {/* Manual Category Selection */}
              <div>
                <h3 className="text-sm font-medium text-gray-700 mb-3">
                  Or Choose Existing Category
                </h3>
                <div className="grid grid-cols-2 gap-2">
                  {subjects.map((subject) => {
                    const IconComponent = iconMap[subject.icon] || BookOpen;
                    return (
                      <button
                        key={subject.id}
                        onClick={() => addKnowledgeToSubject(subject.name)}
                        className="flex items-center p-2 border border-gray-200 rounded-lg hover:border-gray-300 hover:bg-gray-50"
                      >
                        <div 
                          className="p-1 rounded mr-2"
                          style={{ backgroundColor: `${subject.color}20`, color: subject.color }}
                        >
                          <IconComponent className="h-4 w-4" />
                        </div>
                        <span className="text-sm font-medium text-gray-700">{subject.name}</span>
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

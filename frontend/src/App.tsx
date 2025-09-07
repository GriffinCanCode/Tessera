import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Layout } from './components/Layout/Layout';
import { LearningDashboard } from './components/LearningDashboard';
import { Brain } from './components/Brain';
import { Search } from './components/Search/Search';
import { Assimilator } from './components/Assimilator';
import { CrawlManagement } from './components/Crawl';
import { KnowledgeGraph } from './components/KnowledgeGraph';
import { PersonalInsights } from './components/PersonalInsights';
import { Notebook } from './components/Notebook';
import { useAppStore, type ViewType } from './stores';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: (failureCount: number, error: unknown) => {
        // Don't retry on 4xx errors
        if (error && typeof error === 'object' && 'response' in error) {
          const axiosError = error as { response?: { status?: number } };
          if (axiosError.response?.status && axiosError.response.status >= 400 && axiosError.response.status < 500) {
            return false;
          }
        }
        return failureCount < 2;
      },
    },
  },
});

function App() {
  const { currentView, setCurrentView } = useAppStore();

  const handleViewChange = (view: string) => {
    setCurrentView(view as ViewType);
  };

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return <LearningDashboard />;
      case 'brain':
        return <Brain />;
      case 'search':
        return <Search />;
      case 'assimilator':
        return <Assimilator />;
      case 'crawl':
        return <CrawlManagement />;
      case 'graph':
        return (
          <div className="container-page">
            <div className="space-y-6">
              <div className="text-center space-y-4">
                <h1 className="text-4xl font-bold text-gradient bg-gradient-to-r from-purple-600 via-blue-600 to-teal-600">
                  Learning Graph
                </h1>
                <p className="text-lg text-slate-600 max-w-2xl mx-auto">
                  Explore connections between your learning subjects with interactive graph visualization.
                  Discover patterns, relationships, and knowledge pathways across different topics.
                </p>
              </div>
              <KnowledgeGraph />
            </div>
          </div>
        );
      case 'insights':
        return <PersonalInsights onViewChange={handleViewChange} />;
      case 'notebook':
        return <Notebook />;
      default:
        return <LearningDashboard />;
    }
  };

  return (
    <QueryClientProvider client={queryClient}>
      <Layout currentView={currentView} onViewChange={handleViewChange}>
        {renderView()}
      </Layout>
    </QueryClientProvider>
  );
}

export default App;

import { useState } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Layout } from './components/Layout/Layout';
import { Dashboard } from './components/Dashboard/Dashboard';
import { Search } from './components/Search/Search';
import { KnowledgeGraph } from './components/KnowledgeGraph';
import { CrawlManagement } from './components/Crawl';
import { PersonalInsights } from './components/PersonalInsights';
import { Notebook } from './components/Notebook';

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
  const [currentView, setCurrentView] = useState('dashboard');

  const handleViewChange = (view: string) => {
    setCurrentView(view);
  };

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return <Dashboard onViewChange={handleViewChange} />;
      case 'search':
        return <Search />;
      case 'graph':
        return (
          <div className="container-page">
            <div className="space-y-6">
              <div className="text-center space-y-4">
                <h1 className="text-4xl font-bold text-gradient bg-gradient-to-r from-purple-600 via-blue-600 to-teal-600">
                  Knowledge Graph
                </h1>
                <p className="text-lg text-slate-600 max-w-2xl mx-auto">
                  Explore connections between Wikipedia articles with interactive graph visualization.
                  Discover patterns, relationships, and knowledge pathways.
                </p>
              </div>
              <KnowledgeGraph />
            </div>
          </div>
        );
      case 'crawl':
        return <CrawlManagement />;
      case 'insights':
        return <PersonalInsights onViewChange={handleViewChange} />;
      case 'notebook':
        return <Notebook />;
      default:
        return <Dashboard />;
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

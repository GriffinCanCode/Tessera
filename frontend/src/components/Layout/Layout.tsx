import React from 'react';
import { Header } from './Header';
import { SubNavigation } from './SubNavigation';
import { useAppStore, type ViewType } from '../../stores';

interface LayoutProps {
  children: React.ReactNode;
  currentView: string;
  onViewChange: (view: string) => void;
}

export function Layout({ children }: LayoutProps) {
  const { currentView, setCurrentView, sidebarCollapsed, globalLoading, loadingMessage } = useAppStore();

  const handleViewChange = (view: string) => {
    setCurrentView(view as ViewType);
  };

  return (
    <div className="layout-container">
      <Header currentView={currentView} onViewChange={handleViewChange} />
      <SubNavigation currentView={currentView} onViewChange={handleViewChange} />
      <main className={`main-content animate-fade-in ${sidebarCollapsed ? 'sidebar-collapsed' : ''}`}>
        {globalLoading && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 flex items-center space-x-4">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
              <span className="text-gray-700">{loadingMessage || 'Loading...'}</span>
            </div>
          </div>
        )}
        {children}
      </main>
    </div>
  );
}

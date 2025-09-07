import React from 'react';
import { Header } from './Header';

interface LayoutProps {
  children: React.ReactNode;
  currentView: string;
  onViewChange: (view: string) => void;
}

export function Layout({ children, currentView, onViewChange }: LayoutProps) {
  return (
    <div className="layout-container">
      <Header currentView={currentView} onViewChange={onViewChange} />
      <main className="main-content animate-fade-in">{children}</main>
    </div>
  );
}

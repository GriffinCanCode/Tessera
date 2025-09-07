import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

export type ViewType = 'dashboard' | 'brain' | 'search' | 'assimilator' | 'graph' | 'insights' | 'notebook';

interface AppState {
  // Navigation
  currentView: ViewType;
  previousView: ViewType | null;
  
  // UI State
  sidebarCollapsed: boolean;
  showSettings: boolean;
  showNotifications: boolean;
  
  // User Preferences
  theme: 'light' | 'dark' | 'auto';
  animationsEnabled: boolean;
  autoSave: boolean;
  
  // Loading States
  globalLoading: boolean;
  loadingMessage: string;
  
  // Actions
  setCurrentView: (view: ViewType) => void;
  toggleSidebar: () => void;
  setShowSettings: (show: boolean) => void;
  setShowNotifications: (show: boolean) => void;
  setTheme: (theme: 'light' | 'dark' | 'auto') => void;
  setAnimationsEnabled: (enabled: boolean) => void;
  setAutoSave: (enabled: boolean) => void;
  setGlobalLoading: (loading: boolean, message?: string) => void;
  goBack: () => void;
}

export const useAppStore = create<AppState>()(
  devtools(
    persist(
      (set, get) => ({
        // Initial state
        currentView: 'dashboard',
        previousView: null,
        sidebarCollapsed: false,
        showSettings: false,
        showNotifications: false,
        theme: 'auto',
        animationsEnabled: true,
        autoSave: true,
        globalLoading: false,
        loadingMessage: '',

        // Actions
        setCurrentView: (view) => set((state) => ({
          previousView: state.currentView,
          currentView: view,
        }), false, 'setCurrentView'),

        toggleSidebar: () => set((state) => ({
          sidebarCollapsed: !state.sidebarCollapsed,
        }), false, 'toggleSidebar'),

        setShowSettings: (show) => set({ showSettings: show }, false, 'setShowSettings'),
        
        setShowNotifications: (show) => set({ showNotifications: show }, false, 'setShowNotifications'),

        setTheme: (theme) => set({ theme }, false, 'setTheme'),

        setAnimationsEnabled: (enabled) => set({ animationsEnabled: enabled }, false, 'setAnimationsEnabled'),

        setAutoSave: (enabled) => set({ autoSave: enabled }, false, 'setAutoSave'),

        setGlobalLoading: (loading, message = '') => set({
          globalLoading: loading,
          loadingMessage: message,
        }, false, 'setGlobalLoading'),

        goBack: () => {
          const { previousView } = get();
          if (previousView) {
            set((state) => ({
              currentView: previousView,
              previousView: state.currentView,
            }), false, 'goBack');
          }
        },
      }),
      {
        name: 'tessera-app-store',
        partialize: (state) => ({
          theme: state.theme,
          animationsEnabled: state.animationsEnabled,
          autoSave: state.autoSave,
          sidebarCollapsed: state.sidebarCollapsed,
        }),
      }
    ),
    { name: 'AppStore' }
  )
);

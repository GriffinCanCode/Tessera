import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

export interface BotMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  isLoading?: boolean;
  error?: string;
  metadata?: {
    model?: string;
    temperature?: number;
    includeInsights?: boolean;
  };
}

export interface ConversationInfo {
  id: string;
  conversation_id: string; // For API compatibility
  title: string;
  created_at: string;
  updated_at: string;
  last_activity: string; // For API compatibility
  message_count: number;
}

interface NotebookState {
  // Current conversation
  currentConversation: string;
  messages: BotMessage[];
  inputMessage: string;
  
  // Conversations list
  conversations: ConversationInfo[];
  
  // UI State
  isLoading: boolean;
  showSettings: boolean;
  showQuickScrape: boolean;
  
  // Settings
  selectedMode: 'chat' | 'knowledge';
  temperature: number;
  includeInsights: boolean;
  
  // Quick scrape
  scrapeUrl: string;
  
  // Project context
  currentProjectId: number | null;
  
  // Actions
  setCurrentConversation: (id: string) => void;
  setMessages: (messages: BotMessage[]) => void;
  addMessage: (message: BotMessage) => void;
  updateMessage: (id: string, updates: Partial<BotMessage>) => void;
  setInputMessage: (message: string) => void;
  setConversations: (conversations: ConversationInfo[]) => void;
  setIsLoading: (loading: boolean) => void;
  setShowSettings: (show: boolean) => void;
  setShowQuickScrape: (show: boolean) => void;
  setSelectedMode: (mode: 'chat' | 'knowledge') => void;
  setTemperature: (temp: number) => void;
  setIncludeInsights: (include: boolean) => void;
  setScrapeUrl: (url: string) => void;
  setCurrentProjectId: (id: number | null) => void;
  clearCurrentConversation: () => void;
  resetNotebook: () => void;
}

export const useNotebookStore = create<NotebookState>()(
  devtools(
    (set) => ({
      // Initial state
      currentConversation: '',
      messages: [],
      inputMessage: '',
      conversations: [],
      isLoading: false,
      showSettings: false,
      showQuickScrape: false,
      selectedMode: 'chat',
      temperature: 0.7,
      includeInsights: true,
      scrapeUrl: '',
      currentProjectId: null,

      // Actions
      setCurrentConversation: (id) => set({ currentConversation: id }, false, 'setCurrentConversation'),
      
      setMessages: (messages) => set({ messages }, false, 'setMessages'),
      
      addMessage: (message) => set((state) => ({
        messages: [...state.messages, message],
      }), false, 'addMessage'),
      
      updateMessage: (id, updates) => set((state) => ({
        messages: state.messages.map(msg => 
          msg.id === id ? { ...msg, ...updates } : msg
        ),
      }), false, 'updateMessage'),
      
      setInputMessage: (message) => set({ inputMessage: message }, false, 'setInputMessage'),
      
      setConversations: (conversations) => set({ conversations }, false, 'setConversations'),
      
      setIsLoading: (loading) => set({ isLoading: loading }, false, 'setIsLoading'),
      
      setShowSettings: (show) => set({ showSettings: show }, false, 'setShowSettings'),
      
      setShowQuickScrape: (show) => set({ showQuickScrape: show }, false, 'setShowQuickScrape'),
      
      setSelectedMode: (mode) => set({ selectedMode: mode }, false, 'setSelectedMode'),
      
      setTemperature: (temp) => set({ temperature: temp }, false, 'setTemperature'),
      
      setIncludeInsights: (include) => set({ includeInsights: include }, false, 'setIncludeInsights'),
      
      setScrapeUrl: (url) => set({ scrapeUrl: url }, false, 'setScrapeUrl'),
      
      setCurrentProjectId: (id) => set({ currentProjectId: id }, false, 'setCurrentProjectId'),
      
      clearCurrentConversation: () => set({
        currentConversation: '',
        messages: [],
        inputMessage: '',
      }, false, 'clearCurrentConversation'),
      
      resetNotebook: () => set({
        currentConversation: '',
        messages: [],
        inputMessage: '',
        conversations: [],
        isLoading: false,
        showSettings: false,
        showQuickScrape: false,
        scrapeUrl: '',
        currentProjectId: null,
      }, false, 'resetNotebook'),
    }),
    { name: 'NotebookStore' }
  )
);

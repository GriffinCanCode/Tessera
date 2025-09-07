import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

export interface KnowledgeArea {
  id: string;
  name: string;
  percentage: number;
  color: string;
  timeSpent: number;
  totalContent: number;
  completedContent: number;
  region: 'frontal' | 'parietal' | 'temporal' | 'occipital' | 'cerebellum' | 'brainstem' | 'limbic';
  position3D: { x: number; y: number; z: number };
  scale: number;
  connections: string[];
}

export interface BrainStats {
  totalKnowledgePoints: number;
  dominantArea: string;
  balanceScore: number;
  growthRate: number;
}

interface BrainState {
  // Data
  knowledgeAreas: KnowledgeArea[];
  brainStats: BrainStats;
  
  // UI State
  selectedArea: KnowledgeArea | null;
  hoveredArea: KnowledgeArea | null;
  viewMode: '3d' | 'classic';
  animationSpeed: number;
  contextLost: boolean;
  isLoading: boolean;
  
  // Actions
  setKnowledgeAreas: (areas: KnowledgeArea[]) => void;
  setBrainStats: (stats: BrainStats) => void;
  setSelectedArea: (area: KnowledgeArea | null) => void;
  setHoveredArea: (area: KnowledgeArea | null) => void;
  setViewMode: (mode: '3d' | 'classic') => void;
  setAnimationSpeed: (speed: number) => void;
  setContextLost: (lost: boolean) => void;
  setIsLoading: (loading: boolean) => void;
  resetBrainState: () => void;
}

const initialBrainStats: BrainStats = {
  totalKnowledgePoints: 0,
  dominantArea: '',
  balanceScore: 0,
  growthRate: 0,
};

export const useBrainStore = create<BrainState>()(
  devtools(
    (set) => ({
      // Initial state
      knowledgeAreas: [],
      brainStats: initialBrainStats,
      selectedArea: null,
      hoveredArea: null,
      viewMode: '3d',
      animationSpeed: 1.0,
      contextLost: false,
      isLoading: true,

      // Actions
      setKnowledgeAreas: (areas) => set({ knowledgeAreas: areas }, false, 'setKnowledgeAreas'),
      
      setBrainStats: (stats) => set({ brainStats: stats }, false, 'setBrainStats'),
      
      setSelectedArea: (area) => set({ selectedArea: area }, false, 'setSelectedArea'),
      
      setHoveredArea: (area) => set({ hoveredArea: area }, false, 'setHoveredArea'),
      
      setViewMode: (mode) => set({ 
        viewMode: mode,
        contextLost: false, // Reset context lost when changing modes
      }, false, 'setViewMode'),
      
      setAnimationSpeed: (speed) => set({ animationSpeed: speed }, false, 'setAnimationSpeed'),
      
      setContextLost: (lost) => set({ contextLost: lost }, false, 'setContextLost'),
      
      setIsLoading: (loading) => set({ isLoading: loading }, false, 'setIsLoading'),
      
      resetBrainState: () => set({
        knowledgeAreas: [],
        brainStats: initialBrainStats,
        selectedArea: null,
        hoveredArea: null,
        isLoading: true,
      }, false, 'resetBrainState'),
    }),
    { name: 'BrainStore' }
  )
);

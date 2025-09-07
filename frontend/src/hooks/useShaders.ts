// Shader Hooks for React Three Fiber Integration
// Custom hooks for managing GLSL shaders in brain visualization
// Author: Tessera Brain Visualization System

import { useRef, useEffect, useMemo, useCallback } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import {
  createBrainShaderMaterial,
  createNeuralConnectionMaterial,
  createKnowledgeFlowMaterial,
  createEnhancedLightingMaterial,
  ShaderManager,
  type BrainShaderUniforms,
  type NeuralConnectionUniforms,
  type KnowledgeFlowUniforms,
  type EnhancedLightingUniforms
} from '../shaders/utils/shaderLoader';

// Optimized brain shader hook with performance awareness
export function useBrainShader(
  config: {
    brainColor?: THREE.Color;
    brainActivity?: number;
    knowledgeIntensity?: number;
    activityCenter?: THREE.Vector3;
    showNeuralActivity?: boolean;
    deformationStrength?: number;
    selectedRegionColor?: THREE.Color;
    selectedRegionIntensity?: number;
    selectedRegionCenter?: THREE.Vector3;
    selectedRegionRadius?: number;
    performanceLevel?: 'low' | 'medium' | 'high';
  } = {}
) {
  const materialRef = useRef<THREE.ShaderMaterial | undefined>(undefined);
  const materialId = useRef(`brain-${Math.random()}`);
  const lastConfigRef = useRef<string>('');

  // Memoize configuration to avoid unnecessary recreations
  const memoizedConfig = useMemo(() => {
    const configString = JSON.stringify({
      showNeuralActivity: config.showNeuralActivity !== false,
      performanceLevel: config.performanceLevel || 'high',
      // Only include values that affect material creation
      brainActivity: Math.round((config.brainActivity || 0.5) * 10) / 10,
      knowledgeIntensity: Math.round((config.knowledgeIntensity || 0.5) * 10) / 10
    });
    
    // Only update if configuration actually changed
    if (configString === lastConfigRef.current) {
      return null;
    }
    
    lastConfigRef.current = configString;
    return config;
  }, [
    config.showNeuralActivity,
    config.performanceLevel,
    Math.round((config.brainActivity || 0.5) * 10),
    Math.round((config.knowledgeIntensity || 0.5) * 10)
  ]);

  const material = useMemo(() => {
    if (!memoizedConfig) return materialRef.current;
    
    const shaderManager = ShaderManager.getInstance();
    
    // Performance-based shader configuration
    const performanceLevel = config.performanceLevel || 'high';
    const showNeuralActivity = performanceLevel !== 'low' && (config.showNeuralActivity !== false);
    
    const uniforms: Partial<BrainShaderUniforms> = {
      brainColor: { value: config.brainColor || new THREE.Color(0xf0e8e0) },
      brainActivity: { value: config.brainActivity || 0.5 },
      knowledgeIntensity: { value: config.knowledgeIntensity || 0.5 },
      activityCenter: { value: config.activityCenter || new THREE.Vector3(0, 0, 0) },
      showNeuralActivity: { value: showNeuralActivity },
      deformationStrength: { value: config.deformationStrength || 1.0 },
      selectedRegionColor: { value: config.selectedRegionColor || new THREE.Color(0xff6b35) },
      selectedRegionIntensity: { value: config.selectedRegionIntensity || 0.0 },
      selectedRegionCenter: { value: config.selectedRegionCenter || new THREE.Vector3(0, 0, 0) },
      selectedRegionRadius: { value: config.selectedRegionRadius || 0.0 }
    };

    // Dispose old material if it exists
    if (materialRef.current) {
      shaderManager.unregisterMaterial(materialId.current);
      materialRef.current.dispose();
    }

    const mat = createBrainShaderMaterial(uniforms);
    materialRef.current = mat;
    shaderManager.registerMaterial(materialId.current, mat);
    return mat;
  }, [memoizedConfig]);

  // Note: Camera position is automatically updated by THREE.js

  // Throttled configuration updates for performance
  const updateConfig = useCallback(() => {
    const shaderManager = ShaderManager.getInstance();
    if (materialRef.current) {
      const updates: Record<string, unknown> = {};
      
      // Only update uniforms that actually changed
      if (config.brainColor) updates.brainColor = config.brainColor;
      if (config.brainActivity !== undefined) updates.brainActivity = config.brainActivity;
      if (config.knowledgeIntensity !== undefined) updates.knowledgeIntensity = config.knowledgeIntensity;
      if (config.activityCenter) updates.activityCenter = config.activityCenter;
      if (config.selectedRegionColor) updates.selectedRegionColor = config.selectedRegionColor;
      if (config.selectedRegionIntensity !== undefined) updates.selectedRegionIntensity = config.selectedRegionIntensity;
      if (config.selectedRegionCenter) updates.selectedRegionCenter = config.selectedRegionCenter;
      if (config.selectedRegionRadius !== undefined) updates.selectedRegionRadius = config.selectedRegionRadius;
      
      // Batch updates for better performance
      if (Object.keys(updates).length > 0) {
        shaderManager.updateUniforms(materialId.current, updates);
      }
    }
  }, [
    config.brainColor,
    config.brainActivity,
    config.knowledgeIntensity,
    config.activityCenter,
    config.selectedRegionColor,
    config.selectedRegionIntensity,
    config.selectedRegionCenter,
    config.selectedRegionRadius
  ]);

  // Throttle updates to avoid excessive re-renders
  const throttledUpdateConfig = useRef<NodeJS.Timeout | null>(null);
  
  useEffect(() => {
    if (throttledUpdateConfig.current) {
      clearTimeout(throttledUpdateConfig.current);
    }
    
    throttledUpdateConfig.current = setTimeout(() => {
      updateConfig();
    }, 16); // ~60 FPS throttling
    
    return () => {
      if (throttledUpdateConfig.current) {
        clearTimeout(throttledUpdateConfig.current);
      }
    };
  }, [updateConfig]);

  // Cleanup
  useEffect(() => {
    const currentMaterialId = materialId.current;
    return () => {
      const shaderManager = ShaderManager.getInstance();
      shaderManager.unregisterMaterial(currentMaterialId);
    };
  }, []);

  return material;
}

// Optimized neural connection shader hook
export function useNeuralConnectionShader(
  config: {
    startPoint?: THREE.Vector3;
    endPoint?: THREE.Vector3;
    connectionActivity?: number;
    signalStrength?: number;
    pulseSpeed?: number;
    showElectricalActivity?: boolean;
    connectionRadius?: number;
    performanceLevel?: 'low' | 'medium' | 'high';
  } = {}
) {
  const materialRef = useRef<THREE.ShaderMaterial | undefined>(undefined);
  const materialId = useRef(`connection-${Math.random()}`);
  const lastConfigRef = useRef<string>('');

  // Memoize configuration for performance
  const memoizedConfig = useMemo(() => {
    const configString = JSON.stringify({
      showElectricalActivity: config.showElectricalActivity !== false,
      performanceLevel: config.performanceLevel || 'high',
      connectionRadius: Math.round((config.connectionRadius || 0.02) * 1000) / 1000,
      connectionActivity: Math.round((config.connectionActivity || 0.7) * 10) / 10
    });
    
    if (configString === lastConfigRef.current) {
      return null;
    }
    
    lastConfigRef.current = configString;
    return config;
  }, [
    config.showElectricalActivity,
    config.performanceLevel,
    Math.round((config.connectionRadius || 0.02) * 1000),
    Math.round((config.connectionActivity || 0.7) * 10)
  ]);

  const material = useMemo(() => {
    if (!memoizedConfig) return materialRef.current;
    
    const shaderManager = ShaderManager.getInstance();
    
    // Performance-based configuration
    const performanceLevel = config.performanceLevel || 'high';
    const showElectricalActivity = performanceLevel === 'high' && (config.showElectricalActivity !== false);
    const connectionRadius = performanceLevel === 'low' ? 
      (config.connectionRadius || 0.02) * 0.8 : 
      (config.connectionRadius || 0.02);
    
    const uniforms: Partial<NeuralConnectionUniforms> = {
      startPoint: { value: config.startPoint || new THREE.Vector3(-1, 0, 0) },
      endPoint: { value: config.endPoint || new THREE.Vector3(1, 0, 0) },
      connectionActivity: { value: config.connectionActivity || 0.7 },
      signalStrength: { value: config.signalStrength || 1.0 },
      pulseSpeed: { value: config.pulseSpeed || 2.0 },
      showElectricalActivity: { value: showElectricalActivity },
      connectionRadius: { value: connectionRadius }
    };

    // Dispose old material
    if (materialRef.current) {
      shaderManager.unregisterMaterial(materialId.current);
      materialRef.current.dispose();
    }

    const mat = createNeuralConnectionMaterial(uniforms);
    materialRef.current = mat;
    shaderManager.registerMaterial(materialId.current, mat);
    return mat;
  }, [memoizedConfig]);

  // Note: Camera position is automatically updated by THREE.js

  // Update configuration
  const updateConfig = useCallback(() => {
    const shaderManager = ShaderManager.getInstance();
    if (materialRef.current) {
      const updates: Record<string, unknown> = {};
      
      if (config.startPoint) updates.startPoint = config.startPoint;
      if (config.endPoint) updates.endPoint = config.endPoint;
      if (config.connectionActivity !== undefined) updates.connectionActivity = config.connectionActivity;
      if (config.signalStrength !== undefined) updates.signalStrength = config.signalStrength;
      if (config.pulseSpeed !== undefined) updates.pulseSpeed = config.pulseSpeed;
      if (config.showElectricalActivity !== undefined) updates.showElectricalActivity = config.showElectricalActivity;
      if (config.connectionRadius !== undefined) updates.connectionRadius = config.connectionRadius;
      
      shaderManager.updateUniforms(materialId.current, updates);
    }
  }, [config]);

  useEffect(() => {
    updateConfig();
  }, [updateConfig]);

  // Cleanup
  useEffect(() => {
    const currentMaterialId = materialId.current;
    return () => {
      const shaderManager = ShaderManager.getInstance();
      shaderManager.unregisterMaterial(currentMaterialId);
    };
  }, []);

  return material;
}

// Hook for knowledge flow shader material
export function useKnowledgeFlowShader(
  config: {
    sourceRegion?: THREE.Vector3;
    targetRegion?: THREE.Vector3;
    knowledgeActivity?: number;
    flowSpeed?: number;
    informationDensity?: number;
    learningRate?: number;
    showLearningProcess?: boolean;
    showMemoryConsolidation?: boolean;
  } = {}
) {
  // Note: Camera position is automatically handled by THREE.js
  const materialRef = useRef<THREE.ShaderMaterial | undefined>(undefined);
  const materialId = useRef(`knowledge-${Math.random()}`);

  const material = useMemo(() => {
    const shaderManager = ShaderManager.getInstance();
    const uniforms: Partial<KnowledgeFlowUniforms> = {
      sourceRegion: { value: config.sourceRegion || new THREE.Vector3(-2, 0, 0) },
      targetRegion: { value: config.targetRegion || new THREE.Vector3(2, 0, 0) },
      knowledgeActivity: { value: config.knowledgeActivity || 0.6 },
      flowSpeed: { value: config.flowSpeed || 1.5 },
      informationDensity: { value: config.informationDensity || 0.7 },
      learningRate: { value: config.learningRate || 1.0 },
      showLearningProcess: { value: config.showLearningProcess !== false },
      showMemoryConsolidation: { value: config.showMemoryConsolidation !== false }
    };

    const mat = createKnowledgeFlowMaterial(uniforms);
    materialRef.current = mat;
    shaderManager.registerMaterial(materialId.current, mat);
    return mat;
  }, [
    config.sourceRegion,
    config.targetRegion,
    config.knowledgeActivity,
    config.flowSpeed,
    config.informationDensity,
    config.learningRate,
    config.showLearningProcess,
    config.showMemoryConsolidation
  ]);

  // Note: Camera position is automatically updated by THREE.js

  // Update configuration
  const updateConfig = useCallback(() => {
    const shaderManager = ShaderManager.getInstance();
    if (materialRef.current) {
      const updates: Record<string, unknown> = {};
      
      if (config.sourceRegion) updates.sourceRegion = config.sourceRegion;
      if (config.targetRegion) updates.targetRegion = config.targetRegion;
      if (config.knowledgeActivity !== undefined) updates.knowledgeActivity = config.knowledgeActivity;
      if (config.flowSpeed !== undefined) updates.flowSpeed = config.flowSpeed;
      if (config.informationDensity !== undefined) updates.informationDensity = config.informationDensity;
      if (config.learningRate !== undefined) updates.learningRate = config.learningRate;
      if (config.showLearningProcess !== undefined) updates.showLearningProcess = config.showLearningProcess;
      if (config.showMemoryConsolidation !== undefined) updates.showMemoryConsolidation = config.showMemoryConsolidation;
      
      shaderManager.updateUniforms(materialId.current, updates);
    }
  }, [config]);

  useEffect(() => {
    updateConfig();
  }, [updateConfig]);

  // Cleanup
  useEffect(() => {
    const currentMaterialId = materialId.current;
    return () => {
      const shaderManager = ShaderManager.getInstance();
      shaderManager.unregisterMaterial(currentMaterialId);
    };
  }, []);

  return material;
}

// Hook for managing lighting uniforms across all shaders
export function useShaderLighting() {
  const updateLighting = useCallback((lightingConfig: {
    ambientColor?: THREE.Color;
    directionalColor?: THREE.Color;
    directionalDirection?: THREE.Vector3;
    pointColor?: THREE.Color;
    pointPosition?: THREE.Vector3;
    pointDistance?: number;
  }) => {
    // Update lighting for all registered materials
    // This is a simplified approach - in practice, you'd want to track which materials need which lighting
    const updates: Record<string, unknown> = {};
    
    if (lightingConfig.ambientColor) updates.ambientLightColor = lightingConfig.ambientColor;
    if (lightingConfig.directionalColor) updates.directionalLightColor = lightingConfig.directionalColor;
    if (lightingConfig.directionalDirection) updates.directionalLightDirection = lightingConfig.directionalDirection;
    if (lightingConfig.pointColor) updates.pointLightColor = lightingConfig.pointColor;
    if (lightingConfig.pointPosition) updates.pointLightPosition = lightingConfig.pointPosition;
    if (lightingConfig.pointDistance !== undefined) updates.pointLightDistance = lightingConfig.pointDistance;
    
    // Note: This would update all materials - in practice, you'd want more granular control
    console.log('Lighting updates would be applied to all materials:', updates);
  }, []);

  return { updateLighting };
}

// Hook for enhanced lighting shader material
export function useEnhancedLighting(
  config: {
    lightPosition?: THREE.Vector3;
    lightDirection?: THREE.Vector3;
    lightColor?: THREE.Color;
    lightIntensity?: number;
    ambientColor?: THREE.Color;
    ambientIntensity?: number;
    baseColor?: THREE.Color;
    metallic?: number;
    roughness?: number;
    opacity?: number;
    subsurfaceStrength?: number;
    shadowStrength?: number;
    atmosphericDensity?: number;
    atmosphericColor?: THREE.Color;
    rimLightColor?: THREE.Color;
    rimLightPower?: number;
    fresnelStrength?: number;
    enableVolumetricLighting?: boolean;
    enableSubsurfaceScattering?: boolean;
    enableAtmosphericScattering?: boolean;
  } = {}
) {
  const materialRef = useRef<THREE.ShaderMaterial | undefined>(undefined);
  const materialId = useRef(`enhanced-lighting-${Math.random()}`);

  const material = useMemo(() => {
    const shaderManager = ShaderManager.getInstance();
    const uniforms: Partial<EnhancedLightingUniforms> = {
      lightPosition: { value: config.lightPosition || new THREE.Vector3(10, 10, 10) },
      lightDirection: { value: config.lightDirection || new THREE.Vector3(-1, -1, -1) },
      lightColor: { value: config.lightColor || new THREE.Color(0xffffff) },
      lightIntensity: { value: config.lightIntensity || 1.0 },
      ambientColor: { value: config.ambientColor || new THREE.Color(0x404040) },
      ambientIntensity: { value: config.ambientIntensity || 0.3 },
      baseColor: { value: config.baseColor || new THREE.Color(0xf0e8e0) },
      metallic: { value: config.metallic || 0.1 },
      roughness: { value: config.roughness || 0.7 },
      opacity: { value: config.opacity || 1.0 },
      subsurfaceStrength: { value: config.subsurfaceStrength || 0.6 },
      shadowStrength: { value: config.shadowStrength || 0.5 },
      atmosphericDensity: { value: config.atmosphericDensity || 0.1 },
      atmosphericColor: { value: config.atmosphericColor || new THREE.Color(0x87ceeb) },
      rimLightColor: { value: config.rimLightColor || new THREE.Color(0x4ecdc4) },
      rimLightPower: { value: config.rimLightPower || 2.0 },
      fresnelStrength: { value: config.fresnelStrength || 1.0 },
      enableVolumetricLighting: { value: config.enableVolumetricLighting !== false },
      enableSubsurfaceScattering: { value: config.enableSubsurfaceScattering !== false },
      enableAtmosphericScattering: { value: config.enableAtmosphericScattering !== false }
    };

    const mat = createEnhancedLightingMaterial(uniforms);
    materialRef.current = mat;
    shaderManager.registerMaterial(materialId.current, mat);
    return mat;
  }, [
    config.lightPosition,
    config.lightDirection,
    config.lightColor,
    config.lightIntensity,
    config.ambientColor,
    config.ambientIntensity,
    config.baseColor,
    config.metallic,
    config.roughness,
    config.opacity,
    config.subsurfaceStrength,
    config.shadowStrength,
    config.atmosphericDensity,
    config.atmosphericColor,
    config.rimLightColor,
    config.rimLightPower,
    config.fresnelStrength,
    config.enableVolumetricLighting,
    config.enableSubsurfaceScattering,
    config.enableAtmosphericScattering
  ]);

  // Update configuration
  const updateConfig = useCallback(() => {
    const shaderManager = ShaderManager.getInstance();
    if (materialRef.current) {
      const updates: Record<string, unknown> = {};
      
      if (config.lightPosition) updates.lightPosition = config.lightPosition;
      if (config.lightDirection) updates.lightDirection = config.lightDirection;
      if (config.lightColor) updates.lightColor = config.lightColor;
      if (config.lightIntensity !== undefined) updates.lightIntensity = config.lightIntensity;
      if (config.ambientColor) updates.ambientColor = config.ambientColor;
      if (config.ambientIntensity !== undefined) updates.ambientIntensity = config.ambientIntensity;
      if (config.baseColor) updates.baseColor = config.baseColor;
      if (config.metallic !== undefined) updates.metallic = config.metallic;
      if (config.roughness !== undefined) updates.roughness = config.roughness;
      if (config.opacity !== undefined) updates.opacity = config.opacity;
      if (config.subsurfaceStrength !== undefined) updates.subsurfaceStrength = config.subsurfaceStrength;
      if (config.shadowStrength !== undefined) updates.shadowStrength = config.shadowStrength;
      if (config.atmosphericDensity !== undefined) updates.atmosphericDensity = config.atmosphericDensity;
      if (config.atmosphericColor) updates.atmosphericColor = config.atmosphericColor;
      if (config.rimLightColor) updates.rimLightColor = config.rimLightColor;
      if (config.rimLightPower !== undefined) updates.rimLightPower = config.rimLightPower;
      if (config.fresnelStrength !== undefined) updates.fresnelStrength = config.fresnelStrength;
      if (config.enableVolumetricLighting !== undefined) updates.enableVolumetricLighting = config.enableVolumetricLighting;
      if (config.enableSubsurfaceScattering !== undefined) updates.enableSubsurfaceScattering = config.enableSubsurfaceScattering;
      if (config.enableAtmosphericScattering !== undefined) updates.enableAtmosphericScattering = config.enableAtmosphericScattering;
      
      shaderManager.updateUniforms(materialId.current, updates);
    }
  }, [config]);

  useEffect(() => {
    updateConfig();
  }, [updateConfig]);

  // Cleanup
  useEffect(() => {
    const currentMaterialId = materialId.current;
    return () => {
      const shaderManager = ShaderManager.getInstance();
      shaderManager.unregisterMaterial(currentMaterialId);
    };
  }, []);

  return material;
}

// Enhanced shader performance monitoring with adaptive quality
export function useShaderPerformance() {
  const performanceRef = useRef({
    frameCount: 0,
    lastTime: performance.now(),
    fps: 60,
    frameTimeHistory: [] as number[],
    averageFrameTime: 16.67,
    performanceLevel: 'high' as 'low' | 'medium' | 'high',
    adaptiveQuality: true
  });

  const shaderManager = useMemo(() => ShaderManager.getInstance(), []);

  useFrame((_, delta) => {
    const now = performance.now();
    const frameTime = delta * 1000; // Convert to milliseconds
    
    // Track frame time history for better performance analysis
    performanceRef.current.frameTimeHistory.push(frameTime);
    if (performanceRef.current.frameTimeHistory.length > 60) {
      performanceRef.current.frameTimeHistory.shift();
    }
    
    // Calculate average frame time
    if (performanceRef.current.frameTimeHistory.length > 0) {
      performanceRef.current.averageFrameTime = 
        performanceRef.current.frameTimeHistory.reduce((a, b) => a + b, 0) / 
        performanceRef.current.frameTimeHistory.length;
    }
    
    performanceRef.current.frameCount++;
    
    if (now - performanceRef.current.lastTime >= 1000) {
      performanceRef.current.fps = performanceRef.current.frameCount;
      performanceRef.current.frameCount = 0;
      performanceRef.current.lastTime = now;
      
      // Adaptive performance level adjustment
      if (performanceRef.current.adaptiveQuality) {
        const fps = performanceRef.current.fps;
        const avgFrameTime = performanceRef.current.averageFrameTime;
        
        let newLevel: 'low' | 'medium' | 'high';
        if (fps < 25 || avgFrameTime > 40) {
          newLevel = 'low';
        } else if (fps < 45 || avgFrameTime > 22) {
          newLevel = 'medium';
        } else {
          newLevel = 'high';
        }
        
        if (newLevel !== performanceRef.current.performanceLevel) {
          performanceRef.current.performanceLevel = newLevel;
          shaderManager.setPerformanceMode(newLevel === 'low');
          console.info(`Performance level changed to: ${newLevel}`);
        }
      }
    }
  });

  return {
    fps: performanceRef.current.fps,
    averageFrameTime: performanceRef.current.averageFrameTime,
    performanceLevel: performanceRef.current.performanceLevel,
    getPerformanceInfo: () => ({
      fps: performanceRef.current.fps,
      averageFrameTime: performanceRef.current.averageFrameTime,
      performanceLevel: performanceRef.current.performanceLevel,
      isPerformant: performanceRef.current.fps > 30,
      shouldReduceQuality: performanceRef.current.performanceLevel === 'low'
    }),
    setAdaptiveQuality: (enabled: boolean) => {
      performanceRef.current.adaptiveQuality = enabled;
    }
  };
}
// Shader Loader Utility
// Loads and manages GLSL shaders for Tessera brain visualization
// Author: Tessera Brain Visualization System

import * as THREE from 'three';

// Shader file imports (these will be loaded as text)
import brainVertexShader from '../brain/brain.vert?raw';
import brainFragmentShader from '../brain/brain.frag?raw';
import neuralConnectionVertexShader from '../connections/neural-connection.vert?raw';
import neuralConnectionFragmentShader from '../connections/neural-connection.frag?raw';
import knowledgeFlowVertexShader from '../knowledge/knowledge-flow.vert?raw';
import knowledgeFlowFragmentShader from '../knowledge/knowledge-flow.frag?raw';
import enhancedLightingVertexShader from '../lighting/enhanced-lighting.vert?raw';
import enhancedLightingFragmentShader from '../lighting/enhanced-lighting.frag?raw';

// Shader configuration interfaces
export interface BrainShaderUniforms {
  time: { value: number };
  brainColor: { value: THREE.Color };
  brainActivity: { value: number };
  metalness: { value: number };
  roughness: { value: number };
  opacity: { value: number };
  activityColor: { value: THREE.Color };
  // Note: cameraPosition is automatically provided by THREE.js
  rimPower: { value: number };
  subsurfaceStrength: { value: number };
  showNeuralActivity: { value: boolean };
  knowledgeIntensity: { value: number };
  knowledgeColor: { value: THREE.Color };
  deformationStrength: { value: number };
  activityCenter: { value: THREE.Vector3 };
  activityRadius: { value: number };
  
  // Region highlighting uniforms
  selectedRegionColor: { value: THREE.Color };
  selectedRegionIntensity: { value: number };
  selectedRegionCenter: { value: THREE.Vector3 };
  selectedRegionRadius: { value: number };
  
  // Lighting uniforms
  ambientLightColor: { value: THREE.Color };
  directionalLightColor: { value: THREE.Color };
  directionalLightDirection: { value: THREE.Vector3 };
  pointLightColor: { value: THREE.Color };
  pointLightPosition: { value: THREE.Vector3 };
  pointLightDistance: { value: number };
}

export interface NeuralConnectionUniforms {
  time: { value: number };
  connectionActivity: { value: number };
  pulseSpeed: { value: number };
  connectionRadius: { value: number };
  startPoint: { value: THREE.Vector3 };
  endPoint: { value: THREE.Vector3 };
  signalStrength: { value: number };
  baseConnectionColor: { value: THREE.Color };
  activeConnectionColor: { value: THREE.Color };
  signalColor: { value: THREE.Color };
  connectionOpacity: { value: number };
  signalOpacity: { value: number };
  // Note: cameraPosition is automatically provided by THREE.js
  glowIntensity: { value: number };
  electricalNoise: { value: number };
  showElectricalActivity: { value: boolean };
  
  // Lighting uniforms
  ambientLightColor: { value: THREE.Color };
  directionalLightColor: { value: THREE.Color };
  directionalLightDirection: { value: THREE.Vector3 };
}

export interface KnowledgeFlowUniforms {
  time: { value: number };
  flowSpeed: { value: number };
  knowledgeActivity: { value: number };
  sourceRegion: { value: THREE.Vector3 };
  targetRegion: { value: THREE.Vector3 };
  informationDensity: { value: number };
  learningRate: { value: number };
  knowledgeColors: { value: THREE.Color[] };
  learningColor: { value: THREE.Color };
  memoryColor: { value: THREE.Color };
  opacity: { value: number };
  // Note: cameraPosition is automatically provided by THREE.js
  showLearningProcess: { value: boolean };
  showMemoryConsolidation: { value: boolean };
  
  // Lighting uniforms
  ambientLightColor: { value: THREE.Color };
  directionalLightColor: { value: THREE.Color };
  directionalLightDirection: { value: THREE.Vector3 };
}

export interface EnhancedLightingUniforms {
  time: { value: number };
  
  // Lighting uniforms
  lightPosition: { value: THREE.Vector3 };
  lightDirection: { value: THREE.Vector3 };
  lightColor: { value: THREE.Color };
  lightIntensity: { value: number };
  ambientColor: { value: THREE.Color };
  ambientIntensity: { value: number };
  
  // Material uniforms
  baseColor: { value: THREE.Color };
  metallic: { value: number };
  roughness: { value: number };
  opacity: { value: number };
  subsurfaceStrength: { value: number };
  
  // Shadow and atmosphere uniforms
  shadowMap: { value: THREE.Texture | null };
  shadowMatrix: { value: THREE.Matrix4 };
  shadowStrength: { value: number };
  atmosphericDensity: { value: number };
  atmosphericColor: { value: THREE.Color };
  
  // Advanced lighting uniforms
  rimLightColor: { value: THREE.Color };
  rimLightPower: { value: number };
  fresnelStrength: { value: number };
  enableVolumetricLighting: { value: boolean };
  enableSubsurfaceScattering: { value: boolean };
  enableAtmosphericScattering: { value: boolean };
}

// Shader creation functions
// Material cache for reusing identical materials
const materialCache = new Map<string, THREE.ShaderMaterial>();
const MAX_CACHE_SIZE = 50;

function getCachedMaterial(key: string, factory: () => THREE.ShaderMaterial): THREE.ShaderMaterial {
  if (materialCache.has(key)) {
    return materialCache.get(key)!.clone();
  }
  
  const material = factory();
  
  // Limit cache size to prevent memory leaks
  if (materialCache.size >= MAX_CACHE_SIZE) {
    const firstKey = materialCache.keys().next().value;
    const oldMaterial = materialCache.get(firstKey);
    if (oldMaterial) {
      oldMaterial.dispose();
    }
    materialCache.delete(firstKey);
  }
  
  materialCache.set(key, material);
  return material.clone();
}

export function createBrainShaderMaterial(
  uniforms?: Partial<BrainShaderUniforms>
): THREE.ShaderMaterial {
  // Create cache key based on significant uniform values
  const cacheKey = `brain-${JSON.stringify({
    showNeuralActivity: uniforms?.showNeuralActivity ?? true,
    metalness: uniforms?.metalness ?? 0.1,
    roughness: uniforms?.roughness ?? 0.7
  })}`;
  
  return getCachedMaterial(cacheKey, () => {
    const defaultUniforms: BrainShaderUniforms = {
      time: { value: 0 },
      brainColor: { value: new THREE.Color(0xf0e8e0) }, // More brain-like pinkish-gray
      brainActivity: { value: 0.5 },
      metalness: { value: 0.1 }, // Less metallic for organic tissue
      roughness: { value: 0.7 }, // More rough for brain tissue
      opacity: { value: 1.0 }, // Fully opaque
      activityColor: { value: new THREE.Color(0x4f46e5) },
      // Note: cameraPosition is automatically provided by THREE.js
      rimPower: { value: 1.5 },
      subsurfaceStrength: { value: 0.6 }, // Stronger subsurface for organic look
      showNeuralActivity: { value: true },
      knowledgeIntensity: { value: 0.5 },
      knowledgeColor: { value: new THREE.Color(0x06b6d4) },
      deformationStrength: { value: 1.0 },
      activityCenter: { value: new THREE.Vector3(0, 0, 0) },
      activityRadius: { value: 2.0 },
      
      // Region highlighting defaults
      selectedRegionColor: { value: new THREE.Color(0xff6b35) },
      selectedRegionIntensity: { value: 0.0 },
      selectedRegionCenter: { value: new THREE.Vector3(0, 0, 0) },
      selectedRegionRadius: { value: 0.0 },
      
      // Default lighting
      ambientLightColor: { value: new THREE.Color(0xf8f9fa) },
      directionalLightColor: { value: new THREE.Color(0xffffff) },
      directionalLightDirection: { value: new THREE.Vector3(-1, -1, -1) },
      pointLightColor: { value: new THREE.Color(0xe3f2fd) },
      pointLightPosition: { value: new THREE.Vector3(10, 5, 10) },
      pointLightDistance: { value: 20.0 }
    };

    const finalUniforms = { ...defaultUniforms, ...uniforms };

    return new THREE.ShaderMaterial({
      uniforms: finalUniforms,
      vertexShader: brainVertexShader,
      fragmentShader: brainFragmentShader,
      transparent: false,
      side: THREE.DoubleSide,
      depthWrite: true,
      blending: THREE.NormalBlending
    });
  });
}

export function createNeuralConnectionMaterial(
  uniforms?: Partial<NeuralConnectionUniforms>
): THREE.ShaderMaterial {
  // Create cache key for connection materials
  const cacheKey = `connection-${JSON.stringify({
    showElectricalActivity: uniforms?.showElectricalActivity ?? true,
    connectionRadius: uniforms?.connectionRadius ?? 0.02,
    glowIntensity: uniforms?.glowIntensity ?? 1.5
  })}`;
  
  return getCachedMaterial(cacheKey, () => {
    const defaultUniforms: NeuralConnectionUniforms = {
      time: { value: 0 },
      connectionActivity: { value: 0.7 },
      pulseSpeed: { value: 2.0 },
      connectionRadius: { value: 0.02 },
      startPoint: { value: new THREE.Vector3(-1, 0, 0) },
      endPoint: { value: new THREE.Vector3(1, 0, 0) },
      signalStrength: { value: 1.0 },
      baseConnectionColor: { value: new THREE.Color(0x4f46e5) },
      activeConnectionColor: { value: new THREE.Color(0x06b6d4) },
      signalColor: { value: new THREE.Color(0xf59e0b) },
      connectionOpacity: { value: 0.6 },
      signalOpacity: { value: 0.8 },
      // Note: cameraPosition is automatically provided by THREE.js
      glowIntensity: { value: 1.5 },
      electricalNoise: { value: 0.3 },
      showElectricalActivity: { value: true },
      
      // Default lighting
      ambientLightColor: { value: new THREE.Color(0xf8f9fa) },
      directionalLightColor: { value: new THREE.Color(0xffffff) },
      directionalLightDirection: { value: new THREE.Vector3(-1, -1, -1) }
    };

    const finalUniforms = { ...defaultUniforms, ...uniforms };

    return new THREE.ShaderMaterial({
      uniforms: finalUniforms,
      vertexShader: neuralConnectionVertexShader,
      fragmentShader: neuralConnectionFragmentShader,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });
  });
}

export function createKnowledgeFlowMaterial(
  uniforms?: Partial<KnowledgeFlowUniforms>
): THREE.ShaderMaterial {
  const knowledgeTypeColors = [
    new THREE.Color(0x3b82f6), // Factual - Blue
    new THREE.Color(0x10b981), // Procedural - Green
    new THREE.Color(0x8b5cf6), // Conceptual - Purple
    new THREE.Color(0xf59e0b), // Metacognitive - Orange
    new THREE.Color(0xef4444), // Emotional - Red
    new THREE.Color(0xeab308)  // Creative - Yellow
  ];

  const defaultUniforms: KnowledgeFlowUniforms = {
    time: { value: 0 },
    flowSpeed: { value: 1.5 },
    knowledgeActivity: { value: 0.6 },
    sourceRegion: { value: new THREE.Vector3(-2, 0, 0) },
    targetRegion: { value: new THREE.Vector3(2, 0, 0) },
    informationDensity: { value: 0.7 },
    learningRate: { value: 1.0 },
    knowledgeColors: { value: knowledgeTypeColors },
    learningColor: { value: new THREE.Color(0x06b6d4) },
    memoryColor: { value: new THREE.Color(0x8b5cf6) },
    opacity: { value: 0.7 },
    // Note: cameraPosition is automatically provided by THREE.js
    showLearningProcess: { value: true },
    showMemoryConsolidation: { value: true },
    
    // Default lighting
    ambientLightColor: { value: new THREE.Color(0xf8f9fa) },
    directionalLightColor: { value: new THREE.Color(0xffffff) },
    directionalLightDirection: { value: new THREE.Vector3(-1, -1, -1) }
  };

  const finalUniforms = { ...defaultUniforms, ...uniforms };

  return new THREE.ShaderMaterial({
    uniforms: finalUniforms,
    vertexShader: knowledgeFlowVertexShader,
    fragmentShader: knowledgeFlowFragmentShader,
    transparent: true,
    side: THREE.DoubleSide,
    depthWrite: false,
    blending: THREE.NormalBlending
  });
}

export function createEnhancedLightingMaterial(
  uniforms?: Partial<EnhancedLightingUniforms>
): THREE.ShaderMaterial {
  const defaultUniforms: EnhancedLightingUniforms = {
    time: { value: 0 },
    
    // Lighting defaults
    lightPosition: { value: new THREE.Vector3(10, 10, 10) },
    lightDirection: { value: new THREE.Vector3(-1, -1, -1) },
    lightColor: { value: new THREE.Color(0xffffff) },
    lightIntensity: { value: 1.0 },
    ambientColor: { value: new THREE.Color(0x404040) },
    ambientIntensity: { value: 0.3 },
    
    // Material defaults
    baseColor: { value: new THREE.Color(0xf0e8e0) },
    metallic: { value: 0.1 },
    roughness: { value: 0.7 },
    opacity: { value: 1.0 }, // Fully opaque
    subsurfaceStrength: { value: 0.4 }, // Reduced for more opacity
    
    // Shadow and atmosphere defaults
    shadowMap: { value: null },
    shadowMatrix: { value: new THREE.Matrix4() },
    shadowStrength: { value: 0.5 },
    atmosphericDensity: { value: 0.1 },
    atmosphericColor: { value: new THREE.Color(0x87ceeb) },
    
    // Advanced lighting defaults
    rimLightColor: { value: new THREE.Color(0x4ecdc4) },
    rimLightPower: { value: 2.0 },
    fresnelStrength: { value: 1.0 },
    enableVolumetricLighting: { value: true },
    enableSubsurfaceScattering: { value: true },
    enableAtmosphericScattering: { value: true }
  };

  const finalUniforms = { ...defaultUniforms, ...uniforms };

  return new THREE.ShaderMaterial({
    uniforms: finalUniforms,
    vertexShader: enhancedLightingVertexShader,
    fragmentShader: enhancedLightingFragmentShader,
    transparent: false,
    side: THREE.DoubleSide,
    depthWrite: true,
    blending: THREE.NormalBlending
  });
}

// Performance-optimized shader management
export class ShaderManager {
  private static instance: ShaderManager;
  private materials: Map<string, THREE.ShaderMaterial> = new Map();
  private animationId: number | null = null;
  private lastUpdateTime = 0;
  private updateInterval = 16.67; // ~60 FPS
  private performanceMode = false;
  
  // Performance monitoring
  private frameCount = 0;
  private lastFPSCheck = 0;
  private currentFPS = 60;

  static getInstance(): ShaderManager {
    if (!ShaderManager.instance) {
      ShaderManager.instance = new ShaderManager();
    }
    return ShaderManager.instance;
  }
  
  setPerformanceMode(enabled: boolean): void {
    this.performanceMode = enabled;
    this.updateInterval = enabled ? 33.33 : 16.67; // 30 FPS vs 60 FPS
  }
  
  getCurrentFPS(): number {
    return this.currentFPS;
  }

  registerMaterial(id: string, material: THREE.ShaderMaterial): void {
    this.materials.set(id, material);
    
    // Start animation loop if not already running
    if (!this.animationId) {
      this.startAnimationLoop();
    }
  }

  unregisterMaterial(id: string): void {
    this.materials.delete(id);
    
    // Stop animation loop if no materials are registered
    if (this.materials.size === 0 && this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  updateUniforms(id: string, uniforms: Record<string, unknown>): void {
    const material = this.materials.get(id);
    if (material) {
      Object.keys(uniforms).forEach(key => {
        if (material.uniforms[key]) {
          material.uniforms[key].value = uniforms[key];
        }
      });
    }
  }

  private startAnimationLoop(): void {
    const animate = (currentTime: number) => {
      // Performance monitoring
      this.frameCount++;
      if (currentTime - this.lastFPSCheck >= 1000) {
        this.currentFPS = this.frameCount;
        this.frameCount = 0;
        this.lastFPSCheck = currentTime;
        
        // Auto-adjust performance mode based on FPS
        if (this.currentFPS < 30 && !this.performanceMode) {
          this.setPerformanceMode(true);
          console.warn('ShaderManager: Enabling performance mode due to low FPS');
        } else if (this.currentFPS > 50 && this.performanceMode) {
          this.setPerformanceMode(false);
          console.info('ShaderManager: Disabling performance mode due to improved FPS');
        }
      }
      
      // Throttle updates based on performance mode
      if (currentTime - this.lastUpdateTime >= this.updateInterval) {
        const time = currentTime * 0.001;
        
        // Batch uniform updates for better performance
        const uniformUpdates = new Map<string, number>();
        uniformUpdates.set('time', time);
        
        // Update time uniform for all registered materials
        this.materials.forEach(material => {
          uniformUpdates.forEach((value, key) => {
            if (material.uniforms[key]) {
              material.uniforms[key].value = value;
            }
          });
        });
        
        this.lastUpdateTime = currentTime;
      }
      
      this.animationId = requestAnimationFrame(animate);
    };
    
    animate(performance.now());
  }

  dispose(): void {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    
    this.materials.forEach(material => {
      material.dispose();
    });
    
    this.materials.clear();
  }
}

// Export shader source code for direct use if needed
export const shaderSources = {
  brain: {
    vertex: brainVertexShader,
    fragment: brainFragmentShader
  },
  neuralConnection: {
    vertex: neuralConnectionVertexShader,
    fragment: neuralConnectionFragmentShader
  },
  knowledgeFlow: {
    vertex: knowledgeFlowVertexShader,
    fragment: knowledgeFlowFragmentShader
  },
  enhancedLighting: {
    vertex: enhancedLightingVertexShader,
    fragment: enhancedLightingFragmentShader
  }
};

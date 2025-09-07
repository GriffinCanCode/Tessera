import { useEffect, useRef, Suspense, useMemo, useCallback } from 'react';
import { 
  Brain as BrainIcon, 
  Zap, 
  TrendingUp, 
  BarChart3, 
  Sparkles,
  Clock,
  RotateCw
} from 'lucide-react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { OrbitControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import { animate as _animate } from 'animejs';
import TesseraAPI from '../../services/api'; // TODO: Implement getBrainData method
import { useBrainStore } from '../../stores';
import { 
  useBrainShader, 
  useNeuralConnectionShader, 
  useShaderPerformance,
  useEnhancedLighting 
} from '../../hooks/useShaders';

import type { KnowledgeArea } from '../../stores';

// Performance optimization constants
const PERFORMANCE_CONFIG = {
  TARGET_FPS: 60,
  MIN_FPS: 30,
  LOD_DISTANCE_NEAR: 5,
  LOD_DISTANCE_FAR: 15,
  FRUSTUM_CULLING_ENABLED: true,
  INSTANCED_RENDERING_THRESHOLD: 10,
  GEOMETRY_CACHE_SIZE: 50,
  MATERIAL_CACHE_SIZE: 20
};

// Geometry cache for reusing common geometries
const geometryCache = new Map<string, THREE.BufferGeometry>();
const materialCache = new Map<string, THREE.Material>();

// Performance monitoring
class PerformanceMonitor {
  private frameCount = 0;
  private lastTime = performance.now();
  private fps = 60;
  private frameTimeHistory: number[] = [];
  private readonly maxHistorySize = 60;

  update(): void {
    const now = performance.now();
    const deltaTime = now - this.lastTime;
    
    this.frameTimeHistory.push(deltaTime);
    if (this.frameTimeHistory.length > this.maxHistorySize) {
      this.frameTimeHistory.shift();
    }
    
    this.frameCount++;
    
    if (now - this.lastTime >= 1000) {
      this.fps = this.frameCount;
      this.frameCount = 0;
      this.lastTime = now;
    }
  }

  getFPS(): number {
    return this.fps;
  }

  getAverageFrameTime(): number {
    if (this.frameTimeHistory.length === 0) return 16.67; // 60 FPS
    return this.frameTimeHistory.reduce((a, b) => a + b, 0) / this.frameTimeHistory.length;
  }

  shouldReduceQuality(): boolean {
    return this.fps < PERFORMANCE_CONFIG.MIN_FPS;
  }
}

const performanceMonitor = new PerformanceMonitor();

export function Brain() {
  const {
    knowledgeAreas,
    brainStats,
    selectedArea,
    viewMode,
    animationSpeed,
    contextLost,
    setKnowledgeAreas,
    setBrainStats,
    setSelectedArea,
    setIsLoading,
    setViewMode,
    setAnimationSpeed,
    setContextLost
  } = useBrainStore();
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const loadingRef = useRef(false);
  const memoryMonitorRef = useRef<NodeJS.Timeout | null>(null);
  const lastMemoryUsage = useRef<number>(0);
  const containerRef = useRef<HTMLDivElement>(null);

  // Enhanced WebGL context recovery with multiple attempts
  const recoverContext = useCallback(async (attempt: number = 1, maxAttempts: number = 3) => {
    if (attempt > maxAttempts) {
      setContextLost(true);
      return;
    }
    
    try {
      // Clear any cached geometries and materials
        if (typeof window !== 'undefined' && (window as unknown as { THREE?: { Cache: { clear: () => void } } }).THREE) {
          const threeWindow = window as unknown as { THREE: { Cache: { clear: () => void } } };
          threeWindow.THREE.Cache.clear();
        }

      // Force garbage collection if available
      if (typeof window !== 'undefined' && (window as unknown as { gc?: () => void }).gc) {
        (window as unknown as { gc: () => void }).gc();
      }

      // Wait before next attempt
      await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      
      // Try to recreate the canvas
      if (canvasRef.current) {
        const canvas = canvasRef.current;
        const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
        
        if (gl && !gl.isContextLost()) {
          setContextLost(false);
          return;
        }
      }
      
      // If still failed, try again
      recoverContext(attempt + 1, maxAttempts);
      
    } catch (error) {
      recoverContext(attempt + 1, maxAttempts);
    }
  }, [setContextLost]);

  // Memory monitoring for performance optimization
  const monitorMemory = useCallback(() => {
      if (typeof window !== 'undefined' && (window as unknown as { performance?: { memory?: { usedJSHeapSize: number } } }).performance?.memory) {
        const memory = (window as unknown as { performance: { memory: { usedJSHeapSize: number } } }).performance.memory;
      const currentUsage = memory.usedJSHeapSize / 1024 / 1024; // MB
      
      // Check for memory leaks (significant increase)
      if (currentUsage > lastMemoryUsage.current * 1.5 && currentUsage > 100) {
        
        // Force cleanup
        if (typeof window !== 'undefined' && (window as unknown as { THREE?: { Cache: { clear: () => void } } }).THREE) {
          const threeWindow = window as unknown as { THREE: { Cache: { clear: () => void } } };
          threeWindow.THREE.Cache.clear();
        }
      }
      
      lastMemoryUsage.current = currentUsage;
    }
  }, []);

  // Enhanced data loading with error handling and retries
  const loadBrainData = useCallback(async (retryCount: number = 0) => {
    if (loadingRef.current || retryCount > 3) return;
    
    loadingRef.current = true;
    setIsLoading(true);
    
    try {
      // Call the real Tessera API
      const response = await TesseraAPI.getBrainData();
      
      if (response.success && response.data) {
        setKnowledgeAreas(response.data.areas || []);
        setBrainStats(response.data.stats || {
          totalKnowledgePoints: 0,
          dominantArea: '',
          balanceScore: 0,
          growthRate: 0
        });
      } else {
        throw new Error('Failed to load brain data from API');
      }
    } catch (error) {
      // Retry with exponential backoff
      if (retryCount < 3) {
        const delay = Math.pow(2, retryCount) * 1000;
        setTimeout(() => loadBrainData(retryCount + 1), delay);
      } else {
        // Use fallback sample data if API fails completely
        
        const fallbackAreas = [
          {
            id: '1',
            name: 'Machine Learning',
            percentage: 85,
            color: '#3b82f6',
            timeSpent: 120,
            totalContent: 50,
            completedContent: 42,
            region: 'frontal' as const,
            position3D: { x: 0.8, y: 0.3, z: 1.4 },
            scale: 1.0,
            connections: ['2', '3']
          },
          {
            id: '2',
            name: 'Data Science',
            percentage: 72,
            color: '#10b981',
            timeSpent: 95,
            totalContent: 40,
            completedContent: 29,
            region: 'parietal' as const,
            position3D: { x: -0.6, y: 1.2, z: 0.2 },
            scale: 1.0,
            connections: ['1', '4']
          },
          {
            id: '3',
            name: 'Neural Networks',
            percentage: 90,
            color: '#8b5cf6',
            timeSpent: 150,
            totalContent: 60,
            completedContent: 54,
            region: 'temporal' as const,
            position3D: { x: 1.4, y: -0.2, z: 0.6 },
            scale: 1.0,
            connections: ['1', '5']
          },
          {
            id: '4',
            name: 'Statistics',
            percentage: 65,
            color: '#f59e0b',
            timeSpent: 80,
            totalContent: 35,
            completedContent: 23,
            region: 'occipital' as const,
            position3D: { x: -0.4, y: 0.6, z: -1.3 },
            scale: 1.0,
            connections: ['2', '6']
          },
          {
            id: '5',
            name: 'Deep Learning',
            percentage: 78,
            color: '#ef4444',
            timeSpent: 110,
            totalContent: 45,
            completedContent: 35,
            region: 'limbic' as const,
            position3D: { x: 0.3, y: -0.6, z: 0.8 },
            scale: 1.0,
            connections: ['3', '6']
          },
          {
            id: '6',
            name: 'Computer Vision',
            percentage: 60,
            color: '#06b6d4',
            timeSpent: 70,
            totalContent: 30,
            completedContent: 18,
            region: 'cerebellum' as const,
            position3D: { x: -0.2, y: -1.4, z: -0.6 },
            scale: 1.0,
            connections: ['4', '5']
          }
        ];

        const fallbackStats = {
          totalKnowledgePoints: 450,
          dominantArea: 'Neural Networks',
          balanceScore: 75,
          growthRate: 12
        };

        setKnowledgeAreas(fallbackAreas);
        setBrainStats(fallbackStats);
      }
    } finally {
      loadingRef.current = false;
      setIsLoading(false);
    }
  }, [setKnowledgeAreas, setBrainStats, setIsLoading]);

  // Initialize brain data and monitoring
  useEffect(() => {
    loadBrainData();
    
    // Start memory monitoring
    memoryMonitorRef.current = setInterval(monitorMemory, 10000); // Every 10 seconds
    
    return () => {
      if (memoryMonitorRef.current) {
        clearInterval(memoryMonitorRef.current);
      }
    };
  }, [loadBrainData, monitorMemory]);

  // Format time helper (for future use)
  // const formatTime = useCallback((timestamp: number) => {
  //   return new Date(timestamp).toLocaleTimeString();
  // }, []);

  // Brain Region Highlighter - creates invisible interaction zones for brain regions (click only)
  const BrainRegionHighlighter = ({ area, isSelected, onSelect }: {
    area: KnowledgeArea;
    isSelected: boolean;
    onSelect: () => void;
  }) => {
    return (
      <group>
        {/* Invisible interaction mesh for clicking on brain regions */}
        <mesh
          position={[area.position3D.x, area.position3D.y, area.position3D.z]}
          onClick={onSelect}
        >
          <sphereGeometry args={[0.4, 16, 8]} />
          <meshBasicMaterial 
            transparent 
            opacity={0}
            visible={false}
          />
        </mesh>

        {/* Enhanced information display */}
        {isSelected && (
          <Html
            position={[area.position3D.x, area.position3D.y + 1.5, area.position3D.z]}
            center
            distanceFactor={8}
            occlude
          >
            <div className="bg-white/95 backdrop-blur-sm rounded-lg p-3 shadow-lg border border-gray-200 min-w-48">
              <h3 className="font-semibold text-gray-900 mb-2">{area.name}</h3>
              <div className="space-y-1 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-600">Activity:</span>
                  <span className="font-medium" style={{ color: area.color }}>
                    {area.percentage}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Connections:</span>
                  <span className="font-medium">{area.connections.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Region:</span>
                  <span className="font-medium capitalize">{area.region}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Time Spent:</span>
                  <span className="font-medium text-xs">{area.timeSpent}h</span>
                </div>
              </div>
            </div>
          </Html>
        )}
      </group>
    );
  };

  // Optimized Neural Connections with LOD and frustum culling
  const BrainConnections = ({ areas }: { areas: KnowledgeArea[] }) => {
    const { camera } = useThree();
    
    const connections = useMemo(() => {
      // Guard against undefined camera position
      if (!camera?.position) {
        return [];
      }
      
      const connectionPairs: Array<{ 
        start: KnowledgeArea; 
        end: KnowledgeArea; 
        activity: number;
        id: string;
        distance: number;
        visible: boolean;
      }> = [];
      
      areas.forEach(area => {
        area.connections.forEach(connectionId => {
          const connectedArea = areas.find(a => a.id === connectionId);
          if (connectedArea && !connectionPairs.some(
            pair => (pair.start.id === area.id && pair.end.id === connectedArea.id) ||
                    (pair.start.id === connectedArea.id && pair.end.id === area.id)
          )) {
            // Calculate connection activity based on both areas
            const activity = ((area.percentage + connectedArea.percentage) / 200) * 0.8 + 0.2;
            
            // Calculate distance from camera for LOD
            const midpoint = new THREE.Vector3(
              (area.position3D.x + connectedArea.position3D.x) / 2,
              (area.position3D.y + connectedArea.position3D.y) / 2,
              (area.position3D.z + connectedArea.position3D.z) / 2
            );
            const distance = camera.position.distanceTo(midpoint);
            
            // Frustum culling - only render visible connections
            const frustum = new THREE.Frustum();
            const matrix = new THREE.Matrix4().multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
            frustum.setFromProjectionMatrix(matrix);
            
            const sphere = new THREE.Sphere(midpoint, 0.5);
            const visible = !PERFORMANCE_CONFIG.FRUSTUM_CULLING_ENABLED || frustum.intersectsSphere(sphere);
            
            connectionPairs.push({ 
              start: area, 
              end: connectedArea, 
              activity,
              id: `${area.id}-${connectedArea.id}`,
              distance,
              visible
            });
          }
        });
      });
      
      // Sort by distance for LOD rendering
      return connectionPairs.sort((a, b) => a.distance - b.distance);
    }, [areas, camera.position, camera.matrixWorldInverse, camera.projectionMatrix]);

    // Filter connections based on performance and visibility
    const visibleConnections = useMemo(() => {
      const shouldReduceQuality = performanceMonitor.shouldReduceQuality();
      
      return connections.filter((connection, index) => {
        if (!connection.visible) return false;
        
        // Reduce connection count if performance is poor
        if (shouldReduceQuality && index > connections.length * 0.5) {
          return false;
        }
        
        // LOD: Skip distant connections if performance is poor
        if (shouldReduceQuality && connection.distance > PERFORMANCE_CONFIG.LOD_DISTANCE_NEAR) {
          return false;
        }
        
        return true;
      });
    }, [connections]);

    return (
      <>
        {visibleConnections.map(({ start, end, activity, id, distance }) => (
          <NeuralConnection
            key={id}
            startArea={start}
            endArea={end}
            activity={activity}
            distance={distance}
          />
        ))}
      </>
    );
  };

  // Optimized Neural Connection component with LOD and caching
  const NeuralConnection = ({ 
    startArea, 
    endArea, 
    activity,
    distance 
  }: {
    startArea: KnowledgeArea;
    endArea: KnowledgeArea;
    activity: number;
    distance: number;
  }) => {
    const meshRef = useRef<THREE.Mesh>(null);
    
    // Guard against undefined distance
    const safeDistance = distance ?? PERFORMANCE_CONFIG.LOD_DISTANCE_FAR;
    
    // OPTIMIZED: Reuse Vector3 objects to reduce GC pressure
    const startPoint = useMemo(() => {
      const point = new THREE.Vector3();
      point.set(startArea.position3D.x, startArea.position3D.y, startArea.position3D.z);
      return point;
    }, [startArea.position3D.x, startArea.position3D.y, startArea.position3D.z]);

    const endPoint = useMemo(() => {
      const point = new THREE.Vector3();
      point.set(endArea.position3D.x, endArea.position3D.y, endArea.position3D.z);
      return point;
    }, [endArea.position3D.x, endArea.position3D.y, endArea.position3D.z]);

    // LOD-based quality settings
    const lodSettings = useMemo(() => {
      const isNear = safeDistance < PERFORMANCE_CONFIG.LOD_DISTANCE_NEAR;
      const isMid = safeDistance < PERFORMANCE_CONFIG.LOD_DISTANCE_FAR;
      const shouldReduceQuality = performanceMonitor.shouldReduceQuality();
      
      return {
        segments: shouldReduceQuality ? (isNear ? 12 : 8) : (isNear ? 20 : isMid ? 16 : 12),
        radialSegments: shouldReduceQuality ? (isNear ? 6 : 4) : (isNear ? 8 : isMid ? 6 : 4),
        radius: shouldReduceQuality ? 0.015 : 0.02,
        showElectricalActivity: isNear && !shouldReduceQuality
      };
    }, [safeDistance]);

    // Create neural connection shader material
    const connectionMaterial = useNeuralConnectionShader({
      startPoint,
      endPoint,
      connectionActivity: activity,
      signalStrength: 1.0,
      pulseSpeed: 2.0 + Math.random() * 1.0,
      showElectricalActivity: lodSettings.showElectricalActivity,
      connectionRadius: lodSettings.radius
    });

    // OPTIMIZED: Create curve geometry with caching and LOD
    const geometry = useMemo(() => {
      const geometryKey = `tube-${lodSettings.segments}-${lodSettings.radialSegments}-${lodSettings.radius}`;
      
      if (geometryCache.has(geometryKey)) {
        return geometryCache.get(geometryKey)!;
      }
      
      const midpoint = new THREE.Vector3();
      midpoint.addVectors(startPoint, endPoint).multiplyScalar(0.5);
      midpoint.y += 0.5; // Arch the connection upward
      
      const curve = new THREE.CatmullRomCurve3([startPoint, midpoint, endPoint]);
      const tubeGeometry = new THREE.TubeGeometry(
        curve, 
        lodSettings.segments, 
        lodSettings.radius, 
        lodSettings.radialSegments, 
        false
      );
      
      // Cache geometry but limit cache size
      if (geometryCache.size < PERFORMANCE_CONFIG.GEOMETRY_CACHE_SIZE) {
        geometryCache.set(geometryKey, tubeGeometry);
      }
      
      return tubeGeometry;
    }, [startPoint, endPoint, lodSettings]);

    // Don't render if material is not ready
    if (!connectionMaterial) {
      return null;
    }

    return (
      <mesh ref={meshRef} geometry={geometry}>
        <primitive object={connectionMaterial} />
      </mesh>
    );
  };

  // Optimized Brain Hemisphere component with performance monitoring
  const BrainHemisphere = ({ 
    geometry, 
    position, 
    areas, 
    selectedArea 
  }: {
    geometry: THREE.BufferGeometry;
    position: [number, number, number];
    areas: KnowledgeArea[];
    selectedArea: KnowledgeArea | null;
  }) => {
    const { camera } = useThree();
    
    // Performance-aware intensity transitions
    const selectedIntensityRef = useRef(0);
    const hoveredIntensityRef = useRef(0); // Always stays 0
    const selectedRadiusRef = useRef(0);
    const hoveredRadiusRef = useRef(0); // Always stays 0
    const deformationStrengthRef = useRef(0.0);
    
    // LOD calculation for hemisphere
    const distanceToCamera = useMemo(() => {
      const hemispherePos = new THREE.Vector3(...position);
      return camera.position.distanceTo(hemispherePos);
    }, [camera.position, position]);

    // Calculate overall activity
    const overallActivity = areas.length > 0 
      ? areas.reduce((sum, area) => sum + area.percentage, 0) / areas.length / 100 
      : 0.5;

    // Get the most active area for primary highlighting
    const mostActiveArea = areas.reduce((prev, current) => 
      (current.percentage > prev.percentage) ? current : prev, areas[0] || null
    );

    // Determine primary highlight area (selected > most active, hover disabled)
    const primaryArea = selectedArea || mostActiveArea;

    // Target values for smooth transitions (no hover color changes)
    const targetSelectedIntensity = selectedArea ? 1.0 : 0.0;
    const targetSelectedRadius = selectedArea ? 1.0 : 0.0;
    
    // No deformation strength changes - keep brain size constant

    const brainMaterial = useBrainShader({
      brainColor: new THREE.Color('#e8ddd4'), // More opaque brain tissue color
      brainActivity: overallActivity,
      knowledgeIntensity: primaryArea ? primaryArea.percentage / 100 : 0.5,
      activityCenter: useMemo(() => {
        if (primaryArea) {
          const center = new THREE.Vector3();
          center.set(primaryArea.position3D.x, primaryArea.position3D.y, primaryArea.position3D.z);
          return center;
        }
        return new THREE.Vector3(0, 0, 0);
      }, [primaryArea]),
      showNeuralActivity: true,
      deformationStrength: deformationStrengthRef.current,
      // Enhanced region highlighting with smooth animated intensities
      selectedRegionColor: useMemo(() => 
        selectedArea ? new THREE.Color(selectedArea.color) : new THREE.Color('#ff6b35'), 
        [selectedArea]
      ),
      selectedRegionIntensity: selectedIntensityRef.current,
      selectedRegionCenter: useMemo(() => {
        if (selectedArea) {
          const center = new THREE.Vector3();
          center.set(selectedArea.position3D.x, selectedArea.position3D.y, selectedArea.position3D.z);
          return center;
        }
        return new THREE.Vector3(0, 0, 0);
      }, [selectedArea]),
      selectedRegionRadius: selectedRadiusRef.current
    });

    // Performance-aware animation frame updates
    useFrame((_, delta) => {
      // Update performance monitor
      performanceMonitor.update();
      
      // Adaptive transition speed based on performance
      const shouldReduceQuality = performanceMonitor.shouldReduceQuality();
      const baseTransitionSpeed = shouldReduceQuality ? 4.0 : 6.0;
      const fastTransitionSpeed = shouldReduceQuality ? 6.0 : 8.0;
      
      // Skip expensive updates if far from camera
      const isNear = distanceToCamera < PERFORMANCE_CONFIG.LOD_DISTANCE_FAR;
      if (!isNear && shouldReduceQuality) {
        return; // Skip updates for distant hemispheres when performance is poor
      }
      
      // Use faster transitions when turning on, slower when turning off for natural feel
      const selectedTransitionSpeed = targetSelectedIntensity > selectedIntensityRef.current ? fastTransitionSpeed : baseTransitionSpeed;
      
      // Smooth intensity transitions with adaptive timing (selected only)
      selectedIntensityRef.current = THREE.MathUtils.lerp(
        selectedIntensityRef.current, 
        targetSelectedIntensity, 
        delta * selectedTransitionSpeed
      );
      
      // Hover effects disabled - keep at zero
      hoveredIntensityRef.current = 0.0;
      
      // Radius transitions slightly slower for smoother visual effect (selected only)
      selectedRadiusRef.current = THREE.MathUtils.lerp(
        selectedRadiusRef.current, 
        targetSelectedRadius, 
        delta * selectedTransitionSpeed * 0.8
      );
      
      // Hover radius disabled - keep at zero
      hoveredRadiusRef.current = 0.0;
      
      // No deformation transitions - keep at zero
      deformationStrengthRef.current = 0.0;

      // Update shader uniforms with smooth values (click selection only)
      if (brainMaterial?.uniforms) {
        brainMaterial.uniforms.selectedRegionIntensity.value = selectedIntensityRef.current;
        brainMaterial.uniforms.selectedRegionRadius.value = selectedRadiusRef.current;
        brainMaterial.uniforms.deformationStrength.value = 0.0; // Always disabled
      }
    });

    // Don't render if material is not ready
    if (!brainMaterial) {
      return null;
    }

    return (
      <mesh 
        geometry={geometry} 
        position={position}
      >
        <primitive object={brainMaterial} />
      </mesh>
    );
  };

  // Enhanced Brain Outline with shader materials
  const BrainOutline = ({ 
    areas, 
    selectedArea 
  }: { 
    areas: KnowledgeArea[];
    selectedArea: KnowledgeArea | null;
  }) => {
    const brainRef = useRef<THREE.Group>(null);
    
    useFrame((state) => {
      if (brainRef.current) {
        // Simple constant rotation only - no size or position changes
        brainRef.current.rotation.y = state.clock.elapsedTime * 0.05; // Constant rotation speed
        
        // No position changes - keep brain centered
        brainRef.current.position.y = 0;
      }
    });

    // Calculate overall brain activity for shader parameters

    // Create optimized hemisphere geometries with LOD
    const createHemisphereGeometry = (isLeft: boolean) => {
      // Performance-based LOD for geometry detail
      const shouldReduceQuality = performanceMonitor.shouldReduceQuality();
      const widthSegments = shouldReduceQuality ? 48 : 96;
      const heightSegments = shouldReduceQuality ? 24 : 48;
      
      const geometryKey = `hemisphere-${isLeft}-${widthSegments}-${heightSegments}`;
      
      // Check cache first
      if (geometryCache.has(geometryKey)) {
        return geometryCache.get(geometryKey)!;
      }
      
      const geometry = new THREE.SphereGeometry(2.2, widthSegments, heightSegments, 0, Math.PI * (isLeft ? 1 : -1), 0, Math.PI);
      const positions = geometry.attributes.position.array as Float32Array;
      
      // Enhanced anatomically-inspired brain deformation
      for (let i = 0; i < positions.length; i += 3) {
        const x = positions[i];
        const y = positions[i + 1];
        const z = positions[i + 2];
        
        // Anatomical brain regions
        // Frontal lobe (front, larger)
        const frontalLobe = z > 0.5 ? 
          Math.sin(x * 1.8) * Math.cos(y * 1.2) * 0.25 * (z - 0.5) : 0;
        
        // Parietal lobe (top-back)
        const parietalLobe = y > 0.3 && z > -0.5 && z < 0.5 ? 
          Math.sin(x * 2.2) * Math.cos(z * 2.5) * 0.18 * (y - 0.3) : 0;
        
        // Temporal lobe (sides, lower)
        const temporalLobe = Math.abs(x) > 1.0 && y < 0.2 ? 
          Math.sin(y * 3.0) * Math.cos(z * 2.0) * 0.22 * (Math.abs(x) - 1.0) : 0;
        
        // Occipital lobe (back)
        const occipitalLobe = z < -0.8 ? 
          Math.sin(x * 2.0) * Math.cos(y * 1.8) * 0.20 * Math.abs(z + 0.8) : 0;
        
        // Cerebellum area (lower back, smaller bumps)
        const cerebellum = z < -0.5 && y < -0.8 ? 
          Math.sin(x * 4.0) * Math.cos(z * 4.0) * 0.15 * Math.abs(y + 0.8) : 0;
        
        // Cortical folds (sulci and gyri)
        const corticalFolds = 
          Math.sin(x * 12.0) * Math.cos(y * 10.0) * 0.08 +
          Math.sin(z * 14.0) * Math.cos(x * 8.0) * 0.06 +
          Math.sin(y * 16.0) * Math.cos(z * 12.0) * 0.05;
        
        // Fine cortical wrinkles
        const fineWrinkles = 
          Math.sin(x * 25.0) * Math.cos(y * 20.0) * 0.03 +
          Math.sin(z * 30.0) * Math.cos(x * 22.0) * 0.025;
        
        // Brainstem connection (flatten bottom)
        const brainstemFlattening = y < -1.2 ? Math.abs(y + 1.2) * 0.4 : 0;
        
        // Longitudinal fissure (separation between hemispheres)
        const fissureDepth = Math.abs(x) < 0.1 ? Math.abs(x) * 2.0 : 0;
        
        // Combine all anatomical features
        const anatomicalDeformation = 
          frontalLobe + parietalLobe + temporalLobe + occipitalLobe + 
          cerebellum + corticalFolds + fineWrinkles - brainstemFlattening - fissureDepth;
        
        // Apply deformation with anatomical constraints
        const deformation = 1 + anatomicalDeformation * 0.8;
        
        positions[i] = x * deformation;
        positions[i + 1] = y * deformation;
        positions[i + 2] = z * deformation;
      }
      
      geometry.attributes.position.needsUpdate = true;
      geometry.computeVertexNormals();
      
      // Cache the geometry
      if (geometryCache.size < PERFORMANCE_CONFIG.GEOMETRY_CACHE_SIZE) {
        geometryCache.set(geometryKey, geometry);
      }
      
      return geometry;
    };

    const leftHemisphereGeometry = useMemo(() => createHemisphereGeometry(true), []);
    const rightHemisphereGeometry = useMemo(() => createHemisphereGeometry(false), []);

    return (
      <group ref={brainRef}>
        {/* Left hemisphere with enhanced shader */}
        <BrainHemisphere
          geometry={leftHemisphereGeometry}
          position={[0.2, 0, 0]}
          areas={areas}
          selectedArea={selectedArea}
        />

        {/* Right hemisphere with enhanced shader */}
        <BrainHemisphere
          geometry={rightHemisphereGeometry}
          position={[-0.2, 0, 0]}
          areas={areas}
          selectedArea={selectedArea}
        />

        {/* Enhanced region markers for better visual feedback (selected only) */}
        {areas.map((area) => {
          const isAreaSelected = selectedArea?.id === area.id;
          
          if (!isAreaSelected) return null;
          
          return (
            <group key={`marker-${area.id}`}>
              {/* Subtle region marker */}
              <mesh
                position={[area.position3D.x * 1.1, area.position3D.y * 1.1, area.position3D.z * 1.1]}
                scale={[0.15, 0.15, 0.15]}
              >
                <sphereGeometry args={[1, 16, 8]} />
                <meshBasicMaterial
                  color={area.color}
                  transparent
                  opacity={isAreaSelected ? 0.8 : 0.5}
                />
              </mesh>
              
              {/* Pulsing ring for selected area */}
              {isAreaSelected && (
                <mesh
                  position={[area.position3D.x * 1.1, area.position3D.y * 1.1, area.position3D.z * 1.1]}
                  rotation={[Math.PI / 2, 0, 0]}
                >
                  <ringGeometry args={[0.3, 0.35, 16]} />
                  <meshBasicMaterial
                    color={area.color}
                    transparent
                    opacity={0.6}
                    side={THREE.DoubleSide}
                  />
                </mesh>
              )}
            </group>
          );
        })}
      </group>
    );
  };

  // Enhanced Lighting Component
  const EnhancedLightingComponent = () => {
    // Initialize enhanced lighting material for global lighting effects
    useEnhancedLighting({
      lightPosition: new THREE.Vector3(8, 12, 8),
      lightDirection: new THREE.Vector3(-0.5, -1, -0.5),
      lightColor: new THREE.Color('#ffffff'),
      lightIntensity: 1.2,
      ambientColor: new THREE.Color('#f0f4f8'),
      ambientIntensity: 0.4,
      baseColor: new THREE.Color('#e8ddd4'),
      metallic: 0.05,
      roughness: 0.8,
      subsurfaceStrength: 0.4,
      shadowStrength: 0.6,
      atmosphericDensity: 0.05,
      atmosphericColor: new THREE.Color('#e6f3ff'),
      rimLightColor: new THREE.Color('#4ecdc4'),
      rimLightPower: 1.8,
      fresnelStrength: 0.8,
      enableVolumetricLighting: false,
      enableSubsurfaceScattering: true,
      enableAtmosphericScattering: false
    });

    return null; // This component just provides the lighting material
  };

  // BrainScene component for 3D visualization
  const BrainScene = () => {
    const { fps } = useShaderPerformance();

      return (
        <>
          {/* Enhanced Lighting Component */}
          <EnhancedLightingComponent />
          
          {/* Advanced lighting setup with multiple light sources */}
          <ambientLight intensity={0.25} color="#f0f4f8" />
          
          {/* Main directional light (sun-like) */}
          <directionalLight 
            position={[8, 12, 8]} 
            intensity={1.0} 
            color="#ffffff"
            castShadow
            shadow-mapSize-width={4096}
            shadow-mapSize-height={4096}
            shadow-camera-near={0.1}
            shadow-camera-far={50}
            shadow-camera-left={-10}
            shadow-camera-right={10}
            shadow-camera-top={10}
            shadow-camera-bottom={-10}
          />
          
          {/* Key light for brain highlighting */}
          <pointLight 
            position={[6, 8, 6]} 
            intensity={0.8} 
            color="#e8f4fd" 
            distance={20}
            decay={2}
          />
          
          {/* Fill light for softer shadows */}
          <pointLight 
            position={[-4, 4, -4]} 
            intensity={0.4} 
            color="#fdf4e8" 
            distance={15}
            decay={2}
          />
          
          {/* Rim light for brain silhouette */}
          <spotLight
            position={[0, 15, -10]}
            angle={Math.PI / 3}
            penumbra={0.8}
            intensity={0.6}
            color="#4ecdc4"
            target-position={[0, 0, 0]}
            distance={25}
            decay={2}
          />
          
          {/* Atmospheric light for depth */}
          <hemisphereLight
            args={["#87ceeb", "#f0e8e0", 0.3]}
          />
          
          {/* Brain structure with enhanced shaders */}
          <BrainOutline 
            areas={knowledgeAreas} 
            selectedArea={selectedArea}
          />
          <BrainConnections areas={knowledgeAreas} />
          
          {/* Knowledge area interaction zones - click only */}
          {knowledgeAreas.map((area) => (
            <BrainRegionHighlighter
              key={area.id}
              area={area}
              isSelected={selectedArea?.id === area.id}
              onSelect={() => setSelectedArea(area)}
            />
          ))}
          
          {/* Performance indicator (development only) */}
          {process.env.NODE_ENV === 'development' && (
            <mesh position={[0, 4, 0]}>
              <planeGeometry args={[1, 0.2]} />
              <meshBasicMaterial 
                color={fps > 45 ? 'green' : fps > 30 ? 'yellow' : 'red'} 
                transparent 
                opacity={0.7}
              />
            </mesh>
          )}
          
          {/* Performance stats display */}
          {process.env.NODE_ENV === 'development' && (
            <Html position={[0, 3.5, 0]} center>
              <div className="bg-black/80 text-white text-xs p-2 rounded">
                <div>FPS: {fps}</div>
                <div>Frame Time: {performanceMonitor.getAverageFrameTime().toFixed(1)}ms</div>
                <div>Geometry Cache: {geometryCache.size}/{PERFORMANCE_CONFIG.GEOMETRY_CACHE_SIZE}</div>
                <div>Material Cache: {materialCache.size}/{PERFORMANCE_CONFIG.MATERIAL_CACHE_SIZE}</div>
              </div>
            </Html>
          )}
          
          {/* Enhanced orbit controls */}
          <OrbitControls
            enablePan={true}
            enableZoom={true}
            enableRotate={true}
            minDistance={4}
            maxDistance={12}
            autoRotate={!selectedArea}
            autoRotateSpeed={0.3}
            enableDamping={true}
            dampingFactor={0.05}
            maxPolarAngle={Math.PI * 0.9}
            minPolarAngle={Math.PI * 0.1}
          />
        </>
      );
    };

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 via-blue-50 to-indigo-100 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-purple-100 rounded-lg">
              <BrainIcon className="w-8 h-8 text-purple-600" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Tessera Brain Visualization</h1>
              <p className="text-gray-600">Enhanced with GLSL Shaders</p>
            </div>
          </div>
          
          {/* Stats */}
          {brainStats && (
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
              <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                <div className="flex items-center gap-2">
                  <Zap className="w-5 h-5 text-blue-500" />
                  <span className="text-sm font-medium text-gray-600">Knowledge Points</span>
                </div>
                <p className="text-2xl font-bold text-gray-900">{brainStats.totalKnowledgePoints}</p>
              </div>
              
              <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-5 h-5 text-green-500" />
                  <span className="text-sm font-medium text-gray-600">Balance Score</span>
                </div>
                <p className="text-2xl font-bold text-gray-900">{brainStats.balanceScore}%</p>
              </div>
              
              <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                <div className="flex items-center gap-2">
                  <Clock className="w-5 h-5 text-orange-500" />
                  <span className="text-sm font-medium text-gray-600">Growth Rate</span>
                </div>
                <p className="text-2xl font-bold text-gray-900">{brainStats.growthRate}%</p>
              </div>
              
              <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                <div className="flex items-center gap-2">
                  <BarChart3 className="w-5 h-5 text-purple-500" />
                  <span className="text-sm font-medium text-gray-600">Dominant Area</span>
                </div>
                <p className="text-lg font-bold text-gray-900 capitalize">{brainStats.dominantArea || 'None'}</p>
              </div>
            </div>
          )}
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* 3D Brain Visualization */}
          <div className="lg:col-span-3">
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-4 border-b border-gray-200">
                <div className="flex items-center justify-between">
                  <h2 className="text-xl font-semibold text-gray-900">3D Brain Model</h2>
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-purple-500" />
                    <span className="text-sm text-gray-600">Enhanced with Shaders</span>
                  </div>
                </div>
              </div>
              
              <div className="relative h-96 lg:h-[600px]" ref={containerRef}>
                {contextLost ? (
                  <div className="absolute inset-0 flex items-center justify-center bg-gray-50">
                    <div className="text-center">
                      <div className="w-16 h-16 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
                        <RotateCw className="w-8 h-8 text-red-500" />
                      </div>
                      <h3 className="text-lg font-semibold text-gray-900 mb-2">WebGL Context Lost</h3>
                      <p className="text-gray-600 mb-4">The 3D visualization encountered an error.</p>
                      <button
                        onClick={() => recoverContext()}
                        className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                      >
                        Recover Context
                      </button>
                    </div>
                  </div>
                ) : (
                  <Suspense fallback={
                    <div className="absolute inset-0 flex items-center justify-center bg-gray-50">
                      <div className="text-center">
                        <div className="w-16 h-16 mx-auto mb-4 bg-blue-100 rounded-full flex items-center justify-center animate-spin">
                          <BrainIcon className="w-8 h-8 text-blue-500" />
                        </div>
                        <p className="text-gray-600">Loading enhanced brain visualization...</p>
                      </div>
                    </div>
                  }>
                    <Canvas
                      ref={canvasRef}
                      camera={{ 
                        position: [0, 0, 8], 
                        fov: 50,
                        near: 0.1,
                        far: 1000
                      }}
                      dpr={[1, 2]}
                      performance={{ min: 0.5 }}
                      onContextMenu={(e) => e.preventDefault()}
                      onCreated={({ gl }) => {
                        // Enhanced WebGL context configuration for shaders
                        
                        // Get the actual WebGL context from the renderer
                        const webglContext = gl.getContext();
                        
                        if (webglContext) {
                          // Set up context loss prevention
                          webglContext.getExtension('WEBGL_lose_context');
                          
                          // Optimize WebGL settings for shader performance
                          webglContext.pixelStorei(webglContext.UNPACK_FLIP_Y_WEBGL, false);
                          webglContext.pixelStorei(webglContext.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
                          
                          // Enable depth testing for proper 3D rendering
                          webglContext.enable(webglContext.DEPTH_TEST);
                          webglContext.depthFunc(webglContext.LEQUAL);
                          
                          // Set clear color
                          webglContext.clearColor(0.97, 0.98, 0.99, 1.0);
                        }
                      }}
                      onError={(error) => {
                        setContextLost(true);
                      }}
                    >
                      <BrainScene />
                    </Canvas>
                  </Suspense>
                )}
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Controls */}
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Controls</h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    View Mode
                  </label>
                  <select
                    value={viewMode}
                    onChange={(e) => setViewMode(e.target.value as '3d' | 'classic')}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="3d">3D Enhanced</option>
                    <option value="classic">Classic View</option>
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Animation Speed: {animationSpeed}x
                  </label>
                  <input
                    type="range"
                    min="0.1"
                    max="3"
                    step="0.1"
                    value={animationSpeed}
                    onChange={(e) => setAnimationSpeed(parseFloat(e.target.value))}
                    className="w-full"
                  />
                </div>
              </div>
            </div>

            {/* Selected Area Info */}
            {selectedArea && (
              <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Selected Region</h3>
                
                <div className="space-y-3">
                  <div>
                    <h4 className="font-medium text-gray-900">{selectedArea.name}</h4>
                    <p className="text-sm text-gray-600 capitalize">{selectedArea.region}</p>
                  </div>
                  
                  <div className="flex items-center gap-2">
                    <div 
                      className="w-4 h-4 rounded-full"
                      style={{ backgroundColor: selectedArea.color }}
                    />
                    <span className="text-sm font-medium">Activity: {selectedArea.percentage}%</span>
                  </div>
                  
                  <div className="text-sm text-gray-600">
                    <p><strong>Connections:</strong> {selectedArea.connections.length}</p>
                    <p><strong>Time Spent:</strong> {selectedArea.timeSpent}h</p>
                    <p><strong>Progress:</strong> {selectedArea.completedContent}/{selectedArea.totalContent}</p>
                  </div>
                </div>
              </div>
            )}

            {/* Knowledge Areas List */}
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Knowledge Areas</h3>
              
              <div className="space-y-2 max-h-64 overflow-y-auto">
                {knowledgeAreas.map((area) => (
                  <div
                    key={area.id}
                    className={`p-3 rounded-lg cursor-pointer transition-colors ${
                      selectedArea?.id === area.id
                        ? 'bg-blue-50 border border-blue-200'
                        : 'hover:bg-gray-50'
                    }`}
                    onClick={() => setSelectedArea(area)}
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <div 
                        className="w-3 h-3 rounded-full"
                        style={{ backgroundColor: area.color }}
                      />
                      <span className="font-medium text-sm">{area.name}</span>
                    </div>
                    <div className="text-xs text-gray-600">
                      {area.percentage}% activity • {area.connections.length} connections
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
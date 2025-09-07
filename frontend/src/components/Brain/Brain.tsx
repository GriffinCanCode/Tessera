import { useEffect, useRef, Suspense, useMemo, useCallback } from 'react';
import { 
  Brain as BrainIcon, 
  Zap, 
  TrendingUp, 
  BarChart3, 
  Info,
  Sparkles,
  Target,
  Clock,
  RotateCw,
  ZoomIn
} from 'lucide-react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Text, Html } from '@react-three/drei';
import * as THREE from 'three';
import { animate as _animate } from 'animejs';
import TesseraAPI from '../../services/api';
import { useBrainStore } from '../../stores';

import type { KnowledgeArea } from '../../stores';

export function Brain() {
  const {
    knowledgeAreas,
    brainStats,
    selectedArea,
    hoveredArea,
    isLoading,
    viewMode,
    animationSpeed,
    contextLost,
    setKnowledgeAreas,
    setBrainStats,
    setSelectedArea,
    setHoveredArea,
    setIsLoading,
    setViewMode,
    setAnimationSpeed,
    setContextLost
  } = useBrainStore();
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const loadingRef = useRef(false);


  // Handle WebGL context recovery
  useEffect(() => {
    if (contextLost) {
      const timer = setTimeout(() => {
        console.info('Attempting automatic WebGL context recovery');
        setContextLost(false);
      }, 3000);
      
      return () => clearTimeout(timer);
    }
  }, [contextLost, setContextLost]);

  // Monitor WebGL context loss
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const handleContextLost = (event: Event) => {
      console.warn('WebGL context lost, attempting recovery...');
      event.preventDefault();
      setContextLost(true);
    };

    const handleContextRestored = () => {
      console.info('WebGL context restored successfully');
      setContextLost(false);
    };

    canvas.addEventListener('webglcontextlost', handleContextLost);
    canvas.addEventListener('webglcontextrestored', handleContextRestored);

    return () => {
      canvas.removeEventListener('webglcontextlost', handleContextLost);
      canvas.removeEventListener('webglcontextrestored', handleContextRestored);
    };
  }, [viewMode, setContextLost]); // Re-attach when view mode changes

  // Helper function to get region colors
  const getRegionColor = useCallback((region: string) => {
    const colors: Record<string, string> = {
      frontal: '#8b5cf6',     // Purple
      parietal: '#06b6d4',    // Cyan
      temporal: '#10b981',    // Emerald
      occipital: '#f59e0b',   // Amber
      cerebellum: '#ef4444',  // Red
      brainstem: '#6366f1',   // Indigo
      limbic: '#ec4899'       // Pink
    };
    return colors[region] || '#9ca3af'; // Gray fallback
  }, []);

  const loadFallbackData = useCallback(() => {
    console.log('Loading fallback data');
    
    // Fallback data when API is not available or learning schema doesn't exist
    const areas: KnowledgeArea[] = [
      {
        id: 'no_data',
        name: 'No Learning Data',
        percentage: 0,
        color: '#9ca3af',
        timeSpent: 0,
        totalContent: 0,
        completedContent: 0,
        region: 'limbic',
        position3D: { x: 0, y: 0, z: 0 },
        scale: 0.5,
        connections: []
      }
    ];

    setKnowledgeAreas(areas);
    setBrainStats({
      totalKnowledgePoints: 0,
      dominantArea: 'No data available',
      balanceScore: 0,
      growthRate: 0
    });
  }, [setBrainStats, setKnowledgeAreas]);

  const loadBrainDataCallback = useCallback(async () => {
    if (loadingRef.current) {
      console.debug('Already loading brain data, skipping');
      return;
    }
    
    try {
      loadingRef.current = true;
      setIsLoading(true);
      console.log('Loading real brain data from API');
      
      // Fetch real learning analytics from the backend
      const response = await TesseraAPI.getLearningAnalytics();
      
      if (!response.success || !response.data) {
        console.warn('Failed to load learning analytics, using fallback data');
        loadFallbackData();
        return;
      }

      const { subjects, brain_stats } = response.data;
      console.info('Received learning data', { subjects: subjects?.length, brain_stats });

      // Enhanced brain regions with anatomically accurate 3D positioning
      const brainRegionMapping = {
        // Programming, Computer Science, Technical Skills - Frontal Lobe (front-top)
        'frontal': { 
          position3D: { x: 0.8, y: 1.0, z: 1.6 }, 
          keywords: ['programming', 'computer', 'software', 'coding', 'algorithm', 'technical', 'engineering', 'development'],
          description: 'Executive functions, problem-solving, programming logic'
        },
        // Mathematics, Logic, Analysis - Parietal Lobe (top-back)
        'parietal': { 
          position3D: { x: 1.4, y: 1.2, z: -0.3 }, 
          keywords: ['math', 'statistics', 'analysis', 'data', 'logic', 'reasoning', 'calculation', 'quantitative'],
          description: 'Spatial reasoning, mathematical processing, analytical thinking'
        },
        // Languages, Communication, Arts - Temporal Lobe (sides)
        'temporal': { 
          position3D: { x: -1.8, y: 0.2, z: 0.4 }, 
          keywords: ['language', 'communication', 'writing', 'literature', 'art', 'music', 'creative', 'linguistic'],
          description: 'Language processing, auditory processing, memory'
        },
        // Visual, Design, Perception - Occipital Lobe (back)
        'occipital': { 
          position3D: { x: -0.2, y: 0.8, z: -2.0 }, 
          keywords: ['visual', 'design', 'graphics', 'image', 'video', 'ui', 'ux', 'perception', 'color'],
          description: 'Visual processing, spatial awareness, design thinking'
        },
        // Motor Skills, Physical Learning - Cerebellum (back-bottom)
        'cerebellum': { 
          position3D: { x: 0.2, y: -1.6, z: -1.0 }, 
          keywords: ['motor', 'physical', 'coordination', 'balance', 'movement', 'skill', 'practice', 'muscle'],
          description: 'Motor learning, coordination, procedural memory'
        },
        // Core Functions, Fundamentals - Brainstem (center-bottom)
        'brainstem': { 
          position3D: { x: 0, y: -2.0, z: 0.2 }, 
          keywords: ['core', 'fundamental', 'basic', 'foundation', 'essential', 'primary', 'key', 'critical'],
          description: 'Core knowledge, fundamental concepts, essential skills'
        },
        // Emotional, Social, Memory - Limbic System (inner-front)
        'limbic': { 
          position3D: { x: 0.6, y: 0.2, z: 0.8 }, 
          keywords: ['emotion', 'social', 'memory', 'personal', 'relationship', 'psychology', 'human', 'behavior'],
          description: 'Emotional learning, social skills, memory formation'
        }
      };

      // Process subjects and categorize them into brain regions
      const areas: KnowledgeArea[] = [];
      const regionCounts: Record<string, number> = {};
      const regionTimeSpent: Record<string, number> = {};
      const regionTotalContent: Record<string, number> = {};
      const regionCompletedContent: Record<string, number> = {};

      // Initialize region counters
      Object.keys(brainRegionMapping).forEach(region => {
        regionCounts[region] = 0;
        regionTimeSpent[region] = 0;
        regionTotalContent[region] = 0;
        regionCompletedContent[region] = 0;
      });

      // Categorize subjects into brain regions
      subjects.forEach((subject: Record<string, unknown>) => {
        const subjectName = (subject.name as string).toLowerCase();
        let assignedRegion = 'limbic'; // Default fallback

        // Find the best matching region based on keywords
        let maxMatches = 0;
        Object.entries(brainRegionMapping).forEach(([region, config]) => {
          const matches = config.keywords.filter(keyword => 
            subjectName.includes(keyword.toLowerCase())
          ).length;
          
          if (matches > maxMatches) {
            maxMatches = matches;
            assignedRegion = region;
          }
        });

        regionCounts[assignedRegion]++;
        regionTimeSpent[assignedRegion] += (subject.time_spent as number) || 0;
        regionTotalContent[assignedRegion] += (subject.total_content as number) || 0;
        regionCompletedContent[assignedRegion] += (subject.completed_content as number) || 0;
      });

      // Create knowledge areas for regions that have content
      Object.entries(regionCounts).forEach(([region, count]) => {
        if (count > 0) {
          const regionConfig = brainRegionMapping[region as keyof typeof brainRegionMapping];
          const completionRate = regionTotalContent[region] > 0 
            ? (regionCompletedContent[region] / regionTotalContent[region]) * 100 
            : 0;

          areas.push({
            id: region,
            name: region.charAt(0).toUpperCase() + region.slice(1),
            percentage: Math.round(completionRate),
            color: getRegionColor(region),
            timeSpent: regionTimeSpent[region],
            totalContent: regionTotalContent[region],
            completedContent: regionCompletedContent[region],
            region: region as KnowledgeArea['region'],
            position3D: regionConfig.position3D,
            scale: Math.max(0.5, Math.min(2.0, count / 2)), // Scale based on subject count
            connections: [] // Could be enhanced to show inter-region connections
          });
        }
      });

      setKnowledgeAreas(areas);
      setBrainStats({
        totalKnowledgePoints: brain_stats.total_knowledge_points || 0,
        dominantArea: brain_stats.dominant_area || 'Unknown',
        balanceScore: brain_stats.balance_score || 0,
        growthRate: brain_stats.growth_rate || 0
      });

      console.log('Successfully loaded brain data', { areas: areas.length });
      
    } catch (error) {
      console.error('Failed to load learning analytics:', error);
      loadFallbackData();
    } finally {
      setIsLoading(false);
      loadingRef.current = false;
    }
  }, [getRegionColor, setBrainStats, setKnowledgeAreas, setIsLoading, loadFallbackData]);

  useEffect(() => {
    loadBrainDataCallback();
  }, [loadBrainDataCallback]);

  const getIntensity = (percentage: number) => {
    return Math.min(1, percentage / 100);
  };

  const formatTime = useCallback((minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  }, []);

  // 3D Brain Components - Interactive Labels and Highlights
  const BrainRegion = useCallback(({ area, isSelected, isHovered, onSelect, onHover, onUnhover }: {
    area: KnowledgeArea;
    isSelected: boolean;
    isHovered: boolean;
    onSelect: () => void;
    onHover: () => void;
    onUnhover: () => void;
  }) => {
    const intensity = getIntensity(area.percentage);
    
    // Create an invisible interaction mesh at the region position for clicking
    return (
      <group position={[area.position3D.x, area.position3D.y, area.position3D.z]}>
        {/* Invisible interaction sphere for clicking */}
        <mesh
          onClick={onSelect}
          onPointerEnter={onHover}
          onPointerLeave={onUnhover}
        >
          <sphereGeometry args={[0.5, 16, 8]} />
          <meshStandardMaterial
            transparent
            opacity={0}
          />
        </mesh>
        
        {/* Knowledge area label */}
        <Text
          position={[0, -0.7, 0]}
          fontSize={isSelected || isHovered ? 0.16 : 0.12}
          color={area.color}
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.02}
          outlineColor="#000000"
        >
          {area.name}
        </Text>
        
        {/* Percentage indicator */}
        <Text
          position={[0, -0.9, 0]}
          fontSize={isSelected || isHovered ? 0.14 : 0.1}
          color={intensity > 0.5 ? area.color : "#666"}
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.01}
          outlineColor="#ffffff"
        >
          {area.percentage}%
        </Text>

        {/* Activity indicator ring for high-activity areas */}
        {intensity > 0.4 && (
          <mesh 
            rotation={[Math.PI / 2, 0, 0]} 
            position={[0, -0.3, 0]}
            scale={isSelected || isHovered ? [1.3, 1.3, 1.3] : [1, 1, 1]}
          >
            <ringGeometry args={[0.4, 0.5, 16]} />
            <meshStandardMaterial
              color={area.color}
              opacity={0.6 + intensity * 0.3}
              transparent
              side={THREE.DoubleSide}
              emissive={area.color}
              emissiveIntensity={intensity * 0.4}
            />
          </mesh>
        )}

        {/* Pulsing energy effect for very active areas */}
        {intensity > 0.7 && (
          <group>
            {[0, 1, 2].map((i) => (
              <mesh 
                key={i} 
                rotation={[Math.PI / 2, 0, (Math.PI * 2 * i) / 3]} 
                position={[0, -0.2, 0]}
              >
                <ringGeometry args={[0.6, 0.65, 12]} />
                <meshStandardMaterial
                  color={area.color}
                  opacity={0.3}
                  transparent
                  side={THREE.DoubleSide}
                  emissive={area.color}
                  emissiveIntensity={0.3}
                />
              </mesh>
            ))}
          </group>
        )}

        {/* Selection/Hover highlight */}
        {(isSelected || isHovered) && (
          <mesh position={[0, -0.3, 0]} rotation={[Math.PI / 2, 0, 0]}>
            <ringGeometry args={[0.6, 0.8, 24]} />
            <meshStandardMaterial
              color={area.color}
              opacity={isSelected ? 0.8 : 0.5}
              transparent
              side={THREE.DoubleSide}
              emissive={area.color}
              emissiveIntensity={isSelected ? 0.6 : 0.3}
            />
          </mesh>
        )}

        {/* Hover tooltip */}
        {isHovered && (
          <Html distanceFactor={8} position={[0, 0.9, 0]}>
            <div className="bg-gray-900 bg-opacity-95 text-white p-4 rounded-xl text-sm max-w-xs pointer-events-none shadow-2xl border border-gray-700 backdrop-blur-sm">
              <div className="font-bold text-lg mb-2" style={{ color: area.color }}>
                {area.name}
              </div>
              <div className="space-y-1">
                <div className="flex justify-between">
                  <span className="text-gray-300">Mastery:</span>
                  <span className="font-semibold">{area.percentage}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-300">Time:</span>
                  <span className="font-semibold">{formatTime(area.timeSpent)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-300">Progress:</span>
                  <span className="font-semibold">{area.completedContent}/{area.totalContent}</span>
                </div>
                <div className="text-xs text-gray-400 mt-2 pt-2 border-t border-gray-700">
                  Brain Region: {area.region.charAt(0).toUpperCase() + area.region.slice(1)}
                </div>
              </div>
            </div>
          </Html>
        )}
      </group>
    );
  }, [formatTime]);

  const BrainConnections = ({ areas }: { areas: KnowledgeArea[] }) => {
    return (
      <>
        {areas.map((area) =>
          area.connections.map((connectionId) => {
            const connectedArea = areas.find(a => a.id === connectionId);
            if (!connectedArea) return null;

            const start = new THREE.Vector3(area.position3D.x, area.position3D.y, area.position3D.z);
            const end = new THREE.Vector3(connectedArea.position3D.x, connectedArea.position3D.y, connectedArea.position3D.z);
            const curve = new THREE.CatmullRomCurve3([
              start,
              new THREE.Vector3(
                (start.x + end.x) / 2,
                Math.max(start.y, end.y) + 0.5,
                (start.z + end.z) / 2
              ),
              end
            ]);

            return (
              <group key={`${area.id}-${connectionId}`}>
                <mesh>
                  <tubeGeometry args={[curve, 20, 0.02, 8, false]} />
                  <meshStandardMaterial
                    color="#4f46e5"
                    opacity={0.3}
                    transparent
                    emissive="#4f46e5"
                    emissiveIntensity={0.1}
                  />
                </mesh>
              </group>
            );
          })
        )}
      </>
    );
  };

  const BrainOutline = ({ areas }: { areas: KnowledgeArea[] }) => {
    const brainRef = useRef<THREE.Group>(null);
    
    useFrame((state) => {
      if (brainRef.current) {
        brainRef.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.1) * 0.05;
      }
    });

    // Get region color and intensity
    const getRegionColorAndIntensity = (regionName: string) => {
      const area = areas.find(a => a.region === regionName);
      if (!area) return { color: '#f8f9fa', intensity: 0, opacity: 0.15 };
      const intensity = getIntensity(area.percentage);
      return { 
        color: area.color, 
        intensity: intensity,
        opacity: 0.3 + (intensity * 0.4)
      };
    };

    // Create hemisphere geometries
    const createHemisphereGeometry = (isLeft: boolean) => {
      const geometry = new THREE.SphereGeometry(2.2, 64, 32, 0, Math.PI * (isLeft ? 1 : -1), 0, Math.PI);
      const positions = geometry.attributes.position.array as Float32Array;
      
      // Deform the hemisphere to make it more brain-like
      for (let i = 0; i < positions.length; i += 3) {
        const x = positions[i];
        const y = positions[i + 1];
        const z = positions[i + 2];
        
        // Create brain-like bulges and indentations
        const noise1 = Math.sin(x * 2) * Math.cos(y * 2) * 0.15;
        const noise2 = Math.sin(z * 3) * Math.cos(x * 1.5) * 0.1;
        const noise3 = Math.sin(y * 2.5) * Math.cos(z * 2) * 0.12;
        
        // Add cerebral cortex-like wrinkles
        const wrinkle1 = Math.sin(x * 8) * Math.cos(y * 6) * 0.05;
        const wrinkle2 = Math.sin(z * 7) * Math.cos(x * 9) * 0.04;
        
        // Flatten the bottom slightly (brainstem area)
        const flattenBottom = y < -1 ? Math.abs(y + 1) * 0.3 : 0;
        
        // Create the characteristic brain bulges
        const frontBulge = x > 0 && z > 0 ? Math.sin(x * 1.5) * 0.2 : 0;
        const backBulge = x < 0 && z < -0.5 ? Math.cos(x * 2) * 0.15 : 0;
        
        // Apply deformations
        const deformation = 1 + noise1 + noise2 + noise3 + wrinkle1 + wrinkle2 + frontBulge + backBulge - flattenBottom;
        
        positions[i] = x * deformation;
        positions[i + 1] = y * deformation;
        positions[i + 2] = z * deformation;
      }
      
      geometry.attributes.position.needsUpdate = true;
      geometry.computeVertexNormals();
      
      return geometry;
    };

    const leftHemisphereGeometry = useMemo(() => createHemisphereGeometry(true), []);
    const rightHemisphereGeometry = useMemo(() => createHemisphereGeometry(false), []);

    // Create brain region geometries
    const createRegionGeometry = (regionType: string) => {
      let geometry: THREE.BufferGeometry;
      let position: [number, number, number] = [0, 0, 0];
      let scale: [number, number, number] = [1, 1, 1];

      switch (regionType) {
        case 'frontal':
          // Front part of brain
          geometry = new THREE.SphereGeometry(1.2, 32, 16, 0, Math.PI, 0, Math.PI * 0.7);
          position = [0.8, 0.5, 1.2];
          break;
        case 'parietal':
          // Top-back part
          geometry = new THREE.SphereGeometry(1.0, 32, 16, Math.PI * 0.3, Math.PI * 0.4, 0, Math.PI * 0.6);
          position = [0.2, 1.0, -0.5];
          break;
        case 'temporal':
          // Side parts
          geometry = new THREE.SphereGeometry(0.8, 32, 16, Math.PI * 0.5, Math.PI, Math.PI * 0.3, Math.PI * 0.4);
          position = [-1.5, 0, 0.2];
          break;
        case 'occipital':
          // Back part
          geometry = new THREE.SphereGeometry(0.9, 32, 16, Math.PI * 0.8, Math.PI * 0.4, 0, Math.PI * 0.8);
          position = [-0.5, 0.3, -1.8];
          break;
        case 'cerebellum':
          // Bottom-back
          geometry = new THREE.SphereGeometry(0.7, 24, 12);
          position = [0, -1.8, -1.2];
          scale = [0.8, 0.6, 0.8];
          break;
        case 'brainstem':
          // Center-bottom
          geometry = new THREE.CylinderGeometry(0.3, 0.4, 1.2, 16);
          position = [0, -2.2, 0];
          break;
        case 'limbic':
          // Inner structures
          geometry = new THREE.SphereGeometry(0.6, 24, 12);
          position = [0.3, 0.1, 0.5];
          scale = [1.2, 0.8, 1.0];
          break;
        default:
          geometry = new THREE.SphereGeometry(0.5, 16, 8);
      }

      return { geometry, position, scale };
    };

    return (
      <group ref={brainRef}>
        {/* Left Hemisphere */}
        <mesh geometry={leftHemisphereGeometry} position={[0.2, 0, 0]}>
          <meshStandardMaterial
            color={getRegionColorAndIntensity('temporal').color}
            opacity={Math.max(0.15, getRegionColorAndIntensity('temporal').opacity)}
            transparent
            wireframe={false}
            roughness={0.6}
            metalness={0.2}
            emissive={getRegionColorAndIntensity('temporal').color}
            emissiveIntensity={getRegionColorAndIntensity('temporal').intensity * 0.2}
          />
        </mesh>

        {/* Right Hemisphere */}
        <mesh geometry={rightHemisphereGeometry} position={[-0.2, 0, 0]}>
          <meshStandardMaterial
            color={getRegionColorAndIntensity('parietal').color}
            opacity={Math.max(0.15, getRegionColorAndIntensity('parietal').opacity)}
            transparent
            wireframe={false}
            roughness={0.6}
            metalness={0.2}
            emissive={getRegionColorAndIntensity('parietal').color}
            emissiveIntensity={getRegionColorAndIntensity('parietal').intensity * 0.2}
          />
        </mesh>

        {/* Individual Brain Regions */}
        {areas.map((area) => {
          const regionGeom = createRegionGeometry(area.region);
          const { color, intensity, opacity } = getRegionColorAndIntensity(area.region);
          
          return (
            <mesh
              key={`region-${area.region}`}
              geometry={regionGeom.geometry}
              position={regionGeom.position}
              scale={regionGeom.scale}
            >
              <meshStandardMaterial
                color={color}
                opacity={Math.max(0.2, opacity)}
                transparent
                wireframe={false}
                roughness={0.4}
                metalness={0.3}
                emissive={color}
                emissiveIntensity={intensity * 0.4}
              />
            </mesh>
          );
        })}

        {/* Cerebellum with specific coloring */}
        <mesh position={[0, -1.8, -1.2]} scale={[0.6, 0.5, 0.6]}>
          <sphereGeometry args={[0.8, 32, 16]} />
          <meshStandardMaterial
            color={getRegionColorAndIntensity('cerebellum').color}
            opacity={Math.max(0.12, getRegionColorAndIntensity('cerebellum').opacity)}
            transparent
            wireframe={false}
            roughness={0.7}
            metalness={0.1}
            emissive={getRegionColorAndIntensity('cerebellum').color}
            emissiveIntensity={getRegionColorAndIntensity('cerebellum').intensity * 0.3}
          />
        </mesh>
        
        {/* Brainstem with specific coloring */}
        <mesh position={[0, -2.2, 0]} rotation={[0, 0, 0]}>
          <cylinderGeometry args={[0.3, 0.4, 1.2, 16]} />
          <meshStandardMaterial
            color={getRegionColorAndIntensity('brainstem').color}
            opacity={Math.max(0.1, getRegionColorAndIntensity('brainstem').opacity)}
            transparent
            wireframe={false}
            roughness={0.8}
            metalness={0.1}
            emissive={getRegionColorAndIntensity('brainstem').color}
            emissiveIntensity={getRegionColorAndIntensity('brainstem').intensity * 0.3}
          />
        </mesh>
        
        {/* Corpus callosum - connecting structure */}
        <mesh position={[0, 0, 0]} rotation={[0, 0, Math.PI / 2]}>
          <cylinderGeometry args={[0.08, 0.08, 2.5, 8]} />
          <meshStandardMaterial
            color="#dee2e6"
            opacity={0.1}
            transparent
            wireframe={false}
            emissive="#ffffff"
            emissiveIntensity={0.05}
          />
        </mesh>

        {/* Brain outline wireframe for structure */}
        <mesh geometry={leftHemisphereGeometry} position={[0.2, 0, 0]}>
          <meshStandardMaterial
            color="#e9ecef"
            opacity={0.05}
            transparent
            wireframe={true}
          />
        </mesh>
        <mesh geometry={rightHemisphereGeometry} position={[-0.2, 0, 0]}>
          <meshStandardMaterial
            color="#e9ecef"
            opacity={0.05}
            transparent
            wireframe={true}
          />
        </mesh>
      </group>
    );
  };

  // Memoized BrainScene component for 3D visualization to prevent unnecessary re-renders
  const BrainScene = useMemo(() => {
    return () => (
      <>
        {/* Enhanced lighting setup for better brain visualization */}
        <ambientLight intensity={0.3} color="#f8f9fa" />
        <directionalLight 
          position={[5, 8, 5]} 
          intensity={0.8} 
          color="#ffffff"
          castShadow
          shadow-mapSize-width={2048}
          shadow-mapSize-height={2048}
        />
        <pointLight position={[10, 5, 10]} intensity={0.6} color="#e3f2fd" />
        <pointLight position={[-8, -5, -8]} intensity={0.4} color="#f3e5f5" />
        <spotLight
          position={[0, 10, 0]}
          angle={Math.PI / 4}
          penumbra={0.5}
          intensity={0.5}
          color="#fff3e0"
          target-position={[0, 0, 0]}
        />
        
        {/* Brain structure */}
        <BrainOutline areas={knowledgeAreas} />
        <BrainConnections areas={knowledgeAreas} />
        
        {/* Knowledge areas */}
        {knowledgeAreas.map((area) => (
          <BrainRegion
            key={area.id}
            area={area}
            isSelected={selectedArea?.id === area.id}
            isHovered={hoveredArea?.id === area.id}
            onSelect={() => setSelectedArea(area)}
            onHover={() => setHoveredArea(area)}
            onUnhover={() => setHoveredArea(null)}
          />
        ))}
        
        {/* Enhanced orbit controls */}
        <OrbitControls
          enablePan={true}
          enableZoom={true}
          enableRotate={true}
          minDistance={4}
          maxDistance={12}
          autoRotate={!selectedArea && !hoveredArea}
          autoRotateSpeed={0.3}
          enableDamping={true}
          dampingFactor={0.05}
          maxPolarAngle={Math.PI * 0.9}
          minPolarAngle={Math.PI * 0.1}
        />
      </>
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [knowledgeAreas, selectedArea, hoveredArea, setHoveredArea, setSelectedArea]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 via-blue-50 to-indigo-100 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-4">
            <div className="p-4 bg-gradient-to-r from-purple-600 to-blue-600 rounded-full">
              <BrainIcon className="h-12 w-12 text-white" />
            </div>
          </div>
          <h1 className="text-4xl font-bold bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent mb-2">
            Your Knowledge Brain
          </h1>
          <p className="text-lg text-gray-600 max-w-2xl mx-auto">
            Visualize the distribution of your learning across different subjects. 
            Each region represents your mastery level in different knowledge domains.
          </p>
        </div>

        {/* Brain Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-lg p-6 border border-purple-100">
            <div className="flex items-center">
              <div className="p-3 bg-purple-100 rounded-lg">
                <Sparkles className="h-6 w-6 text-purple-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Total Knowledge</p>
                <p className="text-2xl font-bold text-gray-900">{brainStats.totalKnowledgePoints}%</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border border-blue-100">
            <div className="flex items-center">
              <div className="p-3 bg-blue-100 rounded-lg">
                <Target className="h-6 w-6 text-blue-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Dominant Area</p>
                <p className="text-lg font-bold text-gray-900">{brainStats.dominantArea}</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border border-green-100">
            <div className="flex items-center">
              <div className="p-3 bg-green-100 rounded-lg">
                <BarChart3 className="h-6 w-6 text-green-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Balance Score</p>
                <p className="text-2xl font-bold text-gray-900">{brainStats.balanceScore}%</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border border-orange-100">
            <div className="flex items-center">
              <div className="p-3 bg-orange-100 rounded-lg">
                <TrendingUp className="h-6 w-6 text-orange-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Growth Rate</p>
                <p className="text-2xl font-bold text-gray-900">+{brainStats.growthRate}%</p>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Brain Visualization */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-xl shadow-lg p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-900 flex items-center">
                  <Zap className="h-6 w-6 text-yellow-500 mr-2" />
                  Knowledge Distribution
                </h2>
                <div className="flex items-center space-x-4">
                  {/* View Mode Toggle */}
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => setViewMode(viewMode === '3d' ? 'classic' : '3d')}
                      className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                        viewMode === '3d' 
                          ? 'bg-purple-100 text-purple-700' 
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {viewMode === '3d' ? '3D View' : 'Classic View'}
                    </button>
                  </div>
                  
                  {/* Animation Speed Control */}
                  {viewMode === '3d' && (
                    <div className="flex items-center space-x-2">
                      <span className="text-xs text-gray-500">Speed:</span>
                      <input
                        type="range"
                        min="0.1"
                        max="2"
                        step="0.1"
                        value={animationSpeed}
                        onChange={(e) => setAnimationSpeed(parseFloat(e.target.value))}
                        className="w-16 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                      />
                    </div>
                  )}
                  
                  {/* Legend for classic view */}
                  {viewMode === 'classic' && (
                    <div className="flex items-center space-x-4 text-sm text-gray-500">
                      <div className="flex items-center">
                        <div className="w-3 h-3 bg-gradient-to-r from-red-400 to-red-600 rounded-full mr-2"></div>
                        <span>Low (0-30%)</span>
                      </div>
                      <div className="flex items-center">
                        <div className="w-3 h-3 bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full mr-2"></div>
                        <span>Medium (30-60%)</span>
                      </div>
                      <div className="flex items-center">
                        <div className="w-3 h-3 bg-gradient-to-r from-green-400 to-green-600 rounded-full mr-2"></div>
                        <span>High (60%+)</span>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              <div className="relative">
                {viewMode === '3d' ? (
                  <div className="w-full h-96 border border-gray-200 rounded-lg overflow-hidden">
                    {isLoading ? (
                      <div className="flex items-center justify-center h-full bg-gradient-to-b from-blue-50 to-purple-50">
                        <div className="text-center">
                          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mx-auto mb-4"></div>
                          <p className="text-gray-600">Loading brain data...</p>
                        </div>
                      </div>
                    ) : knowledgeAreas.length === 1 && knowledgeAreas[0].id === 'no_data' ? (
                      <div className="flex items-center justify-center h-full bg-gradient-to-b from-blue-50 to-purple-50">
                        <div className="text-center p-8">
                          <BrainIcon className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                          <h3 className="text-lg font-semibold text-gray-600 mb-2">No Learning Data Available</h3>
                          <p className="text-gray-500 mb-4">Add learning content to see your knowledge brain</p>
                          <p className="text-sm text-gray-400">Run setup_learning_database.pl to initialize</p>
                        </div>
                      </div>
                    ) : contextLost ? (
                      <div className="flex flex-col items-center justify-center h-full bg-gradient-to-b from-blue-50 to-purple-50">
                        <div className="text-amber-600 mb-4">⚠️ WebGL Context Lost</div>
                        <button 
                          onClick={() => {
                            setContextLost(false);
                            setViewMode('3d');
                          }}
                          className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
                        >
                          Reload 3D Brain
                        </button>
                        <button 
                          onClick={() => setViewMode('classic')}
                          className="mt-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
                        >
                          Switch to 2D View
                        </button>
                      </div>
                    ) : (
                      <Suspense fallback={
                        <div className="flex items-center justify-center h-full bg-gradient-to-b from-blue-50 to-purple-50">
                          <div className="animate-pulse text-purple-600">Loading 3D Brain...</div>
                        </div>
                      }>
                        <Canvas
                          key={`brain-canvas-${contextLost ? 'recovery' : 'normal'}`}
                          ref={canvasRef}
                          camera={{ 
                            position: [3, 2, 7], 
                            fov: 45,
                            near: 0.1,
                            far: 100
                          }}
                          style={{ background: 'linear-gradient(135deg, #f8fafc 0%, #e2e8f0 50%, #f1f5f9 100%)' }}
                          gl={{ 
                            preserveDrawingBuffer: false,
                            antialias: true,
                            alpha: false,
                            powerPreference: "high-performance",
                            failIfMajorPerformanceCaveat: false
                          }}
                        >
                          <BrainScene />
                        </Canvas>
                      </Suspense>
                    )}
                  </div>
                ) : (
                  // Classic 2D SVG view (existing code)
                  <>
                    <svg 
                      viewBox="0 0 600 400" 
                      className="w-full h-96 border border-gray-200 rounded-lg bg-gradient-to-b from-blue-50 to-purple-50"
                    >
                      {/* Brain outline */}
                      <defs>
                        <filter id="glow">
                          <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
                          <feMerge> 
                            <feMergeNode in="coloredBlur"/>
                            <feMergeNode in="SourceGraphic"/>
                          </feMerge>
                        </filter>
                      </defs>

                      {/* Brain base shape */}
                      <ellipse 
                        cx="300" 
                        cy="200" 
                        rx="200" 
                        ry="150" 
                        fill="none" 
                        stroke="#e5e7eb" 
                        strokeWidth="2"
                        strokeDasharray="5,5"
                      />

                      {/* No data message */}
                      {knowledgeAreas.length === 1 && knowledgeAreas[0].id === 'no_data' && (
                        <g>
                          <rect x="150" y="100" width="300" height="200" fill="#f3f4f6" stroke="#d1d5db" strokeWidth="2" rx="10" />
                          <text x="300" y="180" textAnchor="middle" className="text-sm fill-gray-600">
                            No learning data available
                          </text>
                          <text x="300" y="200" textAnchor="middle" className="text-xs fill-gray-500">
                            Add learning content to see your knowledge brain
                          </text>
                          <text x="300" y="220" textAnchor="middle" className="text-xs fill-gray-500">
                            Run setup_learning_database.pl to initialize
                          </text>
                        </g>
                      )}

                      {/* Knowledge areas - simplified for classic view */}
                      {knowledgeAreas.filter(area => area.id !== 'no_data').map((area, index) => {
                        const intensity = getIntensity(area.percentage);
                        const isActive = hoveredArea?.id === area.id || selectedArea?.id === area.id;
                        
                        // Simple grid positioning for classic view
                        const cols = 3;
                        const x = 150 + (index % cols) * 100;
                        const y = 150 + Math.floor(index / cols) * 80;
                        
                        return (
                          <g key={area.id}>
                            <circle
                              cx={x}
                              cy={y}
                              r={30}
                              fill={area.color}
                              fillOpacity={0.3 + intensity * 0.5}
                              stroke={area.color}
                              strokeWidth={isActive ? 3 : 1}
                              filter={isActive ? "url(#glow)" : "none"}
                              className="cursor-pointer transition-all duration-300"
                              onMouseEnter={() => setHoveredArea(area)}
                              onMouseLeave={() => setHoveredArea(null)}
                              onClick={() => setSelectedArea(area)}
                            />
                            
                            <text
                              x={x}
                              y={y}
                              textAnchor="middle"
                              dominantBaseline="middle"
                              className="text-xs font-semibold pointer-events-none"
                              fill={intensity > 0.5 ? 'white' : area.color}
                            >
                              {area.percentage}%
                            </text>
                          </g>
                        );
                      })}

                      {/* Brain regions labels */}
                      <text x="100" y="50" className="text-xs font-medium fill-gray-500">Frontal Lobe</text>
                      <text x="450" y="50" className="text-xs font-medium fill-gray-500">Parietal Lobe</text>
                      <text x="50" y="250" className="text-xs font-medium fill-gray-500">Temporal Lobe</text>
                      <text x="200" y="370" className="text-xs font-medium fill-gray-500">Cerebellum</text>
                    </svg>

                    {/* Hover tooltip for classic view */}
                    {hoveredArea && viewMode === 'classic' && (
                      <div className="absolute top-4 right-4 bg-black bg-opacity-75 text-white p-3 rounded-lg text-sm max-w-xs">
                        <div className="font-semibold">{hoveredArea.name}</div>
                        <div>Mastery: {hoveredArea.percentage}%</div>
                        <div>Time: {formatTime(hoveredArea.timeSpent)}</div>
                        <div>Progress: {hoveredArea.completedContent}/{hoveredArea.totalContent}</div>
                      </div>
                    )}
                  </>
                )}
              </div>

              {/* 3D Controls */}
              {viewMode === '3d' && !isLoading && knowledgeAreas[0]?.id !== 'no_data' && (
                <div className="mt-4 flex items-center justify-center space-x-4 text-sm text-gray-500">
                  <div className="flex items-center space-x-1">
                    <RotateCw className="h-4 w-4" />
                    <span>Click & drag to rotate</span>
                  </div>
                  <div className="flex items-center space-x-1">
                    <ZoomIn className="h-4 w-4" />
                    <span>Scroll to zoom</span>
                  </div>
                  <div className="text-xs text-purple-600">
                    Auto-rotation: {!selectedArea && !hoveredArea ? 'On' : 'Off'}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Knowledge Area Details */}
          <div>
            <div className="bg-white rounded-xl shadow-lg p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <Info className="h-5 w-5 text-blue-600 mr-2" />
                {selectedArea ? selectedArea.name : 'Knowledge Areas'}
              </h3>

              {selectedArea ? (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Mastery Level</span>
                    <span className="text-lg font-bold" style={{ color: selectedArea.color }}>
                      {selectedArea.percentage}%
                    </span>
                  </div>
                  
                  <div className="w-full bg-gray-200 rounded-full h-3">
                    <div
                      className="h-3 rounded-full transition-all duration-500"
                      style={{ 
                        width: `${selectedArea.percentage}%`,
                        backgroundColor: selectedArea.color 
                      }}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="text-gray-600">Time Invested</span>
                      <div className="font-semibold">{formatTime(selectedArea.timeSpent)}</div>
                    </div>
                    <div>
                      <span className="text-gray-600">Content Progress</span>
                      <div className="font-semibold">{selectedArea.completedContent}/{selectedArea.totalContent}</div>
                    </div>
                    <div>
                      <span className="text-gray-600">Brain Region</span>
                      <div className="font-semibold capitalize">{selectedArea.region} Lobe</div>
                    </div>
                    <div>
                      <span className="text-gray-600">Status</span>
                      <div className="font-semibold">
                        {selectedArea.percentage >= 70 ? 'Expert' :
                         selectedArea.percentage >= 50 ? 'Advanced' :
                         selectedArea.percentage >= 30 ? 'Intermediate' : 'Beginner'}
                      </div>
                    </div>
                  </div>

                  <div className="pt-4 border-t border-gray-200">
                    <h4 className="font-semibold text-gray-900 mb-2">Recommendations</h4>
                    <div className="text-sm text-gray-600">
                      {selectedArea.percentage < 50 ? 
                        `Focus on foundational concepts in ${selectedArea.name} to build stronger knowledge base.` :
                        `Consider advanced topics in ${selectedArea.name} or explore related subjects.`
                      }
                    </div>
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  <p className="text-sm text-gray-600 mb-4">
                    Click on any brain region to see detailed information about your knowledge in that area.
                  </p>
                  
                  {knowledgeAreas.map((area) => (
                    <div 
                      key={area.id}
                      className="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50 cursor-pointer"
                      onClick={() => setSelectedArea(area)}
                    >
                      <div className="flex items-center">
                        <div 
                          className="w-4 h-4 rounded-full mr-3"
                          style={{ backgroundColor: area.color }}
                        />
                        <span className="text-sm font-medium">{area.name}</span>
                      </div>
                      <span className="text-sm font-bold" style={{ color: area.color }}>
                        {area.percentage}%
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Learning Balance */}
            <div className="bg-white rounded-xl shadow-lg p-6 mt-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <Clock className="h-5 w-5 text-green-600 mr-2" />
                Learning Balance
              </h3>
              
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Overall Balance</span>
                  <span className="text-lg font-bold text-green-600">{brainStats.balanceScore}%</span>
                </div>
                
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-gradient-to-r from-green-400 to-green-600 h-2 rounded-full transition-all duration-500"
                    style={{ width: `${brainStats.balanceScore}%` }}
                  />
                </div>

                <div className="text-xs text-gray-500">
                  {brainStats.balanceScore >= 80 ? 'Excellent balance across knowledge domains!' :
                   brainStats.balanceScore >= 60 ? 'Good balance, consider strengthening weaker areas.' :
                   'Focus on balancing your learning across different subjects.'}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

# GLSL Shader Integration Guide

This guide shows how to integrate the new GLSL shaders into your existing Tessera brain visualization.

## Quick Start

### 1. Replace Standard Materials

**Before (Standard THREE.js materials):**
```tsx
<mesh>
  <sphereGeometry args={[2, 64, 32]} />
  <meshStandardMaterial
    color="#f8f9fa"
    opacity={0.8}
    transparent
    emissive="#4f46e5"
    emissiveIntensity={0.1}
  />
</mesh>
```

**After (Enhanced GLSL shaders):**
```tsx
import { useBrainShader } from '../hooks/useShaders';

function BrainRegion({ area }) {
  const brainMaterial = useBrainShader({
    brainColor: new THREE.Color(area.color),
    brainActivity: area.percentage / 100,
    knowledgeIntensity: 0.8,
    showNeuralActivity: true
  });

  return (
    <mesh>
      <sphereGeometry args={[2, 64, 32]} />
      <primitive object={brainMaterial} />
    </mesh>
  );
}
```

### 2. Enhanced Neural Connections

**Before (Simple tube geometry):**
```tsx
<mesh>
  <tubeGeometry args={[curve, 20, 0.02, 8]} />
  <meshStandardMaterial
    color="#4f46e5"
    opacity={0.3}
    transparent
  />
</mesh>
```

**After (Dynamic electrical impulses):**
```tsx
import { useNeuralConnectionShader } from '../hooks/useShaders';

function NeuralConnection({ startPoint, endPoint, activity }) {
  const connectionMaterial = useNeuralConnectionShader({
    startPoint,
    endPoint,
    connectionActivity: activity,
    pulseSpeed: 2.0,
    showElectricalActivity: true
  });

  return (
    <mesh>
      <tubeGeometry args={[curve, 20, 0.02, 8]} />
      <primitive object={connectionMaterial} />
    </mesh>
  );
}
```

## Step-by-Step Integration

### Step 1: Update Your Brain Component

```tsx
// Import the new shader hooks
import { 
  useBrainShader, 
  useNeuralConnectionShader,
  useShaderPerformance 
} from '../hooks/useShaders';

// Replace your existing Brain component
function EnhancedBrain() {
  const { fps } = useShaderPerformance();
  
  // Monitor performance
  useEffect(() => {
    if (fps < 30) {
      console.warn('Consider reducing shader quality for better performance');
    }
  }, [fps]);

  return (
    <Canvas>
      <BrainWithShaders areas={knowledgeAreas} />
    </Canvas>
  );
}
```

### Step 2: Configure Shader Parameters

```tsx
// Customize shader behavior based on your data
const brainMaterial = useBrainShader({
  brainColor: new THREE.Color(area.color),
  brainActivity: calculateActivity(area), // Your custom function
  knowledgeIntensity: area.importance,
  activityCenter: new THREE.Vector3(area.x, area.y, area.z),
  showNeuralActivity: area.isActive,
  deformationStrength: area.isSelected ? 1.5 : 1.0
});
```

### Step 3: Handle Dynamic Updates

```tsx
// Shaders automatically update when config changes
const [activityLevel, setActivityLevel] = useState(0.5);

const brainMaterial = useBrainShader({
  brainActivity: activityLevel, // Will update shader when this changes
  // ... other config
});

// Update activity based on user interaction or data
useEffect(() => {
  const interval = setInterval(() => {
    setActivityLevel(Math.random());
  }, 1000);
  
  return () => clearInterval(interval);
}, []);
```

## Migration from Existing Code

### Replace BrainOutline Component

**Old:**
```tsx
const BrainOutline = ({ areas }) => {
  return (
    <group>
      <mesh geometry={leftHemisphere}>
        <meshStandardMaterial color="#f8f9fa" />
      </mesh>
      <mesh geometry={rightHemisphere}>
        <meshStandardMaterial color="#f8f9fa" />
      </mesh>
    </group>
  );
};
```

**New:**
```tsx
const BrainOutline = ({ areas }) => {
  const leftMaterial = useBrainShader({
    brainColor: new THREE.Color('#f8f9fa'),
    brainActivity: calculateOverallActivity(areas),
    showNeuralActivity: true
  });

  const rightMaterial = useBrainShader({
    brainColor: new THREE.Color('#f8f9fa'),
    brainActivity: calculateOverallActivity(areas),
    showNeuralActivity: true
  });

  return (
    <group>
      <mesh geometry={leftHemisphere}>
        <primitive object={leftMaterial} />
      </mesh>
      <mesh geometry={rightHemisphere}>
        <primitive object={rightMaterial} />
      </mesh>
    </group>
  );
};
```

### Replace BrainConnections Component

**Old:**
```tsx
const BrainConnections = ({ areas }) => {
  return (
    <>
      {connections.map(connection => (
        <mesh key={connection.id}>
          <tubeGeometry args={[curve, 20, 0.02, 8]} />
          <meshStandardMaterial color="#4f46e5" />
        </mesh>
      ))}
    </>
  );
};
```

**New:**
```tsx
const BrainConnections = ({ areas }) => {
  return (
    <>
      {connections.map(connection => {
        const material = useNeuralConnectionShader({
          startPoint: connection.start,
          endPoint: connection.end,
          connectionActivity: connection.activity,
          signalStrength: connection.strength
        });

        return (
          <mesh key={connection.id}>
            <tubeGeometry args={[curve, 20, 0.02, 8]} />
            <primitive object={material} />
          </mesh>
        );
      })}
    </>
  );
};
```

## Performance Optimization

### Conditional Rendering

```tsx
function OptimizedBrain({ areas, quality = 'high' }) {
  const brainMaterial = useBrainShader({
    brainColor: new THREE.Color('#f8f9fa'),
    brainActivity: 0.7,
    showNeuralActivity: quality !== 'low',
    deformationStrength: quality === 'high' ? 1.0 : 0.5
  });

  return (
    <mesh>
      <sphereGeometry 
        args={[
          2, 
          quality === 'high' ? 64 : quality === 'medium' ? 32 : 16,
          quality === 'high' ? 32 : quality === 'medium' ? 16 : 8
        ]} 
      />
      <primitive object={brainMaterial} />
    </mesh>
  );
}
```

### Performance Monitoring

```tsx
function BrainWithAdaptiveQuality() {
  const { fps, getPerformanceInfo } = useShaderPerformance();
  const [quality, setQuality] = useState<'high' | 'medium' | 'low'>('high');

  useEffect(() => {
    const info = getPerformanceInfo();
    if (!info.isPerformant) {
      if (quality === 'high') setQuality('medium');
      else if (quality === 'medium') setQuality('low');
    } else if (info.fps > 50 && quality !== 'high') {
      setQuality('high');
    }
  }, [fps, quality, getPerformanceInfo]);

  return <OptimizedBrain quality={quality} />;
}
```

## Troubleshooting

### Common Issues

1. **Shaders not loading**: Ensure Vite is configured to handle `.glsl`, `.vert`, and `.frag` files
2. **Performance issues**: Use the performance monitoring hook and reduce quality as needed
3. **Visual artifacts**: Check that your geometry has proper normals and UV coordinates

### Debug Mode

```tsx
// Enable debug logging
const material = useBrainShader({
  brainActivity: 0.7,
  // ... other config
});

// Check uniform values
console.log('Brain shader uniforms:', material.uniforms);

// Monitor performance
const { fps } = useShaderPerformance();
console.log('Current FPS:', fps);
```

## Next Steps

1. **Experiment with parameters**: Try different values for `brainActivity`, `deformationStrength`, etc.
2. **Add custom effects**: Extend the shaders with your own GLSL code
3. **Integrate with data**: Connect shader parameters to real-time brain activity data
4. **Optimize for your use case**: Adjust quality settings based on your target devices

For more advanced usage, see the full documentation in `README.md`.

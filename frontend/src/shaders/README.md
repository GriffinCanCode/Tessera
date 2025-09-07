# Tessera Brain Visualization Shaders

This directory contains advanced GLSL shaders for enhanced brain visualization in the Tessera knowledge mapping system. The shaders provide realistic neural activity visualization, dynamic brain surface rendering, and sophisticated knowledge flow effects.

## Shader Overview

### 1. Brain Shaders (`brain/`)
- **Purpose**: Enhanced brain surface rendering with neural activity
- **Features**:
  - Procedural brain surface deformation with cortical folds
  - Real-time neural activity visualization
  - Subsurface scattering for organic appearance
  - Fresnel rim lighting for brain outline
  - Knowledge area intensity mapping

### 2. Neural Connection Shaders (`connections/`)
- **Purpose**: Dynamic visualization of neural pathways and electrical impulses
- **Features**:
  - Animated electrical impulses along connections
  - Dynamic radius based on signal strength
  - Electrical discharge patterns
  - Bezier curve-based natural connection paths
  - Multiple signal propagation waves

### 3. Knowledge Flow Shaders (`knowledge/`)
- **Purpose**: Visualization of information processing and learning
- **Features**:
  - Information packet flow visualization
  - Learning process effects (synaptic strengthening)
  - Memory consolidation patterns
  - Different knowledge type color coding
  - Bidirectional flow support

## Usage Examples

### Basic Brain Shader Usage

```tsx
import { useBrainShader } from '../hooks/useShaders';

function BrainComponent() {
  const brainMaterial = useBrainShader({
    brainColor: new THREE.Color(0xf8f9fa),
    brainActivity: 0.7,
    knowledgeIntensity: 0.8,
    showNeuralActivity: true,
    deformationStrength: 1.2
  });

  return (
    <mesh>
      <sphereGeometry args={[2, 64, 32]} />
      <primitive object={brainMaterial} />
    </mesh>
  );
}
```

### Neural Connection Usage

```tsx
import { useNeuralConnectionShader } from '../hooks/useShaders';

function NeuralConnection({ start, end, activity }) {
  const connectionMaterial = useNeuralConnectionShader({
    startPoint: start,
    endPoint: end,
    connectionActivity: activity,
    signalStrength: 1.0,
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

### Knowledge Flow Usage

```tsx
import { useKnowledgeFlowShader } from '../hooks/useShaders';

function KnowledgeFlow({ source, target, knowledgeType }) {
  const flowMaterial = useKnowledgeFlowShader({
    sourceRegion: source,
    targetRegion: target,
    knowledgeActivity: 0.8,
    flowSpeed: 1.5,
    informationDensity: 0.9,
    showLearningProcess: true
  });

  return (
    <mesh>
      <cylinderGeometry args={[0.1, 0.1, distance, 16]} />
      <primitive object={flowMaterial} />
    </mesh>
  );
}
```

## Shader Parameters

### Brain Shader Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `brainColor` | Color | `#f8f9fa` | Base color of brain tissue |
| `brainActivity` | Float | `0.5` | Overall neural activity level (0-1) |
| `knowledgeIntensity` | Float | `0.5` | Knowledge area activation intensity |
| `activityCenter` | Vector3 | `(0,0,0)` | Center point of neural activity |
| `showNeuralActivity` | Boolean | `true` | Enable/disable neural activity effects |
| `deformationStrength` | Float | `1.0` | Strength of surface deformation |
| `rimPower` | Float | `2.0` | Fresnel rim lighting power |
| `subsurfaceStrength` | Float | `0.3` | Subsurface scattering intensity |

### Neural Connection Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connectionActivity` | Float | `0.7` | Activity level of the connection |
| `pulseSpeed` | Float | `2.0` | Speed of electrical pulses |
| `signalStrength` | Float | `1.0` | Strength of electrical signals |
| `connectionRadius` | Float | `0.02` | Base radius of connection tube |
| `showElectricalActivity` | Boolean | `true` | Show electrical discharge effects |
| `glowIntensity` | Float | `1.5` | Intensity of connection glow |
| `electricalNoise` | Float | `0.3` | Amount of electrical noise |

### Knowledge Flow Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `knowledgeActivity` | Float | `0.6` | Overall knowledge processing activity |
| `flowSpeed` | Float | `1.5` | Speed of information flow |
| `informationDensity` | Float | `0.7` | Density of information packets |
| `learningRate` | Float | `1.0` | Rate of learning process visualization |
| `showLearningProcess` | Boolean | `true` | Show synaptic strengthening effects |
| `showMemoryConsolidation` | Boolean | `true` | Show memory formation patterns |

## Performance Considerations

### Optimization Tips

1. **LOD (Level of Detail)**: Use simpler shaders for distant objects
2. **Conditional Effects**: Disable expensive effects when not visible
3. **Uniform Updates**: Minimize uniform updates per frame
4. **Texture Caching**: Reuse noise textures when possible

### Performance Monitoring

```tsx
import { useShaderPerformance } from '../hooks/useShaders';

function PerformanceMonitor() {
  const { fps, getPerformanceInfo } = useShaderPerformance();
  
  useEffect(() => {
    const info = getPerformanceInfo();
    if (!info.isPerformant) {
      console.warn('Shader performance degraded:', info);
    }
  }, [fps]);
  
  return <div>FPS: {fps}</div>;
}
```

## Shader Architecture

### Vertex Shader Responsibilities
- Geometry deformation and animation
- Position calculations for effects
- Attribute interpolation setup
- View-space transformations

### Fragment Shader Responsibilities
- Surface shading and lighting
- Procedural effect generation
- Color blending and composition
- Transparency calculations

### Uniform Management
- Centralized through `ShaderManager` class
- Automatic time updates
- Efficient batch updates
- Memory cleanup on disposal

## Integration with React Three Fiber

The shaders are designed to work seamlessly with React Three Fiber:

```tsx
// Automatic integration with R3F lighting
function Scene() {
  return (
    <>
      <ambientLight intensity={0.3} color="#f8f9fa" />
      <directionalLight position={[5, 8, 5]} intensity={0.8} />
      
      <BrainWithShaders />
      <NeuralConnectionsWithShaders />
      <KnowledgeFlowWithShaders />
    </>
  );
}
```

## Extending the Shaders

### Adding New Effects

1. **Create new shader files** in appropriate subdirectory
2. **Add to shaderLoader.ts** for material creation
3. **Create React hook** in `useShaders.ts`
4. **Update documentation** with usage examples

### Custom Uniforms

```glsl
// Add to vertex/fragment shader
uniform float customParameter;
uniform vec3 customColor;
uniform bool enableCustomEffect;

// Use in shader calculations
float customEffect = sin(time + customParameter) * float(enableCustomEffect);
vec3 finalColor = mix(baseColor, customColor, customEffect);
```

## Troubleshooting

### Common Issues

1. **Shader compilation errors**: Check browser console for GLSL errors
2. **Performance issues**: Monitor FPS and disable expensive effects
3. **Uniform updates not working**: Ensure proper ShaderManager registration
4. **Visual artifacts**: Check depth testing and blending modes

### Debug Mode

Enable shader debugging by setting:
```tsx
const material = useBrainShader({
  // ... other config
});

// Access material for debugging
console.log(material.uniforms);
```

## Browser Compatibility

- **WebGL 2.0**: Recommended for best performance
- **WebGL 1.0**: Fallback support with reduced features
- **Mobile devices**: Automatic quality reduction on low-end devices

## Future Enhancements

- [ ] Compute shader integration for particle systems
- [ ] Volumetric rendering for brain regions
- [ ] Real-time ray tracing effects
- [ ] Advanced post-processing pipeline
- [ ] VR/AR optimized shader variants

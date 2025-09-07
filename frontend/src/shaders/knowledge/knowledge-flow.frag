// Knowledge Flow Fragment Shader
// Advanced visualization of information processing and learning
// Author: Tessera Brain Visualization System

precision highp float;

// Varyings from vertex shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec2 vUv;
varying float vFlowDirection;
varying float vKnowledgeType;
varying float vFlowIntensity;
varying float vLearningPhase;
varying vec3 vFlowVector;
varying vec3 vViewPosition;

// Uniforms
uniform float time;
uniform float flowSpeed;
uniform vec3 knowledgeColors[6]; // Different colors for knowledge types
uniform vec3 learningColor;
uniform vec3 memoryColor;
uniform float opacity;
// Note: cameraPosition is automatically provided by THREE.js
uniform float informationDensity;
uniform bool showLearningProcess;
uniform bool showMemoryConsolidation;

// Lighting uniforms
uniform vec3 ambientLightColor;
uniform vec3 directionalLightColor;
uniform vec3 directionalLightDirection;

// Noise functions for procedural effects
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Get knowledge type color
vec3 getKnowledgeTypeColor(float knowledgeType) {
    int typeIndex = int(floor(knowledgeType));
    typeIndex = clamp(typeIndex, 0, 5);
    
    // Return appropriate color based on knowledge type
    if (typeIndex == 0) return knowledgeColors[0]; // Factual knowledge - blue
    if (typeIndex == 1) return knowledgeColors[1]; // Procedural knowledge - green
    if (typeIndex == 2) return knowledgeColors[2]; // Conceptual knowledge - purple
    if (typeIndex == 3) return knowledgeColors[3]; // Metacognitive knowledge - orange
    if (typeIndex == 4) return knowledgeColors[4]; // Emotional knowledge - red
    return knowledgeColors[5]; // Creative knowledge - yellow
}

// Enhanced information packet visualization with improved colorization
vec3 informationPackets(vec2 uv, float time, float flowIntensity, float flowDirection) {
    if (flowIntensity < 0.1) {
        return vec3(0.0);
    }
    
    // Create enhanced discrete information packets with varying sizes
    float packetSize = 0.08;
    float packetSpacing = 0.25;
    
    // Calculate packet positions along flow direction
    float flowTime = time * flowSpeed * flowDirection;
    float packetPosition1 = fract((uv.x + flowTime) / packetSpacing);
    float packetPosition2 = fract((uv.x + flowTime + 0.12) / packetSpacing);
    float packetPosition3 = fract((uv.x + flowTime + 0.24) / packetSpacing);
    
    // Create enhanced packet shapes with different characteristics
    float packet1 = smoothstep(0.0, packetSize, packetPosition1) * smoothstep(packetSize * 2.2, packetSize, packetPosition1);
    float packet2 = smoothstep(0.0, packetSize * 0.8, packetPosition2) * 
                   smoothstep(packetSize * 1.6, packetSize * 0.8, packetPosition2);
    float packet3 = smoothstep(0.0, packetSize * 1.2, packetPosition3) * 
                   smoothstep(packetSize * 2.4, packetSize * 1.2, packetPosition3);
    
    // Combine packets with enhanced intensity weighting
    float combinedPackets = packet1 * 0.6 + packet2 * 0.3 + packet3 * 0.1;
    
    // Enhanced cross-sectional variation with multiple harmonics
    float crossSection = (sin(uv.y * 6.28318) * 0.4 + 0.6) * (sin(uv.y * 12.56636) * 0.2 + 0.8);
    combinedPackets *= crossSection;
    
    // Add packet density variation
    float densityVariation = noise(uv * 20.0 + time * 2.0) * 0.3 + 0.7;
    combinedPackets *= densityVariation;
    
    return vec3(combinedPackets * flowIntensity);
}

// Enhanced learning process visualization with improved patterns
vec3 learningVisualization(vec2 uv, float time, float learningPhase) {
    if (!showLearningProcess || learningPhase < 0.2) {
        return vec3(0.0);
    }
    
    // Enhanced synaptic strengthening patterns with multiple layers
    float synapticPattern1 = sin(uv.x * 20.0 + time * 2.0) * cos(uv.y * 15.0 + time * 1.5);
    float synapticPattern2 = sin(uv.x * 25.0 + time * 2.5) * cos(uv.y * 18.0 + time * 1.8);
    float combinedSynaptic = (synapticPattern1 * 0.7 + synapticPattern2 * 0.3);
    combinedSynaptic = smoothstep(0.25, 0.85, combinedSynaptic) * learningPhase;
    
    // Enhanced neural plasticity waves with complexity
    float plasticityWave1 = sin(uv.x * 8.0 + time * 3.0) * sin(uv.y * 6.0 + time * 2.5);
    float plasticityWave2 = sin(uv.x * 12.0 + time * 3.5) * sin(uv.y * 9.0 + time * 2.8);
    float combinedPlasticity = (plasticityWave1 * 0.6 + plasticityWave2 * 0.4);
    combinedPlasticity = smoothstep(0.4, 1.0, combinedPlasticity) * learningPhase * 0.8;
    
    // Add dendritic growth patterns
    float dendriticGrowth = noise(uv * 15.0 + time * 1.0) * learningPhase;
    dendriticGrowth = smoothstep(0.6, 0.9, dendriticGrowth) * 0.5;
    
    // Combine all learning effects
    float totalLearning = combinedSynaptic + combinedPlasticity + dendriticGrowth;
    
    // Enhanced learning color with warmth
    vec3 enhancedLearningColor = mix(learningColor, learningColor * vec3(1.2, 1.1, 0.9), 0.4);
    
    return enhancedLearningColor * totalLearning;
}

// Memory consolidation visualization
vec3 memoryConsolidation(vec2 uv, float time, float learningPhase) {
    if (!showMemoryConsolidation || learningPhase < 0.3) {
        return vec3(0.0);
    }
    
    // Memory trace formation
    float memoryTrace = noise(uv * 10.0 + time * 0.5) * learningPhase;
    memoryTrace = smoothstep(0.6, 1.0, memoryTrace);
    
    // Long-term potentiation patterns
    float ltpPattern = sin(uv.x * 12.0 + time * 1.0) * cos(uv.y * 10.0 + time * 0.8);
    ltpPattern = smoothstep(0.4, 0.9, ltpPattern) * learningPhase * 0.8;
    
    // Combine memory effects
    float totalMemory = memoryTrace + ltpPattern;
    
    return memoryColor * totalMemory * 0.6;
}

// Enhanced information density visualization with improved patterns
vec3 informationDensityEffect(vec2 uv, float time, float density) {
    if (density < 0.2) {
        return vec3(0.0);
    }
    
    // Create enhanced information density patterns with multiple scales
    float densityPattern1 = noise(uv * 25.0 + time * 1.0) * density;
    float densityPattern2 = noise(uv * 35.0 + time * 1.5) * density * 0.8;
    float densityPattern3 = noise(uv * 45.0 + time * 2.0) * density * 0.6;
    float densityPattern4 = noise(uv * 60.0 + time * 2.5) * density * 0.4;
    
    // Add clustering patterns for information hotspots
    float clusterPattern = noise(uv * 15.0 + time * 0.8) * density;
    clusterPattern = smoothstep(0.6, 1.0, clusterPattern) * 0.7;
    
    float combinedDensity = densityPattern1 + densityPattern2 + densityPattern3 + densityPattern4 + clusterPattern;
    combinedDensity = smoothstep(0.7, 1.3, combinedDensity);
    
    // Add sparkle effects for high-density areas
    float sparkle = noise(uv * 80.0 + time * 3.0);
    sparkle = smoothstep(0.85, 1.0, sparkle) * density * 0.5;
    
    return vec3((combinedDensity * 0.4) + sparkle);
}

// Enhanced lighting for knowledge flow
vec3 calculateFlowLighting(vec3 normal, vec3 viewDir, vec3 baseColor, vec3 flowVector) {
    vec3 totalLight = vec3(0.0);
    
    // Ambient component
    totalLight += ambientLightColor * baseColor * 0.3;
    
    // Directional lighting with flow-based modulation
    vec3 lightDir = normalize(-directionalLightDirection);
    float NdotL = max(0.0, dot(normal, lightDir));
    
    // Modulate lighting based on flow direction
    float flowAlignment = dot(flowVector, lightDir) * 0.5 + 0.5;
    NdotL *= (0.7 + flowAlignment * 0.3);
    
    vec3 diffuse = directionalLightColor * baseColor * NdotL;
    totalLight += diffuse;
    
    // Specular highlighting for information streams
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(0.0, dot(normal, halfDir));
    float specular = pow(NdotH, 32.0) * 0.5;
    
    totalLight += directionalLightColor * specular;
    
    return totalLight;
}

void main() {
    // Normalize interpolated normal
    vec3 normal = normalize(vNormal);
    
    // Calculate view direction
    vec3 viewDir = normalize(cameraPosition - vWorldPosition);
    
    // Get base color for knowledge type
    vec3 baseColor = getKnowledgeTypeColor(vKnowledgeType);
    
    // Calculate main lighting
    vec3 litColor = calculateFlowLighting(normal, viewDir, baseColor, vFlowVector);
    
    // Add information packet visualization
    vec3 packets = informationPackets(vUv, time, vFlowIntensity, vFlowDirection);
    packets *= baseColor;
    
    // Add learning process effects
    vec3 learning = learningVisualization(vUv, time, vLearningPhase);
    
    // Add memory consolidation effects
    vec3 memory = memoryConsolidation(vUv, time, vLearningPhase);
    
    // Add information density effects
    vec3 densityEffect = informationDensityEffect(vUv, time, informationDensity);
    densityEffect *= baseColor;
    
    // Flow direction indicator (subtle color shift)
    vec3 flowColorShift = baseColor * (vFlowDirection > 0.0 ? 1.1 : 0.9);
    litColor = mix(litColor, flowColorShift, 0.2);
    
    // Combine all effects
    vec3 finalColor = litColor + packets + learning + memory + densityEffect;
    
    // Add temporal pulsing based on flow intensity
    float pulse = sin(time * 4.0) * 0.1 + 0.9;
    finalColor *= pulse * (0.8 + vFlowIntensity * 0.2);
    
    // Calculate final opacity based on flow intensity
    float finalOpacity = opacity * (0.6 + vFlowIntensity * 0.4);
    
    // Add flow-based transparency variation
    float flowTransparency = abs(vFlowDirection) * 0.3 + 0.7;
    finalOpacity *= flowTransparency;
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    // Output final color
    gl_FragColor = vec4(finalColor, finalOpacity);
}

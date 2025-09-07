// Knowledge Flow Vertex Shader
// Visualization of information and data flow through brain regions
// Author: Tessera Brain Visualization System

// Custom vertex attributes (position, normal, uv are provided by THREE.js)
attribute float flowDirection; // -1.0 to 1.0 for bidirectional flow
attribute float knowledgeType; // 0-5 for different knowledge categories

// Note: modelMatrix, viewMatrix, projectionMatrix, normalMatrix
// are automatically provided by THREE.js
uniform float time;
uniform float flowSpeed;
uniform float knowledgeActivity;
uniform vec3 sourceRegion;
uniform vec3 targetRegion;
uniform float informationDensity;
uniform float learningRate;

// Varyings to fragment shader
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

// Knowledge flow calculation
vec3 calculateFlowVector(vec3 pos, vec3 source, vec3 target, float direction) {
    vec3 baseFlow = normalize(target - source);
    
    // Add some turbulence for more organic flow
    float turbulence1 = sin(pos.x * 5.0 + time * 2.0) * cos(pos.y * 4.0 + time * 1.5);
    float turbulence2 = sin(pos.z * 6.0 + time * 2.5) * cos(pos.x * 3.0 + time * 1.8);
    
    vec3 turbulenceVector = vec3(turbulence1, turbulence2, turbulence1 * turbulence2) * 0.2;
    
    // Apply flow direction (positive = source to target, negative = target to source)
    vec3 finalFlow = baseFlow * direction + turbulenceVector;
    
    return normalize(finalFlow);
}

// Information density waves
float calculateInformationWaves(vec3 pos, float time, float knowledgeType) {
    // Different wave patterns for different knowledge types
    float wave1 = sin(pos.x * 8.0 + time * flowSpeed + knowledgeType * 2.0);
    float wave2 = cos(pos.y * 6.0 + time * flowSpeed * 0.8 + knowledgeType * 1.5);
    float wave3 = sin(pos.z * 10.0 + time * flowSpeed * 1.2 + knowledgeType * 3.0);
    
    // Combine waves with different amplitudes
    float combinedWave = wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25;
    
    // Apply information density modulation
    combinedWave *= informationDensity;
    
    return combinedWave;
}

// Learning process visualization
float calculateLearningPhase(vec3 pos, float time, float learningRate) {
    // Simulate synaptic strengthening during learning
    float synapticStrength = sin(time * learningRate + length(pos) * 5.0) * 0.5 + 0.5;
    
    // Add memory consolidation patterns
    float consolidation = cos(time * learningRate * 0.3 + pos.x * pos.y * 10.0) * 0.3 + 0.7;
    
    return synapticStrength * consolidation;
}

// Dynamic vertex displacement for flow visualization
vec3 flowDisplacement(vec3 pos, vec3 normal, float flowIntensity, float time) {
    // Create flowing displacement along the flow vector
    float displacement = sin(dot(pos, vFlowVector) * 10.0 + time * flowSpeed * 3.0) * flowIntensity * 0.1;
    
    // Add perpendicular oscillation for wave-like motion
    vec3 perpendicular = normalize(cross(vFlowVector, vec3(0.0, 1.0, 0.0)));
    float perpendicularDisp = cos(dot(pos, perpendicular) * 15.0 + time * flowSpeed * 2.0) * flowIntensity * 0.05;
    
    return normal * displacement + perpendicular * perpendicularDisp;
}

void main() {
    // Store attributes for fragment shader
    vUv = uv;
    vFlowDirection = flowDirection;
    vKnowledgeType = knowledgeType;
    
    // Calculate flow vector
    vFlowVector = calculateFlowVector(position, sourceRegion, targetRegion, flowDirection);
    
    // Calculate information waves
    float infoWaves = calculateInformationWaves(position, time, knowledgeType);
    
    // Calculate learning phase
    vLearningPhase = calculateLearningPhase(position, time, learningRate);
    
    // Calculate flow intensity based on activity and waves
    vFlowIntensity = knowledgeActivity * (0.7 + infoWaves * 0.3) * vLearningPhase;
    
    // Apply flow-based displacement
    vec3 displacement = flowDisplacement(position, normal, vFlowIntensity, time);
    vec3 displacedPosition = position + displacement;
    
    // Transform to world space
    vec4 worldPosition = modelMatrix * vec4(displacedPosition, 1.0);
    vWorldPosition = worldPosition.xyz;
    
    // Transform to view space
    vec4 viewPosition = viewMatrix * worldPosition;
    vViewPosition = viewPosition.xyz;
    
    // Transform to clip space
    gl_Position = projectionMatrix * viewPosition;
    
    // Transform normal
    vNormal = normalize(normalMatrix * normal);
    
    // Pass position for fragment calculations
    vPosition = displacedPosition;
}

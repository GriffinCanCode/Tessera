// Neural Connection Vertex Shader
// Dynamic neural pathway visualization with electrical impulses
// Author: Tessera Brain Visualization System

// Custom vertex attributes (position, normal are provided by THREE.js)
attribute float pathPosition; // 0.0 to 1.0 along the connection path
attribute float connectionId; // Unique ID for each connection

// Note: modelMatrix, viewMatrix, projectionMatrix, normalMatrix
// are automatically provided by THREE.js
uniform float time;
uniform float connectionActivity;
uniform float pulseSpeed;
uniform float connectionRadius;
uniform vec3 startPoint;
uniform vec3 endPoint;
uniform float signalStrength;

// Varyings to fragment shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying float vPathPosition;
varying float vConnectionId;
varying float vSignalIntensity;
varying float vPulsePhase;
varying vec3 vViewPosition;

// Smooth curve interpolation for neural pathways
vec3 bezierCurve(vec3 start, vec3 end, vec3 control, float t) {
    float invT = 1.0 - t;
    return invT * invT * start + 2.0 * invT * t * control + t * t * end;
}

// Calculate control point for natural brain connection curves
vec3 calculateControlPoint(vec3 start, vec3 end) {
    vec3 midpoint = (start + end) * 0.5;
    vec3 direction = normalize(end - start);
    vec3 perpendicular = normalize(cross(direction, vec3(0.0, 1.0, 0.0)));
    
    // Add some randomness based on connection endpoints
    float randomOffset = sin(start.x * 10.0 + end.z * 8.0) * 0.3;
    
    // Curve upward and outward for brain-like connections
    return midpoint + vec3(0.0, 0.5 + randomOffset, 0.0) + perpendicular * randomOffset;
}

// Neural signal propagation calculation
float calculateSignalIntensity(float pathPos, float time, float connectionId) {
    // Multiple signals traveling along the connection
    float signal1 = sin((pathPos - time * pulseSpeed) * 20.0 + connectionId * 3.14159);
    float signal2 = sin((pathPos - time * pulseSpeed * 0.7) * 15.0 + connectionId * 2.0);
    float signal3 = sin((pathPos - time * pulseSpeed * 1.3) * 25.0 + connectionId * 1.5);
    
    // Create pulse waves
    signal1 = smoothstep(0.7, 1.0, signal1) * smoothstep(-0.3, 0.3, signal1);
    signal2 = smoothstep(0.6, 1.0, signal2) * smoothstep(-0.4, 0.4, signal2);
    signal3 = smoothstep(0.8, 1.0, signal3) * smoothstep(-0.2, 0.2, signal3);
    
    // Combine signals with different intensities
    float combinedSignal = signal1 * 0.6 + signal2 * 0.3 + signal3 * 0.1;
    
    return combinedSignal * connectionActivity * signalStrength;
}

// Dynamic radius calculation based on activity
float calculateDynamicRadius(float pathPos, float signalIntensity) {
    // Base radius with slight variation along path
    float baseRadius = connectionRadius * (0.8 + 0.2 * sin(pathPos * 10.0));
    
    // Expand radius where signals are present
    float signalExpansion = signalIntensity * connectionRadius * 0.5;
    
    return baseRadius + signalExpansion;
}

void main() {
    // Store path position and connection ID
    vPathPosition = pathPosition;
    vConnectionId = connectionId;
    
    // Calculate control point for bezier curve
    vec3 controlPoint = calculateControlPoint(startPoint, endPoint);
    
    // Get position along the bezier curve
    vec3 curvePosition = bezierCurve(startPoint, endPoint, controlPoint, pathPosition);
    
    // Calculate signal intensity at this position
    vSignalIntensity = calculateSignalIntensity(pathPosition, time, connectionId);
    
    // Calculate pulse phase for fragment shader
    vPulsePhase = fract(time * pulseSpeed + connectionId * 0.1);
    
    // Dynamic radius based on neural activity
    float dynamicRadius = calculateDynamicRadius(pathPosition, vSignalIntensity);
    
    // Apply radial displacement for tube geometry
    vec3 finalPosition = curvePosition + normal * dynamicRadius;
    
    // Transform to world space
    vec4 worldPosition = modelMatrix * vec4(finalPosition, 1.0);
    vWorldPosition = worldPosition.xyz;
    
    // Transform to view space
    vec4 viewPosition = viewMatrix * worldPosition;
    vViewPosition = viewPosition.xyz;
    
    // Transform to clip space
    gl_Position = projectionMatrix * viewPosition;
    
    // Transform normal
    vNormal = normalize(normalMatrix * normal);
    
    // Pass position for fragment calculations
    vPosition = finalPosition;
}

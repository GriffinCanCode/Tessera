// Neural Connection Fragment Shader
// Dynamic electrical impulse visualization for brain connections
// Author: Tessera Brain Visualization System

precision highp float;

// Varyings from vertex shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying float vPathPosition;
varying float vConnectionId;
varying float vSignalIntensity;
varying float vPulsePhase;
varying vec3 vViewPosition;

// Uniforms
uniform float time;
uniform vec3 baseConnectionColor;
uniform vec3 activeConnectionColor;
uniform vec3 signalColor;
uniform float connectionOpacity;
uniform float signalOpacity;
// Note: cameraPosition is automatically provided by THREE.js
uniform float glowIntensity;
uniform float electricalNoise;
uniform bool showElectricalActivity;

// Lighting uniforms
uniform vec3 ambientLightColor;
uniform vec3 directionalLightColor;
uniform vec3 directionalLightDirection;

// Noise function for electrical effects
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

// Enhanced electrical discharge pattern with improved colorization
float electricalPattern(vec2 uv, float time, float intensity) {
    if (!showElectricalActivity || intensity < 0.1) {
        return 0.0;
    }
    
    // Create enhanced branching electrical patterns with more complexity
    float branch1 = abs(sin(uv.x * 30.0 + time * 15.0)) * abs(cos(uv.y * 25.0 + time * 12.0));
    float branch2 = abs(sin(uv.x * 40.0 - time * 18.0)) * abs(cos(uv.y * 35.0 - time * 14.0));
    float branch3 = abs(sin(uv.x * 20.0 + time * 10.0)) * abs(cos(uv.y * 15.0 + time * 8.0));
    float branch4 = abs(sin(uv.x * 50.0 + time * 20.0)) * abs(cos(uv.y * 45.0 + time * 16.0));
    
    // Combine branches with enhanced intensity weighting
    float electrical = (branch1 * 0.4 + branch2 * 0.3 + branch3 * 0.2 + branch4 * 0.1) * intensity;
    
    // Enhanced electrical noise with multiple layers
    float primaryNoise = noise(uv * 100.0 + time * 5.0) * electricalNoise;
    float secondaryNoise = noise(uv * 150.0 + time * 7.0) * electricalNoise * 0.6;
    electrical += (primaryNoise + secondaryNoise) * intensity;
    
    // Create enhanced electrical spikes with smoother transitions
    electrical = smoothstep(0.75, 1.0, electrical);
    
    // Add crackling effect
    float crackling = noise(uv * 200.0 + time * 10.0);
    crackling = smoothstep(0.9, 1.0, crackling) * intensity * 0.3;
    electrical += crackling;
    
    return electrical;
}

// Enhanced signal pulse visualization with improved color dynamics
vec3 signalPulse(float pathPos, float pulsePhase, float signalIntensity) {
    if (signalIntensity < 0.1) {
        return vec3(0.0);
    }
    
    // Create enhanced traveling pulse waves with varying characteristics
    float pulse1 = exp(-pow((pathPos - pulsePhase) * 10.0, 2.0));
    float pulse2 = exp(-pow((pathPos - fract(pulsePhase + 0.3)) * 8.0, 2.0));
    float pulse3 = exp(-pow((pathPos - fract(pulsePhase + 0.7)) * 12.0, 2.0));
    float pulse4 = exp(-pow((pathPos - fract(pulsePhase + 0.15)) * 15.0, 2.0));
    
    // Combine pulses with enhanced weighting
    float combinedPulse = pulse1 * 0.5 + pulse2 * 0.3 + pulse3 * 0.15 + pulse4 * 0.05;
    
    // Modulate with signal intensity
    combinedPulse *= signalIntensity;
    
    // Enhanced color mixing based on pulse characteristics
    vec3 primaryPulseColor = signalColor;
    vec3 secondaryPulseColor = signalColor * vec3(1.2, 0.9, 0.7);
    vec3 tertiaryPulseColor = signalColor * vec3(0.8, 1.1, 1.3);
    
    // Blend colors based on pulse contributions
    vec3 finalPulseColor = primaryPulseColor * (pulse1 / combinedPulse) +
                          secondaryPulseColor * (pulse2 / combinedPulse) +
                          tertiaryPulseColor * ((pulse3 + pulse4) / combinedPulse);
    
    return finalPulseColor * combinedPulse;
}

// Fresnel glow effect
float fresnel(vec3 viewDir, vec3 normal, float power) {
    return pow(1.0 - max(0.0, dot(viewDir, normal)), power);
}

// Enhanced connection lighting
vec3 calculateConnectionLighting(vec3 normal, vec3 viewDir, vec3 baseColor) {
    vec3 totalLight = vec3(0.0);
    
    // Ambient component
    totalLight += ambientLightColor * baseColor * 0.4;
    
    // Directional lighting with wrap-around for cylindrical geometry
    vec3 lightDir = normalize(-directionalLightDirection);
    float NdotL = dot(normal, lightDir);
    float wrappedNdotL = (NdotL + 1.0) * 0.5; // Wrap lighting for better cylinder illumination
    
    vec3 diffuse = directionalLightColor * baseColor * wrappedNdotL;
    totalLight += diffuse;
    
    // Specular highlight for glossy neural pathways
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(0.0, dot(normal, halfDir));
    float specular = pow(NdotH, 64.0) * 0.8;
    
    totalLight += directionalLightColor * specular;
    
    return totalLight;
}

void main() {
    // Normalize interpolated normal
    vec3 normal = normalize(vNormal);
    
    // Calculate view direction
    vec3 viewDir = normalize(cameraPosition - vWorldPosition);
    
    // Base connection color interpolated with activity
    vec3 baseColor = mix(baseConnectionColor, activeConnectionColor, vSignalIntensity);
    
    // Calculate main lighting
    vec3 litColor = calculateConnectionLighting(normal, viewDir, baseColor);
    
    // Add signal pulse effects
    vec3 pulseEffect = signalPulse(vPathPosition, vPulsePhase, vSignalIntensity);
    
    // Add electrical discharge patterns
    vec2 electricalUV = vec2(vPathPosition * 10.0, vConnectionId * 2.0);
    float electrical = electricalPattern(electricalUV, time, vSignalIntensity);
    vec3 electricalColor = signalColor * electrical * 2.0;
    
    // Fresnel glow for energy appearance
    float fresnelGlow = fresnel(viewDir, normal, 2.0);
    vec3 glowColor = mix(baseColor, signalColor, vSignalIntensity) * fresnelGlow * glowIntensity;
    
    // Combine all effects
    vec3 finalColor = litColor + pulseEffect + electricalColor + glowColor;
    
    // Calculate final opacity
    float finalOpacity = connectionOpacity;
    
    // Increase opacity where signals are present
    finalOpacity += vSignalIntensity * signalOpacity;
    
    // Add fresnel-based transparency for depth
    finalOpacity *= (0.7 + fresnelGlow * 0.3);
    
    // Ensure opacity doesn't exceed 1.0
    finalOpacity = min(finalOpacity, 1.0);
    
    // Add subtle pulsing to the entire connection
    float globalPulse = sin(time * 3.0 + vConnectionId) * 0.1 + 0.9;
    finalColor *= globalPulse;
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    // Output final color
    gl_FragColor = vec4(finalColor, finalOpacity);
}

// Brain Fragment Shader
// Advanced brain surface rendering with neural activity visualization
// Author: Tessera Brain Visualization System

precision highp float;

// Varyings from vertex shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec2 vUv;
varying float vActivity;
varying float vElevation;
varying vec3 vViewPosition;
varying float vCortexDepth;
varying float vRegionMask;

// Uniforms
uniform float time;
uniform vec3 brainColor;
uniform float brainActivity;
uniform float metalness;
uniform float roughness;
uniform float opacity;
uniform vec3 activityColor;
// Note: cameraPosition is automatically provided by THREE.js
uniform float rimPower;
uniform float subsurfaceStrength;
uniform bool showNeuralActivity;
uniform float knowledgeIntensity;
uniform vec3 knowledgeColor;
uniform vec3 selectedRegionColor;
uniform float selectedRegionIntensity;

// Lighting uniforms
uniform vec3 ambientLightColor;
uniform vec3 directionalLightColor;
uniform vec3 directionalLightDirection;
uniform vec3 pointLightColor;
uniform vec3 pointLightPosition;
uniform float pointLightDistance;

// Noise function for procedural effects
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

// Fresnel calculation for rim lighting
float fresnel(vec3 viewDir, vec3 normal, float power) {
    return pow(1.0 - max(0.0, dot(viewDir, normal)), power);
}

// Enhanced subsurface scattering for brain tissue
vec3 subsurfaceScattering(vec3 lightDir, vec3 viewDir, vec3 normal, vec3 color, float strength) {
    // Advanced subsurface scattering for organic brain tissue
    float backLight = max(0.0, dot(-lightDir, normal));
    float subsurface = pow(backLight, 1.5) * strength;
    
    // Brain tissue has pinkish-gray subsurface color (more opaque)
    vec3 brainTissueColor = mix(color, vec3(0.92, 0.88, 0.85), 0.2);
    
    // Add depth-based color variation (deeper = more reddish, but less transparent)
    float depthFactor = smoothstep(0.0, 1.0, vCortexDepth);
    vec3 deepTissueColor = mix(brainTissueColor, vec3(0.88, 0.82, 0.78), depthFactor * 0.15);
    
    return deepTissueColor * subsurface;
}

// Brain tissue surface detail
vec3 brainSurfaceDetail(vec2 uv, vec3 baseColor) {
    // Cortical surface texture
    float cortexPattern = noise(uv * 80.0) * 0.15 + noise(uv * 160.0) * 0.08;
    
    // Sulci (grooves) and gyri (ridges) pattern (smoother transitions)
    float sulciPattern = smoothstep(0.2, 0.8, noise(uv * 40.0 + time * 0.02));
    float gyriPattern = 1.0 - sulciPattern;
    
    // Gray matter vs white matter coloring (more opaque)
    vec3 grayMatter = vec3(0.75, 0.72, 0.68);  // More opaque gray-pink
    vec3 whiteMatter = vec3(0.88, 0.85, 0.82); // More opaque pinkish-white
    
    // Mix based on cortex depth and surface patterns
    vec3 tissueColor = mix(grayMatter, whiteMatter, vCortexDepth * 0.6 + cortexPattern);
    
    // Add subtle vascular patterns
    float vascularPattern = noise(uv * 25.0 + time * 0.1) * 0.1;
    vec3 vascularColor = vec3(0.8, 0.6, 0.6);
    tissueColor = mix(tissueColor, vascularColor, vascularPattern * 0.2);
    
    return mix(baseColor, tissueColor, 0.9); // More opaque tissue blending
}

// Enhanced neural activity pattern generation with improved colorization
vec3 neuralActivityPattern(vec2 uv, float activity, float time) {
    if (!showNeuralActivity || activity < 0.1) {
        return vec3(0.0);
    }
    
    // Enhanced electrical impulse patterns with color variation
    float impulse1 = sin(uv.x * 20.0 + time * 8.0) * cos(uv.y * 15.0 + time * 6.0);
    float impulse2 = sin(uv.x * 25.0 - time * 10.0) * cos(uv.y * 18.0 - time * 7.0);
    float impulse3 = sin(uv.x * 30.0 + time * 12.0) * cos(uv.y * 22.0 + time * 9.0);
    
    // Combine impulses with different intensities and color shifts
    float combinedImpulse = (impulse1 * 0.5 + impulse2 * 0.3 + impulse3 * 0.2) * activity;
    
    // Create enhanced synaptic firing pattern
    float synapticNoise = noise(uv * 50.0 + time * 2.0);
    float synapticFiring = smoothstep(0.65, 1.0, synapticNoise) * activity;
    
    // Enhanced neural pathway traces with branching
    float pathway1 = abs(sin(uv.x * 40.0 + time * 5.0)) * abs(cos(uv.y * 35.0 + time * 4.0));
    float pathway2 = abs(sin(uv.y * 45.0 + time * 6.0)) * abs(cos(uv.x * 38.0 + time * 5.5));
    float combinedPathway = max(pathway1, pathway2 * 0.7);
    combinedPathway = smoothstep(0.75, 1.0, combinedPathway) * activity * 0.6;
    
    // Add dendritic branching patterns
    float dendrites = noise(uv * 30.0 + time * 1.5) * noise(uv * 60.0 + time * 0.8);
    dendrites = smoothstep(0.6, 0.9, dendrites) * activity * 0.4;
    
    // Combine all neural activity patterns
    float totalActivity = max(0.0, combinedImpulse + synapticFiring + combinedPathway + dendrites);
    
    // Enhanced color mixing for neural activity
    vec3 baseActivityColor = activityColor;
    
    // Add color variation based on activity type
    vec3 impulseColor = mix(baseActivityColor, baseActivityColor * vec3(1.3, 0.9, 0.7), combinedImpulse);
    vec3 synapticColor = mix(baseActivityColor, baseActivityColor * vec3(0.8, 1.2, 1.1), synapticFiring);
    vec3 pathwayColor = mix(baseActivityColor, baseActivityColor * vec3(1.1, 1.1, 1.4), combinedPathway);
    vec3 dendriticColor = mix(baseActivityColor, baseActivityColor * vec3(0.9, 1.3, 0.8), dendrites);
    
    // Blend activity colors based on their contributions (safe division)
    vec3 finalActivityColor = baseActivityColor;
    if (totalActivity > 0.001) {
        finalActivityColor = impulseColor * (combinedImpulse / totalActivity) +
                            synapticColor * (synapticFiring / totalActivity) +
                            pathwayColor * (combinedPathway / totalActivity) +
                            dendriticColor * (dendrites / totalActivity);
    }
    
    return finalActivityColor * totalActivity;
}

// Enhanced region highlighting with advanced colorization and smooth transitions
vec3 regionHighlighting(vec2 uv, vec3 baseColor) {
    vec3 highlightColor = baseColor;
    
    // Selected region highlighting with enhanced visual effects and smooth transitions
    if (selectedRegionIntensity > 0.01) {
        // Smooth intensity transition for on/off states
        float smoothIntensity = smoothstep(0.0, 0.2, selectedRegionIntensity);
        
        // Multi-layered region boundaries with much smoother transitions
        float regionCore = smoothstep(0.7, 1.0, vRegionMask);
        float regionMid = smoothstep(0.4, 0.8, vRegionMask);
        float regionOuter = smoothstep(0.1, 0.6, vRegionMask);
        float regionExtended = smoothstep(0.0, 0.4, vRegionMask);
        
        // Continuous pulsing animation that doesn't restart on hover
        float primaryPulse = sin(time * 2.8) * 0.3 + 0.7;
        float secondaryPulse = sin(time * 4.2 + vRegionMask * 6.0) * 0.25 + 0.75;
        float tertiaryPulse = sin(time * 1.6 + vRegionMask * 4.0) * 0.15 + 0.85;
        float combinedPulse = primaryPulse * secondaryPulse * tertiaryPulse;
        
        // Much more vibrant color enhancement
        vec3 enhancedSelectedColor = selectedRegionColor;
        enhancedSelectedColor = mix(enhancedSelectedColor, 
                                   enhancedSelectedColor * vec3(1.6, 1.3, 1.1), 0.6);
        
        // Dramatically increased highlighting intensity
        // Core region - much brighter and more prominent
        vec3 coreGlow = enhancedSelectedColor * smoothIntensity * combinedPulse * 3.0;
        
        // Mid region - stronger gradient transition
        vec3 midGlow = mix(enhancedSelectedColor, baseColor, 0.2) * smoothIntensity * combinedPulse * 2.0;
        
        // Outer region - more visible color wash
        vec3 outerGlow = mix(enhancedSelectedColor, baseColor, 0.5) * smoothIntensity * 1.2;
        
        // Extended region - subtle but visible influence
        vec3 extendedGlow = mix(enhancedSelectedColor, baseColor, 0.8) * smoothIntensity * 0.8;
        
        // Enhanced boundary outline with stronger presence
        float boundaryNoise = noise(uv * 40.0 + time * 1.5) * 0.3 + 0.7;
        vec3 boundaryColor = enhancedSelectedColor * boundaryNoise * 4.0;
        
        // Layer the highlighting effects with continuous animation blending
        highlightColor = mix(highlightColor, extendedGlow * combinedPulse, regionExtended * 0.4 * smoothIntensity);
        highlightColor = mix(highlightColor, outerGlow * combinedPulse, regionOuter * 0.6 * smoothIntensity);
        highlightColor = mix(highlightColor, midGlow * combinedPulse, regionMid * 0.8 * smoothIntensity);
        highlightColor = mix(highlightColor, coreGlow * combinedPulse, regionCore * 0.9 * smoothIntensity);
        highlightColor += boundaryColor * regionCore * 0.6 * smoothIntensity * combinedPulse;
        
        // Enhanced rim lighting with continuous animation
        float rimEffect = (1.0 - regionCore) * regionMid * smoothIntensity;
        vec3 rimColor = enhancedSelectedColor * 1.2;
        highlightColor += rimColor * rimEffect * 0.5 * combinedPulse;
        
        // Add glowing aura effect with continuous pulsing
        float auraEffect = regionExtended * (1.0 - regionOuter) * smoothIntensity;
        vec3 auraColor = enhancedSelectedColor * 0.6;
        float auraPulse = sin(time * 1.8) * 0.2 + 0.8;
        highlightColor += auraColor * auraEffect * auraPulse * 0.4;
    }
    
    // Hovered region highlighting disabled - no color changes on hover
    // All hover color effects removed to maintain consistent brain colors
    
    return highlightColor;
}

// Enhanced knowledge area visualization with improved flow patterns
vec3 knowledgeVisualization(vec2 uv, float intensity) {
    if (intensity < 0.1) {
        return vec3(0.0);
    }
    
    // Create enhanced knowledge flow patterns with multiple layers
    float flow1 = sin(uv.x * 12.0 + time * 3.0) * cos(uv.y * 10.0 + time * 2.5);
    float flow2 = sin(uv.x * 8.0 - time * 2.0) * cos(uv.y * 14.0 - time * 3.5);
    float flow3 = sin(uv.x * 16.0 + time * 4.0) * cos(uv.y * 12.0 + time * 3.0);
    
    // Add spiral knowledge patterns
    float spiral = sin(length(uv - 0.5) * 20.0 - time * 5.0) * cos(atan(uv.y - 0.5, uv.x - 0.5) * 8.0);
    
    // Combine flow patterns with varying intensities
    float primaryFlow = (flow1 + flow2) * 0.4 * intensity;
    float secondaryFlow = flow3 * 0.3 * intensity;
    float spiralFlow = spiral * 0.3 * intensity;
    
    float totalFlow = primaryFlow + secondaryFlow + spiralFlow;
    totalFlow = smoothstep(0.2, 0.9, totalFlow);
    
    // Enhanced knowledge color with depth and warmth
    vec3 enhancedKnowledgeColor = knowledgeColor;
    enhancedKnowledgeColor = mix(enhancedKnowledgeColor, 
                                enhancedKnowledgeColor * vec3(1.2, 1.1, 0.9), 0.4);
    
    // Add knowledge particle effects
    float particles = noise(uv * 40.0 + time * 2.0) * noise(uv * 80.0 - time * 1.5);
    particles = smoothstep(0.7, 1.0, particles) * intensity * 0.5;
    
    vec3 flowColor = enhancedKnowledgeColor * totalFlow * 0.8;
    vec3 particleColor = enhancedKnowledgeColor * particles * 1.2;
    
    return flowColor + particleColor;
}

// Enhanced Phong lighting model
vec3 calculateLighting(vec3 normal, vec3 viewDir, vec3 albedo) {
    vec3 totalLight = vec3(0.0);
    
    // Ambient lighting
    totalLight += ambientLightColor * albedo * 0.3;
    
    // Directional lighting (main light)
    vec3 lightDir = normalize(-directionalLightDirection);
    float NdotL = max(0.0, dot(normal, lightDir));
    
    // Diffuse component
    vec3 diffuse = directionalLightColor * albedo * NdotL;
    
    // Specular component (Blinn-Phong)
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(0.0, dot(normal, halfDir));
    float specularPower = mix(32.0, 128.0, 1.0 - roughness);
    float specular = pow(NdotH, specularPower) * (1.0 - roughness) * metalness;
    vec3 specularColor = mix(vec3(0.04), albedo, metalness);
    
    totalLight += diffuse + specularColor * specular * directionalLightColor;
    
    // Point lighting
    vec3 pointLightDir = pointLightPosition - vWorldPosition;
    float pointLightDist = length(pointLightDir);
    pointLightDir = normalize(pointLightDir);
    
    if (pointLightDist < pointLightDistance) {
        float attenuation = 1.0 - (pointLightDist / pointLightDistance);
        attenuation = attenuation * attenuation;
        
        float pointNdotL = max(0.0, dot(normal, pointLightDir));
        vec3 pointDiffuse = pointLightColor * albedo * pointNdotL * attenuation;
        
        // Point light specular
        vec3 pointHalfDir = normalize(pointLightDir + viewDir);
        float pointNdotH = max(0.0, dot(normal, pointHalfDir));
        float pointSpecular = pow(pointNdotH, specularPower) * (1.0 - roughness) * metalness * attenuation;
        
        totalLight += pointDiffuse + specularColor * pointSpecular * pointLightColor;
    }
    
    // Add subsurface scattering
    vec3 subsurface = subsurfaceScattering(lightDir, viewDir, normal, albedo, subsurfaceStrength);
    totalLight += subsurface;
    
    return totalLight;
}

void main() {
    // Normalize interpolated normal
    vec3 normal = normalize(vNormal);
    
    // Calculate view direction
    vec3 viewDir = normalize(cameraPosition - vWorldPosition);
    
    // Enhanced brain tissue coloring
    vec3 baseColor = brainSurfaceDetail(vUv, brainColor);
    
    // Calculate main lighting with enhanced brain tissue properties
    vec3 litColor = calculateLighting(normal, viewDir, baseColor);
    
    // Add region highlighting with clear boundaries
    vec3 regionHighlighted = regionHighlighting(vUv, litColor);
    
    // Add neural activity visualization
    vec3 neuralActivity = neuralActivityPattern(vUv, vActivity, time);
    
    // Add knowledge area visualization
    vec3 knowledgeViz = knowledgeVisualization(vUv, knowledgeIntensity);
    
    // Enhanced Fresnel rim lighting for brain outline
    float fresnelFactor = fresnel(viewDir, normal, rimPower);
    vec3 rimColor = mix(vec3(0.9, 0.85, 0.8), activityColor, vActivity) * fresnelFactor * 0.6;
    
    // Combine all lighting components
    vec3 finalColor = regionHighlighted + neuralActivity + knowledgeViz + rimColor;
    
    // Add continuous time-based brain effects
    // Subtle additive glow that cycles over time
    float globalGlow = sin(time * 2.0) * 0.03 + 0.03;
    finalColor += finalColor * globalGlow;
    
    // Continuous subtle sparkle effect
    float sparkleNoise = noise(vUv * 60.0 + time * 1.0);
    float sparkleIntensity = smoothstep(0.92, 1.0, sparkleNoise);
    finalColor += vec3(1.0, 1.0, 1.0) * sparkleIntensity * 0.05;
    
    // Add depth-based atmospheric effect
    float depth = length(vViewPosition);
    float fogFactor = 1.0 - exp(-depth * 0.008);
    finalColor = mix(finalColor, vec3(0.92, 0.90, 0.88), fogFactor * 0.08);
    
    // Enhanced gamma correction for more realistic appearance
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    // Subtle color grading for brain tissue
    finalColor = mix(finalColor, finalColor * vec3(1.05, 0.98, 0.95), 0.2);
    
    // Output final color with opacity
    gl_FragColor = vec4(finalColor, opacity);
}

// Brain Vertex Shader
// Enhanced brain surface rendering with procedural deformation and animation
// Author: Tessera Brain Visualization System

// Note: position, normal, uv, modelMatrix, viewMatrix, projectionMatrix, normalMatrix
// are automatically provided by THREE.js - no need to declare them
uniform float time;
uniform float brainActivity;
uniform float deformationStrength;
uniform vec3 activityCenter;
uniform float activityRadius;
uniform vec3 selectedRegionCenter;
uniform float selectedRegionRadius;

// Varyings to fragment shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec2 vUv;
varying float vActivity;
varying float vElevation;
varying vec3 vViewPosition;
varying float vCortexDepth;
varying float vRegionMask;

// Noise functions for procedural brain surface
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

float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;
    
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Enhanced brain-specific surface deformation with region-aware effects
vec3 brainDeformation(vec3 pos, vec3 norm) {
    // Create realistic cortical folds (sulci and gyri) with enhanced detail
    float corticalFolds = fbm(pos.xy * 12.0 + time * 0.05) * 0.12;
    float sulciPattern = fbm(pos.xz * 15.0 + time * 0.03) * 0.10;
    float gyriPattern = fbm(pos.yz * 18.0 + time * 0.04) * 0.08;
    
    // Add enhanced cerebral cortex wrinkles with more detail
    float cortexWrinkles = fbm(pos.xy * 25.0) * 0.06;
    float fineDetails = fbm(pos.xz * 50.0) * 0.03;
    float microDetails = fbm(pos.yz * 80.0) * 0.015;
    
    // Combine surface patterns for realistic brain texture
    float surfaceDetail = corticalFolds + sulciPattern * 0.8 + gyriPattern * 0.6 + 
                         cortexWrinkles + fineDetails + microDetails;
    
    // Enhanced anatomical brain lobe variations
    // Frontal lobe bulge with more complexity
    float frontalLobe = smoothstep(-0.5, 0.5, pos.z) * sin(pos.x * 2.0) * cos(pos.y * 1.5) * 0.15;
    frontalLobe += smoothstep(-0.3, 0.7, pos.z) * sin(pos.x * 3.5) * cos(pos.y * 2.2) * 0.08;
    
    // Temporal lobe indentation with enhanced detail
    float temporalLobe = smoothstep(-1.0, 0.0, pos.y) * sin(pos.x * 3.0) * cos(pos.z * 2.0) * 0.10;
    temporalLobe += smoothstep(-0.8, 0.2, pos.y) * sin(pos.x * 4.5) * cos(pos.z * 3.0) * 0.06;
    
    // Occipital lobe shape with more definition
    float occipitalLobe = smoothstep(0.0, 1.0, -pos.z) * sin(pos.x * 2.5) * cos(pos.y * 2.0) * 0.12;
    occipitalLobe += smoothstep(0.2, 1.2, -pos.z) * sin(pos.x * 3.8) * cos(pos.y * 2.8) * 0.07;
    
    // Combine anatomical features
    float anatomicalShape = frontalLobe + temporalLobe + occipitalLobe;
    
    // Enhanced neural activity-based deformation with region awareness and global hover
    float distanceToActivity = distance(pos, activityCenter);
    float activityInfluence = smoothstep(activityRadius * 1.2, 0.0, distanceToActivity);
    
    // Enhanced activity deformation with continuous time-based effects
    float baseActivityDeformation = sin(time * 8.0 + distanceToActivity * 10.0) * activityInfluence * brainActivity * 0.12;
    float globalTimeDeformation = sin(time * 6.0 + length(pos) * 4.0) * 0.02; // Continuous time-based deformation
    float activityDeformation = baseActivityDeformation + globalTimeDeformation;
    
    // Combine all deformations with enhanced blending (region deformation will be added in main)
    float totalDeformation = (surfaceDetail + anatomicalShape + activityDeformation) * deformationStrength;
    
    // Add subtle breathing effect to the entire brain
    float breathingEffect = sin(time * 1.5) * 0.02;
    totalDeformation += breathingEffect;
    
    // Clamp total deformation to prevent extreme values
    totalDeformation = clamp(totalDeformation, -0.5, 0.5);
    
    return pos + norm * totalDeformation;
}

// Calculate cortex depth for realistic brain tissue coloring
float calculateCortexDepth(vec3 pos) {
    // Distance from surface (approximated)
    float surfaceDistance = length(pos) - 2.0; // Assuming brain radius ~2
    
    // Normalize to 0-1 range (0 = surface, 1 = deep)
    float depth = smoothstep(-0.3, 0.3, surfaceDistance);
    
    // Add noise for variation
    depth += fbm(pos.xy * 20.0) * 0.2;
    
    return clamp(depth, 0.0, 1.0);
}

// Enhanced region mask calculation with ultra-smooth transitions
float calculateRegionMask(vec3 pos) {
    float mask = 0.0;
    
    // Enhanced selected region mask with extended smooth falloff zones
    if (selectedRegionRadius > 0.0) {
        float distToSelected = distance(pos, selectedRegionCenter);
        
        // Much larger influence area with smoother transitions
        // Core region - very smooth falloff
        float coreRegion = 1.0 - smoothstep(0.0, selectedRegionRadius * 0.8, distToSelected);
        
        // Mid region - extended smooth falloff
        float midRegion = 1.0 - smoothstep(selectedRegionRadius * 0.3, selectedRegionRadius * 1.2, distToSelected);
        
        // Outer region - very soft extended falloff
        float outerRegion = 1.0 - smoothstep(selectedRegionRadius * 0.6, selectedRegionRadius * 1.8, distToSelected);
        
        // Extended region - subtle but wide influence
        float extendedRegion = 1.0 - smoothstep(selectedRegionRadius * 1.0, selectedRegionRadius * 2.5, distToSelected);
        
        // Combine regions with enhanced weighting for smoother blending
        float selectedMask = coreRegion * 1.0 + midRegion * 0.8 + outerRegion * 0.6 + extendedRegion * 0.3;
        
        // Apply additional smoothing to the mask
        selectedMask = smoothstep(0.0, 1.0, selectedMask);
        mask = max(mask, selectedMask);
    }
    
    // Hover region mask removed - click selection only
    
    // Apply multiple levels of smoothing for ultra-smooth transitions
    mask = smoothstep(0.0, 1.0, mask);
    mask = smoothstep(0.0, 1.0, mask); // Double smoothing for extra smoothness
    mask = clamp(mask, 0.0, 1.0);
    
    return mask;
}

// Enhanced pulsing neural activity calculation with improved patterns
float calculateNeuralActivity(vec3 pos) {
    // Enhanced distance-based activity falloff with multiple zones
    float distanceToCenter = distance(pos, activityCenter);
    
    // Core activity zone - high intensity
    float coreActivity = smoothstep(activityRadius * 0.8, 0.0, distanceToCenter);
    
    // Extended activity zone - medium intensity
    float extendedActivity = smoothstep(activityRadius * 1.5, activityRadius * 0.8, distanceToCenter);
    
    // Peripheral activity zone - low intensity
    float peripheralActivity = smoothstep(activityRadius * 2.2, activityRadius * 1.5, distanceToCenter);
    
    float baseActivity = coreActivity * 1.0 + extendedActivity * 0.6 + peripheralActivity * 0.3;
    
    // Continuous temporal pulsing with better timing coordination
    float pulse1 = sin(time * 3.2 + distanceToCenter * 6.0) * 0.35 + 0.65;
    float pulse2 = sin(time * 4.8 + distanceToCenter * 9.0 + pos.x * 4.0) * 0.28 + 0.72;
    float pulse3 = sin(time * 1.6 + distanceToCenter * 3.0 + pos.y * 2.5) * 0.22 + 0.78;
    float pulse4 = sin(time * 6.4 + distanceToCenter * 12.0 + pos.z * 5.5) * 0.18 + 0.82;
    
    // Continuous wave propagation with smoother timing
    float waveEffect = sin(time * 3.8 - distanceToCenter * 8.0) * 0.28 + 0.72;
    
    // Combine all pulses for complex neural activity pattern
    float combinedPulse = pulse1 * pulse2 * pulse3 * pulse4 * waveEffect;
    
    // Add noise for organic variation
    float activityNoise = fbm(pos.xy * 10.0 + time * 0.5) * 0.2 + 0.9;
    
    return baseActivity * combinedPulse * activityNoise * brainActivity;
}

void main() {
    // Store original UV coordinates
    vUv = uv;
    
    // Use original position without any deformation
    vec3 finalPosition = position;
    
    // Calculate region mask for highlighting (using original position)
    vRegionMask = calculateRegionMask(finalPosition);
    
    // All deformation disabled to maintain consistent brain size
    
    // Calculate world position
    vec4 worldPosition = modelMatrix * vec4(finalPosition, 1.0);
    vWorldPosition = worldPosition.xyz;
    
    // Calculate view position
    vec4 viewPosition = viewMatrix * worldPosition;
    vViewPosition = viewPosition.xyz;
    
    // Transform to clip space
    gl_Position = projectionMatrix * viewPosition;
    
    // Pass transformed normal to fragment shader
    vNormal = normalize(normalMatrix * normal);
    
    // Pass position for fragment shader calculations
    vPosition = finalPosition;
    
    // Calculate neural activity for this vertex
    vActivity = calculateNeuralActivity(finalPosition);
    
    // Calculate elevation for additional effects
    vElevation = finalPosition.y;
    
    // Calculate cortex depth for realistic brain tissue rendering
    vCortexDepth = calculateCortexDepth(finalPosition);
}

// Enhanced Lighting Fragment Shader
// Advanced PBR lighting with dynamic shadows and atmospheric effects
// Author: Tessera Brain Visualization System

precision highp float;

// Varyings from vertex shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec2 vUv;
varying vec3 vViewPosition;
varying vec3 vLightDirection;
varying vec3 vViewDirection;
varying float vDepth;
varying vec4 vShadowCoord;

// Lighting uniforms
uniform float time;
uniform vec3 lightPosition;
uniform vec3 lightDirection;
uniform vec3 lightColor;
uniform float lightIntensity;
uniform vec3 ambientColor;
uniform float ambientIntensity;

// Material uniforms
uniform vec3 baseColor;
uniform float metallic;
uniform float roughness;
uniform float opacity;
uniform float subsurfaceStrength;

// Shadow and atmosphere uniforms
uniform sampler2D shadowMap;
uniform float shadowStrength;
uniform float atmosphericDensity;
uniform vec3 atmosphericColor;

// Advanced lighting uniforms
uniform vec3 rimLightColor;
uniform float rimLightPower;
uniform float fresnelStrength;
uniform bool enableVolumetricLighting;
uniform bool enableSubsurfaceScattering;
uniform bool enableAtmosphericScattering;

// Noise function for atmospheric effects
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

// Advanced Fresnel calculation
float fresnelSchlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

// Distribution function (GGX/Trowbridge-Reitz)
float distributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265 * denom * denom;
    
    return num / denom;
}

// Geometry function (Smith's method)
float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

// Enhanced subsurface scattering with improved color mixing
vec3 subsurfaceScattering(vec3 lightDir, vec3 viewDir, vec3 normal, vec3 color, float strength) {
    // Enhanced translucency effect with multiple scattering layers
    float backLight = max(0.0, dot(-lightDir, normal));
    float subsurface = pow(backLight, 1.2) * strength;
    
    // Add enhanced depth-based color variation with warmer tones
    float depth = vDepth * 0.01;
    vec3 subsurfaceColor = mix(color, color * vec3(1.3, 1.0, 0.9), depth);
    
    // Enhanced light scattering simulation with multiple layers
    float primaryScattering = 1.0 - pow(abs(dot(viewDir, normal)), 0.4);
    float secondaryScattering = 1.0 - pow(abs(dot(viewDir, normal)), 0.8);
    float scatteringFactor = primaryScattering * 0.7 + secondaryScattering * 0.3;
    
    subsurface *= scatteringFactor;
    
    // Add subtle color temperature variation based on scattering
    vec3 warmScattering = subsurfaceColor * vec3(1.1, 0.95, 0.85);
    vec3 coolScattering = subsurfaceColor * vec3(0.9, 1.05, 1.15);
    subsurfaceColor = mix(coolScattering, warmScattering, scatteringFactor);
    
    return subsurfaceColor * subsurface;
}

// Enhanced volumetric lighting effect with improved color gradients
vec3 volumetricLighting(vec3 worldPos, vec3 lightPos, vec3 viewDir) {
    vec3 lightDir = lightPos - worldPos;
    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    
    // Enhanced ray marching for volumetric effect with color variation
    vec3 volumetricColor = vec3(0.0);
    float stepSize = lightDistance / 20.0; // More samples for smoother effect
    
    for (int i = 0; i < 20; i++) {
        vec3 samplePos = worldPos + lightDir * stepSize * float(i);
        float stepRatio = float(i) / 20.0;
        
        // Enhanced density calculation with multiple noise layers
        float primaryDensity = noise(samplePos.xy * 0.1 + time * 0.02) * 0.4 + 0.6;
        float secondaryDensity = noise(samplePos.xz * 0.15 + time * 0.015) * 0.3 + 0.7;
        float density = primaryDensity * secondaryDensity;
        
        // Enhanced atmospheric attenuation with color shift
        float attenuation = 1.0 / (1.0 + lightDistance * lightDistance * 0.008);
        
        // Color temperature variation based on distance
        vec3 nearColor = lightColor * vec3(1.2, 1.0, 0.8); // Warmer near light
        vec3 farColor = lightColor * vec3(0.8, 0.9, 1.2);  // Cooler far from light
        vec3 stepColor = mix(nearColor, farColor, stepRatio);
        
        volumetricColor += stepColor * density * attenuation * stepSize * 0.08;
    }
    
    return volumetricColor * atmosphericDensity;
}

// Atmospheric scattering
vec3 atmosphericScattering(vec3 worldPos, vec3 lightDir, vec3 viewDir) {
    float distance = length(worldPos);
    
    // Rayleigh scattering (shorter wavelengths scatter more)
    float rayleighFactor = exp(-distance * atmosphericDensity * 0.005);
    vec3 rayleigh = atmosphericColor * rayleighFactor;
    
    // Mie scattering (forward scattering)
    float miePhase = pow(max(0.0, dot(viewDir, lightDir)), 4.0);
    float mieFactor = exp(-distance * atmosphericDensity * 0.002);
    vec3 mie = vec3(miePhase * mieFactor * 0.3);
    
    return (rayleigh + mie) * lightIntensity;
}

// Shadow calculation
float calculateShadow(vec4 shadowCoord) {
    vec3 projCoords = shadowCoord.xyz / shadowCoord.w;
    projCoords = projCoords * 0.5 + 0.5;
    
    if (projCoords.z > 1.0 || projCoords.x < 0.0 || projCoords.x > 1.0 || 
        projCoords.y < 0.0 || projCoords.y > 1.0) {
        return 1.0;
    }
    
    float closestDepth = texture2D(shadowMap, projCoords.xy).r;
    float currentDepth = projCoords.z;
    
    // PCF (Percentage Closer Filtering) for soft shadows
    float shadow = 0.0;
    vec2 texelSize = 1.0 / vec2(2048.0); // Assuming 2048x2048 shadow map
    
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            float pcfDepth = texture2D(shadowMap, projCoords.xy + vec2(x, y) * texelSize).r;
            shadow += currentDepth - 0.005 > pcfDepth ? 0.0 : 1.0;
        }
    }
    
    shadow /= 9.0;
    return mix(1.0, shadow, shadowStrength);
}

// Main PBR lighting calculation
vec3 calculatePBRLighting(vec3 albedo, vec3 normal, vec3 viewDir, vec3 lightDir) {
    vec3 halfwayDir = normalize(viewDir + lightDir);
    
    // Calculate lighting components
    float NdotV = max(dot(normal, viewDir), 0.0);
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotH = max(dot(normal, halfwayDir), 0.0);
    float VdotH = max(dot(viewDir, halfwayDir), 0.0);
    
    // Fresnel reflectance at normal incidence
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    
    // Cook-Torrance BRDF
    float D = distributionGGX(normal, halfwayDir, roughness);
    float G = geometrySmith(normal, viewDir, lightDir, roughness);
    vec3 F = fresnelSchlickRoughness(VdotH, F0, roughness);
    
    vec3 numerator = D * G * F;
    float denominator = 4.0 * NdotV * NdotL + 0.001; // Prevent divide by zero
    vec3 specular = numerator / denominator;
    
    // Energy conservation
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic;
    
    // Lambert diffuse
    vec3 diffuse = kD * albedo / 3.14159265;
    
    // Combine diffuse and specular
    return (diffuse + specular) * lightColor * lightIntensity * NdotL;
}

void main() {
    // Normalize interpolated normal
    vec3 normal = normalize(vNormal);
    vec3 viewDir = normalize(vViewDirection);
    vec3 lightDir = normalize(vLightDirection);
    
    // Base material color
    vec3 albedo = baseColor;
    
    // Calculate shadow factor
    float shadowFactor = calculateShadow(vShadowCoord);
    
    // Main PBR lighting
    vec3 lighting = calculatePBRLighting(albedo, normal, viewDir, lightDir) * shadowFactor;
    
    // Ambient lighting
    vec3 ambient = ambientColor * ambientIntensity * albedo;
    
    // Enhanced subsurface scattering
    vec3 subsurface = vec3(0.0);
    if (enableSubsurfaceScattering) {
        subsurface = subsurfaceScattering(lightDir, viewDir, normal, albedo, subsurfaceStrength);
    }
    
    // Volumetric lighting
    vec3 volumetric = vec3(0.0);
    if (enableVolumetricLighting) {
        volumetric = volumetricLighting(vWorldPosition, lightPosition, viewDir);
    }
    
    // Atmospheric scattering
    vec3 atmospheric = vec3(0.0);
    if (enableAtmosphericScattering) {
        atmospheric = atmosphericScattering(vWorldPosition, lightDir, viewDir);
    }
    
    // Rim lighting for enhanced silhouette
    float rimFactor = 1.0 - max(0.0, dot(viewDir, normal));
    rimFactor = pow(rimFactor, rimLightPower);
    vec3 rimLight = rimLightColor * rimFactor * fresnelStrength;
    
    // Combine all lighting components
    vec3 finalColor = lighting + ambient + subsurface + volumetric + atmospheric + rimLight;
    
    // Tone mapping (ACES)
    finalColor = (finalColor * (2.51 * finalColor + 0.03)) / (finalColor * (2.43 * finalColor + 0.59) + 0.14);
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    gl_FragColor = vec4(finalColor, opacity);
}

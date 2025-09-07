// Enhanced Lighting Vertex Shader
// Advanced PBR lighting with dynamic shadows and atmospheric effects
// Author: Tessera Brain Visualization System

// Uniforms
uniform float time;
uniform vec3 lightPosition;
uniform vec3 lightDirection;
uniform float lightIntensity;
uniform vec3 ambientColor;
uniform float shadowStrength;
uniform float atmosphericDensity;

// Varyings to fragment shader
varying vec3 vPosition;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec2 vUv;
varying vec3 vViewPosition;
varying vec3 vLightDirection;
varying vec3 vViewDirection;
varying float vDepth;
varying vec4 vShadowCoord;

// Shadow mapping matrix
uniform mat4 shadowMatrix;

// Atmospheric scattering calculation
vec3 calculateAtmosphericScattering(vec3 worldPos, vec3 lightDir) {
    float distance = length(worldPos);
    float scattering = exp(-distance * atmosphericDensity * 0.01);
    
    // Rayleigh scattering (blue light scatters more)
    vec3 rayleigh = vec3(0.3, 0.5, 1.0) * scattering;
    
    // Mie scattering (forward scattering)
    float mie = pow(max(0.0, dot(normalize(worldPos), lightDir)), 8.0) * scattering;
    
    return rayleigh + vec3(mie * 0.8);
}

void main() {
    // Store original UV coordinates
    vUv = uv;
    
    // Transform position to world space
    vec4 worldPosition = modelMatrix * vec4(position, 1.0);
    vWorldPosition = worldPosition.xyz;
    
    // Calculate view position
    vec4 viewPosition = viewMatrix * worldPosition;
    vViewPosition = viewPosition.xyz;
    vDepth = -viewPosition.z;
    
    // Transform to clip space
    gl_Position = projectionMatrix * viewPosition;
    
    // Transform normal to world space
    vNormal = normalize(normalMatrix * normal);
    
    // Pass position for fragment shader calculations
    vPosition = position;
    
    // Calculate light direction in world space
    vLightDirection = normalize(lightPosition - vWorldPosition);
    
    // Calculate view direction
    vViewDirection = normalize(cameraPosition - vWorldPosition);
    
    // Calculate shadow coordinates
    vShadowCoord = shadowMatrix * worldPosition;
}

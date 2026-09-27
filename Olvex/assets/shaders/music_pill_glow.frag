#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uAccentColor;
    vec2 uLightPos;   // (x, y) in pixels relative to top-left
    vec2 uSize;       // (width, height) in pixels
    float uRadius;    // corner radius in pixels
};

// Signed distance field for rounded box / capsule
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * uSize;
    
    // 1. Calculate continuous distance from light source
    float dist = length(pixelPos - uLightPos);
    
    // 2. Continuous multi-scale radiance falloff (Core exponential + Halo Gaussian)
    // Eliminates all discrete layer step-boundaries and Mach banding
    float coreFalloff = exp(-dist / 26.0) * 0.28;
    float haloFalloff = exp(-(dist * dist) / (2.0 * 75.0 * 75.0)) * 0.16;
    float ambientFalloff = exp(-(dist * dist) / (2.0 * 160.0 * 160.0)) * 0.08;
    float totalIntensity = coreFalloff + haloFalloff + ambientFalloff;
    
    // 3. Smooth chromatic shift from inner warm core to diffuse outer halo
    float colorMix = clamp(dist / 90.0, 0.0, 1.0);
    float smoothMix = colorMix * colorMix * (3.0 - 2.0 * colorMix); // smoothstep
    vec3 coreColor = uAccentColor.rgb * 0.55;  // darker core
    vec3 haloColor = uAccentColor.rgb * 0.78;  // brighter diffuse halo
    vec3 glowRgb = mix(coreColor, haloColor, smoothMix);
    
    // 4. Analytical pill capsule anti-aliasing via signed distance field
    vec2 pillCenter = uSize * 0.5;
    vec2 p = pixelPos - pillCenter;
    vec2 halfExtents = uSize * 0.5;
    float sdf = sdRoundedBox(p, halfExtents, uRadius);
    
    // Subpixel anti-aliased edge clip
    float fw = max(fwidth(sdf), 0.001);
    float clipAlpha = clamp(0.5 - sdf / fw, 0.0, 1.0);
    
    float finalAlpha = totalIntensity * clipAlpha * qt_Opacity;
    
    // Premultiplied alpha output
    fragColor = vec4(glowRgb * finalAlpha, finalAlpha);
}

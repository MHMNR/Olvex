#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float iFillProgress;
    vec4 iPrimary;
    vec4 iPrimaryContainer;
    vec4 iOnPrimaryContainer;
    float iWidth;
    float iHeight;
};

void main() {
    vec2 uv = qt_TexCoord0;

    // Base fluid height
    float baseWaterY = 1.0 - clamp(iFillProgress, 0.0, 1.0);

    // Time scaling for viscosity
    float t = iTime * 1.5;

    // Complex domain warping to create viscous fluid displacement
    // We add sine waves to x and y to distort the space before calculating the wave height
    float warpX1 = sin(uv.y * 3.14 + t * 0.8) * 0.05;
    float warpX2 = cos(uv.y * 6.28 - t * 0.5) * 0.03;
    vec2 warpedUv = uv + vec2(warpX1 + warpX2, 0.0);

    // 3-harmonic wave equation for a richer, less repetitive fluid surface
    float wave1 = sin(warpedUv.x * 5.0 + t * 1.2) * 0.04
                + sin(warpedUv.x * 11.0 - t * 0.9 + 1.2) * 0.02
                + cos(warpedUv.x * 19.0 + t * 1.5) * 0.01;

    float wave2 = sin(warpedUv.x * 4.0 + t * 0.9 + 2.0) * 0.03
                + cos(warpedUv.x * 9.0 - t * 1.1 + 0.5) * 0.02
                + sin(warpedUv.x * 15.0 + t * 1.3) * 0.01;

    // Fluid layers with different displacements
    float surfaceY1 = baseWaterY + wave1;
    float surfaceY2 = baseWaterY + wave2 + 0.015;
    float surfaceY3 = baseWaterY + wave1 * 0.5 - wave2 * 0.5 + 0.03;

    // Smoothstep masks for crisp, anti-aliased liquid boundaries
    float maskLayer3 = smoothstep(surfaceY3 + 0.005, surfaceY3 - 0.005, uv.y);
    float maskLayer2 = smoothstep(surfaceY2 + 0.005, surfaceY2 - 0.005, uv.y);
    float maskLayer1 = smoothstep(surfaceY1 + 0.005, surfaceY1 - 0.005, uv.y);

    // Composition
    vec4 col = vec4(0.0); // Transparent background

    // Deepest layer (lowest opacity)
    col = mix(col, vec4(iPrimaryContainer.rgb, 0.35), maskLayer3);

    // Middle layer
    col = mix(col, vec4(iPrimaryContainer.rgb, 0.65), maskLayer2);

    // Front layer (highest opacity)
    col = mix(col, vec4(iPrimaryContainer.rgb, 0.95), maskLayer1);

    // Add a specular highlight on the front crest to give it a wet, glossy look
    float strokeMask = smoothstep(0.01, 0.0, abs(uv.y - surfaceY1));
    col = mix(col, vec4(iOnPrimaryContainer.rgb, 0.8), strokeMask * maskLayer1);
    
    // Add some subtle rim lighting on the second layer
    float strokeMask2 = smoothstep(0.01, 0.0, abs(uv.y - surfaceY2));
    col = mix(col, vec4(iOnPrimaryContainer.rgb, 0.4), strokeMask2 * maskLayer2 * (1.0 - maskLayer1));

    fragColor = col * qt_Opacity;
}

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iProgress;        // 0.0 to 1.0 (driven by M3 standard/emphasizedDecel curve)
    float iAspectRatio;     // width / height
    vec4 iPrimary;          // Colours.palette.m3primary
    vec4 iTertiary;         // Colours.palette.m3tertiary
    vec4 iPrimaryContainer; // Colours.palette.m3primaryContainer
    float iOriginX;         // 0.5 (center)
    float iOriginY;         // 0.5 (center)
};

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 origin = vec2(iOriginX, iOriginY);

    // Aspect-ratio corrected coordinates centered at origin
    vec2 p = vec2((uv.x - origin.x) * iAspectRatio, uv.y - origin.y);
    float dist = length(p);

    // Maximum distance to the screen corners
    float maxDist = length(vec2(0.5 * iAspectRatio, 0.5)) * 1.18;

    // Smooth wave expansion radius
    float currentRadius = clamp(iProgress, 0.0, 1.0) * maxDist;

    // ── Primary Soft Gaussian Wavefront ──
    // Wide, soft Gaussian bell curve for ambient liquid feel
    float d1 = dist - currentRadius;
    float w1 = mix(0.18, 0.45, iProgress) * maxDist;
    float wave1 = exp(-pow(d1 / max(0.001, w1 * 0.5), 2.0));

    // ── Secondary Soft Harmonic Trail ──
    float r2 = max(0.0, currentRadius - 0.14 * maxDist);
    float d2 = dist - r2;
    float w2 = mix(0.14, 0.36, iProgress) * maxDist;
    float wave2 = exp(-pow(d2 / max(0.001, w2 * 0.45), 2.0)) * 0.45;

    // ── Tertiary Subtle Echo ──
    float r3 = max(0.0, currentRadius - 0.26 * maxDist);
    float d3 = dist - r3;
    float w3 = mix(0.10, 0.28, iProgress) * maxDist;
    float wave3 = exp(-pow(d3 / max(0.001, w3 * 0.4), 2.0)) * 0.20;

    // ── Center Ambient Pool Wash (Soft Initial Glow) ──
    float centerGlow = smoothstep(currentRadius * 0.7, 0.0, dist)
                     * pow(max(0.0, 1.0 - dist / max(0.001, currentRadius * 0.75)), 2.0)
                     * 0.12 * max(0.0, 1.0 - iProgress * 1.6);

    // ── Dynamic Color Composition ──
    float colorT = clamp(dist / maxDist, 0.0, 1.0);
    vec3 waveColor = mix(iPrimary.rgb, iTertiary.rgb, colorT * 0.35);

    // Ultra-soft specular crest
    vec3 crestColor = mix(waveColor, vec3(1.0), 0.25);
    vec3 finalRgb = mix(waveColor, crestColor, wave1 * 0.30);

    // Android-calibrated subtle opacity weights (delicate, non-intrusive glow)
    float totalWave = (wave1 * 0.20 + wave2 * 0.10 + wave3 * 0.05 + centerGlow);

    // Smooth entry and exit fade envelopes (Android fade params: 0.0->0.08 in, 0.35->1.0 out)
    float fadeIn = smoothstep(0.0, 0.08, iProgress);
    float fadeOut = pow(max(0.0, 1.0 - iProgress), 1.1);
    float fadeEnvelope = fadeIn * fadeOut;

    float finalAlpha = clamp(totalWave * fadeEnvelope * qt_Opacity, 0.0, 1.0);

    // Pre-multiplied color output for Qt Quick SceneGraph
    fragColor = vec4(finalRgb * finalAlpha, finalAlpha);
}

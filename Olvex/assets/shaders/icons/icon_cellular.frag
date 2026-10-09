#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uStrength;    // 0.0 to 1.0 (0 to 4 bars)
    float uSearching;   // 1.0 = searching animation wave, 0.0 = static signal
    float uTime;
};

// 2D Rounded Box
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // 4 Stepped Vertical Bars
    // Bar centers: x = -0.60, -0.20, 0.20, 0.60
    // Bar half heights: 0.16, 0.32, 0.48, 0.64
    float barHalfW = 0.10;
    float barCornerR = 0.04;
    float bottomY = 0.65; // Align all bars at bottom

    float b1D = sdRoundedBox(p - vec2(-0.54, bottomY - 0.20), vec2(barHalfW, 0.20), barCornerR);
    float b2D = sdRoundedBox(p - vec2(-0.18, bottomY - 0.36), vec2(barHalfW, 0.36), barCornerR);
    float b3D = sdRoundedBox(p - vec2(0.18, bottomY - 0.52), vec2(barHalfW, 0.52), barCornerR);
    float b4D = sdRoundedBox(p - vec2(0.54, bottomY - 0.68), vec2(barHalfW, 0.68), barCornerR);

    // Alpha per bar based on signal strength [0.0 to 1.0]
    float active1 = (uStrength >= 0.12) ? 1.0 : 0.22;
    float active2 = (uStrength >= 0.38) ? 1.0 : 0.22;
    float active3 = (uStrength >= 0.62) ? 1.0 : 0.22;
    float active4 = (uStrength >= 0.88) ? 1.0 : 0.22;

    // Searching wave pulse
    if (uSearching > 0.01) {
        float wavePhase = mod(uTime * 4.0, 4.0);
        active1 = mix(0.22, 1.0, clamp(1.0 - abs(wavePhase - 0.0), 0.0, 1.0));
        active2 = mix(0.22, 1.0, clamp(1.0 - abs(wavePhase - 1.0), 0.0, 1.0));
        active3 = mix(0.22, 1.0, clamp(1.0 - abs(wavePhase - 2.0), 0.0, 1.0));
        active4 = mix(0.22, 1.0, clamp(1.0 - abs(wavePhase - 3.0), 0.0, 1.0));
    }

    float pixelScale = max(fwidth(p.x) * 1.4, 0.001);

    float a1 = clamp((0.0 - b1D) / pixelScale + 0.5, 0.0, 1.0) * active1;
    float a2 = clamp((0.0 - b2D) / pixelScale + 0.5, 0.0, 1.0) * active2;
    float a3 = clamp((0.0 - b3D) / pixelScale + 0.5, 0.0, 1.0) * active3;
    float a4 = clamp((0.0 - b4D) / pixelScale + 0.5, 0.0, 1.0) * active4;

    float finalAlpha = max(max(a1, a2), max(a3, a4));

    fragColor = uColor * finalAlpha * qt_Opacity;
}

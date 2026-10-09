#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uConnected;   // 1.0 (on), 0.0 (off)
    float uSearching;   // 1.0 (pairing beacon pulse)
    float uTransition;  // 0.0 to 1.0 (spring transition on toggle)
    float uTime;
};

// 2D Line Segment SDF
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// 2D Circle SDF
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // HyperOS 3 Folme Spring Bounce on state change
    float bounce = 1.0 + 0.10 * sin(uTransition * 3.14159265);
    vec2 bP = p / bounce;

    float th = 0.095; // HyperOS 3 crisp stroke width
    float conn = clamp(uConnected, 0.0, 1.0);

    // Dynamic wing fold parameter (OFF -> ON)
    // In OFF state, wings tuck neatly behind spine with 0.35 opacity
    float fold = mix(0.15, 1.0, smoothstep(0.0, 0.85, conn));

    // Exact geometric coordinates for standard 45-degree Bluetooth Bindrune
    vec2 pSpineTop = vec2(0.0, -0.72);
    vec2 pSpineBot = vec2(0.0, 0.72);
    vec2 pCenter   = vec2(0.0, 0.0);

    vec2 pWingTop  = vec2(0.38 * fold, -0.36 * fold);
    vec2 pWingBot  = vec2(0.38 * fold, 0.36 * fold);
    vec2 pSpurTop  = vec2(-0.38 * fold, -0.36 * fold);
    vec2 pSpurBot  = vec2(-0.38 * fold, 0.36 * fold);

    // 1. Central Spine Line
    float spineD = sdSegment(bP, pSpineTop, pSpineBot) - th * 0.5;

    // 2. Diagonal Upper Path: Bottom-Left Spur -> Center -> Top-Right Wing -> Top Spine
    float d1Spur = sdSegment(bP, pSpurBot, pCenter) - th * 0.5;
    float d1Wing = sdSegment(bP, pCenter, pWingTop) - th * 0.5;
    float d1Ret  = sdSegment(bP, pWingTop, pSpineTop) - th * 0.5;
    float path1D = min(min(d1Spur, d1Wing), d1Ret);

    // 3. Diagonal Lower Path: Top-Left Spur -> Center -> Bottom-Right Wing -> Bottom Spine
    float d2Spur = sdSegment(bP, pSpurTop, pCenter) - th * 0.5;
    float d2Wing = sdSegment(bP, pCenter, pWingBot) - th * 0.5;
    float d2Ret  = sdSegment(bP, pWingBot, pSpineBot) - th * 0.5;
    float path2D = min(min(d2Spur, d2Wing), d2Ret);

    float runeD = min(spineD, min(path1D, path2D));

    // 4. Searching / Pairing Beacon Pulses (Dual Expanding Waves)
    float wave1 = mod(uTime * 1.5, 1.0);
    float wave2 = mod(uTime * 1.5 + 0.5, 1.0);
    float rWave1 = mix(0.30, 0.90, wave1);
    float rWave2 = mix(0.30, 0.90, wave2);

    float ring1D = abs(sdCircle(p, rWave1)) - 0.035;
    float ring2D = abs(sdCircle(p, rWave2)) - 0.035;

    float px = max(fwidth(p.x) * 1.4, 0.001);

    float runeAlpha = clamp((0.0 - runeD) / px + 0.5, 0.0, 1.0);
    
    // Dim rune when disconnected
    float stateAlpha = (conn > 0.05 || uSearching > 0.05) ? 1.0 : 0.35;
    runeAlpha *= stateAlpha;

    float ring1Alpha = (uSearching > 0.05) ? clamp((0.0 - ring1D) / px + 0.5, 0.0, 1.0) * (1.0 - wave1) * 0.60 : 0.0;
    float ring2Alpha = (uSearching > 0.05) ? clamp((0.0 - ring2D) / px + 0.5, 0.0, 1.0) * (1.0 - wave2) * 0.60 : 0.0;

    float finalAlpha = max(runeAlpha, max(ring1Alpha, ring2Alpha));

    fragColor = uColor * finalAlpha * qt_Opacity;
}

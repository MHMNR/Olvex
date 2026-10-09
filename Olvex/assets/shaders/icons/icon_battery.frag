#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uLevel;       // 0.0 to 1.0 (battery level percentage)
    float uCharging;    // 1.0 (charging), 0.0 (discharging)
    float uTransition;  // 0.0 to 1.0 (spring transition)
    float uTime;
};

// 2D Rounded Box SDF
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// 2D Line Segment SDF
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // Shift left slightly so battery cap aligns perfectly
    vec2 bP = p - vec2(-0.06, 0.0);

    float strokeTh = 0.08;

    // 1. Outer Battery Body Rounded Capsule Frame
    vec2 frameSize = vec2(0.62, 0.32);
    float frameR = 0.12;
    float outerBoxD = sdRoundedBox(bP, frameSize, frameR);
    float frameD = abs(outerBoxD) - strokeTh * 0.5;

    // 2. Positive Terminal Cap (Right Nub)
    vec2 capPos = bP - vec2(0.68, 0.0);
    float capD = sdRoundedBox(capPos, vec2(0.06, 0.14), 0.04);

    float shellD = min(frameD, capD);

    // 3. Inner Fill Gauge Bar
    float lvl = clamp(uLevel, 0.05, 1.0);
    float maxInnerW = 0.52;
    float curInnerW = maxInnerW * lvl;
    
    // Fill aligns to the left inside the shell
    vec2 fillCenter = vec2(-maxInnerW + curInnerW, 0.0);
    vec2 fillSize = vec2(curInnerW, 0.23);
    float fillD = sdRoundedBox(bP - fillCenter, fillSize, 0.06);

    // 4. Centered Lightning Bolt (Charging Mode)
    vec2 bA = vec2(-0.02, -0.28);
    vec2 bB = vec2(-0.16, 0.02);
    vec2 bC = vec2(0.04, -0.02);
    vec2 bD = vec2(-0.10, 0.28);
    
    float bolt1 = sdSegment(bP, bA, bB) - 0.06;
    float bolt2 = sdSegment(bP, bB, bC) - 0.06;
    float bolt3 = sdSegment(bP, bC, bD) - 0.06;
    float boltD = min(min(bolt1, bolt2), bolt3);

    // AA Composition
    float px = max(fwidth(p.x) * 1.4, 0.001);

    float shellAlpha = clamp((0.0 - shellD) / px + 0.5, 0.0, 1.0);
    float fillAlpha  = clamp((0.0 - fillD) / px + 0.5, 0.0, 1.0);
    float boltAlpha  = (uCharging > 0.05) ? clamp((0.0 - boltD) / px + 0.5, 0.0, 1.0) * uCharging : 0.0;

    // Color logic: low battery (<20%) -> red/warning, charging -> green/bolt
    vec4 finalColor = uColor;
    if (uCharging > 0.5) {
        // Cutout lightning bolt negative space from fill
        fillAlpha = max(0.0, fillAlpha - boltAlpha);
    }

    float finalAlpha = max(max(shellAlpha, fillAlpha), boltAlpha);

    fragColor = finalColor * finalAlpha * qt_Opacity;
}

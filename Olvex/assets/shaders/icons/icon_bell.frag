#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uMuted;      // 0.0 (normal) to 1.0 (DND / muted)
    float uSwing;      // 0.0 (still) to 1.0 (ringing animation)
    float uHasBadge;   // 0.0 or 1.0 (notification indicator dot)
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

// 2D Trapezoid SDF
float sdTrapezoid(vec2 p, float r1, float r2, float he) {
    vec2 k1 = vec2(r2, he);
    vec2 k2 = vec2(r2 - r1, 2.0 * he);
    p.x = abs(p.x);
    vec2 ca = vec2(max(0.0, p.x - ((p.y < 0.0) ? r1 : r2)), abs(p.y) - he);
    vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

// 2D Rotation
vec2 rotate(vec2 p, float angle) {
    float s = sin(angle), c = cos(angle);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // Harmonic bell swing rotation around top hanger pivot
    vec2 pivot = vec2(0.0, -0.62);
    float swingAngle = sin(uTime * 10.0) * 0.20 * uSwing * (1.0 - uMuted);
    vec2 rP = rotate(p - pivot, swingAngle) + pivot;

    // 1. Top Hanger Loop
    float hangerD = sdCircle(rP - vec2(0.0, -0.58), 0.075);

    // 2. Bell Head Dome
    float domeD = sdCircle(rP - vec2(0.0, -0.22), 0.36);

    // 3. Bell Flared Waist & Skirt
    float skirtD = sdTrapezoid(rP - vec2(0.0, 0.06), 0.35, 0.54, 0.24) - 0.04;

    // Smooth blending of dome and skirt into a unified silhouette
    float h = clamp(0.5 + 0.5 * (skirtD - domeD) / 0.08, 0.0, 1.0);
    float bodyD = mix(skirtD, domeD, h) - 0.08 * h * (1.0 - h);

    // 4. Bottom Rim Lip
    float rimD = sdSegment(rP, vec2(-0.54, 0.32), vec2(0.54, 0.32)) - 0.055;
    float bellSolidD = min(hangerD, min(bodyD, rimD));

    // 5. Clapper (Bottom rounded sphere with counter-phase oscillation)
    float clapperAngle = -sin(uTime * 12.0) * 0.30 * uSwing * (1.0 - uMuted);
    vec2 clapperP = rotate(p - vec2(0.0, 0.32), clapperAngle) + vec2(0.0, 0.32);
    float clapperD = sdCircle(clapperP - vec2(0.0, 0.44), 0.115);

    // 6. Notification Indicator Badge (pulsing dot at top-right)
    float badgeD = sdCircle(p - vec2(0.60, -0.60), 0.15) * uHasBadge + 10.0 * (1.0 - uHasBadge);

    // 7. HyperOS 3 Mute Slash with Negative-Space Channel Knockout
    vec2 slashA = vec2(-0.70, -0.70);
    vec2 slashB = mix(vec2(-0.70, -0.70), vec2(0.70, 0.70), clamp(uMuted * 1.15, 0.0, 1.0));
    
    float slashD = sdSegment(p, slashA, slashB) - 0.085;  // Slash stroke
    float cutoutD = sdSegment(p, slashA, slashB) - 0.165; // Knockout negative space gap

    // AA Composition
    float px = max(fwidth(p.x) * 1.4, 0.001);

    // Knockout the bell body and clapper along the slash line
    float bellFinalD = (uMuted > 0.05) ? max(bellSolidD, -cutoutD) : bellSolidD;
    float clapperFinalD = (uMuted > 0.05) ? max(clapperD, -cutoutD) : clapperD;

    float bellAlpha = clamp((0.0 - bellFinalD) / px + 0.5, 0.0, 1.0);
    float clapperAlpha = clamp((0.0 - clapperFinalD) / px + 0.5, 0.0, 1.0);
    float badgeAlpha = (uHasBadge > 0.1) ? clamp((0.0 - badgeD) / px + 0.5, 0.0, 1.0) : 0.0;
    float slashAlpha = (uMuted > 0.01) ? clamp((0.0 - slashD) / px + 0.5, 0.0, 1.0) * smoothstep(0.0, 0.15, uMuted) : 0.0;

    float finalAlpha = max(max(bellAlpha, clapperAlpha), max(badgeAlpha, slashAlpha));

    fragColor = uColor * finalAlpha * qt_Opacity;
}

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uVolume;          // 0.0 to 1.0 (slider level)
    float uMuted;           // 0.0 to 1.0 (state morph: 0 = unmuted, 1 = muted)
    float uTransition;      // 0.0 to 1.0 (spring state change transition)
    float uTime;
};

// 2D Line Segment
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// 2D Box
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 2D Trapezoid
float sdTrapezoid(vec2 p, float r1, float r2, float he) {
    vec2 k1 = vec2(r2, he);
    vec2 k2 = vec2(r2 - r1, 2.0 * he);
    p.x = abs(p.x);
    vec2 ca = vec2(max(0.0, p.x - ((p.y < 0.0) ? r1 : r2)), abs(p.y) - he);
    vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

// Circular Arc opening to the right
float sdArcRight(vec2 p, float r, float angleSpan, float th) {
    float a = atan(p.y, p.x);
    if (abs(a) <= angleSpan && p.x > 0.0) {
        return abs(length(p) - r) - th * 0.5;
    }
    vec2 p1 = vec2(cos(angleSpan), sin(angleSpan)) * r;
    vec2 p2 = vec2(cos(-angleSpan), sin(-angleSpan)) * r;
    return min(length(p - p1), length(p - p2)) - th * 0.5;
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // HyperOS Tactile Squash & Stretch on mute/unmute toggle transition
    // uTransition gives a micro-bounce [1.0 -> 0.90 -> 1.0]
    float bounceScale = 1.0 + 0.12 * sin(uTransition * 3.14159265);
    vec2 bP = p / vec2(bounceScale, 2.0 - bounceScale);

    // Speaker position
    vec2 spP = bP - vec2(-0.16, 0.0);

    // 1. Speaker Body: Left box
    float boxD = sdBox(spP - vec2(-0.28, 0.0), vec2(0.10, 0.18)) - 0.04;

    // 2. Speaker Cone: Trapezoid
    vec2 coneP = vec2(spP.y, spP.x - (-0.08));
    float coneD = sdTrapezoid(coneP, 0.18, 0.42, 0.15) - 0.04;

    // Smooth union
    float h = clamp(0.5 + 0.5 * (coneD - boxD) / 0.06, 0.0, 1.0);
    float speakerD = mix(coneD, boxD, h) - 0.06 * h * (1.0 - h);

    // 3. HyperOS 3 Dual Bold Soundwave Arcs
    vec2 arcCenter = spP - vec2(0.02, 0.0);
    float th = 0.11; // Bold HyperOS stroke thickness
    float span = 0.65; // ~75 degree opening

    float waveCollapse = 1.0 - uMuted;
    float r1 = mix(0.18, 0.44, clamp(waveCollapse * 1.4, 0.0, 1.0));
    float r2 = mix(0.28, 0.78, clamp((waveCollapse - 0.25) * 1.5, 0.0, 1.0));

    float arc1D = sdArcRight(arcCenter, r1, span * clamp(waveCollapse * 1.3, 0.0, 1.0), th);
    float arc2D = sdArcRight(arcCenter, r2, span * clamp((waveCollapse - 0.2) * 1.3, 0.0, 1.0), th);

    float vol = clamp(uVolume, 0.0, 1.0);
    float a1 = smoothstep(0.04, 0.28, vol) * waveCollapse;
    float a2 = smoothstep(0.40, 0.72, vol) * clamp((waveCollapse - 0.2) * 1.4, 0.0, 1.0);

    // 4. Mute Slash Line (Dynamic Stroke Growth from top-left)
    vec2 slashA = vec2(-0.70, -0.70);
    vec2 slashB = mix(vec2(-0.70, -0.70), vec2(0.70, 0.70), clamp(uMuted * 1.15, 0.0, 1.0));
    float slashD = sdSegment(p, slashA, slashB) - 0.08;
    float cutoutD = sdSegment(p, slashA, slashB) - 0.16;

    // AA Composition
    float delta = fwidth(p.x) * 1.4;
    float pixelScale = max(delta, 0.001);

    float spFinalD = (uMuted > 0.1) ? max(speakerD, -cutoutD) : speakerD;
    float speakerAlpha = clamp((0.0 - spFinalD) / pixelScale + 0.5, 0.0, 1.0);

    float arc1Alpha = clamp((0.0 - arc1D) / pixelScale + 0.5, 0.0, 1.0) * a1;
    float arc2Alpha = clamp((0.0 - arc2D) / pixelScale + 0.5, 0.0, 1.0) * a2;
    float slashAlpha = (uMuted > 0.01) ? clamp((0.0 - slashD) / pixelScale + 0.5, 0.0, 1.0) * smoothstep(0.0, 0.2, uMuted) : 0.0;

    float finalAlpha = max(speakerAlpha, max(arc1Alpha, max(arc2Alpha, slashAlpha)));

    fragColor = uColor * finalAlpha * qt_Opacity;
}

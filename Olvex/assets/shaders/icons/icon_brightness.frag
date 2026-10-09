#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uBrightness;  // 0.0 to 1.0 (level)
    float uTransition;  // 0.0 to 1.0 (spring transition)
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

// 2D Rotation
vec2 rotate(vec2 p, float angle) {
    float s = sin(angle), c = cos(angle);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // HyperOS 3 Folme Spring Scale Bounce
    float bounce = 1.0 + 0.10 * sin(uTransition * 3.14159265);
    vec2 bP = p / bounce;

    float bVal = clamp(uBrightness, 0.0, 1.0);

    // Subtle continuous rotation for sun rays (1 rev per 24s)
    float rotAngle = uTime * 0.25;
    vec2 rP = rotate(bP, rotAngle);

    // 1. Central Sun Disc
    float sunR = mix(0.24, 0.38, bVal);
    float sunD = sdCircle(bP, sunR);

    // 2. 8 Radial Corona Rays (SDF Capsule Array)
    float raysD = 10.0;
    float rayInner = mix(0.44, 0.52, bVal);
    float rayOuter = mix(0.56, 0.84, bVal);
    float rayTh    = mix(0.06, 0.09, bVal);

    for (int i = 0; i < 8; i++) {
        float ang = float(i) * (3.14159265 / 4.0);
        vec2 dir = vec2(cos(ang), sin(ang));
        vec2 pA = dir * rayInner;
        vec2 pB = dir * rayOuter;
        float dRay = sdSegment(rP, pA, pB) - rayTh * 0.5;
        raysD = min(raysD, dRay);
    }

    // Ray visibility scales with brightness
    float rayAlphaScale = smoothstep(0.08, 0.35, bVal);

    // AA Composition
    float px = max(fwidth(p.x) * 1.4, 0.001);

    float sunAlpha  = clamp((0.0 - sunD) / px + 0.5, 0.0, 1.0);
    float raysAlpha = clamp((0.0 - raysD) / px + 0.5, 0.0, 1.0) * rayAlphaScale;

    float finalAlpha = max(sunAlpha, raysAlpha);

    fragColor = uColor * finalAlpha * qt_Opacity;
}

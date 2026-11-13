#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uProgress;
    float uTime;
    float uRadius;
    vec4 uPrimaryColor;
    vec2 uOrigin;
    vec2 uSize;
    float uSeed;
};

float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / max(edge1 - edge0, 0.0001), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Quintic C2-continuous value noise (zero 1st and 2nd derivative discontinuities across cells)
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 ROT_M = mat2(0.80, -0.60, 0.60, 0.80);

float fbm3(vec2 p) {
    float v = 0.0;
    float a = 0.52;
    for (int i = 0; i < 3; ++i) {
        v += a * valueNoise(p);
        p = ROT_M * p * 2.02 + vec2(17.1, 31.7);
        a *= 0.5;
    }
    return v;
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float p = clamp(uProgress, 0.0, 1.0);
    if (p <= 0.0005 || qt_Opacity <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 safeSize = max(uSize, vec2(1.0));
    vec2 pixelPos = qt_TexCoord0 * safeSize;

    // Analytical rounded card SDF clip with Euclidean gradient AA
    vec2 boxHalf = 0.5 * safeSize;
    float safeRadius = min(uRadius, min(boxHalf.x, boxHalf.y));
    float distBox = sdRoundedBox(pixelPos - boxHalf, boxHalf, safeRadius);
    float boxGrad = length(vec2(dFdx(distBox), dFdy(distBox)));
    float boxAA = max(boxGrad, 0.75);
    float boxMask = 1.0 - smootherstep(-boxAA, boxAA, distBox);
    if (boxMask <= 0.0005) {
        fragColor = vec4(0.0);
        return;
    }

    // Fast path when fully spread: 100% solid m3primary with zero FBM work
    if (p >= 0.999) {
        float fullAlpha = boxMask * qt_Opacity;
        fragColor = vec4(uPrimaryColor.rgb * fullAlpha, fullAlpha);
        return;
    }

    // Vector from M3Shape icon badge center (33, 33)
    vec2 delta = pixelPos - uOrigin;
    float dist = length(delta);
    vec2 dir = delta / max(dist, 0.001);

    // Distance to furthest corner from origin so p=1 covers 100% of card
    vec2 farCorner = max(uOrigin, safeSize - uOrigin);
    float maxDist = length(farCorner) + 24.0;

    // Seamless polar-vector + low-gradient radial coordinates (guarantees monotonic radial front)
    vec2 seedOff = vec2(uSeed * 19.37, uSeed * 43.19);
    vec2 flowPhase = vec2(uTime * 0.55 + p * 1.15, -uTime * 0.42 + p * 0.85);
    vec2 angularCoord = dir * 1.65 + seedOff;
    vec2 gentleRadial = delta / 280.0 - dir * (p * 0.95);

    // C2-continuous 2-stage domain-warped liquid contour lobes
    vec2 q = vec2(
        fbm3(angularCoord + gentleRadial + flowPhase * 0.55),
        fbm3(angularCoord + gentleRadial + vec2(5.2, 1.3) - flowPhase * 0.48)
    );
    float lobePrimary = fbm3(angularCoord * 1.25 + gentleRadial * 1.15 + 1.20 * (q - 0.5) + flowPhase * 0.40) - 0.5;
    float lobeSecondary = fbm3(angularCoord * 2.35 - 0.80 * (q - 0.5) - flowPhase * 0.65) - 0.5;

    // C2 window: 0 inside badge at p=0, organic fluid lobes mid-flight, 0 at p=1
    float waveEnv = smootherstep(0.0, 0.14, p) * (1.0 - smootherstep(0.74, 0.98, p));
    float waveScale = min(maxDist * 0.34, 96.0);
    float waveOffset = (lobePrimary * waveScale + lobeSecondary * (waveScale * 0.48)) * waveEnv;

    // Starts at r=11px (hidden inside the 36x36 M3Shape badge) and expands past furthest corner
    float baseFrontR = mix(11.0, maxDist * 1.12, p);
    float frontR = baseFrontR + waveOffset;

    // Euclidean gradient subpixel anti-aliased liquid boundary
    float signedDist = dist - frontR;
    float gradLen = clamp(length(vec2(dFdx(signedDist), dFdy(signedDist))), 0.85, 2.25);
    float edgeAA = gradLen * 1.15;
    float liquidMask = (1.0 - smootherstep(-edgeAA, edgeAA, signedDist)) * smootherstep(0.0, 0.008, p);

    float finalAlpha = clamp(liquidMask * boxMask * qt_Opacity, 0.0, 1.0);
    fragColor = vec4(uPrimaryColor.rgb * finalAlpha, finalAlpha);
}

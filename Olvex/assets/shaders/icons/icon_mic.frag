#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uMuted;       // 0.0 (active), 1.0 (muted)
    float uInputLevel;  // 0.0 to 1.0 (audio input level meter)
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

// 2D Rounded Arc SDF
float sdArcU(vec2 p, float r, float angleSpan, float th) {
    float a = atan(p.x, p.y);
    if (abs(a) <= angleSpan && p.y >= 0.0) {
        return abs(length(p) - r) - th * 0.5;
    }
    vec2 capR = vec2(sin(angleSpan), cos(angleSpan)) * r;
    vec2 capL = vec2(sin(-angleSpan), cos(-angleSpan)) * r;
    return min(length(p - capR), length(p - capL)) - th * 0.5;
}

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // HyperOS 3 Folme Spring Scale Bounce
    float bounce = 1.0 + 0.10 * sin(uTransition * 3.14159265);
    vec2 bP = p / bounce;

    float th = 0.09;

    // 1. Mic Rounded Capsule Head
    vec2 capA = vec2(0.0, -0.36);
    vec2 capB = vec2(0.0, -0.04);
    float capsuleD = sdSegment(bP, capA, capB) - 0.20;

    // 2. U-shaped Cradle Collar (opening upwards)
    vec2 cradleOrigin = vec2(0.0, -0.12);
    float cradleD = sdArcU(bP - cradleOrigin, 0.36, 1.57, th);

    // 3. Vertical Stand Stem
    vec2 stemA = vec2(0.0, 0.24);
    vec2 stemB = vec2(0.0, 0.52);
    float stemD = sdSegment(bP, stemA, stemB) - th * 0.5;

    // 4. Base Horizontal Foot
    vec2 baseA = vec2(-0.28, 0.52);
    vec2 baseB = vec2(0.28, 0.52);
    float baseD = sdSegment(bP, baseA, baseB) - th * 0.5;

    float micSolidD = min(min(capsuleD, cradleD), min(stemD, baseD));

    // 5. HyperOS 3 Mute Slash with Negative-Space Channel Knockout
    vec2 slashA = vec2(-0.70, -0.70);
    vec2 slashB = mix(vec2(-0.70, -0.70), vec2(0.70, 0.70), clamp(uMuted * 1.15, 0.0, 1.0));
    
    float slashD = sdSegment(p, slashA, slashB) - 0.085;  // Slash stroke
    float cutoutD = sdSegment(p, slashA, slashB) - 0.165; // Knockout negative space gap

    // AA Composition
    float px = max(fwidth(p.x) * 1.4, 0.001);

    // Knockout the mic body along the slash line
    float micFinalD = (uMuted > 0.05) ? max(micSolidD, -cutoutD) : micSolidD;

    float micAlpha   = clamp((0.0 - micFinalD) / px + 0.5, 0.0, 1.0);
    float slashAlpha = (uMuted > 0.01) ? clamp((0.0 - slashD) / px + 0.5, 0.0, 1.0) * smoothstep(0.0, 0.15, uMuted) : 0.0;

    float finalAlpha = max(micAlpha, slashAlpha);

    fragColor = uColor * finalAlpha * qt_Opacity;
}

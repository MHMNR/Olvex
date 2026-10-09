#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uColor;
    float uStrength;      // 0.0 to 1.0
    float uConnected;     // 1.0 (on), 0.0 (off)
    float uConnecting;    // 1.0 (searching/pulse)
    float uTransition;    // 0.0 to 1.0 (spring bounce)
    float uTime;
};

// 2D Circle SDF
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

// 2D Rounded Arc SDF centered at origin opening upwards
float sdArcBand(vec2 p, float r, float angleSpan, float th) {
    if (angleSpan <= 0.002) return 10.0;
    float a = atan(p.x, -p.y);
    float l = length(p);
    float ringDist = abs(l - r) - th * 0.5;
    
    // Check if inside angle span
    if (abs(a) <= angleSpan && p.y <= 0.0) {
        return ringDist;
    }
    
    // Rounded endcaps
    vec2 capR = vec2(sin(angleSpan), -cos(angleSpan)) * r;
    vec2 capL = vec2(sin(-angleSpan), -cos(-angleSpan)) * r;
    return min(length(p - capR), length(p - capL)) - th * 0.5;
}

void main() {
    // Normalize coordinates to [-1.0, 1.0] with aspect ratio 1:1
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;

    // HyperOS 3 Folme Spring Scale Bounce
    float bounce = 1.0 + 0.08 * sin(uTransition * 3.14159265);
    vec2 bP = p / bounce;

    // Center anchor for Wi-Fi concentric arcs
    vec2 origin = vec2(0.0, 0.48);
    vec2 wP = bP - origin;

    // Band Parameters
    float maxAngle = 0.733; // ~42 degrees each side (84 deg total span)
    float th = 0.12;        // Clean, bold HyperOS 3 stroke width

    // HyperOS 3 Cascading Staggered Arc Unroll (OFF -> ON)
    float conn = clamp(uConnected, 0.0, 1.0);
    
    // Center dot scales in (0.0 -> 0.3 of transition)
    float dotScale = smoothstep(0.0, 0.35, conn);
    float dotD = sdCircle(wP, mix(0.02, 0.11, dotScale));

    // Arc 1 unrolls (0.15 -> 0.60)
    float span1 = maxAngle * smoothstep(0.12, 0.55, conn);
    float arc1D = sdArcBand(wP, 0.36, span1, th);

    // Arc 2 unrolls (0.35 -> 0.80)
    float span2 = maxAngle * smoothstep(0.30, 0.75, conn);
    float arc2D = sdArcBand(wP, 0.66, span2, th);

    // Arc 3 unrolls (0.55 -> 1.00)
    float span3 = maxAngle * smoothstep(0.50, 1.00, conn);
    float arc3D = sdArcBand(wP, 0.96, span3, th);

    // Dynamic Signal Strength gating
    float str = clamp(uStrength, 0.0, 1.0);
    
    // Connecting / Searching Radar Sweep wave
    float radarWave = mod(uTime * 2.5, 3.0);
    float radDot = (uConnecting > 0.5) ? (1.0 - smoothstep(0.0, 0.8, abs(radarWave - 0.0))) : 1.0;
    float rad1   = (uConnecting > 0.5) ? (1.0 - smoothstep(0.0, 0.8, abs(radarWave - 1.0))) : 1.0;
    float rad2   = (uConnecting > 0.5) ? (1.0 - smoothstep(0.0, 0.8, abs(radarWave - 2.0))) : 1.0;
    float rad3   = (uConnecting > 0.5) ? (1.0 - smoothstep(0.0, 0.8, abs(radarWave - 3.0))) : 1.0;

    float aDot = max(dotScale, (uConnecting > 0.5 ? 0.3 + 0.7 * radDot : (conn < 0.05 ? 0.28 : 1.0)));
    float a1   = max(smoothstep(0.05, 0.25, str) * smoothstep(0.05, 0.2, span1), uConnecting * (0.2 + 0.8 * rad1));
    float a2   = max(smoothstep(0.30, 0.60, str) * smoothstep(0.05, 0.2, span2), uConnecting * (0.2 + 0.8 * rad2));
    float a3   = max(smoothstep(0.65, 0.90, str) * smoothstep(0.05, 0.2, span3), uConnecting * (0.2 + 0.8 * rad3));

    // Antialiasing using fwidth
    float px = max(fwidth(p.x) * 1.4, 0.001);

    float alphaDot = clamp((0.0 - dotD) / px + 0.5, 0.0, 1.0) * aDot;
    float alpha1   = clamp((0.0 - arc1D) / px + 0.5, 0.0, 1.0) * a1;
    float alpha2   = clamp((0.0 - arc2D) / px + 0.5, 0.0, 1.0) * a2;
    float alpha3   = clamp((0.0 - arc3D) / px + 0.5, 0.0, 1.0) * a3;

    // Off state: when disconnected and not connecting, show clean dimmed base dot + lowest arc
    if (conn < 0.05 && uConnecting < 0.05) {
        float offArc = sdArcBand(wP, 0.66, maxAngle, th * 0.85);
        float alphaOff = clamp((0.0 - offArc) / px + 0.5, 0.0, 1.0) * 0.20;
        alphaDot = max(alphaDot, 0.28);
        alpha2 = alphaOff;
    }

    float finalAlpha = max(max(alphaDot, alpha1), max(alpha2, alpha3));

    fragColor = uColor * finalAlpha * qt_Opacity;
}

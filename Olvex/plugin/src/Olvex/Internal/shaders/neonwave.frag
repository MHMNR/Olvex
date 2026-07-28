#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float maxHeightRatio;
    float edgeFeather;
    float topFadeRatio;
    int bandCount;
    float _pad0;
    float _pad1;
    vec4 accentColor;
    vec4 boostedColor;
    vec4 values[8];
};

float valueAt(int index) {
    index = clamp(index, 0, bandCount - 1);
    int vecIndex = index / 4;
    int component = index - vecIndex * 4;
    vec4 packed = values[vecIndex];
    if (component == 0)
        return packed.x;
    if (component == 1)
        return packed.y;
    if (component == 2)
        return packed.z;
    return packed.w;
}

float cubicValue(float p0, float p1, float p2, float p3, float t) {
    const float tension = 0.2;
    float cp1 = p1 + (p2 - p0) * tension;
    float cp2 = p2 - (p3 - p1) * tension;
    float invT = 1.0 - t;
    return invT * invT * invT * p1 + 3.0 * invT * invT * t * cp1 + 3.0 * invT * t * t * cp2 + t * t * t * p2;
}

float waveValue(float xNorm) {
    float pos = clamp(xNorm, 0.0, 1.0) * float(max(bandCount - 1, 1));
    int i = int(floor(pos));
    float t = pos - float(i);

    float p0 = valueAt(max(i - 1, 0));
    float p1 = valueAt(i);
    float p2 = valueAt(min(i + 1, bandCount - 1));
    float p3 = valueAt(min(i + 2, bandCount - 1));
    return clamp(cubicValue(p0, p1, p2, p3, t), 0.0, 1.0);
}

vec4 gradientColor(float fillRatio, float multiplier, bool innerPass) {
    float t = clamp(fillRatio / max(multiplier, 0.001), 0.0, 1.0);
    vec4 c1 = innerPass ? vec4(boostedColor.rgb, 0.9) : vec4(boostedColor.rgb, 0.8);
    vec4 c2 = innerPass ? vec4(accentColor.rgb, 0.7) : vec4(boostedColor.rgb, 0.4);
    vec4 c3 = innerPass ? vec4(accentColor.rgb, 0.15) : vec4(boostedColor.rgb, 0.1);
    vec4 c4 = vec4(boostedColor.rgb, 0.0);

    if (t <= 0.3)
        return mix(c1, c2, t / 0.3);
    if (t <= 0.8)
        return mix(c2, c3, (t - 0.3) / 0.5);
    return mix(c3, c4, (t - 0.8) / 0.2);
}

vec4 drawPass(vec2 pixel, float multiplier, bool innerPass) {
    float maxGlowH = itemHeight * maxHeightRatio;
    float value = waveValue(qt_TexCoord0.x);
    float top = itemHeight - value * maxGlowH * multiplier;
    float dist = pixel.y - top;
    float aa = max(edgeFeather, fwidth(dist));
    float fill = smoothstep(-aa, aa, dist);
    float fadePx = itemHeight * clamp(topFadeRatio, 0.0, 0.9);
    float topFade = fadePx > 0.5 ? smoothstep(0.0, fadePx, pixel.y) : 1.0;

    float fillRatio = clamp((itemHeight - pixel.y) / max(maxGlowH, 0.001), 0.0, 1.0);
    vec4 color = gradientColor(fillRatio, multiplier, innerPass);
    return vec4(color.rgb * color.a * fill * topFade, color.a * fill * topFade);
}

void main() {
    vec2 pixel = qt_TexCoord0 * vec2(itemWidth, itemHeight);

    vec4 outerPass = drawPass(pixel, 1.0, false);
    vec4 innerPass = drawPass(pixel, 0.65, true);

    float outAlpha = innerPass.a + outerPass.a * (1.0 - innerPass.a);
    vec3 outRgb = innerPass.rgb + outerPass.rgb * (1.0 - innerPass.a);

    fragColor = vec4(outRgb, outAlpha) * qt_Opacity;
}

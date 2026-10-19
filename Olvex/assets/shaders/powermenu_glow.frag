#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uAccentColor;
    vec2 uLightPos;   // (x, y) cursor pos in pixels relative to card top-left
    vec2 uSize;       // (width, height) of card in pixels
    float uRadius;    // card corner radius in pixels
};

// Signed distance field for rounded card box
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Triangular-PDF Dither (TPDF)
// Highest perceptual quality for eliminating 8-bit Mach bands / quantization stepping
float tpdfDither(vec2 pos) {
    vec3 m1 = vec3(0.06711056, 0.00583715, 52.9829189);
    vec3 m2 = vec3(0.07142857, 0.00392156, 37.1923412);
    float r1 = fract(m1.z * fract(dot(pos, m1.xy)));
    float r2 = fract(m2.z * fract(dot(pos + vec2(1.5, 3.7), m2.xy)));
    return (r1 - r2) * (1.5 / 255.0);
}

// C2-continuous quintic smootherstep (Perlin / Quilez)
// Has continuous 1st AND 2nd derivatives. Acceleration gracefully reaches 0 at edges.
// Zero Mach banding, zero ring contours.
float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * uSize;
    float dist = length(pixelPos - uLightPos);

    // Fluent Design style card spotlight radius
    float radius = max(uSize.x, uSize.y) * 0.95;

    // Invert smootherstep so center is 1.0 and smoothly decays to 0.0 at radius
    float glow = 1.0 - smootherstep(0.0, radius, dist);

    // Quadratic perceptual attenuation curve
    // Ensures a gentle, uniform falloff from center outwards
    float intensity = glow * glow * 0.40;

    // TPDF dithering to break color bit-depth banding
    intensity = clamp(intensity + tpdfDither(gl_FragCoord.xy), 0.0, 1.0);

    // SDF rounded rectangle clipping
    vec2 center = uSize * 0.5;
    vec2 p = pixelPos - center;
    float sdf = sdRoundedBox(p, center, uRadius);
    float fw = max(fwidth(sdf), 0.001);
    float clipAlpha = clamp(0.5 - sdf / fw, 0.0, 1.0);

    float finalAlpha = intensity * clipAlpha * qt_Opacity;
    fragColor = vec4(uAccentColor.rgb * finalAlpha, finalAlpha);
}

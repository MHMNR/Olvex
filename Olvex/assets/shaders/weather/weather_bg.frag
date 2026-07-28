#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float iKind;
    float iIsDay;
    vec4 iPrimary;
    vec4 iSecondary;
    vec4 iTertiary;
    float iWidth;
    float iHeight;
};

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec3 skyGradient(vec2 uv, float day)
{
    vec3 top = mix(iTertiary.rgb, iPrimary.rgb, 0.32);
    vec3 bot = mix(iSecondary.rgb, iPrimary.rgb, 0.48);
    vec3 base = mix(bot, top, clamp(uv.y, 0.0, 1.0));
    if (day < 0.5) {
        base *= 0.38;
        float stars = step(0.993, hash(floor(uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0)) * 0.45)));
        base += vec3(stars) * 0.55;
    }
    return base;
}

vec3 kindClear(vec2 uv, float t, float day)
{
    vec3 base = skyGradient(uv, day);
    if (day > 0.5) {
        vec2 sun = uv - vec2(0.8, 0.2);
        float glow = exp(-dot(sun, sun) * 20.0);
        float rays = pow(max(0.0, sin(atan(sun.y, sun.x) * 7.0 + t * 0.35)), 4.0);
        rays *= exp(-length(sun) * 2.8);
        base += iPrimary.rgb * glow * 0.85;
        base += iPrimary.rgb * rays * 0.22;
    } else {
        vec2 moon = uv - vec2(0.82, 0.18);
        base += iTertiary.rgb * exp(-dot(moon, moon) * 28.0) * 0.55;
    }
    return base;
}

vec3 kindCloudy(vec2 uv, float t, float day)
{
    vec3 base = kindClear(uv, t, day);
    float c1 = fbm(uv * vec2(2.2, 1.1) + vec2(t * 0.018, 0.0));
    float c2 = fbm(uv * vec2(1.6, 0.8) + vec2(-t * 0.012, 0.08));
    float clouds = smoothstep(0.4, 0.84, c1 * 0.55 + c2 * 0.45);
    vec3 cloudCol = day > 0.5 ? vec3(0.96, 0.97, 1.0) : vec3(0.55, 0.6, 0.75);
    return mix(base, cloudCol, clouds * (day > 0.5 ? 0.58 : 0.5));
}

vec3 kindOvercast(vec2 uv, float t)
{
    vec2 p = uv * vec2(2.4, 1.6) + vec2(t * 0.009, t * 0.004);
    float n = fbm(p);
    vec3 col = mix(iSecondary.rgb * 0.45, iTertiary.rgb * 0.55, n);
    col = mix(col, iPrimary.rgb * 0.22, fbm(p * 1.6 + 1.7) * 0.35);
    return col;
}

vec3 kindFog(vec2 uv, float t)
{
    float layers = fbm(uv * 2.8 + vec2(t * 0.007, -t * 0.003));
    float mist = fbm(uv * 1.1 + vec2(-t * 0.004, t * 0.002));
    float f = smoothstep(0.18, 0.92, layers * 0.58 + mist * 0.48);
    vec3 col = mix(iTertiary.rgb * 0.38, iSecondary.rgb * 0.5, uv.y);
    return mix(col, mix(iPrimary.rgb, vec3(0.9), 0.65), f * 0.72);
}

vec3 kindMist(vec2 uv, float t)
{
    vec3 fog = kindFog(uv, t);
    float veil = fbm(uv * 4.0 + vec2(t * 0.01, 0.0));
    return mix(fog, iTertiary.rgb * 0.55, veil * 0.35);
}

vec3 kindRain(vec2 uv, float t)
{
    vec3 base = kindOvercast(uv, t) * 0.72;
    vec2 grid = uv * vec2(max(iWidth, 1.0) * 0.09, max(iHeight, 1.0) * 0.16);
    vec2 id = floor(grid);
    float rnd = hash(id);
    float spd = 0.35 + rnd * 0.55;
    float drop = fract(grid.y + t * spd + rnd);
    float dropX = abs(fract(grid.x + rnd * 0.37) - 0.5);
    float streak = smoothstep(0.42, 0.0, dropX) * smoothstep(0.92, 0.15, drop);
    base += iPrimary.rgb * streak * 0.38;
    return base;
}

vec3 kindSnow(vec2 uv, float t)
{
    vec3 base = mix(iSecondary.rgb * 0.42, vec3(0.88, 0.9, 0.95), uv.y * 0.65);
    vec2 p = uv * vec2(max(iWidth, 1.0) * 0.045, max(iHeight, 1.0) * 0.07);
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float rnd = hash(cell);
    float y = fract(f.y + t * (0.12 + rnd * 0.22) + rnd);
    float x = f.x + sin(t * 0.45 + rnd * 6.28) * 0.12;
    float flake = smoothstep(0.14, 0.0, length(vec2(x, y) - vec2(0.5)));
    flake *= step(0.55, rnd);
    base += vec3(flake) * 0.85;
    return base;
}

vec3 kindStorm(vec2 uv, float t)
{
    vec3 base = kindRain(uv, t);
    float flash = pow(max(0.0, sin(t * 2.8 + hash(vec2(floor(t * 1.8), 1.0)) * 8.0)), 14.0);
    base += iTertiary.rgb * flash * 0.45;
    return base;
}

vec3 kindLoading(vec2 uv, float t)
{
    float wave = 0.5 + 0.5 * sin(t * 1.2 + uv.x * 4.0);
    return mix(iSecondary.rgb * 0.28, iPrimary.rgb * 0.22, wave);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float kind = iKind;
    float day = iIsDay;
    float t = iTime;
    vec3 col;

    if (kind < 0.5)
        col = kindClear(uv, t, 1.0);
    else if (kind < 1.5)
        col = kindCloudy(uv, t, 1.0);
    else if (kind < 2.5)
        col = kindOvercast(uv, t);
    else if (kind < 3.5)
        col = kindFog(uv, t);
    else if (kind < 4.5)
        col = kindMist(uv, t);
    else if (kind < 5.5)
        col = kindRain(uv, t);
    else if (kind < 6.5)
        col = kindSnow(uv, t);
    else if (kind < 7.5)
        col = kindStorm(uv, t);
    else if (kind < 8.5)
        col = kindClear(uv, t, 0.0);
    else if (kind < 9.5)
        col = kindCloudy(uv, t, 0.0);
    else
        col = kindLoading(uv, t);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
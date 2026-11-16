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
    float iSunProgress;
    float iMoonPhase;
    float iWindSpeed;
};

float windNorm()
{
    return clamp(iWindSpeed / 45.0, 0.0, 1.5);
}

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float valueNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash12(i + vec2(0.0, 0.0)), hash12(i + vec2(1.0, 0.0)), u.x),
        mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        v += a * valueNoise(p);
        p = rot * p * 2.03;
        a *= 0.5;
    }
    return v;
}

float sdSegment(vec2 p, vec2 a, vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

float getCycle(float forceNight)
{
    float c = mod(mod(iSunProgress, 2.0) + 2.0, 2.0);
    if (forceNight > 0.5 && c < 1.0)
        return 1.50;
    return c;
}

float getSunElev(float cycle)
{
    return sin(cycle * 3.14159265);
}

vec2 sunArcPos(float aspect, float cycle)
{
    float signedDay = (cycle > 1.5) ? (cycle - 2.0) : cycle;
    float theta = mix(2.62, 0.52, clamp(signedDay, -0.18, 1.18));
    float sunX = (0.50 + cos(theta) * 0.50) * aspect;
    float sunY = 1.48 - sin(theta) * 1.30;
    return vec2(sunX, sunY);
}

vec2 moonArcPos(float aspect, float cycle)
{
    float signedNight = (cycle < 0.5) ? (cycle + 1.0) : (cycle - 1.0);
    float theta = mix(2.62, 0.52, clamp(signedNight, -0.18, 1.18));
    float moonX = (0.50 + cos(theta) * 0.50) * aspect;
    float moonY = 1.48 - sin(theta) * 1.28;
    return vec2(moonX, moonY);
}

float goldenFactorFromElev(float sunElev)
{
    return exp(-pow((sunElev - 0.03) / 0.22, 2.0));
}

// ── Sky Base (Continuous 24h Night -> Blue Hour -> Golden Hour -> Day) ────────
vec3 skyBase(vec2 uv, vec2 aspectUV, float t, float day)
{
    float aspect = iWidth / max(iHeight, 1.0);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float dayWeight = smoothstep(-0.34, 0.32, sunElev);
    float blueHour = exp(-pow((sunElev + 0.16) / 0.16, 2.0));
    float twilight = goldenFactorFromElev(sunElev);
    vec2 sunPos = sunArcPos(aspect, cycle);

    // Night sky base
    vec3 nZenith  = mix(vec3(0.02, 0.04, 0.11), iSecondary.rgb * 0.16, 0.35);
    vec3 nHorizon = mix(vec3(0.07, 0.12, 0.24), iTertiary.rgb * 0.24, 0.38);
    vec3 nightCol = mix(nZenith, nHorizon, smoothstep(0.0, 1.0, uv.y));

    // Subtle diagonal Milky Way stardust band
    float starVis = smoothstep(0.10, -0.34, sunElev);
    if (starVis > 0.01) {
        vec2 mwUV = mat2(0.84, -0.54, 0.54, 0.84) * (aspectUV - vec2(0.5 * aspect, 0.45));
        float mwBand = exp(-pow(mwUV.y * 3.8, 2.0));
        float mwDust = fbm(mwUV * vec2(2.6, 4.2) + vec2(t * 0.004, 0.0));
        float mwCore = mwBand * smoothstep(0.28, 0.78, mwDust) * (1.0 - uv.y * 0.45);
        nightCol += mix(vec3(0.16, 0.24, 0.44), iPrimary.rgb * 0.45, 0.25) * mwCore * 0.26 * starVis;

        // 3-layer twinkling stars with 4-point diffraction glint on bright stars
        for (int layer = 0; layer < 3; layer++) {
            float scale = layer == 0 ? 11.0 : (layer == 1 ? 22.0 : 36.0);
            vec2 g = aspectUV * scale + float(layer) * 19.3;
            vec2 id = floor(g);
            vec2 f = fract(g) - 0.5;
            vec2 rnd = hash22(id);
            float thresh = layer == 0 ? 0.82 : (layer == 1 ? 0.84 : 0.80);
            float show = step(thresh, rnd.x);
            vec2 p = f - (rnd - 0.5) * 0.55;
            float d = length(p);
            float r = layer == 0 ? 0.085 : (layer == 1 ? 0.055 : 0.038);
            float core = smoothstep(r, 0.0, d);
            float glint = (layer == 0 && rnd.y > 0.62)
                ? (exp(-abs(p.x) * 30.0) * exp(-abs(p.y) * 8.0) + exp(-abs(p.y) * 30.0) * exp(-abs(p.x) * 8.0)) * 0.80
                : 0.0;
            float twinkle = 0.42 + 0.58 * sin(t * (1.4 + rnd.y * 2.8) + rnd.x * 50.0);
            vec3 starTint = mix(vec3(0.88, 0.94, 1.0), vec3(1.0, 0.92, 0.82), step(0.75, rnd.y) * 0.45);
            nightCol += starTint * (core + glint) * show * twinkle * (1.0 - uv.y * 0.48) * starVis;
        }

        // Slot-randomized diagonal shooting stars
        float mSlot = floor(t / 5.8);
        float mLocal = t - mSlot * 5.8;
        float mTrigger = 0.6 + hash12(vec2(mSlot, 3.7)) * 2.8;
        float mDt = mLocal - mTrigger;
        if (mDt >= 0.0 && mDt < 0.95) {
            float prog = mDt / 0.95;
            vec2 start = vec2((0.12 + 0.52 * hash12(vec2(mSlot, 7.1))) * aspect, 0.06 + 0.20 * hash12(vec2(mSlot, 11.3)));
            vec2 dir = vec2((0.36 + 0.25 * hash12(vec2(mSlot, 15.9))) * aspect, 0.20 + 0.12 * hash12(vec2(mSlot, 21.7)));
            vec2 head = start + dir * prog;
            vec2 tail = start + dir * max(0.0, prog - 0.24);
            float d = sdSegment(aspectUV, tail, head);
            float fade = sin(prog * 3.14159265);
            float meteor = smoothstep(0.007, 0.0, d) * fade;
            float headGlow = exp(-length(aspectUV - head) * 42.0) * fade * 0.7;
            nightCol += vec3(0.95, 0.98, 1.0) * (meteor * 1.15 + headGlow) * starVis;
        }
    }

    // Day sky base
    vec3 dayZenith  = mix(vec3(0.11, 0.36, 0.78), iPrimary.rgb, 0.25);
    vec3 dayMid     = mix(vec3(0.28, 0.56, 0.89), iPrimary.rgb, 0.22);
    vec3 dayHorizon = mix(vec3(0.50, 0.76, 0.96), iSecondary.rgb, 0.32);

    vec3 dayCol = mix(dayZenith, dayMid, smoothstep(0.0, 0.55, uv.y));
    dayCol = mix(dayCol, dayHorizon, smoothstep(0.42, 1.0, uv.y));

    vec3 col = mix(nightCol, dayCol, dayWeight);

    // Civil / nautical blue-hour transition between night and golden hour
    if (blueHour > 0.01) {
        vec3 bhZenith  = mix(vec3(0.05, 0.09, 0.24), iSecondary.rgb * 0.30, 0.24);
        vec3 bhHorizon = mix(vec3(0.24, 0.28, 0.50), iTertiary.rgb * 0.45, 0.22);
        vec3 bhCol = mix(bhZenith, bhHorizon, smoothstep(0.0, 1.0, uv.y));
        col = mix(col, bhCol, blueHour * 0.55);
    }

    // Smooth twilight / golden-hour bloom across dawn & dusk
    if (twilight > 0.01) {
        vec3 twiZenith  = mix(vec3(0.10, 0.14, 0.34), iSecondary.rgb * 0.45, 0.22);
        vec3 twiMid     = mix(vec3(0.74, 0.34, 0.44), iTertiary.rgb * 0.80, 0.20);
        vec3 twiHorizon = mix(vec3(0.98, 0.58, 0.26), iPrimary.rgb, 0.16);
        vec3 twiCol = mix(twiZenith, twiMid, smoothstep(0.05, 0.58, uv.y));
        twiCol = mix(twiCol, twiHorizon, smoothstep(0.45, 1.0, uv.y));
        col = mix(col, twiCol, twilight * 0.72);

        float horizGlow = exp(-abs(aspectUV.x - sunPos.x) * 1.25) * smoothstep(0.28, 0.98, uv.y);
        col += vec3(1.0, 0.60, 0.24) * horizGlow * twilight * 0.42;
    }
    return col;
}

// ── 0: Clear (Continuous Sunrise/Sunset Sun Arc + Calendar-Phase Moon) ────────
vec3 kindClear(vec2 uv, vec2 aspectUV, float t, float day)
{
    vec3 col = skyBase(uv, aspectUV, t, day);
    float aspect = iWidth / max(iHeight, 1.0);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float sunVis = smoothstep(-0.14, 0.10, sunElev);
    float moonVis = smoothstep(0.14, -0.14, sunElev);
    float golden = goldenFactorFromElev(sunElev);

    // Sun (rises smoothly from below horizon at dawn, sets smoothly at dusk)
    if (sunVis > 0.005) {
        vec2 sunPos = sunArcPos(aspect, cycle);
        vec2 d = aspectUV - sunPos;
        float dist = length(d);

        vec3 noonSun = mix(vec3(1.0, 0.96, 0.82), iPrimary.rgb, 0.20);
        vec3 goldSun = mix(vec3(1.0, 0.62, 0.24), iTertiary.rgb, 0.18);
        vec3 sunCol = mix(noonSun, goldSun, golden);

        float disc = smoothstep(0.095, 0.052, dist);
        float corona = exp(-dist * 4.8) * (0.65 + 0.08 * sin(t * 1.3));
        float wideGlow = exp(-dist * 1.45) * (0.32 + 0.24 * golden);

        float angle = atan(d.y, d.x);
        float ray1 = pow(max(0.0, sin(angle * 7.0 + t * 0.28)), 3.0);
        float ray2 = pow(max(0.0, cos(angle * 11.0 - t * 0.19)), 4.0);
        float rayShimmer = 0.82 + 0.18 * sin(angle * 3.0 + t * 0.65);
        float rays = (ray1 * 0.62 + ray2 * 0.38) * rayShimmer * exp(-dist * 1.35);

        vec2 axis = vec2(0.5 * aspect, 0.55) - sunPos;
        float flare1 = smoothstep(0.075, 0.045, length(aspectUV - (sunPos + axis * (0.48 + 0.03 * sin(t * 0.7))))) * 0.13;
        float flare2 = smoothstep(0.045, 0.022, length(aspectUV - (sunPos + axis * (0.82 - 0.02 * cos(t * 0.6))))) * 0.11;

        col += sunCol * (disc * 0.95 + corona + wideGlow + rays * (0.30 + 0.32 * golden) + flare1 + flare2) * sunVis;

        // Drifting warm sunlit dust motes
        vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
        vec2 mp = px + vec2(t * 10.0, -t * 7.0);
        vec2 mc = floor(mp / 58.0);
        vec2 mr = hash22(mc);
        if (mr.x > 0.58) {
            vec2 mf = fract(mp / 58.0) - 0.5;
            float md = length(mf - (mr - 0.5) * 0.45) * 58.0;
            float mote = smoothstep(2.4, 0.3, md) * (0.4 + 0.6 * sin(t * 1.8 + mr.y * 25.0));
            col += sunCol * mote * 0.25 * sunVis;
        }
    }

    // Calendar-based 3D Moon Phase (rises smoothly at dusk, sets smoothly at dawn)
    if (moonVis > 0.005) {
        vec2 moonPos = moonArcPos(aspect, cycle);
        vec2 moonDelta = aspectUV - moonPos;
        float dist = length(moonDelta);
        float moonR = 0.072;
        vec2 m = moonDelta / moonR;
        float r2 = dot(m, m);
        float discMask = smoothstep(1.04, 0.88, sqrt(r2));

        float phase = clamp(iMoonPhase, 0.0, 1.0);
        float theta = phase * 6.2831853;
        vec3 N = vec3(m.x, -m.y, sqrt(max(0.0, 1.0 - min(r2, 1.0))));
        vec3 L = normalize(vec3(sin(theta), 0.16, -cos(theta)));
        float sunlit = smoothstep(-0.06, 0.10, dot(N, L));
        float mare = 0.80 + 0.20 * fbm(moonDelta * 28.0 + vec2(3.1, 7.4));
        float phaseLit = mix(0.06, 1.0, sunlit) * mare;

        float illum = 0.5 - 0.5 * cos(theta);
        float innerHalo = exp(-dist * 3.8) * (0.46 + 0.05 * sin(t * 1.0)) * (0.25 + 0.75 * illum);
        float outerHalo = exp(-dist * 1.35) * 0.18 * (0.25 + 0.75 * illum);
        vec3 moonCol = mix(vec3(0.88, 0.93, 1.0), iTertiary.rgb, 0.22);
        col += moonCol * (discMask * phaseLit * 0.96 + innerHalo + outerHalo) * moonVis;

        // Gentle drifting moonlit night-air wisps
        float nWisp = fbm(vec2(aspectUV.x * 1.4 - t * 0.015, aspectUV.y * 3.6 + 5.2));
        float wispMask = smoothstep(0.55, 0.85, nWisp) * (1.0 - smoothstep(0.20, 0.85, uv.y));
        col = mix(col, mix(vec3(0.22, 0.30, 0.48), iSecondary.rgb * 0.45, 0.25), wispMask * 0.14 * moonVis);
    }

    // High-altitude wispy cirrus catching golden-hour or daylight
    float cirrusN = fbm(vec2(aspectUV.x * 1.6 - t * 0.018, aspectUV.y * 4.2 + 2.1));
    float cirrus = smoothstep(0.52, 0.82, cirrusN) * (1.0 - smoothstep(0.15, 0.72, uv.y));
    vec3 cirrusCol = mix(vec3(0.96, 0.98, 1.0), vec3(1.0, 0.68, 0.46), golden);
    col = mix(col, cirrusCol, cirrus * (0.12 + 0.16 * golden) * smoothstep(-0.20, 0.15, sunElev));

    return col;
}

// Organic non-repeating volumetric cloud density at a given altitude band
float cloudDensity(vec2 aspectUV, vec2 drift, vec2 scale, float yCenter, float bandTightness, float coverage, float seed)
{
    vec2 p = vec2(aspectUV.x * scale.x - drift.x, (aspectUV.y - yCenter) * scale.y - drift.y) + seed;
    // Domain warp for natural billowing asymmetry (never looks like a repeated emoji)
    vec2 q = vec2(
        fbm(p * 0.85 + vec2(1.7, 9.2)),
        fbm(p * 0.85 + vec2(8.3, 2.8))
    );
    float n = fbm(p + q * 0.95);
    float band = exp(-pow((aspectUV.y - yCenter) * bandTightness, 2.0));
    float raw = n * 0.78 + band * 0.42 - (1.0 - coverage);
    return smoothstep(0.38, 0.56, raw);
}

vec2 sunArcPos(float aspect)
{
    return sunArcPos(aspect, getCycle(0.0));
}

float goldenFactor()
{
    return goldenFactorFromElev(getSunElev(getCycle(0.0)));
}

// ── 1: Cloudy (Self-shadowed volumetric clouds w/ 24h lighting) ───────────────
vec3 kindCloudy(vec2 uv, vec2 aspectUV, float t, float day)
{
    vec3 col = kindClear(uv, aspectUV, t, day);
    float aspect = iWidth / max(iHeight, 1.0);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);
    vec2 lightPos = mix(moonArcPos(aspect, cycle), sunArcPos(aspect, cycle), step(0.0, sunElev));
    vec2 sunDir = normalize(lightPos - aspectUV);

    vec3 dayLit = mix(mix(vec3(0.99, 0.99, 1.0), vec3(1.0, 0.74, 0.48), golden * 0.72), iPrimary.rgb, 0.08);
    vec3 dayShd = mix(mix(vec3(0.56, 0.65, 0.78), vec3(0.52, 0.40, 0.54), golden * 0.60), iSecondary.rgb, 0.20);
    vec3 nightLit = mix(vec3(0.38, 0.45, 0.64), iTertiary.rgb, 0.18);
    vec3 nightShd = vec3(0.11, 0.14, 0.24);
    vec3 litCol = mix(nightLit, dayLit, w);
    vec3 shdCol = mix(nightShd, dayShd, w);

    // 1. High wispy cirrus streaks
    float cirrus = cloudDensity(aspectUV, vec2(t * 0.045, 0.0), vec2(1.2, 4.8), 0.22, 4.2, 0.72, 3.1);
    col = mix(col, litCol, cirrus * 0.36);

    // 2. Mid-altitude billowing cloud bank with directional self-shadowing
    float dMid = cloudDensity(aspectUV, vec2(t * 0.085, 0.0), vec2(1.9, 2.6), 0.38, 2.9, 0.76, 11.7);
    float dMidSun = cloudDensity(aspectUV + sunDir * 0.035, vec2(t * 0.085, 0.0), vec2(1.9, 2.6), 0.38, 2.9, 0.76, 11.7);
    float midLight = clamp(0.65 + (dMid - dMidSun) * 2.2, 0.10, 1.0);
    col = mix(col, mix(shdCol, litCol, midLight), dMid * 0.86);

    // 3. Lower foreground drifting cloud clusters
    float dNear = cloudDensity(aspectUV, vec2(t * 0.135, 0.0), vec2(1.4, 2.2), 0.60, 2.6, 0.70, 27.4);
    float dNearSun = cloudDensity(aspectUV + sunDir * 0.042, vec2(t * 0.135, 0.0), vec2(1.4, 2.2), 0.60, 2.6, 0.70, 27.4);
    float nearLight = clamp(0.60 + (dNear - dNearSun) * 2.4, 0.08, 1.0);
    col = mix(col, mix(shdCol, litCol, nearLight), dNear * 0.90);

    return col;
}

// ── 2: Overcast (Thick cloud deck — sun/moon hidden, ambient day/night/twilight)
vec3 kindOvercast(vec2 uv, vec2 aspectUV, float t, float day)
{
    vec3 sky = skyBase(uv, aspectUV, t, day);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);

    vec3 darkSky = mix(vec3(0.05, 0.07, 0.13), mix(mix(vec3(0.20, 0.24, 0.32), vec3(0.32, 0.22, 0.32), golden * 0.55), iSecondary.rgb * 0.35, 0.30), w);
    vec3 midSky  = mix(vec3(0.11, 0.14, 0.22), mix(mix(vec3(0.36, 0.42, 0.50), vec3(0.56, 0.36, 0.38), golden * 0.55), iTertiary.rgb * 0.45, 0.30), w);
    vec3 col = mix(mix(darkSky, midSky, uv.y), sky, 0.18);

    // 3 faster-drifting high-contrast cloud billows
    float c1 = fbm(vec2(aspectUV.x * 1.4 - t * 0.14, aspectUV.y * 2.4));
    float c2 = fbm(vec2(aspectUV.x * 2.3 - t * 0.22, aspectUV.y * 3.6 + 4.7));
    float c3 = fbm(vec2(aspectUV.x * 3.5 - t * 0.30, aspectUV.y * 4.8 + 8.3));

    float ridge1 = smoothstep(0.36, 0.72, c1);
    float ridge2 = smoothstep(0.42, 0.76, c2);
    float ridge3 = smoothstep(0.45, 0.78, c3);

    vec3 silver = mix(vec3(0.22, 0.26, 0.36), mix(mix(vec3(0.68, 0.73, 0.82), vec3(0.94, 0.66, 0.50), golden * 0.72), iPrimary.rgb * 0.78, 0.18), w);
    vec3 belly  = mix(vec3(0.06, 0.08, 0.14), mix(mix(vec3(0.20, 0.24, 0.32), vec3(0.36, 0.24, 0.32), golden * 0.60), iSecondary.rgb * 0.28, 0.28), w);

    col = mix(col, silver, ridge1 * 0.48 * (1.0 - uv.y * 0.45));
    col = mix(col, belly,  ridge2 * 0.50);
    col = mix(col, silver * 0.88, ridge3 * 0.34);

    // Sweeping diffuse light break
    float shaft = exp(-pow((aspectUV.x - mod(t * 0.24, 2.4) + 0.5 + uv.y * 0.35) * 3.2, 2.0));
    col += silver * shaft * mix(0.10, 0.22, w) * (1.0 - uv.y * 0.6);
    return col;
}

// ── 3: Fog (Layered atmospheric depth fog with 24h scatter & hue) ───────────
vec3 kindFog(vec2 uv, vec2 aspectUV, float t, float day)
{
    float aspect = iWidth / max(iHeight, 1.0);
    vec3 sky = skyBase(uv, aspectUV, t, day);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);
    vec2 lightPos = mix(moonArcPos(aspect, cycle), sunArcPos(aspect, cycle), step(0.0, sunElev));

    vec3 skyTop = mix(vec3(0.06, 0.09, 0.16), mix(mix(vec3(0.32, 0.38, 0.46), vec3(0.54, 0.38, 0.44), golden * 0.65), iSecondary.rgb * 0.48, 0.24), w);
    vec3 fogMid = mix(vec3(0.15, 0.19, 0.27), mix(mix(vec3(0.56, 0.61, 0.68), vec3(0.84, 0.62, 0.52), golden * 0.68), iTertiary.rgb * 0.58, 0.18), w);
    vec3 fogLow = mix(vec3(0.22, 0.26, 0.35), mix(mix(vec3(0.76, 0.80, 0.85), vec3(0.96, 0.74, 0.56), golden * 0.65), iPrimary.rgb * 0.78, 0.14), w);

    vec3 col = mix(skyTop, fogMid, smoothstep(0.0, 0.55, uv.y));
    col = mix(col, fogLow, smoothstep(0.45, 1.0, uv.y));
    col = mix(col, sky, 0.24 * (1.0 - uv.y * 0.65));

    // Broad ambient upper-sky luminance (thick fog hides direct sun/moon spot)
    float upperGlow = smoothstep(0.65, 0.0, uv.y);
    vec3 ambientCol = mix(vec3(0.28, 0.36, 0.52), mix(vec3(0.86, 0.88, 0.92), vec3(0.98, 0.70, 0.46), golden), w);
    col += ambientCol * upperGlow * mix(0.08, 0.16 + 0.10 * golden, w);

    // 4 silky domain-warped horizontal fog sheets at different depths
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float speed = 0.028 + fi * 0.016;
        vec2 p = vec2(aspectUV.x * (0.9 + fi * 0.35) - t * speed, aspectUV.y * (2.6 + fi * 0.9) + fi * 3.7);
        vec2 warp = vec2(fbm(p * 0.7 + vec2(t * 0.015, 0.0)), fbm(p * 0.7 + vec2(4.2, 1.9)));
        float sheet = fbm(p + warp * 0.65);
        float depthFade = smoothstep(0.10 + fi * 0.10, 0.90, uv.y);
        float alpha = smoothstep(0.28, 0.78, sheet) * depthFade * (0.24 + fi * 0.07);
        vec3 layerCol = mix(fogMid, fogLow, 0.35 + fi * 0.18);
        col = mix(col, layerCol, alpha);
    }
    return col;
}

// ── 4: Drizzle / Mist (Soft mist ribbons + fine light drizzle streaks) ────────
vec3 kindMist(vec2 uv, vec2 aspectUV, float t, float day)
{
    float aspect = iWidth / max(iHeight, 1.0);
    vec3 sky = skyBase(uv, aspectUV, t, day);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);
    vec2 lightPos = mix(moonArcPos(aspect, cycle), sunArcPos(aspect, cycle), step(0.0, sunElev));

    vec3 clearTop = mix(vec3(0.05, 0.08, 0.15), mix(mix(vec3(0.20, 0.30, 0.44), vec3(0.48, 0.34, 0.44), golden * 0.60), iPrimary.rgb * 0.45, 0.24), w);
    vec3 coolBot  = mix(vec3(0.12, 0.16, 0.26), mix(mix(vec3(0.36, 0.46, 0.58), vec3(0.78, 0.54, 0.46), golden * 0.62), iSecondary.rgb * 0.50, 0.26), w);
    vec3 col = mix(mix(clearTop, coolBot, uv.y), sky, 0.38 * (1.0 - uv.y * 0.35));

    float scatter = exp(-length(aspectUV - lightPos) * 1.15);
    vec3 scatterCol = mix(vec3(0.48, 0.58, 0.80), mix(vec3(0.95, 0.96, 1.0), vec3(1.0, 0.70, 0.38), golden), w);
    col += scatterCol * scatter * mix(0.10, 0.20 + 0.16 * golden, w);

    vec3 ribbonCol = mix(
        mix(vec3(0.36, 0.44, 0.58), iPrimary.rgb * 0.55, 0.18),
        mix(mix(vec3(0.84, 0.90, 0.96), vec3(1.0, 0.78, 0.62), golden * 0.65), iPrimary.rgb, 0.18),
        w
    );

    // Delicate thin horizontal mist wisps
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float yTarget = 0.25 + fi * 0.18;
        float waveY = yTarget + sin(aspectUV.x * 2.2 - t * (0.25 + fi * 0.06) + fi * 1.7) * 0.045;
        float ribbon = exp(-pow((uv.y - waveY) * 18.0, 2.0));
        float breakN = smoothstep(0.28, 0.75, valueNoise(vec2(aspectUV.x * 2.0 - t * (0.12 + fi * 0.04), fi * 5.3)));
        col = mix(col, ribbonCol, ribbon * breakN * 0.38);
    }

    // Fine delicate drizzle streaks (distinct from heavy rain)
    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    float dAngle = 0.08 + windNorm() * 0.16;
    float ca = cos(dAngle);
    float sa = sin(dAngle);
    vec2 rp = mat2(ca, -sa, sa, ca) * px;
    float dCellW = 18.0;
    float dCol = floor(rp.x / dCellW);
    float dRnd = hash12(vec2(dCol, 3.7));
    float dRnd2 = hash12(vec2(dCol * 1.9 + 5.1, 8.3));
    float dCenterX = (dCol + 0.2 + dRnd2 * 0.6) * dCellW;
    float dDx = abs(rp.x - dCenterX);
    float dPeriod = 26.0 + dRnd * 18.0;
    float dY = mod(rp.y - t * (165.0 + dRnd2 * 45.0) - dRnd * 500.0, dPeriod);
    float dStreak = step(dY, 10.0) * smoothstep(0.0, 10.0, dY) * smoothstep(0.95, 0.0, dDx) * step(0.32, dRnd2);
    col += ribbonCol * dStreak * 0.42;

    // Suspended fine mist droplets drifting gently
    vec2 mp = px - vec2(t * 18.0, t * 5.0);
    vec2 mc = floor(mp / 42.0);
    vec2 mr = hash22(mc);
    if (mr.x > 0.52) {
        vec2 mf = fract(mp / 42.0) - 0.5;
        float md = length(mf - (mr - 0.5) * 0.45) * 42.0;
        float dew = smoothstep(2.0, 0.3, md) * (0.35 + 0.65 * sin(t * 2.0 + mr.y * 20.0));
        col += ribbonCol * dew * 0.28;
    }
    return col;
}

// ── Staggered, razor-thin slanted rain layer (zero grid/block artifacts) ──────
float rainLayer(vec2 px, float t, float angle, float density, float speed, float lenPx, float widthPx, float seed)
{
    float ca = cos(angle);
    float sa = sin(angle);
    vec2 rp = mat2(ca, -sa, sa, ca) * px;

    float cellW = 1.0 / max(density, 0.001);
    float colIdx = floor(rp.x / cellW);
    float colRnd = hash12(vec2(colIdx, seed));
    float colRnd2 = hash12(vec2(colIdx * 1.7 + 9.3, seed + 4.1));

    float centerX = (colIdx + 0.22 + colRnd2 * 0.56) * cellW;
    float dx = abs(rp.x - centerX);

    float period = lenPx * (2.3 + colRnd * 2.0);
    float yScroll = rp.y - t * speed * (0.84 + colRnd2 * 0.32) - colRnd * 900.0;
    float yInPeriod = mod(yScroll, period);
    float streakLen = lenPx * (0.70 + colRnd * 0.65);

    float inStreak = step(yInPeriod, streakLen);
    float tailFade = pow(smoothstep(0.0, streakLen, yInPeriod), 1.35);
    float lineAlpha = smoothstep(widthPx, 0.0, dx) * inStreak * tailFade;

    return lineAlpha * step(0.18, colRnd2);
}

// ── 5: Rain (Gentle 3-layer slanted rain + soft surface splash glints) ─────────
vec3 kindRain(vec2 uv, vec2 aspectUV, float t, float angle, float speedScale, float day)
{
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);
    vec3 col = kindOvercast(uv, aspectUV, t * 0.65, day) * mix(0.78, 0.82, w);
    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));

    float rFar  = rainLayer(px, t, angle - 0.02, 0.068, 220.0 * speedScale, 18.0, 0.85, 1.0);
    float rMid  = rainLayer(px, t, angle,        0.044, 320.0 * speedScale, 28.0, 1.15, 7.3);
    float rNear = rainLayer(px, t, angle + 0.02, 0.024, 440.0 * speedScale, 40.0, 1.50, 19.7);

    vec3 streakCol = mix(
        mix(vec3(0.56, 0.68, 0.88), iPrimary.rgb * 0.65, 0.22),
        mix(mix(vec3(0.78, 0.88, 1.0), vec3(1.0, 0.82, 0.68), golden * 0.55), iPrimary.rgb, 0.22),
        w
    );
    col += streakCol * (rFar * 0.22 + rMid * 0.42 + rNear * 0.65);

    // Gentle raindrop splash ripples along bottom edge
    if (uv.y > 0.78) {
        float spX = floor(px.x / 28.0);
        float spRnd = hash12(vec2(spX, floor(t * 2.2)));
        if (spRnd > 0.68) {
            float life = fract(t * 2.2 + spRnd);
            vec2 spCenter = vec2((spX + 0.5) * 28.0, iHeight * (0.86 + spRnd * 0.10));
            vec2 diff = (px - spCenter) * vec2(1.0, 2.4);
            float ring = smoothstep(2.0, 0.0, abs(length(diff) - life * 10.0));
            col += streakCol * ring * (1.0 - life) * 0.28;
        }
    }
    return col;
}

// ── 3x3-neighbor-checked DOF snow layer (flutter, bokeh, crystalline glints) ──
float snowLayer(vec2 px, float t, float cellSize, float speed, float wind, float radius, float blur, float density, float crystalAmt, float seed)
{
    float windGust = sin(t * 0.31) * 0.35 + sin(t * 0.13 + 2.1) * 0.25;
    vec2 p = px - vec2(t * wind * (1.0 + windGust * 0.45), t * speed);
    vec2 baseCell = floor(p / cellSize);
    vec2 f = fract(p / cellSize);
    float acc = 0.0;

    for (int oy = -1; oy <= 1; oy++) {
        for (int ox = -1; ox <= 1; ox++) {
            vec2 c = baseCell + vec2(float(ox), float(oy));
            vec2 rnd = hash22(c + seed);
            if (rnd.x < density)
                continue;
            float rnd3 = hash12(c * 1.37 + seed + 17.1);
            float freq = 0.9 + rnd.y * 1.5;
            float phase = rnd.x * 25.0 + rnd3 * 12.0;

            float swayX = sin(t * freq + phase) * 0.18 + cos(t * freq * 1.73 + phase) * 0.07;
            float swayY = cos(t * freq * 0.85 + phase * 1.3) * 0.08;
            vec2 pos = vec2(float(ox), float(oy)) + vec2(0.5) + (rnd - 0.5) * 0.46 + vec2(swayX, swayY);

            vec2 delta = (f - pos) * cellSize;
            float d = length(delta);
            float localR = radius * (0.62 + rnd3 * 0.72);

            float core = smoothstep(localR * 0.55 + blur * 0.35, 0.0, d);
            float halo = smoothstep(localR + blur, max(0.0, localR * 0.35), d) * 0.55;
            float flake = max(core, halo);

            if (crystalAmt > 0.01 && d < localR + blur + 2.0) {
                float ang = atan(delta.y, delta.x) + t * (rnd.y - 0.5) * 1.6 + rnd3 * 6.283;
                float arms = pow(0.5 + 0.5 * cos(ang * 6.0), 2.2);
                float crystalR = localR * (0.72 + 0.48 * arms);
                float crystalCore = smoothstep(crystalR + blur * 0.45, max(0.0, crystalR * 0.25), d);
                float centerDot = smoothstep(localR * 0.38, 0.0, d);
                float crystal = max(centerDot, crystalCore * (0.68 + 0.32 * arms));
                flake = mix(flake, crystal, crystalAmt * smoothstep(0.45, 0.85, rnd3));
            }

            float alpha = (0.48 + 0.52 * rnd3) * (0.85 + 0.15 * sin(t * 2.2 + phase));
            acc = min(1.0, acc + flake * alpha * 0.88);
        }
    }
    return acc;
}

// ── 6: Snow (Winter cloud haze, blowing drift + 4-layer DOF crystal snowfall) ─
vec3 kindSnow(vec2 uv, vec2 aspectUV, float t, float day)
{
    float aspect = iWidth / max(iHeight, 1.0);
    vec3 sky = skyBase(uv, aspectUV, t, day);
    float cycle = getCycle(1.0 - day);
    float sunElev = getSunElev(cycle);
    float w = smoothstep(-0.34, 0.32, sunElev);
    float golden = goldenFactorFromElev(sunElev);
    vec2 lightPos = mix(moonArcPos(aspect, cycle), sunArcPos(aspect, cycle), step(0.0, sunElev));

    vec3 top = mix(vec3(0.05, 0.08, 0.15), mix(mix(vec3(0.20, 0.26, 0.36), vec3(0.42, 0.28, 0.38), golden * 0.58), iSecondary.rgb * 0.40, 0.32), w);
    vec3 bot = mix(vec3(0.14, 0.19, 0.30), mix(mix(vec3(0.44, 0.52, 0.64), vec3(0.76, 0.52, 0.44), golden * 0.58), iTertiary.rgb * 0.50, 0.30), w);
    vec3 col = mix(mix(top, bot, smoothstep(0.0, 1.0, uv.y)), sky, 0.30 * (1.0 - uv.y * 0.25));

    float scatter = exp(-length(aspectUV - lightPos) * 1.10);
    vec3 scatterCol = mix(vec3(0.44, 0.56, 0.78), mix(vec3(0.94, 0.96, 1.0), vec3(1.0, 0.72, 0.42), golden), w);
    col += scatterCol * scatter * mix(0.08, 0.16 + 0.14 * golden, w);

    vec3 cloudCol = mix(vec3(0.16, 0.20, 0.30), mix(mix(vec3(0.56, 0.64, 0.75), vec3(0.84, 0.58, 0.52), golden * 0.62), iPrimary.rgb, 0.16), w);
    float snowCloud = fbm(vec2(aspectUV.x * 1.4 - t * 0.022, aspectUV.y * 2.4));
    float cloudMask = smoothstep(0.32, 0.78, snowCloud) * (1.0 - smoothstep(0.15, 0.72, uv.y));
    col = mix(col, cloudCol, cloudMask * 0.34);

    vec3 driftCol = mix(vec3(0.24, 0.29, 0.40), mix(mix(vec3(0.76, 0.82, 0.90), vec3(0.94, 0.72, 0.58), golden * 0.55), iPrimary.rgb, 0.14), w);
    float driftN = fbm(vec2(aspectUV.x * 2.2 - t * 0.065, aspectUV.y * 3.5 - t * 0.015));
    float driftMask = smoothstep(0.45, 1.0, uv.y) * smoothstep(0.35, 0.82, driftN);
    col = mix(col, driftCol, driftMask * 0.24);

    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    float sDeep = snowLayer(px, t, 22.0, 20.0,  6.0, 0.95, 0.85, 0.42, 0.00,  1.7);
    float sFar  = snowLayer(px, t, 34.0, 32.0, 11.0, 1.55, 1.15, 0.46, 0.00,  5.3);
    float sMid  = snowLayer(px, t, 52.0, 48.0, 16.0, 2.55, 1.50, 0.54, 0.45, 13.1);
    float sNear = snowLayer(px, t, 88.0, 70.0, 24.0, 4.60, 2.80, 0.68, 0.75, 29.7);

    vec3 flakeCol = mix(vec3(0.95, 0.98, 1.0), iPrimary.rgb, 0.08);
    float snowAmt = sDeep * 0.26 + sFar * 0.42 + sMid * 0.72 + sNear * 0.62;
    col += flakeCol * snowAmt * (1.0 - col * 0.35);
    return col;
}

// ── 7: Storm (Gentle-paced storm rain + irregular forked/sheet lightning) ─────
vec3 kindStorm(vec2 uv, vec2 aspectUV, float t, float day)
{
    vec3 col = kindRain(uv, aspectUV, t, 0.25, 1.25, day) * 0.74;
    float aspect = iWidth / max(iHeight, 1.0);

    // Irregular non-metronome lightning slots (~3.6s windows, ~50% active, random offset)
    float slot = floor(t / 3.6);
    float localT = t - slot * 3.6;
    float rA = hash12(vec2(slot, 13.7));
    float rB = hash12(vec2(slot, 29.3));

    if (rA > 0.42) {
        float triggerT = 0.5 + rB * 2.1;
        float dt = localT - triggerT;
        if (dt >= 0.0 && dt < 0.55) {
            // Natural asymmetric flash envelope (sharp strike + decay + optional secondary flicker)
            float strike1 = exp(-dt * 22.0) * smoothstep(0.0, 0.015, dt);
            float strike2 = (rA > 0.68) ? exp(-max(0.0, dt - 0.14) * 26.0) * step(0.14, dt) * 0.75 : 0.0;
            float flash = strike1 + strike2;

            float bx = (0.18 + 0.64 * hash12(vec2(slot, 41.9))) * aspect;
            // Internal cloud illumination (uneven FBM-modulated glow in upper cloud deck)
            float cloudN = fbm(aspectUV * 3.2 + vec2(slot * 3.1, 0.0));
            float cloudGlow = exp(-length((aspectUV - vec2(bx, 0.14)) * vec2(0.85, 1.6)) * 2.4) * (0.5 + 0.8 * cloudN);
            vec3 flashCol = mix(vec3(0.76, 0.86, 1.0), iTertiary.rgb, 0.25);
            col += flashCol * flash * (0.20 + 0.70 * cloudGlow);

            // ~55% of strikes produce a visible forked cloud-to-ground bolt
            if (rB > 0.45) {
                vec2 p0 = vec2(bx, 0.0);
                vec2 p1 = p0 + vec2((hash12(vec2(slot, 1.1)) - 0.5) * 0.12, 0.14);
                vec2 p2 = p1 + vec2((hash12(vec2(slot, 2.2)) - 0.5) * 0.14, 0.15);
                vec2 p3 = p2 + vec2((hash12(vec2(slot, 3.3)) - 0.5) * 0.14, 0.16);
                vec2 p4 = p3 + vec2((hash12(vec2(slot, 4.4)) - 0.5) * 0.12, 0.15);
                vec2 p5 = p4 + vec2((hash12(vec2(slot, 5.5)) - 0.5) * 0.10, 0.16);

                float dMain = min(
                    min(sdSegment(aspectUV, p0, p1), sdSegment(aspectUV, p1, p2)),
                    min(min(sdSegment(aspectUV, p2, p3), sdSegment(aspectUV, p3, p4)), sdSegment(aspectUV, p4, p5))
                );

                // 2 forked side branches
                vec2 b1a = p1 + vec2((hash12(vec2(slot, 6.6)) - 0.5) * 0.16, 0.12);
                vec2 b1b = b1a + vec2((hash12(vec2(slot, 7.7)) - 0.5) * 0.12, 0.13);
                vec2 b2a = p3 + vec2((hash12(vec2(slot, 8.8)) - 0.5) * 0.15, 0.12);
                float dBranch = min(min(sdSegment(aspectUV, p1, b1a), sdSegment(aspectUV, b1a, b1b)), sdSegment(aspectUV, p3, b2a));

                float boltCore = smoothstep(0.0055, 0.0008, dMain) + smoothstep(0.0035, 0.0005, dBranch) * 0.65;
                float boltHalo = (exp(-dMain * 55.0) + exp(-dBranch * 70.0) * 0.5) * 0.55;
                col += vec3(0.95, 0.98, 1.0) * (boltCore + boltHalo) * flash;
            }
        }
    }
    return col;
}

// ── 10: Loading ───────────────────────────────────────────────────────────────
vec3 kindLoading(vec2 uv, float t)
{
    float wave = 0.5 + 0.5 * sin(t * 1.8 + uv.x * 3.5 - uv.y * 1.5);
    return mix(iSecondary.rgb * 0.28, iPrimary.rgb * 0.36, wave);
}

// ── 11: Sleet / Freezing Rain (Cold overcast + icy rain streaks + ice pellets) ─
vec3 kindSleet(vec2 uv, vec2 aspectUV, float t, float day)
{
    float w = smoothstep(-0.34, 0.32, getSunElev(getCycle(1.0 - day)));
    vec3 col = kindOvercast(uv, aspectUV, t * 0.75, day) * mix(0.84, 0.88, w);
    col = mix(col, vec3(0.55, 0.72, 0.90) * mix(0.32, 0.68, w), 0.18);

    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    float angle = 0.16 + windNorm() * 0.20;
    float rThin = rainLayer(px, t, angle, 0.052, 260.0, 20.0, 0.95, 3.1);
    float pellets = snowLayer(px, t, 36.0, 125.0, 18.0 + windNorm() * 24.0, 1.9, 0.55, 0.52, 0.0, 14.3);

    vec3 iceCol = mix(vec3(0.76, 0.88, 1.0), iPrimary.rgb, 0.14);
    col += iceCol * (rThin * 0.38 + pellets * 0.72);
    return col;
}

// ── 12: Heavy Rain / Downpour (Dark clouds + 4-layer dense sheets + splashes) ──
vec3 kindHeavyRain(vec2 uv, vec2 aspectUV, float t, float day)
{
    float w = smoothstep(-0.34, 0.32, getSunElev(getCycle(1.0 - day)));
    vec3 col = kindOvercast(uv, aspectUV, t * 0.95, day) * mix(0.64, 0.68, w);
    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    float angle = 0.22 + windNorm() * 0.22;

    float rFar  = rainLayer(px, t, angle - 0.02, 0.085, 300.0, 22.0, 0.95, 2.3);
    float rMid  = rainLayer(px, t, angle,        0.058, 420.0, 34.0, 1.25, 9.1);
    float rNear = rainLayer(px, t, angle + 0.02, 0.036, 540.0, 48.0, 1.65, 21.4);

    vec3 streakCol = mix(vec3(0.62, 0.75, 0.94), iPrimary.rgb, 0.20);
    col += streakCol * (rFar * 0.30 + rMid * 0.52 + rNear * 0.78);

    if (uv.y > 0.72) {
        float spX = floor(px.x / 20.0);
        float spRnd = hash12(vec2(spX, floor(t * 3.4)));
        if (spRnd > 0.52) {
            float life = fract(t * 3.4 + spRnd);
            vec2 spCenter = vec2((spX + 0.5) * 20.0, iHeight * (0.82 + spRnd * 0.14));
            vec2 diff = (px - spCenter) * vec2(1.0, 2.4);
            float ring = smoothstep(2.2, 0.0, abs(length(diff) - life * 12.0));
            col += streakCol * ring * (1.0 - life) * 0.38;
        }
    }
    return col;
}

// ── 13: Thunderstorm with Hail (Lightning + storm rain + faceted hailstones) ───
vec3 kindHailStorm(vec2 uv, vec2 aspectUV, float t, float day)
{
    vec3 col = kindStorm(uv, aspectUV, t, day);
    vec2 px = uv * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    float hailFar  = snowLayer(px, t, 46.0, 185.0, 28.0 + windNorm() * 26.0, 2.2, 0.35, 0.62, 0.0, 31.7);
    float hailNear = snowLayer(px, t, 74.0, 240.0, 38.0 + windNorm() * 34.0, 3.6, 0.45, 0.72, 0.0, 47.9);
    vec3 hailCol = vec3(0.92, 0.96, 1.0);
    col += hailCol * (hailFar * 0.58 + hailNear * 0.88);
    return col;
}

// ── 14: Haze / Dust / Heat Shimmer (Warm amber haze + convective shimmer) ────
vec3 kindHaze(vec2 uv, vec2 aspectUV, float t, float day)
{
    float shimmer = sin(uv.y * 28.0 - t * 3.2 + sin(uv.x * 12.0 + t * 1.4)) * 0.008 * smoothstep(0.15, 0.95, uv.y);
    vec2 sUV = vec2(uv.x + shimmer, uv.y);
    vec2 sAspect = vec2(aspectUV.x + shimmer, aspectUV.y);

    float w = smoothstep(-0.34, 0.32, getSunElev(getCycle(1.0 - day)));
    vec3 sky = skyBase(sUV, sAspect, t, day);
    vec3 hazeTop = mix(vec3(0.14, 0.11, 0.16), mix(vec3(0.76, 0.58, 0.40), iTertiary.rgb * 0.85, 0.25), w);
    vec3 hazeBot = mix(vec3(0.24, 0.18, 0.18), mix(vec3(0.95, 0.72, 0.44), iPrimary.rgb * 0.90, 0.22), w);
    vec3 col = mix(mix(hazeTop, hazeBot, smoothstep(0.0, 1.0, sUV.y)), sky, 0.28);

    // Drifting warm dust bands + suspended dust motes
    float dustBand = fbm(vec2(sAspect.x * 1.4 - t * (0.045 + windNorm() * 0.06), sAspect.y * 2.8));
    col = mix(col, hazeBot * 1.08, smoothstep(0.35, 0.82, dustBand) * 0.38);

    vec2 px = sUV * vec2(max(iWidth, 1.0), max(iHeight, 1.0));
    vec2 mp = px - vec2(t * (22.0 + windNorm() * 30.0), -t * 6.0);
    vec2 mc = floor(mp / 46.0);
    vec2 mr = hash22(mc);
    if (mr.x > 0.48) {
        vec2 mf = fract(mp / 46.0) - 0.5;
        float md = length(mf - (mr - 0.5) * 0.45) * 46.0;
        float speck = smoothstep(2.2, 0.3, md) * (0.4 + 0.6 * sin(t * 2.1 + mr.y * 22.0));
        col += vec3(1.0, 0.84, 0.56) * speck * 0.34;
    }
    return col;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 aspectUV = vec2(uv.x * (iWidth / max(iHeight, 1.0)), uv.y);
    float kind = iKind;
    float t = iTime;
    vec3 col;

    float day = 1.0;
    float wAngle = 0.16 + windNorm() * 0.22;
    if (kind < 0.5)
        col = kindClear(uv, aspectUV, t, day);
    else if (kind < 1.5)
        col = kindCloudy(uv, aspectUV, t, day);
    else if (kind < 2.5)
        col = kindOvercast(uv, aspectUV, t, day);
    else if (kind < 3.5)
        col = kindFog(uv, aspectUV, t, day);
    else if (kind < 4.5)
        col = kindMist(uv, aspectUV, t, day);
    else if (kind < 5.5)
        col = kindRain(uv, aspectUV, t, wAngle, 1.0 + windNorm() * 0.25, day);
    else if (kind < 6.5)
        col = kindSnow(uv, aspectUV, t, day);
    else if (kind < 7.5)
        col = kindStorm(uv, aspectUV, t, day);
    else if (kind < 8.5)
        col = kindClear(uv, aspectUV, t, 0.0);
    else if (kind < 9.5)
        col = kindCloudy(uv, aspectUV, t, 0.0);
    else if (kind < 10.5)
        col = kindLoading(uv, t);
    else if (kind < 11.5)
        col = kindSleet(uv, aspectUV, t, day);
    else if (kind < 12.5)
        col = kindHeavyRain(uv, aspectUV, t, day);
    else if (kind < 13.5)
        col = kindHailStorm(uv, aspectUV, t, day);
    else
        col = kindHaze(uv, aspectUV, t, day);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}

.pragma library

function isValidSeed(seed) {
    return seed && seed.a > 0 && seed.hslLightness > 0.02;
}

// Visualizer — vibrant, saturated glow from thumbnail seed.
function vibrantAccent(seed) {
    if (!isValidSeed(seed))
        return null;

    const hue = seed.hslHue;
    let sat = Math.min(0.96, Math.max(0.58, seed.hslSaturation * 1.45 + 0.22));
    let lit = Math.min(0.80, Math.max(0.44, seed.hslLightness * 1.25 + 0.20));

    if (seed.hslSaturation < 0.14) {
        sat = 0.64;
        lit = 0.54;
    }

    return Qt.hsla(hue, sat, lit, 1);
}

// Tinted surface color based on global theme
function surfaceColor(seed, isLight) {
    if (!isValidSeed(seed))
        return null;

    const hue = seed.hslHue;
    const sat = Math.min(0.20, seed.hslSaturation * 0.4); 
    const lit = isLight ? 0.94 : 0.12;

    return Qt.hsla(hue, sat, lit, 1);
}

function onSurfaceColor(isLight) {
    return isLight ? Qt.rgba(0, 0, 0, 0.90) : Qt.rgba(1, 1, 1, 0.90);
}

// Play/pause fill — adapts to global theme
function playButtonFill(primary, isLight) {
    if (!isValidSeed(primary))
        return null;

    const sat = Math.min(1.0, primary.hslSaturation * 1.22 + 0.08);
    const lit = isLight ? Math.min(0.35, primary.hslLightness) : Math.max(0.82, primary.hslLightness);
    return Qt.hsla(primary.hslHue, sat, lit, primary.a);
}

function relativeLuminance(c) {
    if (!isValidSeed(c))
        return 0;

    function channel(v) {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }

    return channel(c.r) * 0.2126 + channel(c.g) * 0.7152 + channel(c.b) * 0.0722;
}

// Play icon on fill
function playIconOnFill(isLight, fill) {
    if (isValidSeed(fill))
        return relativeLuminance(fill) > 0.48 ? Qt.rgba(0, 0, 0, 0.92) : Qt.rgba(1, 1, 1, 0.94);
    return isLight ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0, 0, 0, 0.92);
}

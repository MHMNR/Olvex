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

// Play/pause fill — m3primary with slightly richer chroma on light pill.
function playButtonFill(primary) {
    if (!isValidSeed(primary))
        return null;

    const sat = Math.min(1.0, primary.hslSaturation * 1.22 + 0.08);
    return Qt.hsla(primary.hslHue, sat, primary.hslLightness, primary.a);
}

// Light primary fill — fixed dark icon for contrast.
function playIconOnFill() {
    return Qt.rgba(0, 0, 0, 0.92);
}
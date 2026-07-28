.pragma library

// Matches M3ExpressivePalette / Legacy M3Palette writable roles (m3* + term0–15).
var PALETTE_PROPS = {
    m3primary: true,
    m3onPrimary: true,
    m3primaryContainer: true,
    m3onPrimaryContainer: true,
    m3secondary: true,
    m3onSecondary: true,
    m3secondaryContainer: true,
    m3onSecondaryContainer: true,
    m3tertiary: true,
    m3onTertiary: true,
    m3tertiaryContainer: true,
    m3onTertiaryContainer: true,
    m3error: true,
    m3onError: true,
    m3errorContainer: true,
    m3onErrorContainer: true,
    m3background: true,
    m3onBackground: true,
    m3surface: true,
    m3onSurface: true,
    m3surfaceVariant: true,
    m3onSurfaceVariant: true,
    m3surfaceDim: true,
    m3surfaceBright: true,
    m3surfaceContainerLowest: true,
    m3surfaceContainerLow: true,
    m3surfaceContainer: true,
    m3surfaceContainerHigh: true,
    m3surfaceContainerHighest: true,
    m3inverseSurface: true,
    m3inverseOnSurface: true,
    m3inversePrimary: true,
    m3outline: true,
    m3outlineVariant: true,
    m3shadow: true,
    m3scrim: true,
    m3surfaceTint: true,
    m3primaryFixed: true,
    m3primaryFixedDim: true,
    m3onPrimaryFixed: true,
    m3onPrimaryFixedVariant: true,
    m3secondaryFixed: true,
    m3secondaryFixedDim: true,
    m3onSecondaryFixed: true,
    m3onSecondaryFixedVariant: true,
    m3tertiaryFixed: true,
    m3tertiaryFixedDim: true,
    m3onTertiaryFixed: true,
    m3onTertiaryFixedVariant: true,
    m3success: true,
    m3onSuccess: true,
    m3successContainer: true,
    m3onSuccessContainer: true,
    term0: true,
    term1: true,
    term2: true,
    term3: true,
    term4: true,
    term5: true,
    term6: true,
    term7: true,
    term8: true,
    term9: true,
    term10: true,
    term11: true,
    term12: true,
    term13: true,
    term14: true,
    term15: true
};

function hexColour(value) {
    if (!value)
        return "";
    const raw = String(value).trim();
    if (raw.startsWith("#"))
        return raw;
    return "#" + raw;
}

function snakeToM3Prop(name) {
    const camel = name.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    return camel.startsWith("term") ? camel : "m3" + camel;
}

function mapsToPalette(name) {
    return !!PALETTE_PROPS[snakeToM3Prop(name)];
}

function filterScheme(scheme) {
    if (!scheme || !scheme.colours)
        return scheme;

    const colours = {};
    for (const [name, colour] of Object.entries(scheme.colours)) {
        if (mapsToPalette(name))
            colours[name] = colour;
    }
    return Object.assign({}, scheme, { colours: colours });
}

function parseSchemePayloadRaw(data) {
    if (!data || !data.length)
        return null;
    try {
        const trimmed = String(data).trim();
        if (trimmed.startsWith("{"))
            return JSON.parse(trimmed);
        const match = trimmed.match(/\{[\s\S]*\}/);
        if (!match)
            return null;
        return JSON.parse(match[0]);
    } catch (e) {
        console.log("[M3ColorMapper] parse failed:", e);
        return null;
    }
}

function parseSchemePayload(data) {
    const scheme = parseSchemePayloadRaw(data);
    return scheme ? filterScheme(scheme) : null;
}

function stringifySchemePayload(data) {
    const scheme = parseSchemePayload(data);
    return scheme ? JSON.stringify(scheme) : "";
}

function extractPrimaryColour(scheme) {
    if (!scheme?.colours)
        return "";
    const raw = scheme.colours.primary ?? scheme.colours.m3primary;
    if (!raw)
        return "";
    return hexColour(raw);
}

function schemeColour(scheme, ...keys) {
    const colours = scheme?.colours;
    if (!colours)
        return "";
    for (let i = 0; i < keys.length; i++) {
        const hit = colours[keys[i]];
        if (hit)
            return hexColour(hit);
    }
    return "";
}

function applySchemeToPalette(palette, scheme) {
    if (!palette || !scheme || !scheme.colours)
        return false;

    const filtered = filterScheme(scheme);
    for (const [name, colour] of Object.entries(filtered.colours)) {
        const prop = snakeToM3Prop(name);
        if (prop in palette)
            palette[prop] = hexColour(colour);
    }
    return true;
}
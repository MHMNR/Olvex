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
    m3success: true,
    m3onSuccess: true,
    m3successContainer: true,
    m3onSuccessContainer: true
};

// Konsole / Qt colour templates — must stay in scheme.json for `apply_colours`.
var KONSOLE_PROPS = {
    klink: true,
    klinkSelection: true,
    kvisited: true,
    kvisitedSelection: true,
    knegative: true,
    knegativeSelection: true,
    kneutral: true,
    kneutralSelection: true,
    kpositive: true,
    kpositiveSelection: true
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
    if (KONSOLE_PROPS[name])
        return true;
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

// Built-in M3 Expressive dark defaults — used only when no wallpaper is set.
function fallbackScheme() {
    return {
        name: "fallback",
        mode: "dark",
        colours: {
            m3primary: "#CFBCFF",
            m3onPrimary: "#381E72",
            m3primaryContainer: "#4F378A",
            m3onPrimaryContainer: "#E9DDFF",
            m3secondary: "#CCC2DC",
            m3onSecondary: "#332D41",
            m3secondaryContainer: "#4A4458",
            m3onSecondaryContainer: "#E8DEF8",
            m3tertiary: "#EFB8C8",
            m3onTertiary: "#492532",
            m3tertiaryContainer: "#633B48",
            m3onTertiaryContainer: "#FFD8E4",
            m3error: "#F2B8B5",
            m3onError: "#601410",
            m3errorContainer: "#8C1D18",
            m3onErrorContainer: "#F9DEDC",
            m3background: "#141218",
            m3onBackground: "#E6E1E5",
            m3surface: "#141218",
            m3onSurface: "#E6E1E5",
            m3surfaceVariant: "#49454F",
            m3onSurfaceVariant: "#CAC4D0",
            m3surfaceDim: "#141218",
            m3surfaceBright: "#3B383E",
            m3surfaceContainerLowest: "#0F0D13",
            m3surfaceContainerLow: "#1D1B20",
            m3surfaceContainer: "#211F26",
            m3surfaceContainerHigh: "#2B2930",
            m3surfaceContainerHighest: "#36343B",
            m3inverseSurface: "#E6E1E5",
            m3inverseOnSurface: "#313033",
            m3inversePrimary: "#6750A4",
            m3outline: "#938F99",
            m3outlineVariant: "#49454F",
            m3shadow: "#000000",
            m3scrim: "#000000",
            m3surfaceTint: "#CFBCFF"
        }
    };
}
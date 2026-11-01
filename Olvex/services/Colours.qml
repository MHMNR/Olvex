pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import "color"

Singleton {
    id: root

    // ── Palette ─────────────────────────────────────
    signal themePaletteUpdated
    property bool themeTransitioning: false

    M3ExpressivePalette {
        id: bootPalette
    }

    property string bootSchemeMode: "dark"
    readonly property string schemeMode: bootSchemeMode
    property string bootSchemeName: "dynamic"
    readonly property string schemeName: bootSchemeName
    property string bootSchemeFlavour: "default"
    readonly property string schemeFlavour: bootSchemeFlavour
    readonly property bool configLight: {
        const mode = GlobalConfig.appearance.themeMode;
        const schemeIsLight = (bootSchemeMode === "light");
        if (mode === "light") return true;
        if (mode === "dark") return false;
        return schemeIsLight;
    }
    readonly property bool light: configLight
    readonly property var palette: bootPalette
    readonly property var tPalette: bootTPalette
    readonly property var current: bootPalette
    readonly property var preview: bootPalette

    // ── Transparency ────────────────────────────────
    readonly property bool transparencyEnabled: Tokens.transparency.enabled
    readonly property real transparencyBase: {
        const isLight = root.light;
        const t = Tokens.transparency;
        if (!t) return 0.5;
        const val = isLight
            ? ((t.baseLight !== undefined && t.baseLight > 0) ? t.baseLight : t.base)
            : ((t.baseDark !== undefined && t.baseDark > 0) ? t.baseDark : t.base);
        return Math.max(0.01, Math.min(1, val));
    }
    readonly property real transparencyLayers: {
        const isLight = root.light;
        const t = Tokens.transparency;
        if (!t) return 0.4;
        const val = isLight
            ? ((t.layersLight !== undefined && t.layersLight >= 0) ? t.layersLight : (t.layers ?? 0.4))
            : ((t.layersDark !== undefined && t.layersDark >= 0) ? t.layersDark : (t.layers ?? 0.4));
        return Math.max(0, Math.min(1, val));
    }
    readonly property bool transparencyBlur: Tokens.transparency.blur
    property int customBlurRadius: -1
    property int customBlurPasses: -1
    readonly property int transparencyBlurRadius: customBlurRadius > 0 ? customBlurRadius : (Tokens.transparency.blurRadius ?? (GlobalConfig.appearance.transparency.blurRadius ? GlobalConfig.appearance.transparency.blurRadius : 8))
    readonly property int transparencyBlurPasses: customBlurPasses > 0 ? customBlurPasses : (Tokens.transparency.blurPasses ?? (GlobalConfig.appearance.transparency.blurPasses ? GlobalConfig.appearance.transparency.blurPasses : 2))
    onTransparencyEnabledChanged: root.requestReloadHyprRules()
    onTransparencyBaseChanged: root.requestReloadHyprRules()
    onTransparencyLayersChanged: root.requestReloadHyprRules()
    onTransparencyBlurChanged: root.requestReloadHyprRules()
    onTransparencyBlurRadiusChanged: root.requestReloadHyprRules()
    onTransparencyBlurPassesChanged: root.requestReloadHyprRules()
    onLightChanged: root.syncActiveTransparency()

    function syncActiveTransparency() {
        if (!GlobalConfig.appearance || !GlobalConfig.appearance.transparency) return;
        const t = GlobalConfig.appearance.transparency;
        const targetBase = root.light
            ? ((t.baseLight !== undefined && t.baseLight > 0) ? t.baseLight : t.base)
            : ((t.baseDark !== undefined && t.baseDark > 0) ? t.baseDark : t.base);
        const targetLayers = root.light
            ? ((t.layersLight !== undefined && t.layersLight >= 0) ? t.layersLight : t.layers)
            : ((t.layersDark !== undefined && t.layersDark >= 0) ? t.layersDark : t.layers);
        let changed = false;
        if (Math.abs(t.base - targetBase) > 0.0001) {
            t.base = targetBase;
            changed = true;
        }
        if (Math.abs(t.layers - targetLayers) > 0.0001) {
            t.layers = targetLayers;
            changed = true;
        }
        if (changed) {
            GlobalConfig.save();
        }
    }

    function setBlurRadius(radius) {
        customBlurRadius = Math.max(1, Math.min(30, Math.round(radius)));
        root.requestReloadHyprRules();
    }

    function setBlurPasses(passes) {
        customBlurPasses = Math.max(1, Math.min(5, Math.round(passes)));
        root.requestReloadHyprRules();
    }

    // ── Wallpaper luminance ─────────────────────────
    readonly property real wallLuminance: analyser.luminance

    ImageAnalyser {
        id: analyser
        source: Wallpapers.colourSourcePath(Wallpapers.current)
    }

    // ── Layer / transparency math (inlined from engine) ──
    function getLuminance(c) {
        if (c.r === 0 && c.g === 0 && c.b === 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function surfaceLayer(layerLevel) {
        const layer = layerLevel ?? 1;
        if (!light || layer === 0)
            return layer;
        return Math.min(4, layer + 1);
    }

    function contrastRatio(a, b) {
        const la = getLuminance(a);
        const lb = getLuminance(b);
        const hi = Math.max(la, lb);
        const lo = Math.min(la, lb) + 1e-6;
        return (hi + 0.05) / (lo + 0.05);
    }

    function containerAtLevel(level) {
        if (level <= 1)
            return bootPalette.m3surfaceContainerLow;
        if (level === 2)
            return bootPalette.m3surfaceContainer;
        if (level === 3)
            return bootPalette.m3surfaceContainerHigh;
        return bootPalette.m3surfaceContainerHighest;
    }

    function tintContainer(base, amount) {
        const tint = bootPalette.m3primaryContainer;
        return Qt.rgba(
            Math.max(0, Math.min(1, base.r * (1 - amount) + tint.r * amount)),
            Math.max(0, Math.min(1, base.g * (1 - amount) + tint.g * amount)),
            Math.max(0, Math.min(1, base.b * (1 - amount) + tint.b * amount)),
            1);
    }

    // Opaque, palette-tinted shell surface used by ContentWindow blobs (same tint with transparency on or off;
    // opacity is applied once by ContentWindow via transparencyBase).
    readonly property color shellTint: light
        ? tintContainer(bootPalette.m3surfaceContainer, 0.25)
        : tintContainer(bootPalette.m3surface, 0.14)
    readonly property color shellTintDrawer: light
        ? tintContainer(bootPalette.m3surfaceContainer, 0.30)
        : tintContainer(bootPalette.m3surface, 0.22)

    function opaqueLightContainer(layerLevel, againstColor) {
        const level = Math.max(1, Math.min(4, layerLevel ?? 2));
        const base = bootPalette.m3surfaceContainerLowest;

        // Guard: If bootPalette is still dark during async refresh, synthesize an instant light container
        if (getLuminance(base) < 0.40) {
            const h = base.hslHue >= 0 ? base.hslHue : 0;
            const s = Math.min(0.20, base.hslSaturation * 0.35);
            const l = Math.min(0.99, 0.92 + level * 0.018);
            return Qt.hsla(h, s, l, 1.0);
        }

        const tintAmounts = [0.20, 0.13, 0.08, 0.04, 0.01];
        return tintContainer(base, tintAmounts[level] ?? 0.08);
    }

    function opaqueDarkContainer(layerLevel) {
        const level = Math.max(1, Math.min(4, layerLevel ?? 2));
        // Dark M3 Expressive hierarchy (matching Android dark screenshots):
        // Level 1 (recessed/search well): deep dark container (#1d1311)
        // Level 2 (elevated card/bar pill/dock): warm dark container (#2f201d) clearly above shellTint (#1f1411)
        // Level 3 (inner tile / QS toggle pill): lifted warm brown-grey (#3d2b26)
        // Level 4 (hover / icon well / highest): bright warm brown-grey (#4c3630)
        if (level === 1)
            return tintContainer(bootPalette.m3surfaceContainerLow, 0.05);
        if (level === 2)
            return tintContainer(bootPalette.m3surfaceContainerHigh, 0.12);
        if (level === 3) {
            const base = tintContainer(bootPalette.m3surfaceContainerHighest, 0.20);
            return Qt.tint(base, Qt.alpha(bootPalette.m3onSurface, 0.04));
        }
        const base = tintContainer(bootPalette.m3surfaceContainerHighest, 0.26);
        return Qt.tint(base, Qt.alpha(bootPalette.m3onSurface, 0.10));
    }

    function alterColour(c, a, layerLevel) {
        const layer = Math.max(1, Math.min(4, surfaceLayer(layerLevel)));
        if (!light) {
            const darkRgb = opaqueDarkContainer(layer);
            return Qt.rgba(darkRgb.r, darkRgb.g, darkRgb.b, a);
        }
        const base = containerAtLevel(layer);
        const tinted = tintContainer(base, 0.12 + layer * 0.02);
        return Qt.rgba(tinted.r, tinted.g, tinted.b, a);
    }

    function isSurfaceColor(c) {
        return c === bootPalette.m3surface
            || c === bootPalette.m3background
            || c === bootPalette.m3surfaceDim
            || c === bootPalette.m3surfaceBright
            || c === bootPalette.m3surfaceContainerLowest
            || c === bootPalette.m3surfaceContainerLow
            || c === bootPalette.m3surfaceContainer
            || c === bootPalette.m3surfaceContainerHigh
            || c === bootPalette.m3surfaceContainerHighest
            || c === bootPalette.m3surfaceVariant
            || c === bootPalette.m3inverseSurface;
    }

    function surfaceLevelOf(c, fallbackLevel) {
        if (c === bootPalette.m3surfaceContainerLowest) return 0;
        if (c === bootPalette.m3surfaceContainerLow) return 1;
        if (c === bootPalette.m3surfaceContainer) return 2;
        if (c === bootPalette.m3surfaceContainerHigh) return 3;
        if (c === bootPalette.m3surfaceContainerHighest) return 4;
        return fallbackLevel ?? 1;
    }

    function applyLayer(c, layerLevel) {
        if (!isSurfaceColor(c))
            return c;

        const baseLevel = surfaceLevelOf(c, layerLevel ?? 1);
        const layer = surfaceLayer(layerLevel !== undefined ? Math.max(layerLevel, baseLevel) : baseLevel);

        if (!transparencyEnabled) {
            if (layer === 0)
                return shellTint;
            if (light)
                return opaqueLightContainer(layer);
            return alterColour(c, 1.0, layer);
        }

        const layerAlpha = Math.min(1, transparencyLayers * (1 + (layer > 1 ? (layer - 1) * 0.05 : 0)));

        if (layer === 0)
            return Qt.alpha(shellTint, transparencyBase);

        if (light)
            return Qt.alpha(opaqueLightContainer(layer), layerAlpha);

        return alterColour(c, layerAlpha, layer);
    }

    // Declarative fast-path elevation properties for standard surface container
    readonly property color _surfaceContainerLayer1: applyLayer(bootPalette.m3surfaceContainer, 1)
    readonly property color _surfaceContainerLayer2: applyLayer(bootPalette.m3surfaceContainer, 2)
    readonly property color _surfaceContainerLayer3: applyLayer(bootPalette.m3surfaceContainer, 3)

    function layer(c, layerLevel) {
        if (c === bootPalette.m3surfaceContainer) {
            if (layerLevel === 2 || layerLevel === undefined) return _surfaceContainerLayer2;
            if (layerLevel === 1) return _surfaceContainerLayer1;
            if (layerLevel === 3) return _surfaceContainerLayer3;
        }
        return applyLayer(c, layerLevel);
    }

    function on(c) {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function opaqueDarkTile(role) {
        if (role === "surface")
            return opaqueDarkContainer(2);
        if (role === "fill")
            return opaqueDarkContainer(3);
        if (role === "hover")
            return Qt.tint(opaqueDarkContainer(3), Qt.alpha(palette.m3onSurface, 0.08));
        if (role === "tonal" || role === "elevated")
            return opaqueDarkContainer(4);
        return opaqueDarkContainer(1);
    }

    // ── Tile colours (M3 elevation stack) ───────────
    readonly property color _tileSurfaceRgb: opaqueLightContainer(4)
    readonly property color _tileFillRgb: opaqueLightContainer(2, _tileSurfaceRgb)
    readonly property color _tileFillHoverRgb: opaqueLightContainer(2, _tileFillRgb)
    readonly property color _tileFillSubtleRgb: opaqueLightContainer(1)
    readonly property color _tileFillTonalRgb: opaqueLightContainer(2, _tileSurfaceRgb)
    readonly property color _tileFillElevatedRgb: opaqueLightContainer(3, _tileFillRgb)

    readonly property color tileSurface: light
        ? (transparencyEnabled ? applyTileAlpha(_tileSurfaceRgb, 4) : _tileSurfaceRgb)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainer, 2) : opaqueDarkTile("surface"))
    readonly property color tileFill: light
        ? (transparencyEnabled ? applyTileAlpha(tintContainer(containerAtLevel(2), 0.16), 2) : tintContainer(containerAtLevel(2), 0.16))
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerHigh, 3) : opaqueDarkTile("fill"))
    readonly property color tileFillHover: light
        ? applyTileAlpha(_tileFillHoverRgb, 4)
        : (transparencyEnabled ? Qt.tint(applyLayer(palette.m3surfaceContainerHigh, 3), Qt.alpha(palette.m3onSurface, 0.08)) : opaqueDarkTile("hover"))
    readonly property color tileFillSubtle: light
        ? applyTileAlpha(_tileFillSubtleRgb, 1)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerLow, 1) : palette.m3surfaceContainerLow)
    readonly property color tileFillTonal: light
        ? applyTileAlpha(_tileFillTonalRgb, 4)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerHighest, 4) : opaqueDarkTile("tonal"))
    readonly property color tileFillElevated: light
        ? applyTileAlpha(_tileFillElevatedRgb, 4)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerHighest, 4) : opaqueDarkTile("elevated"))
    readonly property color tileStroke: "transparent"
    readonly property color tileStrokeSubtle: "transparent"
    readonly property color tileInnerLine: "transparent"
    readonly property color tileGlass: tileFill
    readonly property color tileGlassStrong: tileSurface
    readonly property color tileShine: "transparent"
    readonly property color tileShineSoft: "transparent"
    readonly property color notifTileFill: tileFill
    readonly property color tileHoverAccent: light
        ? palette.m3primaryContainer
        : Qt.alpha(palette.m3primaryContainer, 0.38)
    readonly property color tileHoverSecondary: light
        ? palette.m3secondaryContainer
        : Qt.alpha(palette.m3secondaryContainer, 0.48)
    readonly property color tileInactive: tileFillElevated
    readonly property color tileIconWell: light
        ? palette.m3secondaryContainer
        : tileFillElevated

    function applyTileAlpha(opaqueRgb, layerLevel) {
        if (!transparencyEnabled)
            return opaqueRgb;
        const layer = surfaceLayer(layerLevel ?? 2);
        return Qt.alpha(opaqueRgb, layer === 0 ? transparencyBase : transparencyLayers);
    }

    // ── Boot TPalette (transparency-layered) ────────
    component BootTPalette: QtObject {
        readonly property color m3background: root.layer(bootPalette.m3background, 0)
        readonly property color m3onBackground: root.layer(bootPalette.m3onBackground)
        readonly property color m3surface: root.layer(bootPalette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(bootPalette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(bootPalette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(bootPalette.m3surfaceContainerLowest, 0)
        readonly property color m3surfaceContainerLow: root.layer(bootPalette.m3surfaceContainerLow, 1)
        readonly property color m3surfaceContainer: root.layer(bootPalette.m3surfaceContainer, 2)
        readonly property color m3surfaceContainerHigh: root.layer(bootPalette.m3surfaceContainerHigh, 3)
        readonly property color m3surfaceContainerHighest: root.layer(bootPalette.m3surfaceContainerHighest, 4)
        readonly property color m3onSurface: root.layer(bootPalette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(bootPalette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(bootPalette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(bootPalette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(bootPalette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(bootPalette.m3outline)
        readonly property color m3outlineVariant: root.layer(bootPalette.m3outlineVariant)
        readonly property color m3shadow: root.layer(bootPalette.m3shadow)
        readonly property color m3scrim: root.layer(bootPalette.m3scrim)
        readonly property color m3surfaceTint: root.layer(bootPalette.m3surfaceTint)
        readonly property color m3primary: root.layer(bootPalette.m3primary)
        readonly property color m3onPrimary: root.layer(bootPalette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(bootPalette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(bootPalette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(bootPalette.m3inversePrimary)
        readonly property color m3secondary: root.layer(bootPalette.m3secondary)
        readonly property color m3onSecondary: root.layer(bootPalette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(bootPalette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(bootPalette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(bootPalette.m3tertiary)
        readonly property color m3onTertiary: root.layer(bootPalette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(bootPalette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(bootPalette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(bootPalette.m3error)
        readonly property color m3onError: root.layer(bootPalette.m3onError)
        readonly property color m3errorContainer: root.layer(bootPalette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(bootPalette.m3onErrorContainer)
        readonly property color m3success: root.layer(bootPalette.m3success)
        readonly property color m3onSuccess: root.layer(bootPalette.m3onSuccess)
        readonly property color m3successContainer: root.layer(bootPalette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(bootPalette.m3onSuccessContainer)
    }

    BootTPalette {
        id: bootTPalette
    }

    // ── Wallpaper colour ingestion ──────────────────
    property string _pendingWallColors: ""
    property bool _pendingWallPreview: false

    function flushPendingWallColors(): void {
        if (!_pendingWallColors.length)
            return;
        const scheme = M3ColorMapper.parseSchemePayload(_pendingWallColors);
        if (scheme) {
            bootPalette.applyScheme(scheme);
            bootSchemeMode = scheme.mode ?? "dark";
            root.themePaletteUpdated();
            console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary}`);
        }
        _pendingWallColors = "";
        _pendingWallPreview = false;
    }

    property string _lastIngestedData: ""

    function ingestWallpaperColors(data, isPreview) {
        const scheme = M3ColorMapper.parseSchemePayload(data);
        if (!scheme) {
            console.log("[Colours] Invalid wallpaper palette payload");
            return;
        }

        const normalizedData = M3ColorMapper.stringifySchemePayload(data);
        if (!isPreview && normalizedData && normalizedData === root._lastIngestedData)
            return;

        console.log(`[Colours] Wallpaper palette (${isPreview ? "preview" : "current"})`);
        if (!isPreview) {
            root._lastIngestedData = normalizedData;
            root.themeTransitioning = true;
            if (!bootPalette.applyScheme(scheme))
                console.log("[Colours] bootPalette applyScheme failed");
            else {
                bootSchemeMode = scheme.mode ?? "dark";
                bootSchemeName = scheme.name ?? "dynamic";
                bootSchemeFlavour = scheme.flavour ?? "default";
                root.themePaletteUpdated();
                console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary} (scheme: ${bootSchemeName} ${bootSchemeFlavour})`);
            }
            Qt.callLater(() => { root.themeTransitioning = false; });
        }
    }

    function load(data, isPreview) { ingestWallpaperColors(data, isPreview) }

    function useFallbackPalette(): void {
        root._lastIngestedData = "";
        const scheme = M3ColorMapper.fallbackScheme();
        bootPalette.applyScheme(scheme);
        bootSchemeMode = scheme.mode ?? "dark";
        root.themePaletteUpdated();
        console.log("[Colours] Using fallback palette");
    }

    function refreshThemePalette() {
        const path = Wallpapers.actualCurrent || Wallpapers.current;
        if (path)
            Wallpapers.forceAccentRefresh(path, false);
    }

    function setShowPreview(value) {
        // No-op: preview support removed with engine unification
    }

    function setMode(mode) {
        // Launcher actions call setMode without writing themeMode first.
        // Keep config in sync so schemeModeArg / configLight bind correctly.
        if (mode === "light" || mode === "dark" || mode === "auto") {
            if (mode === "light" || mode === "dark") {
                bootSchemeMode = mode;
            }
            if (GlobalConfig.appearance.themeMode !== mode) {
                GlobalConfig.appearance.themeMode = mode;
                GlobalConfig.save();
            }
            root._lastIngestedData = "";
            root.themePaletteUpdated();
        }
        // Extract owns palette quality:
        //   auto  → smart mode+variant from wallpaper
        //   light/dark → --scheme-mode + smart variant (same quality as auto-dark)
        // Do NOT scheme-set -v here — that forced expressive and nuked dark.
        if (root.schemeName === "dynamic") {
            root.refreshThemePalette();
        } else {
            let resolvedMode = mode;
            if (resolvedMode === "auto") resolvedMode = "dark"; // Default to dark for static schemes on auto
            schemeSetProc.command = ["olvex", "scheme", "set", "--notify", "-m", resolvedMode];
            schemeSetProc.running = true;
        }
    }

    Process {
        id: schemeSetProc
        onExited: {
            // Variant changes are automatically handled by scheme.json FileView
        }
    }

    // ── Scheme file watcher ─────────────────────────
    FileView {
        id: schemeFile

        printErrors: false
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: schemeFile.reload()
        onLoaded: {
            if (!Wallpapers.bootstrapDone)
                return;
            if (!(Wallpapers.actualCurrent || "").trim())
                return;
            root.ingestWallpaperColors(text(), false);
        }
    }

    // ── Hyprland blur rules ─────────────────────────
    property bool cooldownPending
    property real lastBaseTransparency

    function requestReloadHyprRules() {
        cooldownTimer.restart();
    }

    function reloadHyprRules() {
        const namespaces = ["olvex-drawers", "quickshell:osk"];
        const messages = [];
        const shouldBlur = transparencyEnabled && transparencyBlur;
        const ignoreAlpha = transparencyEnabled ? Math.max(0.1, transparencyBase * 0.7) : 1.0;
        namespaces.forEach(ns => {
            if (shouldBlur) {
                messages.push(`eval hl.layer_rule({ match = { namespace = "${ns}" }, blur = true, ignore_alpha = ${ignoreAlpha.toFixed(3)} })`);
            } else {
                messages.push(`eval hl.layer_rule({ match = { namespace = "${ns}" }, blur = false })`);
            }
        });
        if (shouldBlur) {
            const size = Math.max(1, Math.min(30, transparencyBlurRadius));
            const passes = Math.max(1, Math.min(5, transparencyBlurPasses));
            messages.push(`eval hl.config({ decoration = { blur = { size = ${size}, passes = ${passes} } } })`);
        }
        Hypr.extras.batchMessage(messages);
    }

    // ── Connections ─────────────────────────────────
    Timer {
        id: themeSchemePoll

        interval: 100
        repeat: true
        property int pollsLeft: 0

        onTriggered: {
            schemeFile.reload();
            pollsLeft--;
            if (pollsLeft <= 0)
                stop();
        }

        function kick() {
            pollsLeft = 3;
            restart();
        }
    }

    Connections {
        target: GlobalConfig.appearance
        function onThemeModeChanged() {
            if (root.schemeName === "dynamic") {
                root.refreshThemePalette();
                themeSchemePoll.kick();
            } else {
                let resolvedMode = GlobalConfig.appearance.themeMode;
                if (resolvedMode === "auto") resolvedMode = "dark";
                schemeSetProc.command = ["olvex", "scheme", "set", "--notify", "-m", resolvedMode];
                schemeSetProc.running = true;
            }
        }
        function onSchemeVariantChanged() {
            schemeSetProc.command = ["olvex", "scheme", "set", "--notify", "-v", GlobalConfig.appearance.schemeVariant];
            schemeSetProc.running = true;
        }
        function onPrimaryColorChanged() {
            schemeSetProc.command = ["olvex", "scheme", "set", "--notify", "-c", GlobalConfig.appearance.primaryColor];
            schemeSetProc.running = true;
        }
    }
    
    function setSchemeName(name, flavour = "") {
        let cmd = ["olvex", "scheme", "set", "--notify", "-n", name];
        if (flavour) cmd.push("-f", flavour);
        schemeSetProc.command = cmd;
        schemeSetProc.running = true;
    }

    Connections {
        target: Wallpapers
        function onColorsGenerated(data, isPreview) {
            root.ingestWallpaperColors(data, isPreview);
        }
    }

    // Sync system GTK & XDG Desktop Portal theme for Flutter (LocalSend), GTK (Thunar), etc.
    Process {
        id: portalThemeSyncProc
    }

    Timer {
        id: portalThemeDebounceTimer
        interval: 300
        repeat: false
        onTriggered: root._doSyncSystemPortalTheme()
    }

    function syncSystemPortalTheme() {
        portalThemeDebounceTimer.restart();
    }

    function _doSyncSystemPortalTheme() {
        const mode = light ? "light" : "dark";
        const gtkTheme = light ? "adw-gtk3" : "adw-gtk3-dark";
        const cmd = `gsettings set org.gnome.desktop.interface color-scheme 'prefer-${mode}' && gsettings set org.gnome.desktop.interface gtk-theme '${gtkTheme}' && dconf write /org/gnome/desktop/interface/color-scheme "'prefer-${mode}'" && dconf write /org/gnome/desktop/interface/gtk-theme "'${gtkTheme}'"`;
        portalThemeSyncProc.command = ["bash", "-c", cmd];
        portalThemeSyncProc.running = true;
    }

    Connections {
        target: GlobalConfig.appearance.transparency
        function onEnabledChanged() { root.requestReloadHyprRules() }
        function onBaseChanged() { root.requestReloadHyprRules() }
        function onLayersChanged() { root.requestReloadHyprRules() }
        function onBlurChanged() { root.requestReloadHyprRules() }
    }

    Connections {
        target: Tokens.transparency
        function onEnabledChanged() { root.requestReloadHyprRules() }
        function onBaseChanged() { root.requestReloadHyprRules() }
        function onLayersChanged() { root.requestReloadHyprRules() }
        function onBlurChanged() { root.requestReloadHyprRules() }
    }

    Connections {
        target: root
        function onLightChanged() {
            root.requestReloadHyprRules();
            root.syncSystemPortalTheme();
        }
    }

    Connections {
        target: GlobalConfig
        function onLoaded() { root.requestReloadHyprRules() }
        function onSaved() { root.requestReloadHyprRules() }
    }

    Connections {
        target: Hypr
        function onConfigReloaded() { root.reloadHyprRules() }
    }

    Component.onCompleted: {
        root.syncActiveTransparency();
        root.requestReloadHyprRules();
        root.syncSystemPortalTheme();
        useFallbackPalette();
    }

    Timer {
        id: cooldownTimer
        interval: 30
        onTriggered: {
            root.reloadHyprRules();
        }
    }

    Timer {
        id: cAnimCompleteTimer
        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }
}

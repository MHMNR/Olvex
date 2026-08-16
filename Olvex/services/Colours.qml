pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import "color"
import "color/M3ColorMapper.js" as Mapper

Singleton {
    id: root

    // ── Palette ─────────────────────────────────────
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
        if (mode === "light") return true;
        if (mode === "dark") return false;
        return bootSchemeMode === "light";
    }
    readonly property bool light: configLight
    readonly property var palette: bootPalette
    readonly property var tPalette: bootTPalette
    readonly property var current: bootPalette
    readonly property var preview: bootPalette

    // ── Transparency ────────────────────────────────
    readonly property bool transparencyEnabled: Tokens.transparency.enabled
    readonly property real transparencyBase: Math.max(0.01, Math.min(1, Tokens.transparency.base - (light ? 0.1 : 0)))
    readonly property real transparencyLayers: Tokens.transparency.layers
    onTransparencyEnabledChanged: root.requestReloadHyprRules()
    onTransparencyBaseChanged: root.requestReloadHyprRules()
    onTransparencyLayersChanged: root.requestReloadHyprRules()

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
        const tint = bootPalette.m3outlineVariant;
        return Qt.rgba(
            Math.max(0, Math.min(1, base.r * (1 - amount) + tint.r * amount)),
            Math.max(0, Math.min(1, base.g * (1 - amount) + tint.g * amount)),
            Math.max(0, Math.min(1, base.b * (1 - amount) + tint.b * amount)),
            1);
    }

    function opaqueLightContainer(layerLevel, againstColor) {
        let level = surfaceLayer(layerLevel ?? 2);
        let color = containerAtLevel(level);
        const ref = againstColor ?? bootPalette.m3surface;
        const target = againstColor ? 1.10 : 1.06;
        const refLum = getLuminance(ref);

        function needsStep(c) {
            return contrastRatio(c, ref) < target
                || (againstColor && getLuminance(c) >= refLum);
        }

        while (needsStep(color) && level < 4) {
            level++;
            color = containerAtLevel(level);
        }

        let tint = 0.06;
        while (needsStep(color) && tint <= 0.42) {
            color = tintContainer(color, tint);
            tint += 0.06;
        }
        return color;
    }

    function alterColour(c, a, layerLevel) {
        const luminance = getLuminance(c);
        const layer = surfaceLayer(layerLevel);
        const offset = (!light || layer <= 1 ? 1 : (light ? layer * 0.4 : -layer / 2))
            * (light ? 0.2 : 0.3) * (1 - transparencyBase)
            * (1 + wallLuminance * (light ? (layer === 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(
            Math.max(0, Math.min(1, c.r * scale)),
            Math.max(0, Math.min(1, c.g * scale)),
            Math.max(0, Math.min(1, c.b * scale)),
            a);
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
            if (light && layer > 0)
                return opaqueLightContainer(layer);
            if (layer === 0)
                return bootPalette.m3surface;
            if (layer === 1)
                return bootPalette.m3surfaceContainerLow;
            if (layer === 2)
                return bootPalette.m3surfaceContainer;
            if (layer === 3)
                return bootPalette.m3surfaceContainerHigh;
            return bootPalette.m3surfaceContainerHighest;
        }

        if (light && layer > 0)
            return Qt.alpha(opaqueLightContainer(layer), transparencyLayers);

        return layer === 0
            ? Qt.alpha(c, transparencyBase)
            : alterColour(c, transparencyLayers, layer);
    }

    function layer(c, layerLevel) {
        return applyLayer(c, layerLevel);
    }

    function on(c) {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function opaqueDarkTile(role) {
        if (role === "surface")
            return palette.m3surfaceContainer;
        if (role === "fill")
            return palette.m3surfaceVariant;
        if (role === "hover")
            return Qt.tint(palette.m3surfaceVariant, Qt.alpha(palette.m3primary, 0.12));
        if (role === "tonal" || role === "elevated")
            return Qt.tint(palette.m3surfaceVariant, Qt.alpha(palette.m3primary, 0.08));
        return palette.m3surfaceContainerLow;
    }

    // ── Tile colours (M3 elevation stack) ───────────
    readonly property color _tileSurfaceRgb: opaqueLightContainer(2)
    readonly property color _tileFillRgb: opaqueLightContainer(4, _tileSurfaceRgb)
    readonly property color _tileFillHoverRgb: opaqueLightContainer(4, _tileFillRgb)
    readonly property color _tileFillSubtleRgb: opaqueLightContainer(1)
    readonly property color _tileFillTonalRgb: opaqueLightContainer(4, _tileSurfaceRgb)
    readonly property color _tileFillElevatedRgb: opaqueLightContainer(4, _tileFillRgb)

    readonly property color tileSurface: light
        ? applyTileAlpha(_tileSurfaceRgb, 2)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainer, 2) : opaqueDarkTile("surface"))
    readonly property color tileFill: light
        ? applyTileAlpha(_tileFillRgb, 4)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerHighest, 4) : opaqueDarkTile("fill"))
    readonly property color tileFillHover: light
        ? applyTileAlpha(_tileFillHoverRgb, 4)
        : (transparencyEnabled ? Qt.tint(applyLayer(palette.m3surfaceVariant, 4), Qt.alpha(palette.m3primary, 0.15)) : opaqueDarkTile("hover"))
    readonly property color tileFillSubtle: light
        ? applyTileAlpha(_tileFillSubtleRgb, 1)
        : (transparencyEnabled ? applyLayer(palette.m3surfaceContainerLow, 1) : palette.m3surfaceContainerLow)
    readonly property color tileFillTonal: light
        ? applyTileAlpha(_tileFillTonalRgb, 4)
        : (transparencyEnabled ? Qt.tint(applyLayer(palette.m3surfaceVariant, 4), Qt.alpha(palette.m3primary, 0.12)) : opaqueDarkTile("tonal"))
    readonly property color tileFillElevated: light
        ? applyTileAlpha(_tileFillElevatedRgb, 4)
        : (transparencyEnabled ? Qt.tint(applyLayer(palette.m3surfaceVariant, 4), Qt.alpha(palette.m3primary, 0.12)) : opaqueDarkTile("elevated"))
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
        const scheme = Mapper.parseSchemePayload(_pendingWallColors);
        if (scheme) {
            bootPalette.applyScheme(scheme);
            bootSchemeMode = scheme.mode ?? "dark";
            console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary}`);
        }
        _pendingWallColors = "";
        _pendingWallPreview = false;
    }

    function ingestWallpaperColors(data, isPreview) {
        const scheme = Mapper.parseSchemePayload(data);
        if (!scheme) {
            console.log("[Colours] Invalid wallpaper palette payload");
            return;
        }
        console.log(`[Colours] Wallpaper palette (${isPreview ? "preview" : "current"}, ${Object.keys(scheme.colours ?? {}).length} scheme keys → ${Object.keys(Mapper.PALETTE_PROPS).length} QML tokens)`);
        if (!isPreview) {
            root.themeTransitioning = true;
            if (!bootPalette.applyScheme(scheme))
                console.log("[Colours] bootPalette applyScheme failed");
            else {
                bootSchemeMode = scheme.mode ?? "dark";
                bootSchemeName = scheme.name ?? "dynamic";
                bootSchemeFlavour = scheme.flavour ?? "default";
                console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary} (scheme: ${bootSchemeName} ${bootSchemeFlavour})`);
            }
            Qt.callLater(() => { root.themeTransitioning = false; });
        }
    }

    function load(data, isPreview) { ingestWallpaperColors(data, isPreview) }

    function useFallbackPalette(): void {
        const scheme = Mapper.fallbackScheme();
        bootPalette.applyScheme(scheme);
        bootSchemeMode = scheme.mode ?? "dark";
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
            if (GlobalConfig.appearance.themeMode !== mode) {
                GlobalConfig.appearance.themeMode = mode;
                GlobalConfig.save();
            }
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
        const str = "keyword layerrule %1 %2, match:namespace %3";
        const namespaces = ["olvex-drawers", "quickshell:osk"];
        const messages = [];
        const ignoreAlpha = transparencyEnabled ? Math.max(0.005, transparencyBase * 0.7) : 1.0;
        namespaces.forEach(ns => {
            messages.push(str.arg("blur").arg(transparencyEnabled ? 1 : 0).arg(ns));
            messages.push(str.arg("ignore_alpha").arg(ignoreAlpha.toFixed(3)).arg(ns));
        });
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
    }

    Connections {
        target: Tokens.transparency
        function onEnabledChanged() { root.requestReloadHyprRules() }
        function onBaseChanged() { root.requestReloadHyprRules() }
        function onLayersChanged() { root.requestReloadHyprRules() }
    }

    Connections {
        target: root
        function onLightChanged() {
            root.requestReloadHyprRules();
            root.syncSystemPortalTheme();
        }
    }

    Connections {
        target: Hypr
        function onConfigReloaded() { root.reloadHyprRules() }
    }

    Component.onCompleted: {
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

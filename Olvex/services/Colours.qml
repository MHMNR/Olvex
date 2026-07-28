pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils
import "color"
import "color/M3ColorMapper.js" as Mapper

Singleton {
    id: root

    readonly property bool legacyMode: Quickshell.env("OLVEX_COLOR_ENGINE") === "legacy"
        || GlobalConfig.services.colorEngine === "legacy"

    readonly property string activeEngine: legacyMode ? "legacy" : "expressive"

    component LegacyComp: LegacyColourEngine {}
    component ExpressiveComp: ExpressiveColourEngine {}

    M3ExpressivePalette {
        id: bootPalette
    }

    property string _pendingWallColors: ""
    property bool _pendingWallPreview: false

    Loader {
        id: engineLoader
        sourceComponent: root.legacyMode ? LegacyComp : ExpressiveComp
        onLoaded: {
            root.flushPendingWallColors();
            debounceTimer.restart();
        }
    }

    readonly property var engine: engineLoader.item

    function setShowPreview(value) {
        if (engine)
            engine.showPreview = value;
    }

    readonly property bool showPreview: Wallpapers.showPreview || (engine ? engine.showPreview : false)
    readonly property string scheme: engine ? engine.scheme : ""
    readonly property string flavour: engine ? engine.flavour : ""
    property string bootSchemeMode: "dark"
    readonly property string schemeMode: engine ? engine.schemeMode : bootSchemeMode
    readonly property bool configLight: {
        const mode = GlobalConfig.appearance.themeMode;
        if (mode === "light")
            return true;
        if (mode === "dark")
            return false;
        return bootSchemeMode === "light";
    }
    readonly property bool light: engine ? engine.light : configLight
    readonly property bool currentLight: engine ? engine.currentLight : false
    readonly property bool previewLight: engine ? engine.previewLight : false
    // Media-pill pattern: bootPalette is the live global source (direct applyScheme).
    // Engine mirrors for preview + luminance; never replace bootPalette on the UI path.
    readonly property var palette: (showPreview && engine) ? engine.palette : bootPalette
    readonly property var tPalette: bootTPalette
    // M3 elevation stack: contrast-tuned RGB, then transparency.layers alpha (Caelestia-style).
    readonly property color _tileSurfaceRgb: opaqueLightContainer(2)
    readonly property color _tileFillRgb: opaqueLightContainer(3, _tileSurfaceRgb)
    readonly property color _tileFillHoverRgb: opaqueLightContainer(4, _tileFillRgb)
    readonly property color _tileFillSubtleRgb: opaqueLightContainer(1)
    readonly property color _tileFillTonalRgb: opaqueLightContainer(3, _tileSurfaceRgb)
    readonly property color _tileFillElevatedRgb: opaqueLightContainer(4, _tileFillRgb)

    readonly property color tileSurface: light
        ? applyTileAlpha(_tileSurfaceRgb, 2)
        : Qt.alpha(palette.m3onSurface, 0.05)
    readonly property color tileFill: light
        ? applyTileAlpha(_tileFillRgb, 3)
        : Qt.alpha(palette.m3onSurface, 0.08)
    readonly property color tileFillHover: light
        ? applyTileAlpha(_tileFillHoverRgb, 4)
        : Qt.alpha(palette.m3onSurface, 0.12)
    readonly property color tileFillSubtle: light
        ? applyTileAlpha(_tileFillSubtleRgb, 1)
        : Qt.alpha(palette.m3onSurface, 0.04)
    readonly property color tileFillTonal: light
        ? applyTileAlpha(_tileFillTonalRgb, 3)
        : layer(palette.m3surfaceContainerHigh, 1)
    readonly property color tileFillElevated: light
        ? applyTileAlpha(_tileFillElevatedRgb, 4)
        : layer(palette.m3surfaceContainerHighest, 2)
    readonly property color tileStroke: light
        ? Qt.alpha(palette.m3outline, 0.32)
        : Qt.alpha(palette.m3onSurface, 0.1)
    readonly property color tileStrokeSubtle: light
        ? Qt.alpha(palette.m3outlineVariant, 0.5)
        : Qt.alpha(palette.m3outlineVariant, 0.18)
    readonly property color tileInnerLine: light
        ? Qt.alpha(palette.m3outlineVariant, 0.3)
        : Qt.rgba(1.0, 1.0, 1.0, 0.04)
    readonly property color tileGlass: tileFill
    readonly property color tileGlassStrong: tileSurface
    readonly property color tileShine: light
        ? Qt.alpha(palette.m3outlineVariant, 0.45)
        : Qt.rgba(1.0, 1.0, 1.0, 0.15)
    readonly property color tileShineSoft: light
        ? Qt.alpha(palette.m3outlineVariant, 0.28)
        : Qt.rgba(1.0, 1.0, 1.0, 0.05)
    readonly property color notifTileFill: tileSurface
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
    readonly property var current: bootPalette
    readonly property var preview: engine ? engine.preview : bootPalette
    readonly property var transparency: engine ? engine.transparency : bootTransparency
    readonly property real wallLuminance: engine ? engine.wallLuminance : 0
    readonly property string pickerState: engine && engine.pickerState !== undefined ? engine.pickerState : activeEngine

    property bool cooldownPending
    property real lastBaseTransparency

    function requestReloadHyprRules() {
        if (cooldownTimer.running) {
            cooldownPending = true;
        } else {
            reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    component BootTransparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Tokens.transparency.layers

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
        }
    }

    BootTransparency {
        id: bootTransparency
    }

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
        readonly property color m3primaryFixed: root.layer(bootPalette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(bootPalette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(bootPalette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(bootPalette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(bootPalette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(bootPalette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(bootPalette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(bootPalette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(bootPalette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(bootPalette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(bootPalette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(bootPalette.m3onTertiaryFixedVariant)
    }

    BootTPalette {
        id: bootTPalette
    }

    function getLuminance(c) {
        if (c.r === 0 && c.g === 0 && c.b === 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function surfaceLayer(layerLevel) {
        const layer = layerLevel ?? 1;
        // Light mode: step up M3 container elevation so cards read on pale backgrounds.
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

    function applyTileAlpha(opaqueRgb, layerLevel) {
        if (!transparency.enabled)
            return opaqueRgb;
        const layer = surfaceLayer(layerLevel ?? 2);
        return Qt.alpha(opaqueRgb, layer === 0 ? transparency.base : transparency.layers);
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
            * (light ? 0.2 : 0.3) * (1 - transparency.base)
            * (1 + wallLuminance * (light ? (layer === 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(
            Math.max(0, Math.min(1, c.r * scale)),
            Math.max(0, Math.min(1, c.g * scale)),
            Math.max(0, Math.min(1, c.b * scale)),
            a);
    }

    function applyLayer(c, layerLevel) {
        const layer = surfaceLayer(layerLevel);

        if (!transparency.enabled) {
            if (light && layer > 0)
                return opaqueLightContainer(layerLevel);
            if (layer === 0)
                return c;
            if (layer === 1)
                return bootPalette.m3surfaceContainerLow;
            if (layer === 2)
                return bootPalette.m3surfaceContainer;
            if (layer === 3)
                return bootPalette.m3surfaceContainerHigh;
            return bootPalette.m3surfaceContainerHighest;
        }

        if (light && layer > 0)
            return Qt.alpha(opaqueLightContainer(layerLevel), transparency.layers);

        return layer === 0
            ? Qt.alpha(c, transparency.base)
            : alterColour(c, transparency.layers, layer);
    }

    function layer(c, layerLevel) {
        if (showPreview && engine)
            return engine.applyLayer(c, layerLevel);
        return applyLayer(c, layerLevel);
    }

    function on(c) {
        if (engine)
            return engine.on(c);
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function flushPendingWallColors(): void {
        if (!_pendingWallColors.length || !engineLoader.item)
            return;
        engineLoader.item.load(_pendingWallColors, _pendingWallPreview);
        if (_pendingWallPreview)
            engineLoader.item.showPreview = true;
        else
            Wallpapers.previewColourLock = false;
        _pendingWallColors = "";
        _pendingWallPreview = false;
    }

    function ingestWallpaperColors(data, isPreview) {
        const scheme = Mapper.parseSchemePayload(data);
        if (!scheme) {
            console.log("[Colours] Invalid wallpaper palette payload");
            return;
        }
        console.log(`[Colours] Wallpaper palette (${isPreview ? "preview" : "current"}, ${Object.keys(scheme.colours ?? {}).length} essential roles)`);
        if (!isPreview) {
            if (!bootPalette.applyScheme(scheme))
                console.log("[Colours] bootPalette applyScheme failed");
            else {
                bootSchemeMode = scheme.mode ?? "dark";
                console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary}`);
            }
        }

        if (engineLoader.item) {
            engineLoader.item.load(data, isPreview);
            if (isPreview)
                setShowPreview(true);
            else
                Wallpapers.previewColourLock = false;
        } else {
            _pendingWallColors = data;
            _pendingWallPreview = isPreview;
        }
    }

    function load(data, isPreview) { ingestWallpaperColors(data, isPreview) }

    function useFallbackPalette(): void {
        const scheme = Mapper.fallbackScheme();
        const payload = JSON.stringify(scheme);
        bootPalette.applyScheme(scheme);
        bootSchemeMode = scheme.mode ?? "dark";
        _pendingWallColors = "";
        _pendingWallPreview = false;
        if (engineLoader.item)
            engineLoader.item.load(payload, false);
    }
    function refreshThemePalette() {
        const path = Wallpapers.actualCurrent || Wallpapers.current;
        if (path)
            Wallpapers.forceAccentRefresh(path, false);
    }

    function setMode(mode) { if (engine) engine.setMode(mode) }
    function reloadHyprRules() {
        const str = "keyword layerrule %1 %2, match:namespace %3";
        const namespaces = ["olvex-drawers", "quickshell:osk"];
        const messages = [];
        namespaces.forEach(ns => {
            messages.push(str.arg("blur").arg(transparency.enabled ? 1 : 0).arg(ns));
            messages.push(str.arg("ignore_alpha").arg(transparency.base - 0.03).arg(ns));
        });
        Hypr.extras.batchMessage(messages);
    }

    FileView {
        id: schemeFile

        printErrors: false
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!Wallpapers.bootstrapDone)
                return;
            if (!(Wallpapers.actualCurrent || "").trim())
                return;
            root.ingestWallpaperColors(text(), false);
        }
    }

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
            root.refreshThemePalette();
            themeSchemePoll.kick();
        }
    }

    Component.onCompleted: root.requestReloadHyprRules()

    Timer {
        id: cooldownTimer
        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer
        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    Connections {
        target: Hypr
        function onConfigReloaded() { root.reloadHyprRules() }
    }

    Connections {
        target: GlobalConfig.appearance.transparency
        function onLayersChanged() { root.requestReloadHyprRules() }
    }

    Connections {
        target: root
        function onLightChanged() { root.requestReloadHyprRules() }
    }

    Connections {
        target: engineLoader
        function onItemChanged() { root.flushPendingWallColors(); }
    }

    Connections {
        target: Wallpapers
        function onColorsGenerated(data, isPreview) {
            root.ingestWallpaperColors(data, isPreview);
        }
    }
}
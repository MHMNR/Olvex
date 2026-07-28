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
    readonly property string schemeMode: engine ? engine.schemeMode : "dark"
    readonly property bool light: engine ? engine.light : false
    readonly property bool currentLight: engine ? engine.currentLight : false
    readonly property bool previewLight: engine ? engine.previewLight : false
    // Media-pill pattern: bootPalette is the live global source (direct applyScheme).
    // Engine mirrors for preview + luminance; never replace bootPalette on the UI path.
    readonly property var palette: (showPreview && engine) ? engine.palette : bootPalette
    readonly property var tPalette: bootTPalette
    readonly property var current: bootPalette
    readonly property var preview: engine ? engine.preview : bootPalette
    readonly property var transparency: engine ? engine.transparency : bootTransparency
    readonly property real wallLuminance: engine ? engine.wallLuminance : 0
    readonly property string pickerState: engine && engine.pickerState !== undefined ? engine.pickerState : activeEngine

    component BootTransparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Tokens.transparency.layers

        onEnabledChanged: debounceTimer.restart()
        onBaseChanged: debounceTimer.restart()
    }

    BootTransparency {
        id: bootTransparency
    }

    component BootTPalette: QtObject {
        readonly property color m3primary: bootPalette.m3primary
        readonly property color m3onPrimary: bootPalette.m3onPrimary
        readonly property color m3primaryContainer: root.layer(bootPalette.m3primaryContainer, 2)
        readonly property color m3onPrimaryContainer: bootPalette.m3onPrimaryContainer
        readonly property color m3secondary: bootPalette.m3secondary
        readonly property color m3onSecondary: bootPalette.m3onSecondary
        readonly property color m3secondaryContainer: root.layer(bootPalette.m3secondaryContainer, 2)
        readonly property color m3onSecondaryContainer: bootPalette.m3onSecondaryContainer
        readonly property color m3tertiary: bootPalette.m3tertiary
        readonly property color m3onTertiary: bootPalette.m3onTertiary
        readonly property color m3tertiaryContainer: root.layer(bootPalette.m3tertiaryContainer, 2)
        readonly property color m3onTertiaryContainer: bootPalette.m3onTertiaryContainer
        readonly property color m3error: bootPalette.m3error
        readonly property color m3onError: bootPalette.m3onError
        readonly property color m3errorContainer: bootPalette.m3errorContainer
        readonly property color m3onErrorContainer: bootPalette.m3onErrorContainer
        readonly property color m3background: root.layer(bootPalette.m3background, 0)
        readonly property color m3onBackground: bootPalette.m3onBackground
        readonly property color m3surface: root.layer(bootPalette.m3surface, 0)
        readonly property color m3onSurface: bootPalette.m3onSurface
        readonly property color m3surfaceVariant: root.layer(bootPalette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: bootPalette.m3onSurfaceVariant
        readonly property color m3surfaceDim: root.layer(bootPalette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(bootPalette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(bootPalette.m3surfaceContainerLowest, 0)
        readonly property color m3surfaceContainerLow: root.layer(bootPalette.m3surfaceContainerLow, 1)
        readonly property color m3surfaceContainer: root.layer(bootPalette.m3surfaceContainer, 2)
        readonly property color m3surfaceContainerHigh: root.layer(bootPalette.m3surfaceContainerHigh, 3)
        readonly property color m3surfaceContainerHighest: root.layer(bootPalette.m3surfaceContainerHighest, 4)
        readonly property color m3inverseSurface: root.layer(bootPalette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: bootPalette.m3inverseOnSurface
        readonly property color m3inversePrimary: bootPalette.m3inversePrimary
        readonly property color m3outline: bootPalette.m3outline
        readonly property color m3outlineVariant: bootPalette.m3outlineVariant
        readonly property color m3shadow: bootPalette.m3shadow
        readonly property color m3scrim: bootPalette.m3scrim
        readonly property color m3surfaceTint: bootPalette.m3surfaceTint
        readonly property color m3primaryFixed: bootPalette.m3primaryFixed
        readonly property color m3primaryFixedDim: bootPalette.m3primaryFixedDim
        readonly property color m3onPrimaryFixed: bootPalette.m3onPrimaryFixed
        readonly property color m3onPrimaryFixedVariant: bootPalette.m3onPrimaryFixedVariant
        readonly property color m3secondaryFixed: bootPalette.m3secondaryFixed
        readonly property color m3secondaryFixedDim: bootPalette.m3secondaryFixedDim
        readonly property color m3onSecondaryFixed: bootPalette.m3onSecondaryFixed
        readonly property color m3onSecondaryFixedVariant: bootPalette.m3onSecondaryFixedVariant
        readonly property color m3tertiaryFixed: bootPalette.m3tertiaryFixed
        readonly property color m3tertiaryFixedDim: bootPalette.m3tertiaryFixedDim
        readonly property color m3onTertiaryFixed: bootPalette.m3onTertiaryFixed
        readonly property color m3onTertiaryFixedVariant: bootPalette.m3onTertiaryFixedVariant
        readonly property color m3success: bootPalette.m3success
        readonly property color m3onSuccess: bootPalette.m3onSuccess
        readonly property color m3successContainer: bootPalette.m3successContainer
        readonly property color m3onSuccessContainer: bootPalette.m3onSuccessContainer
    }

    BootTPalette {
        id: bootTPalette
    }

    function applyLayer(c, layerLevel) {
        if (layerLevel === 0)
            return transparency.enabled ? Qt.alpha(c, transparency.base) : c;
        if (!transparency.enabled) {
            if (layerLevel === 1) return bootPalette.m3surfaceContainer;
            if (layerLevel === 2) return bootPalette.m3surfaceContainerHigh;
            return bootPalette.m3surfaceContainerHighest;
        }
        const luminance = (c.r === 0 && c.g === 0 && c.b === 0) ? 0
            : Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
        const calcBase = transparency.enabled ? transparency.base : 0.8;
        const offset = (light ? (layerLevel === 1 ? 1 : -layerLevel / 2) : (layerLevel / 1.5))
            * (light ? 0.2 : 0.3) * (1 - calcBase)
            * (1 + wallLuminance * (light ? (layerLevel === 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(
            Math.max(0, Math.min(1, c.r * scale)),
            Math.max(0, Math.min(1, c.g * scale)),
            Math.max(0, Math.min(1, c.b * scale)),
            transparency.layers);
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
            else
                console.log(`[Colours] bootPalette primary now ${bootPalette.m3primary}`);
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
        _pendingWallColors = "";
        _pendingWallPreview = false;
        if (engineLoader.item)
            engineLoader.item.load(payload, false);
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

    Component.onCompleted: debounceTimer.triggered()

    Timer {
        id: debounceTimer
        interval: 300
        onTriggered: root.reloadHyprRules()
    }

    Connections {
        target: Hypr
        function onConfigReloaded() { root.reloadHyprRules() }
    }

    Connections {
        target: GlobalConfig.appearance.transparency
        function onEnabledChanged() { debounceTimer.restart() }
        function onBaseChanged() { debounceTimer.restart() }
        function onLayersChanged() { debounceTimer.restart() }
    }

    Connections {
        target: root
        function onLightChanged() { debounceTimer.restart() }
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
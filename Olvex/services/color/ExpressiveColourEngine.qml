pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import "M3ColorMapper.js" as Mapper

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool showPreview
    property string scheme
    property string flavour
    property string schemeMode: "dark"
    readonly property string pickerState: picker.state

    readonly property bool light: showPreview ? previewLight : currentLight
    readonly property bool currentLight: {
        const mode = GlobalConfig.appearance.themeMode;
        if (mode === "auto") return root.schemeMode === "light";
        return mode === "light";
    }
    property bool previewLight
    readonly property M3ExpressivePalette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3ExpressivePalette current: M3ExpressivePalette {}
    readonly property M3ExpressivePalette preview: M3ExpressivePalette {}
    readonly property Transparency transparency: Transparency {}
    readonly property alias wallLuminance: analyser.luminance

    function getLuminance(c) {
        if (c.r === 0 && c.g === 0 && c.b === 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c, a, layer) {
        const luminance = getLuminance(c);
        const calcBase = transparency.enabled ? transparency.base : 0.8;
        const offset = (light ? (layer === 1 ? 1 : -layer / 2) : (layer / 1.5))
            * (light ? 0.2 : 0.3) * (1 - calcBase)
            * (1 + wallLuminance * (light ? (layer === 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(
            Math.max(0, Math.min(1, c.r * scale)),
            Math.max(0, Math.min(1, c.g * scale)),
            Math.max(0, Math.min(1, c.b * scale)),
            a);
    }

    function applyLayer(c, layerLevel) {
        if (layerLevel === 0)
            return transparency.enabled ? Qt.alpha(c, transparency.base) : c;
        if (!transparency.enabled) {
            if (layerLevel === 1) return root.palette.m3surfaceContainer;
            if (layerLevel === 2) return root.palette.m3surfaceContainerHigh;
            return root.palette.m3surfaceContainerHighest;
        }
        return alterColour(c, transparency.enabled ? transparency.layers : 1.0, layerLevel ?? 1);
    }

    function on(c) {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function applyScheme(schemeObj, isPreview) {
        if (!schemeObj)
            return;
        const colours = isPreview ? preview : current;
        colours.applyScheme(schemeObj);

        if (isPreview) {
            const mode = GlobalConfig.appearance.themeMode;
            previewLight = (mode === "auto") ? (schemeObj.mode === "light") : (mode === "light");
            return;
        }

        root.scheme = schemeObj.name ?? "";
        root.flavour = schemeObj.flavour ?? "";
        root.schemeMode = schemeObj.mode ?? "dark";

        const mode = GlobalConfig.appearance.themeMode;
        if (mode !== "auto" && schemeObj.mode !== mode) {
            console.log(`[Colours/Expressive] Mode mismatch (${schemeObj.mode} vs ${mode}), re-extracting from wallpaper`);
            if (Wallpapers.actualCurrent)
                Wallpapers.requestAccentRefresh(Wallpapers.actualCurrent, false);
        }
    }

    function load(data, isPreview) {
        const schemeObj = Mapper.parseSchemePayload(data);
        if (!schemeObj) {
            console.log("[Colours/Expressive] No valid scheme in payload");
            return;
        }
        console.log(`[Colours/Expressive] Applying ${isPreview ? "preview" : "current"} (${Object.keys(schemeObj.colours ?? {}).length} essential roles)`);
        root.applyScheme(schemeObj, isPreview);
    }

    function setMode(mode) {
        if (mode === "auto") {
            if (Wallpapers.actualCurrent)
                Wallpapers.requestAccentRefresh(Wallpapers.actualCurrent, false);
            return;
        }
        Quickshell.execDetached(["olvex", "scheme", "set", "--notify", "-m", mode]);
    }

    Connections {
        target: Wallpapers
        function onBootstrapDoneChanged() {
            if (Wallpapers.bootstrapDone)
                picker.tryLoadPersisted();
        }
    }

    Component.onCompleted: {
        if (Wallpapers.bootstrapDone)
            picker.tryLoadPersisted();
    }

    ExpressiveColourPicker {
        id: picker
        onPaletteReady: function(schemeObj, isPreview) {
            const payload = Mapper.stringifySchemePayload(JSON.stringify(schemeObj));
            Colours.ingestWallpaperColors(payload.length ? payload : JSON.stringify(schemeObj), isPreview);
            if (isPreview)
                root.showPreview = true;
        }
        onPaletteFailed: function(reason, isPreview) {
            console.log("[Colours/Expressive] picker failed:", reason, "preview=", isPreview);
        }
    }

    Connections {
        target: GlobalConfig.appearance
        function onThemeModeChanged() {
            root.setMode(GlobalConfig.appearance.themeMode);
            Wallpapers.requestAccentRefresh(Wallpapers.current, false);
        }
        function onSchemeVariantChanged() {
            Quickshell.execDetached(["olvex", "scheme", "set", "--notify", "-v", GlobalConfig.appearance.schemeVariant]);
            Wallpapers.requestAccentRefresh(Wallpapers.current, false);
        }
        function onPrimaryColorChanged() {
            Quickshell.execDetached(["olvex", "scheme", "set", "--notify", "-c", GlobalConfig.appearance.primaryColor]);
            Wallpapers.requestAccentRefresh(Wallpapers.current, false);
        }
    }

    ImageAnalyser {
        id: analyser
        source: Wallpapers.colourSourcePath(Wallpapers.current)
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Tokens.transparency.layers
    }

    component M3TPalette: QtObject {
        readonly property color m3primary: root.palette.m3primary
        readonly property color m3onPrimary: root.palette.m3onPrimary
        readonly property color m3primaryContainer: root.applyLayer(root.palette.m3primaryContainer, 2)
        readonly property color m3onPrimaryContainer: root.palette.m3onPrimaryContainer
        readonly property color m3secondary: root.palette.m3secondary
        readonly property color m3onSecondary: root.palette.m3onSecondary
        readonly property color m3secondaryContainer: root.applyLayer(root.palette.m3secondaryContainer, 2)
        readonly property color m3onSecondaryContainer: root.palette.m3onSecondaryContainer
        readonly property color m3tertiary: root.palette.m3tertiary
        readonly property color m3onTertiary: root.palette.m3onTertiary
        readonly property color m3tertiaryContainer: root.applyLayer(root.palette.m3tertiaryContainer, 2)
        readonly property color m3onTertiaryContainer: root.palette.m3onTertiaryContainer
        readonly property color m3error: root.palette.m3error
        readonly property color m3onError: root.palette.m3onError
        readonly property color m3errorContainer: root.palette.m3errorContainer
        readonly property color m3onErrorContainer: root.palette.m3onErrorContainer
        readonly property color m3background: root.applyLayer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.palette.m3onBackground
        readonly property color m3surface: root.applyLayer(root.palette.m3surface, 0)
        readonly property color m3onSurface: root.palette.m3onSurface
        readonly property color m3surfaceVariant: root.applyLayer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.palette.m3onSurfaceVariant
        readonly property color m3surfaceDim: root.applyLayer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.applyLayer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.applyLayer(root.palette.m3surfaceContainerLowest, 0)
        readonly property color m3surfaceContainerLow: root.applyLayer(root.palette.m3surfaceContainerLow, 1)
        readonly property color m3surfaceContainer: root.applyLayer(root.palette.m3surfaceContainer, 2)
        readonly property color m3surfaceContainerHigh: root.applyLayer(root.palette.m3surfaceContainerHigh, 3)
        readonly property color m3surfaceContainerHighest: root.applyLayer(root.palette.m3surfaceContainerHighest, 4)
        readonly property color m3inverseSurface: root.applyLayer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.palette.m3inverseOnSurface
        readonly property color m3inversePrimary: root.palette.m3inversePrimary
        readonly property color m3outline: root.palette.m3outline
        readonly property color m3outlineVariant: root.palette.m3outlineVariant
        readonly property color m3shadow: root.palette.m3shadow
        readonly property color m3scrim: root.palette.m3scrim
        readonly property color m3surfaceTint: root.palette.m3surfaceTint
        readonly property color m3primaryFixed: root.palette.m3primaryFixed
        readonly property color m3primaryFixedDim: root.palette.m3primaryFixedDim
        readonly property color m3onPrimaryFixed: root.palette.m3onPrimaryFixed
        readonly property color m3onPrimaryFixedVariant: root.palette.m3onPrimaryFixedVariant
        readonly property color m3secondaryFixed: root.palette.m3secondaryFixed
        readonly property color m3secondaryFixedDim: root.palette.m3secondaryFixedDim
        readonly property color m3onSecondaryFixed: root.palette.m3onSecondaryFixed
        readonly property color m3onSecondaryFixedVariant: root.palette.m3onSecondaryFixedVariant
        readonly property color m3tertiaryFixed: root.palette.m3tertiaryFixed
        readonly property color m3tertiaryFixedDim: root.palette.m3tertiaryFixedDim
        readonly property color m3onTertiaryFixed: root.palette.m3onTertiaryFixed
        readonly property color m3onTertiaryFixedVariant: root.palette.m3onTertiaryFixedVariant
        readonly property color m3success: root.palette.m3success
        readonly property color m3onSuccess: root.palette.m3onSuccess
        readonly property color m3successContainer: root.palette.m3successContainer
        readonly property color m3onSuccessContainer: root.palette.m3onSuccessContainer
    }
}
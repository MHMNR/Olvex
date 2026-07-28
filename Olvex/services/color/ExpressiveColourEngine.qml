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
            return root.palette.m3surfaceContainerLow;
        if (level === 2)
            return root.palette.m3surfaceContainer;
        if (level === 3)
            return root.palette.m3surfaceContainerHigh;
        return root.palette.m3surfaceContainerHighest;
    }

    function tintContainer(base, amount) {
        const tint = root.palette.m3outlineVariant;
        return Qt.rgba(
            Math.max(0, Math.min(1, base.r * (1 - amount) + tint.r * amount)),
            Math.max(0, Math.min(1, base.g * (1 - amount) + tint.g * amount)),
            Math.max(0, Math.min(1, base.b * (1 - amount) + tint.b * amount)),
            1);
    }

    function opaqueLightContainer(layerLevel, againstColor) {
        let level = surfaceLayer(layerLevel ?? 2);
        let color = containerAtLevel(level);
        const ref = againstColor ?? root.palette.m3surface;
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
                return root.palette.m3surfaceContainerLow;
            if (layer === 2)
                return root.palette.m3surfaceContainer;
            if (layer === 3)
                return root.palette.m3surfaceContainerHigh;
            return root.palette.m3surfaceContainerHighest;
        }

        if (light && layer > 0)
            return Qt.alpha(opaqueLightContainer(layerLevel), transparency.layers);

        return layer === 0
            ? Qt.alpha(c, transparency.base)
            : alterColour(c, transparency.layers, layer);
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

    function refreshAccentAfterSchemeSet() {
        const path = Wallpapers.actualCurrent || Wallpapers.current;
        if (path)
            Wallpapers.forceAccentRefresh(path, false);
    }

    function runSchemeSet(args) {
        schemeSetProc.command = ["olvex", "scheme", "set", "--notify"].concat(args);
        schemeSetProc.running = true;
    }

    function setMode(mode) {
        root.refreshAccentAfterSchemeSet();
        if (mode === "auto")
            return;
        root.runSchemeSet(["-m", mode]);
    }

    Process {
        id: schemeSetProc

        onExited: root.refreshAccentAfterSchemeSet()
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
            const mode = GlobalConfig.appearance.themeMode;
            if (mode !== "auto")
                root.runSchemeSet(["-m", mode]);
        }
        function onSchemeVariantChanged() {
            root.runSchemeSet(["-v", GlobalConfig.appearance.schemeVariant]);
        }
        function onPrimaryColorChanged() {
            root.runSchemeSet(["-c", GlobalConfig.appearance.primaryColor]);
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

    function layer(c, layerLevel) {
        return applyLayer(c, layerLevel);
    }

    component M3TPalette: QtObject {
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }
}
pragma ComponentBehavior: Bound

import QtQuick
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import "MediaAccentMapper.js" as AccentMap

// Single ImageAnalyser pipeline: album-art → dominantColour → vibrantAccent (visualizer) + playButtonFill (play bg).
Item {
    id: root

    enabled: true

    property string artUrl: ""
    property bool accentReady: false
    property string committedNormUrl: ""
    property string committedTrackKey: ""
    property string trackKey: ""
    property color visualizerAccent: "#4F378A"
    property color playButtonBg: "#CFBCFF"
    property color playIconColor: AccentMap.playIconOnFill(Colours.light, playButtonBg)
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color onSurfaceColor: Colours.palette.m3onSurface

    signal accentColorsChanged

    property color _pendingSurface: null
    property color _pendingOnSurface: null

    property color _pendingVisualizer: null
    property color _pendingPlayBg: null
    property color _pendingPlayIcon: null
    property bool _cacheRestoreInFlight: false
    property bool _accentNotifyPending: false
    property bool _settingArtUrl: false
    // Stamp of artUrl at the time each analysis was kicked — used to discard stale results
    property string _pendingAnalysisUrl: ""

    readonly property bool hasArt: root.artUrl !== ""

    function syncSystemDefaults(): void {
        if (root.accentReady)
            return;
        root.visualizerAccent = Colours.palette.m3primaryContainer;
        root.playButtonBg = Colours.palette.m3primary;
        root.playIconColor = AccentMap.playIconOnFill(Colours.light, root.playButtonBg);
        root.surfaceColor = Colours.palette.m3surfaceContainerHigh;
        root.onSurfaceColor = Colours.palette.m3onSurface;
        root._notifyAccentColors();
    }

    function _notifyAccentColors(): void {
        if (root._accentNotifyPending)
            return;
        root._accentNotifyPending = true;
        Qt.callLater(() => {
            root._accentNotifyPending = false;
            root.accentColorsChanged();
        });
    }

    readonly property string artSourceUrl: {
        const url = Players.stripArtDisplayUrl(root.artUrl);
        return url || "";
    }

    function normalizedArtUrl(url: string): string {
        return Players.normalizeMediaArtUrl(url);
    }

    function resetPending(): void {
        root._pendingVisualizer = null;
        root._pendingPlayBg = null;
        root._pendingPlayIcon = null;
        root._pendingSurface = null;
        root._pendingOnSurface = null;
    }

    function applySystemFallback(): void {
        Players.clearLiveAccent();
        root.visualizerAccent = Colours.palette.m3primaryContainer;
        root.playButtonBg = Colours.palette.m3primary;
        root.playIconColor = AccentMap.playIconOnFill(Colours.light, root.playButtonBg);
        root.surfaceColor = Colours.palette.m3surfaceContainerHigh;
        root.onSurfaceColor = Colours.palette.m3onSurface;
        root.accentReady = false;
        root.committedNormUrl = "";
        root.resetPending();
        root._notifyAccentColors();
    }

    property bool _publishing: false

    function publishAccent(url: string): void {
        if (root._publishing)
            return;
        root._publishing = true;
        Players.publishLiveAccent(root.visualizerAccent, root.playButtonBg, url, root.playIconColor, root.surfaceColor, root.onSurfaceColor);
        root._publishing = false;
    }

    function applyCachedPreview(url: string, cached: var): void {
        root.visualizerAccent = cached.visualizer;
        root.playButtonBg = cached.playButtonBg;
        root.playIconColor = cached.playIconColor;
        root.surfaceColor = cached.surfaceColor || root.surfaceColor;
        root.onSurfaceColor = cached.onSurfaceColor || root.onSurfaceColor;
        if (url)
            root.artUrl = url;
        const norm = root.normalizedArtUrl(url || root.artUrl);
        root.accentReady = true;
        root.committedNormUrl = norm;
        root.committedTrackKey = root.trackKey;
        accentRetryTimer.stop();
        bootRestoreTimer.stop();

        const alreadyLive = Players.liveAccentReady && Players.liveVisualizerAccent.toString() === cached.visualizer.toString() && Players.livePlayButtonBg.toString() === cached.playButtonBg.toString();
        if (!alreadyLive)
            root.publishAccent(url);
        root._notifyAccentColors();
    }

    function lookupTrackCache(url: string): var {
        if (!url)
            return null;
        const hit = Players.getMediaAccent(url);
        if (!hit?.visualizer || !hit?.playButtonBg)
            return null;
        const rawBg = typeof hit.playButtonBg === "string" ? Qt.color(hit.playButtonBg) : hit.playButtonBg;
        const playBg = AccentMap.playButtonFill(rawBg, Colours.light) ?? rawBg;
        return {
            visualizer: typeof hit.visualizer === "string" ? Qt.color(hit.visualizer) : hit.visualizer,
            playButtonBg: playBg,
            playIconColor: AccentMap.playIconOnFill(Colours.light, playBg),
            surfaceColor: AccentMap.surfaceColor(rawBg, Colours.light) || Colours.palette.m3surfaceContainerHigh,
            onSurfaceColor: AccentMap.onSurfaceColor(Colours.light)
        };
    }

    function restoreCachedPreview(url: string): bool {
        if (!url || root.accentReady || root._cacheRestoreInFlight)
            return false;
        const cached = root.lookupTrackCache(url);
        if (!cached)
            return false;
        root._cacheRestoreInFlight = true;
        root.applyCachedPreview(url, cached);
        root._cacheRestoreInFlight = false;
        return true;
    }

    function schedulePrimaryPick(): void {
        // Obsolete: entirely replaced by ImageAnalyser
    }

    function isVisibleAccent(c: color): bool {
        return c && c.a > 0 && c.hslLightness > 0.02;
    }

    function onSeedReady(): void {
        // Discard stale results — if artUrl changed while analysis was in flight, ignore
        if (root._pendingAnalysisUrl && root._pendingAnalysisUrl !== root.artUrl)
            return;
        const seed = accentAnalyser.dominantColour;
        const vis = AccentMap.vibrantAccent(seed);
        const fill = AccentMap.playButtonFill(seed, Colours.light);
        if (!vis || !fill)
            return;
        root._pendingVisualizer = vis;
        root._pendingPlayBg = fill;
        root._pendingPlayIcon = AccentMap.playIconOnFill(Colours.light, fill);
        root._pendingSurface = AccentMap.surfaceColor(seed, Colours.light);
        root._pendingOnSurface = AccentMap.onSurfaceColor(Colours.light);

        root.visualizerAccent = vis;
        root.playButtonBg = fill;
        root.playIconColor = root._pendingPlayIcon;
        root.surfaceColor = root._pendingSurface;
        root.onSurfaceColor = root._pendingOnSurface;

        root._notifyAccentColors();
        root.tryCommit();
    }

    function tryCommit(): void {
        if (!root.artUrl)
            return;

        const norm = root.normalizedArtUrl(root.artUrl);
        if (norm === root.committedNormUrl && root.accentReady)
            return;

        const hasVis = root.isVisibleAccent(root._pendingVisualizer);
        const hasPlay = root.isVisibleAccent(root._pendingPlayBg);

        if (hasPlay) {
            root.playButtonBg = root._pendingPlayBg;
            root.playIconColor = root._pendingPlayIcon;
            if (root._pendingSurface) {
                root.surfaceColor = root._pendingSurface;
                root.onSurfaceColor = root._pendingOnSurface;
            }
        }
        if (hasVis)
            root.visualizerAccent = root._pendingVisualizer;

        if (!hasVis || !hasPlay)
            return;

        root.accentReady = true;
        root.committedNormUrl = norm;
        root.committedTrackKey = root.trackKey;
        accentRetryTimer.stop();
        bootRestoreTimer.stop();
        root.publishAccent(root.artUrl);
        root._notifyAccentColors();
    }

    function setArtUrl(url: string): void {
        if (root._settingArtUrl)
            return;
        root._settingArtUrl = true;

        const cleanUrl = root.normalizedArtUrl(url);
        const nextKey = Players.active ? Players.getTrackKey(Players.active) : "";

        if (!cleanUrl) {
            if (root.committedNormUrl)
                root.applySystemFallback();
            root.artUrl = "";
            root.trackKey = "";
            accentAnalyser.source = "";
            accentAnalyser.sourceItem = null;
            root._settingArtUrl = false;
            return;
        }

        if (cleanUrl === root.committedNormUrl && root.accentReady && nextKey === root.committedTrackKey) {
            if (root.artUrl !== cleanUrl)
                root.artUrl = cleanUrl;
            root.trackKey = nextKey;
            root._settingArtUrl = false;
            return;
        }

        const trackChanged = nextKey !== root.committedTrackKey || cleanUrl !== root.committedNormUrl;

        if (root.artUrl !== cleanUrl)
            root.artUrl = cleanUrl;
        root.trackKey = nextKey;

        if (trackChanged) {
            root.accentReady = false;
            root.committedNormUrl = "";
            root.committedTrackKey = nextKey;
            root.resetPending();
            bootRestoreTimer.stop();
            accentAnalyser.source = "";
            accentAnalyser.sourceItem = null;
        }

        root.restoreCachedPreview(cleanUrl);
        if (!trackChanged)
            bootRestoreTimer.restart();

        if (!root.accentReady)
            root.scheduleAnalysis();

        root._settingArtUrl = false;
    }

    function probeReady(): bool {
        return accentProbe.status === Image.Ready && accentProbe.source !== "";
    }

    function configureAnalyser(): void {
        accentAnalyser.source = "";
        accentAnalyser.sourceItem = accentProbe;
    }

    function scheduleAnalysis(): void {
        if (!root.artUrl)
            return;
        root._pendingAnalysisUrl = root.artUrl;
        root.configureAnalyser();
        if (root.probeReady()) {
            accentAnalyser.requestUpdate();
        }
        // If probe not ready yet, onStatusChanged will call scheduleAnalysis again once loaded.
        accentRetryTimer.restart();
    }

    function commitFromAnalyser(): void {
        if (root.artSourceUrl === "" && !root.probeReady())
            return;
        root.onSeedReady();
    }

    Image {
        id: accentProbe
        visible: false
        source: root.artSourceUrl
        asynchronous: true
        cache: false

        onStatusChanged: {
            if (status === Image.Ready && !root.accentReady)
                root.scheduleAnalysis();
        }
    }

    ImageAnalyser {
        id: accentAnalyser

        profile: "albumArt"
        rescaleSize: 128
    }

    Timer {
        id: bootRestoreTimer
        interval: 150
        repeat: true
        property int tries: 0

        onTriggered: {
            CpuProfile.bump("accentBootRestoreTimer");
            if (root.accentReady || !root.artUrl) {
                stop();
                tries = 0;
                return;
            }
            if (root.restoreCachedPreview(root.artUrl) || tries >= 30) {
                stop();
                tries = 0;
                if (!root.accentReady)
                    root.scheduleAnalysis();
                return;
            }
            tries++;
        }
    }

    Timer {
        id: accentRetryTimer
        interval: 120
        repeat: true
        property int tries: 0

        onTriggered: {
            CpuProfile.bump("accentRetryTimer");
            if (root.accentReady) {
                stop();
                tries = 0;
                return;
            }
            // Don't re-trigger analysis if one is already running
            if (!accentAnalyser.running) {
                root.commitFromAnalyser();
                if (!root.accentReady) {
                    root.configureAnalyser();
                    accentAnalyser.requestUpdate();
                }
            }
            if (root.accentReady || tries >= 50) {
                stop();
                tries = 0;
                return;
            }
            root.configureAnalyser();
            accentAnalyser.requestUpdate();
            tries++;
        }
    }

    Connections {
        target: accentAnalyser
        function onDominantColourChanged() {
            root.commitFromAnalyser();
        }
    }

    Connections {
        target: GlobalConfig.appearance
        function onSchemeVariantChanged() {
            if (root.accentReady && root.hasArt)
                root.commitFromAnalyser();
            else
                root.syncSystemDefaults();
        }
        function onThemeModeChanged() {
            if (root.accentReady && root.hasArt)
                root.commitFromAnalyser();
            else
                root.syncSystemDefaults();
        }
    }

    Connections {
        target: Players
        function onMediaAccentPrewarmed() {
            if (!root.accentReady && root.artUrl)
                root.restoreCachedPreview(root.artUrl);
        }
        function onMediaAccentRevisionChanged() {
            if (!root.accentReady && root.artUrl)
                root.restoreCachedPreview(root.artUrl);
        }
    }

    Component.onCompleted: {
        root.syncSystemDefaults();
        if (Players.currentArtUrl)
            root.setArtUrl(Players.currentArtUrl);
        else if (root.artUrl)
            root.setArtUrl(root.artUrl);
    }
}

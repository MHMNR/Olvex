pragma ComponentBehavior: Bound

import QtQuick
import Olvex
import Olvex.Config
import qs.services
import qs.utils
import "MediaAccentMapper.js" as AccentMap

// Visualizer: album-art seed. Play/pause bg: MediaPrimaryColourPicker (M3 primary only).
Item {
    id: root

    enabled: true

    property string artUrl: ""
    property bool accentReady: false
    property string committedNormUrl: ""
    property string committedTrackKey: ""
    property string trackKey: ""
    property color visualizerAccent: Colours.palette.m3primaryContainer
    property color playButtonBg: Colours.palette.m3primary
    property color playIconColor: AccentMap.playIconOnFill()

    property color _pendingVisualizer: null
    property color _pendingPlayBg: null
    property color _pendingPlayIcon: null
    property string _primaryPickFailNorm: ""
    property int _primaryPickFailCount: 0

    readonly property bool hasArt: root.artUrl !== ""
    readonly property color musicOnAccent: Colours.on(root.visualizerAccent)
    readonly property string artLocalPath: {
        const url = Players.stripArtDisplayUrl(root.artUrl);
        if (!url)
            return "";
        if (url.startsWith("file://"))
            return decodeURIComponent(url.replace(/^file:\/+/, "/"));
        if (url.startsWith("/"))
            return url;
        return "";
    }

    function normalizedArtUrl(url: string): string {
        return Players.normalizeMediaArtUrl(url);
    }

    function resetPending(): void {
        root._pendingVisualizer = null;
        root._pendingPlayBg = null;
        root._pendingPlayIcon = null;
    }

    function applySystemFallback(): void {
        Players.clearLiveAccent();
        root.visualizerAccent = Players.musicVisualizerAccent;
        root.playButtonBg = Players.musicPlayButtonBg;
        root.playIconColor = Players.musicPlayIconColor;
        root.accentReady = false;
        root.committedNormUrl = "";
        root.resetPending();
    }

    function publishAccent(url: string): void {
        Players.publishLiveAccent(root.visualizerAccent, root.playButtonBg, url, root.playIconColor);
    }

    function applyCachedPreview(url: string, cached: var): void {
        root.visualizerAccent = cached.visualizer;
        root.playButtonBg = cached.playButtonBg;
        root.playIconColor = cached.playIconColor;
        if (url)
            root.artUrl = url;
        root.publishAccent(url);
    }

    function lookupTrackCache(url: string): var {
        if (!url)
            return null;
        const hit = Players.getMediaAccent(url);
        if (!hit?.visualizer || !hit?.playButtonBg)
            return null;
        const rawBg = typeof hit.playButtonBg === "string" ? Qt.color(hit.playButtonBg) : hit.playButtonBg;
        const playBg = AccentMap.playButtonFill(rawBg) ?? rawBg;
        return {
            visualizer: typeof hit.visualizer === "string" ? Qt.color(hit.visualizer) : hit.visualizer,
            playButtonBg: playBg,
            playIconColor: AccentMap.playIconOnFill()
        };
    }

    function restoreCachedPreview(url: string): bool {
        if (!url)
            return false;
        const cached = root.lookupTrackCache(url);
        if (!cached)
            return false;
        root.applyCachedPreview(url, cached);
        return true;
    }

    function schedulePrimaryPick(): void {
        if (!root.artUrl)
            return;
        const norm = root.normalizedArtUrl(root.artUrl);
        if (root._primaryPickFailNorm === norm && root._primaryPickFailCount >= 2)
            return;
        primaryPicker.pickFromArt(root.artUrl, root.artLocalPath);
    }

    function isVisibleAccent(c: color): bool {
        return c && c.a > 0 && c.hslLightness > 0.02;
    }

    function onPrimaryReady(primary: color, onPrimary: color): void {
        if (!root.isVisibleAccent(primary))
            return;
        const fill = AccentMap.playButtonFill(primary) ?? primary;
        const icon = AccentMap.playIconOnFill();
        root._pendingPlayBg = fill;
        root._pendingPlayIcon = icon;
        root.playButtonBg = fill;
        root.playIconColor = icon;
        Players.publishPlayButtonBg(fill, root.artUrl, icon);
        root.tryCommit();
    }

    function onSeedReady(): void {
        const vis = AccentMap.vibrantAccent(accentAnalyser.dominantColour);
        if (!vis)
            return;
        root._pendingVisualizer = vis;
        root.visualizerAccent = vis;
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
            root.playIconColor = AccentMap.playIconOnFill();
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
    }

    function setArtUrl(url: string): void {
        const cleanUrl = Players.stripArtDisplayUrl(url);
        const norm = root.normalizedArtUrl(cleanUrl);
        const prevNorm = root.normalizedArtUrl(Players.stripArtDisplayUrl(root.artUrl));
        const nextKey = Players.active ? Players.getTrackKey(Players.active) : "";
        const prevKey = root.trackKey;

        if (!cleanUrl) {
            root.artUrl = "";
            root.trackKey = "";
            root.applySystemFallback();
            accentRetryTimer.stop();
            bootRestoreTimer.stop();
            primaryPicker.cancel();
            return;
        }

        if (norm === root.committedNormUrl && root.accentReady
                && nextKey === root.committedTrackKey) {
            if (root.artUrl !== cleanUrl)
                root.artUrl = cleanUrl;
            root.trackKey = nextKey;
            return;
        }

        const trackChanged = (prevKey !== "" && nextKey !== "" && nextKey !== prevKey)
            || (prevNorm !== "" && norm !== prevNorm);
        root.artUrl = cleanUrl;
        root.trackKey = nextKey;

        if (trackChanged) {
            root.accentReady = false;
            root.committedNormUrl = "";
            root.committedTrackKey = "";
            root._primaryPickFailNorm = "";
            root._primaryPickFailCount = 0;
            root.resetPending();
            bootRestoreTimer.stop();
            primaryPicker.lastSource = "";
            primaryPicker.lastConfigKey = "";
            primaryPicker.lastPrimary = Qt.rgba(0, 0, 0, 0);
            primaryPicker.lastOnPrimary = Qt.rgba(0, 0, 0, 0);
        }

        root.restoreCachedPreview(cleanUrl);
        if (!trackChanged)
            bootRestoreTimer.restart();
        root.scheduleAnalysis();
    }

    function probeReady(): bool {
        return accentProbe.status === Image.Ready && accentProbe.source !== "";
    }

    function configureAnalyser(): void {
        if (root.artLocalPath !== "") {
            accentAnalyser.sourceItem = null;
            accentAnalyser.source = root.artLocalPath;
            return;
        }
        if (root.probeReady()) {
            accentAnalyser.source = "";
            accentAnalyser.sourceItem = accentProbe;
            return;
        }
        accentAnalyser.source = "";
        accentAnalyser.sourceItem = null;
    }

    function scheduleAnalysis(): void {
        if (!root.artUrl)
            return;
        root.configureAnalyser();
        root.schedulePrimaryPick();
        const run = () => accentAnalyser.requestUpdate();
        if (root.artLocalPath !== "" || root.probeReady())
            run();
        else
            Qt.callLater(run);
        accentRetryTimer.restart();
    }

    function commitFromAnalyser(): void {
        if (!root.artUrl)
            return;
        if (root.artLocalPath === "" && !root.probeReady())
            return;
        root.onSeedReady();
    }

    MediaPrimaryColourPicker {
        id: primaryPicker

        onPrimaryReady: (primary, onPrimary) => {
            root._primaryPickFailNorm = "";
            root._primaryPickFailCount = 0;
            root.onPrimaryReady(primary, onPrimary);
        }
        onPrimaryFailed: reason => {
            const norm = root.normalizedArtUrl(root.artUrl);
            if (norm === root._primaryPickFailNorm)
                root._primaryPickFailCount++;
            else {
                root._primaryPickFailNorm = norm;
                root._primaryPickFailCount = 1;
            }
            if (root._primaryPickFailCount <= 2)
                console.log("[MediaAccent] primary pick failed:", reason);
        }
    }

    Image {
        id: accentProbe

        width: 128
        height: 128
        x: -192
        y: -192
        opacity: 0.01
        visible: root.hasArt && root.artLocalPath === ""
        source: root.artLocalPath === "" ? Players.stripArtDisplayUrl(root.artUrl) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: root.artLocalPath === ""

        onStatusChanged: {
            if (status === Image.Ready)
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
            root.commitFromAnalyser();
            if (root.accentReady || tries >= 50) {
                stop();
                tries = 0;
                return;
            }
            if (!root._pendingPlayBg)
                root.schedulePrimaryPick();
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
            if (root.artUrl)
                root.schedulePrimaryPick();
        }
        function onThemeModeChanged() {
            if (root.artUrl)
                root.schedulePrimaryPick();
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
        if (Players.currentArtUrl)
            root.setArtUrl(Players.currentArtUrl);
        else if (root.artUrl)
            root.setArtUrl(root.artUrl);
    }
}
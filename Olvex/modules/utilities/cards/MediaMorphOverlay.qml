pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Olvex.Components
import M3Shapes
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import "../../../components"
import "../../../components/effects"

Item {
    id: root

    anchors.fill: parent

    required property ShellScreen screen

    // ── Backend state (untouched) ──────────────────────────────────────────────
    property bool active: false
    property bool docked: false
    property bool suppressDismiss: false
    property bool dockLayoutReady: false
    property real _lastDockX: -1
    property real _lastDockY: -1
    property int _dockStableTicks: 0
    property int _dockSyncCount: 0
    readonly property string musicArtUrl: Players.currentArtUrl
    property string artDisplaySource: ""
    readonly property bool artIsLocal: root.musicArtUrl.startsWith("file:")
        || root.musicArtUrl.startsWith("/")
    readonly property bool hasMusicArt: root.musicArtUrl !== ""
    readonly property color resolvedVisualizerAccent: Players.musicVisualizerAccent
    readonly property color resolvedPlayButtonBg: Players.musicPlayButtonBg
    readonly property color musicAccent: Players.musicVisualizerAccent
    readonly property color musicOnAccent: Players.musicOnAccent
    readonly property color playButtonBg: Players.musicPlayButtonBg
    readonly property color playIconColor: Players.musicPlayIconColor
    property real startX: 0
    property real startY: 0
    property real startW: 48
    property real startH: 160

    // ── Card geometry ──────────────────────────────────────────────────────────
    readonly property real endW: 380
    readonly property real endH: 180
    readonly property real endRadius: 28
    readonly property real expandedPlayY: 68
    readonly property real expandedSideButtonY: 72
    readonly property real expandedProgressY: 128
    readonly property real expandedProgressHeight: 36
    readonly property real startRadius: startW / 2
    readonly property int expandDur: 430
    readonly property int collapseDur: 260
    readonly property var spatialEasing: Tokens.anim.expressiveDefaultSpatial
    readonly property var spatialEasingDecel: Tokens.anim.emphasizedDecel
    readonly property int contentRevealDelay: 172
    readonly property int progressRevealDelay: 200
    readonly property bool morphAnimating: expandTransition.running || collapseTransition.running
    readonly property bool opensRight: startX < root.width / 2

    readonly property real playerProgress: Players.interpolatedProgress
    readonly property real playerPosition: Players.interpolatedPosition
    readonly property real playerLength: Players.interpolatedLength
    property real seekPreview: -1
    readonly property real displayProgress: {
        const p = seekPreview >= 0 ? seekPreview : playerProgress;
        return p < 0.004 ? 0 : p;
    }
    readonly property bool hasProgressFill: root.displayProgress > 0
    readonly property real displayPosition: seekPreview >= 0 && playerLength > 0
        ? seekPreview * playerLength
        : playerPosition
    readonly property bool canSeek: Players.active !== null
        && (Players.active.canSeek ?? false)
        && (Players.active.positionSupported ?? false)

    // ── Art source helpers ─────────────────────────────────────────────────────
    function updateArtDisplaySource(): void {
        const url = root.musicArtUrl;
        if (!url) { root.artDisplaySource = ""; return; }
        if (root.artIsLocal) {
            root.artDisplaySource = "";
            Qt.callLater(() => { if (root.musicArtUrl === url) root.artDisplaySource = url; });
            return;
        }
        root.artDisplaySource = url + "#olvex-art=" + Players.artReloadNonce;
    }

    function lengthStr(length: real): string {
        if (length < 0) return "--:--";
        let l = length;
        if (l > 1000000) l /= 1000000;
        const hours = Math.floor(l / 3600);
        const mins = Math.floor((l % 3600) / 60);
        const secs = Math.floor(l % 60).toString().padStart(2, "0");
        if (hours > 0) return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    readonly property real audioIntensity: {
        const values = Audio.cava?.values ?? [];
        if (!values.length) return Players.active?.isPlaying ? 0.25 : 0.08;
        let total = 0;
        for (const value of values) total += Math.max(0, Math.min(1, value));
        return Math.max(0.08, Math.min(1, total / values.length));
    }
    readonly property real morphAudioIntensity: morphAnimating ? 0.12 : audioIntensity

    // ── Pill element positions (set by start/syncDock) ─────────────────────────
    property real realArtX: 7
    property real realArtY: 7
    property real realArtW: 34
    property real realArtH: 34
    property real realBtn1X: 9
    property real realBtn1Y: 49
    property real realBtn2X: 9
    property real realBtn2Y: 83
    property real realBtn3X: 9
    property real realBtn3Y: 117
    property real realBtnSize: 30

    readonly property real pillX: musicPill.x
    readonly property real pillY: musicPill.y
    readonly property real pillW: musicPill.width
    readonly property real pillH: musicPill.height
    readonly property real targetEndX: opensRight ? startX + startW + 24 : startX - endW - 24
    property real endX: {
        const maxX = Math.max(16, root.width - root.endW - 16);
        return Math.max(16, Math.min(maxX, root.targetEndX));
    }
    property real endY: {
        const targetY = startY + (startH - endH) / 2;
        const maxY = Math.max(16, root.height - root.endH - 16);
        return Math.max(16, Math.min(maxY, targetY));
    }

    visible: !!Players.active
    z: 2000

    // ── Layout helpers ─────────────────────────────────────────────────────────
    function applyLayout(x: real, y: real, w: real, h: real, color: color,
                         artX: real, artY: real, artW: real, artH: real,
                         btn1X: real, btn1Y: real,
                         btn2X: real, btn2Y: real,
                         btn3X: real, btn3Y: real,
                         btnSize: real): void {
        startX = x; startY = y; startW = w; startH = h;
        realArtX = artX; realArtY = artY; realArtW = artW; realArtH = artH;
        realBtn1X = btn1X; realBtn1Y = btn1Y;
        realBtn2X = btn2X; realBtn2Y = btn2Y;
        realBtn3X = btn3X; realBtn3Y = btn3Y;
        realBtnSize = btnSize;
        musicPill.x = startX;
        musicPill.y = startY;
        musicPill.width = startW;
        musicPill.height = startH;
        musicPill.radius = startRadius;
    }

    function resetDockLayout(): void {
        docked = false; dockLayoutReady = false;
        _lastDockX = -1; _lastDockY = -1;
        _dockStableTicks = 0; _dockSyncCount = 0;
    }

    function syncDock(x: real, y: real, w: real, h: real, color: color,
                      artX: real, artY: real, artW: real, artH: real,
                      btn1X: real, btn1Y: real,
                      btn2X: real, btn2Y: real,
                      btn3X: real, btn3Y: real,
                      btnSize: real): void {
        if (root.active) return;
        applyLayout(x, y, w, h, color, artX, artY, artW, artH,
                    btn1X, btn1Y, btn2X, btn2Y, btn3X, btn3Y, btnSize);
        if (w <= 0 || h <= 0) return;
        if (Math.abs(x - _lastDockX) < 0.5 && Math.abs(y - _lastDockY) < 0.5)
            _dockStableTicks++;
        else
            _dockStableTicks = 0;
        _lastDockX = x; _lastDockY = y; _dockSyncCount++;
        if (_dockStableTicks >= 3 && _dockSyncCount >= 8) dockLayoutReady = true;
        if (!active) musicPill.state = "compact";
    }

    function start(x: real, y: real, w: real, h: real, color: color,
                   artX: real, artY: real, artW: real, artH: real,
                   btn1X: real, btn1Y: real,
                   btn2X: real, btn2Y: real,
                   btn3X: real, btn3Y: real,
                   btnSize: real): void {
        applyLayout(x, y, w, h, color, artX, artY, artW, artH,
                    btn1X, btn1Y, btn2X, btn2Y, btn3X, btn3Y, btnSize);
        docked = true;
        expand();
    }

    function expand(): void {
        hideTimer.stop(); expandDeferred.stop();
        const w = startW > 0 ? startW : 48;
        const h = startH > 0 ? startH : 160;
        if (startW <= 0 || startH <= 0) { startW = w; startH = h; }
        musicPill.x = startX; musicPill.y = startY;
        musicPill.width = w; musicPill.height = h;
        musicPill.radius = w / 2;
        dockLayoutReady = true; docked = false;
        root.suppressDismiss = true;
        active = true;
        musicPill.state = "compact";
        expandDeferred.start();
        forceActiveFocus();
    }

    function close(): void {
        seekPreview = -1;
        musicPill.state = "compact";
        hideTimer.start();
    }

    // ── Connections / lifecycle ────────────────────────────────────────────────
    Connections {
        target: Players
        function onActiveChanged() {
            if (!Players.active) { root.active = false; root.resetDockLayout(); }
            else root.resetDockLayout();
        }
    }

    Component.onCompleted: {
        Players.registerMediaMorph(root.screen.name, root);
        root.updateArtDisplaySource();
    }

    Connections {
        target: Players
        function onCurrentArtUrlChanged() { root.updateArtDisplaySource(); }
        function onArtReloadNonceChanged() { root.updateArtDisplaySource(); }
    }

    Component.onDestruction: { Players.unregisterMediaMorph(root.screen.name, root); }

    Timer {
        id: expandDeferred; interval: 16; repeat: false
        onTriggered: { if (!root.active) return; musicPill.state = "expanded"; dismissGuard.restart(); }
    }
    Timer {
        id: hideTimer; interval: root.collapseDur + 40
        onTriggered: { root.active = false; root.docked = false; root.dockLayoutReady = false; }
    }
    Timer { id: dismissGuard; interval: 200; repeat: false; onTriggered: root.suppressDismiss = false }

    Keys.onEscapePressed: close()

    // ── Cava service ──────────────────────────────────────────────────────────
    readonly property bool needsCava: Players.active && (Players.active.isPlaying ?? false)
    Loader {
        active: root.needsCava
        sourceComponent: Component {
            Item {
                ServiceRef { service: Audio.cava }
                Connections {
                    target: Audio.cava
                    function onValuesChanged(): void { CpuProfile.bump("cavaValuesChanged"); }
                }
            }
        }
    }

    // ── Dismiss layer ─────────────────────────────────────────────────────────
    MouseArea {
        z: 0; anchors.fill: parent
        enabled: root.active && !root.suppressDismiss
        hoverEnabled: true
        onClicked: close()
    }

    // ── Control button — shared component (qs.components/MorphControlButton.qml),
    //    identical to the bar music pill so the pill→card morph stays seamless ──

    // ── The morphing card ──────────────────────────────────────────────────────
    Rectangle {
        id: musicPill

        z: 1
        opacity: root.active ? 1 : 0
        enabled: root.active
        x: root.startX; y: root.startY
        width: root.startW; height: root.startH
        radius: root.startRadius
        clip: true
        color: "transparent"

        property real morphSquashX: 1.0
        property real morphSquashY: 1.0
        property real morphLift: 0.0
        // Crossfades compact visual layer → card visual layer during morph (1=compact, 0=expanded)
        property real compactFade: 1.0

        transform: [
            Translate { x: root.opensRight ? musicPill.morphLift : -musicPill.morphLift; y: 0 },
            Scale {
                origin.x: root.opensRight ? 0 : musicPill.width
                origin.y: musicPill.height / 2
                xScale: musicPill.morphSquashX
                yScale: musicPill.morphSquashY
            }
        ]

        layer.enabled: root.morphAnimating
        layer.smooth: true
        state: "compact"

        // ── Card background — matches pill: surfaceColor + m3surfaceTint tonal ──
        Rectangle {
            anchors.fill: parent
            radius: musicPill.radius
            color: Players.musicSurfaceColor
            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
            }
        }



        // ── Neon wave visualizer ───────────────────────────────────────────────
        StyledClippingRect {
            anchors.fill: parent
            radius: musicPill.radius
            color: "transparent"

            NeonWaveVisualizer {
                anchors.fill: parent
                accentColor: root.resolvedVisualizerAccent
                numBands: 32
                maxHeightRatio: 0.8
                valueMultiplier: 1.5
                active: Players.active?.isPlaying ?? false
                frameInterval: 33
            }
        }

        // ── Art — StyledClippingRect (backup pattern: default pos = pill pos, states drive everything) ──
        StyledClippingRect {
            id: musicIcon
            x: 7; y: 7
            width: 34; height: 34; radius: 17
            color: root.hasMusicArt
                ? Qt.alpha(Players.musicOnSurfaceColor, 0.10)
                : Qt.alpha(root.musicAccent, 0.22)

            Image {
                id: artImage
                anchors.fill: parent
                source: root.artDisplaySource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: !root.artIsLocal
                opacity: status === Image.Ready && source !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
            MaterialIcon {
                id: musicPlaceholderIcon
                anchors.centerIn: parent
                text: "music_note"
                color: root.hasMusicArt ? Qt.alpha(Players.musicOnSurfaceColor, 0.4) : root.musicOnAccent
                font.pointSize: 14
                visible: !root.hasMusicArt || artImage.status !== Image.Ready
            }
        }

        // ── Track info (title + artist) — single Column, backup pattern ──────────
        // titleChip = dummy for opacity animation compat with transitions
        Item { id: titleChip; opacity: 0 }

        Column {
            id: trackInfo
            x: 116; y: 18
            width: 204
            spacing: 2
            opacity: 0

            StyledText {
                width: parent.width
                text: Players.active ? (Players.active.trackTitle || qsTr("Unknown Title")) : ""
                color: Players.musicOnSurfaceColor
                textPointSize: Tokens.font.size.normal
                font.weight: 600
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
            StyledText {
                width: parent.width
                text: Players.active ? (Players.active.trackArtist || qsTr("Unknown Artist")) : ""
                color: Qt.alpha(Players.musicOnSurfaceColor, 0.55)
                textPointSize: Tokens.font.size.small
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
        }

        // ── Controls surface ───────────────────────────────────────────────────
        Item { id: controlsSurface; opacity: 0 }

        // ── Buttons z:10 ──────────────────────────────────────────────────────
        MorphControlButton {
            id: prevBtnContainer
            z: 10; iconName: "skip_previous"
            onClicked: Players.previous()
        }
        MorphControlButton {
            id: playBtn
            z: 10; emphasized: true
            spinning: Players.active?.isPlaying ?? false
            iconName: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
            onClicked: Players.togglePlaying()
        }
        MorphControlButton {
            id: nextBtnContainer
            z: 10; iconName: "skip_next"
            onClicked: Players.next()
        }

        // ── Click absorber z:5 ────────────────────────────────────────────────
        MouseArea {
            z: 5; anchors.fill: parent; hoverEnabled: true
            enabled: musicPill.state !== "expanded"
            onClicked: (mouse) => {
                mouse.accepted = true
                if (root.seekPreview >= 0) return
                if (!root.active) root.expand()
            }
        }

        // ── Progress bar ───────────────────────────────────────────────────────
        Item {
            id: expandedContent
            anchors.fill: parent
            opacity: 0

            Item {
                id: expandedProgressWrap
                x: 24; y: root.expandedProgressY
                width: musicPill.width - 48
                height: root.expandedProgressHeight

                Text {
                    id: timeElapsed
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lengthStr(root.displayPosition)
                    color: Qt.alpha(Players.musicOnSurfaceColor, 0.45)
                    font.pixelSize: 11
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                }

                Text {
                    id: timeTotal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lengthStr(root.playerLength)
                    color: Qt.alpha(Players.musicOnSurfaceColor, 0.45)
                    font.pixelSize: 11
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                }

                Item {
                    id: progressTrackRow
                    anchors.left: timeElapsed.right; anchors.right: timeTotal.left
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28

                    // M3 Expressive seekbar tokens
                    readonly property real activeThickness: 4
                    readonly property real inactiveThickness: 4
                    readonly property real thumbW: dragging ? 6 : 4
                    readonly property real thumbH: dragging ? 26 : 18
                    readonly property real gap: 6            // thumb ↔ track gap
                    readonly property bool isPlaying: Players.active?.isPlaying ?? false
                    property bool dragging: false

                    readonly property real fillW: Math.max(0, Math.min(width, width * root.displayProgress))
                    // Where the thumb center sits
                    readonly property real thumbX: fillW

                    // ── Active indicator: thick wavy line (value-clipped, no Item clip) ──
                    WavyLine {
                        id: waveIndicator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: progressTrackRow.height
                        visible: amplitudeMultiplier > 0.001

                        lineWidth: progressTrackRow.activeThickness
                        color: Players.musicVisualizerAccent
                        frequency: 7
                        startX: 0
                        fullLength: progressTrackRow.width
                        // Draw wave only up to fill, leaving gap before thumb
                        value: progressTrackRow.width > 0
                            ? Math.max(0, (progressTrackRow.fillW - progressTrackRow.gap) / progressTrackRow.width)
                            : 0

                        // Playing → wavy; seeking or paused → flat (rect below takes over)
                        // amplitude = lineWidth × mult = 4 × 1.6 = 6.4px peak (swing >> half-width → no flat baseline edge)
                        amplitudeMultiplier: (root.seekPreview >= 0 || !progressTrackRow.isPlaying) ? 0 : 1.6

                        Behavior on amplitudeMultiplier {
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                        Behavior on value { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }

                        Anim on waveProgress {
                            running: waveIndicator.amplitudeMultiplier > 0
                            from: 0; to: 1
                            duration: 900
                            easing.type: Easing.Linear
                            loops: Animation.Infinite
                        }
                    }

                    // ── Active flat fill — shown when paused/seeking (no wave) ──────
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, progressTrackRow.fillW - progressTrackRow.gap)
                        height: progressTrackRow.activeThickness
                        radius: height / 2
                        color: Players.musicVisualizerAccent
                        visible: waveIndicator.amplitudeMultiplier <= 0.001
                        Behavior on width {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    // ── Inactive (remaining) track — from thumb gap to right edge ──
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressTrackRow.thumbX + progressTrackRow.gap
                        width: Math.max(0, progressTrackRow.width - x)
                        height: progressTrackRow.inactiveThickness
                        radius: height / 2
                        color: Qt.alpha(Players.musicOnSurfaceColor, 0.22)

                        Behavior on x {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    // ── Stadium thumb — grows on press (M3 Expressive) ─────────────
                    Rectangle {
                        id: seekThumb
                        visible: root.canSeek
                        x: progressTrackRow.thumbX - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: progressTrackRow.thumbW
                        height: progressTrackRow.thumbH
                        radius: width / 2
                        color: Players.musicOnSurfaceColor

                        Behavior on x {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on width { SpringAnimation { spring: 5.0; damping: 0.7; epsilon: 0.01 } }
                        Behavior on height { SpringAnimation { spring: 5.0; damping: 0.7; epsilon: 0.01 } }
                    }

                    // ── Seek interaction ───────────────────────────────────────
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -8; anchors.bottomMargin: -8
                        enabled: root.canSeek && musicPill.state === "expanded"
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (mouse) => {
                            progressTrackRow.dragging = true
                            root.seekPreview = Math.max(0, Math.min(1, mouse.x / width))
                        }
                        onReleased: {
                            progressTrackRow.dragging = false
                            if (root.seekPreview >= 0) {
                                Players.seekTo(root.seekPreview)
                                root.seekPreview = -1
                            }
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) root.seekPreview = Math.max(0, Math.min(1, mouse.x / width))
                        }
                        onCanceled: {
                            progressTrackRow.dragging = false
                            root.seekPreview = -1
                        }
                    }
                }
            }
        }

        states: [
            State {
                name: "compact"
                PropertyChanges { target: musicPill; x: root.startX; y: root.startY; width: root.startW; height: root.startH; radius: root.startRadius; compactFade: 1.0 }
                PropertyChanges { target: musicIcon; x: root.realArtX; y: root.realArtY; width: root.realArtW; height: root.realArtH; radius: root.realArtH / 2 }
                PropertyChanges { target: titleChip; opacity: 0 }
                PropertyChanges { target: trackInfo; opacity: 0; y: 26 }
                PropertyChanges { target: controlsSurface; opacity: 0 }
                PropertyChanges { target: expandedContent; opacity: 0 }
                PropertyChanges { target: prevBtnContainer; x: root.realBtn1X; y: root.realBtn1Y; width: root.realBtnSize; height: root.realBtnSize; radius: root.realBtnSize / 2; iconSize: Tokens.font.size.large }
                PropertyChanges { target: playBtn;          x: root.realBtn2X; y: root.realBtn2Y; width: root.realBtnSize; height: root.realBtnSize; radius: root.realBtnSize / 2; iconSize: Tokens.font.size.larger }
                PropertyChanges { target: nextBtnContainer; x: root.realBtn3X; y: root.realBtn3Y; width: root.realBtnSize; height: root.realBtnSize; radius: root.realBtnSize / 2; iconSize: Tokens.font.size.large }
            },
            State {
                name: "expanded"
                PropertyChanges { target: musicPill; x: root.endX; y: root.endY; width: root.endW; height: root.endH; radius: root.endRadius; compactFade: 0.0 }
                PropertyChanges { target: musicIcon; x: 20; y: 20; width: 80; height: 80; radius: 16 }
                PropertyChanges { target: titleChip; opacity: 1 }
                PropertyChanges { target: trackInfo; opacity: 1; y: 18 }
                PropertyChanges { target: controlsSurface; opacity: 1 }
                PropertyChanges { target: expandedContent; opacity: 1 }
                PropertyChanges { target: prevBtnContainer; x: 138; y: root.expandedSideButtonY; width: 40; height: 40; radius: 20; iconSize: 18 }
                PropertyChanges { target: playBtn;          x: 190; y: root.expandedPlayY;        width: 48; height: 48; radius: 24; iconSize: 22 }
                PropertyChanges { target: nextBtnContainer; x: 250; y: root.expandedSideButtonY; width: 40; height: 40; radius: 20; iconSize: 18 }
            }
        ]

        // ── Transitions ────────────────────────────────────────────────────────
        transitions: [
            Transition {
                id: expandTransition
                from: "compact"; to: "expanded"
                ParallelAnimation {
                    // Container bounds travel — full expand duration (Layer 1)
                    NumberAnimation { targets: [musicPill]; properties: "x,y,width,height"; duration: root.expandDur; easing: root.spatialEasing }
                    // Shape mask completes at 75% of expand (Container Transform shapeMaskProgressThresholds 0→0.75)
                    NumberAnimation { targets: [musicPill]; properties: "radius"; duration: Math.round(root.expandDur * 0.75); easing: root.spatialEasing }
                    // Shared elements (art, buttons) travel full duration
                    NumberAnimation { targets: [musicIcon]; properties: "x,y,width,height"; duration: root.expandDur; easing: root.spatialEasing }
                    NumberAnimation { targets: [musicIcon]; properties: "radius"; duration: Math.round(root.expandDur * 0.75); easing: root.spatialEasing }
                    NumberAnimation { targets: [prevBtnContainer, playBtn, nextBtnContainer]; properties: "x,y,width,height"; duration: root.expandDur; easing: root.spatialEasing }
                    NumberAnimation { targets: [prevBtnContainer, playBtn, nextBtnContainer]; properties: "radius"; duration: Math.round(root.expandDur * 0.75); easing: root.spatialEasing }
                    SequentialAnimation {
                        PauseAnimation { duration: 60 }
                        NumberAnimation { targets: [prevBtnContainer, playBtn, nextBtnContainer]; property: "iconSize"; duration: 250; easing: root.spatialEasing }
                    }
                    // Morph squash/lift
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphSquashX"; to: 1.045; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphSquashX"; to: 1.0; duration: Math.round(root.expandDur * 0.58); easing: root.spatialEasingDecel }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphSquashY"; to: 0.965; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphSquashY"; to: 1.0; duration: Math.round(root.expandDur * 0.58); easing: root.spatialEasingDecel }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphLift"; to: 8; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphLift"; to: 0; duration: Math.round(root.expandDur * 0.58); easing: root.spatialEasingDecel }
                    }
                    // Compact layer crossfades to card layer simultaneously with bounds morph
                    NumberAnimation { target: musicPill; property: "compactFade"; to: 0.0; duration: Math.round(root.expandDur * 0.6); easing: root.spatialEasing }
                    // Card content slides up from within the expanding container
                    SequentialAnimation {
                        PauseAnimation { duration: root.contentRevealDelay }
                        ParallelAnimation {
                            NumberAnimation { targets: [titleChip, trackInfo, controlsSurface]; property: "opacity"; to: 1; duration: Tokens.anim.durations.expressiveDefaultEffects; easing: Tokens.anim.emphasizedDecel }
                            NumberAnimation { target: trackInfo; property: "y"; to: 18; duration: Tokens.anim.durations.expressiveDefaultEffects; easing: Tokens.anim.emphasizedDecel }
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: root.progressRevealDelay }
                        NumberAnimation { target: expandedContent; property: "opacity"; to: 1; duration: Tokens.anim.durations.expressiveDefaultEffects; easing: Tokens.anim.emphasizedDecel }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"; to: "compact"
                ParallelAnimation {
                    // Card content fades + slides at 60–90% of collapse; compact layer restores simultaneously
                    SequentialAnimation {
                        PauseAnimation { duration: Math.round(root.collapseDur * 0.6) }
                        ParallelAnimation {
                            NumberAnimation { targets: [titleChip, trackInfo, controlsSurface, expandedContent]; property: "opacity"; to: 0; duration: Math.round(root.collapseDur * 0.3); easing: root.spatialEasing }
                            NumberAnimation { target: trackInfo; property: "y"; to: 26; duration: Math.round(root.collapseDur * 0.3); easing: root.spatialEasing }
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: Math.round(root.collapseDur * 0.6) }
                        NumberAnimation { target: musicPill; property: "compactFade"; to: 1.0; duration: Math.round(root.collapseDur * 0.4); easing: root.spatialEasing }
                    }
                    NumberAnimation { targets: [musicPill, musicIcon]; properties: "x,y,width,height,radius"; duration: root.collapseDur; easing: root.spatialEasing }
                    NumberAnimation { targets: [prevBtnContainer, playBtn, nextBtnContainer]; properties: "x,y,width,height,radius"; duration: root.collapseDur; easing: root.spatialEasing }
                    NumberAnimation { targets: [prevBtnContainer, playBtn, nextBtnContainer]; property: "iconSize"; duration: root.collapseDur; easing: root.spatialEasing }
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphSquashY"; to: 1.035; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphSquashY"; to: 1.0; duration: Math.round(root.collapseDur * 0.55); easing: root.spatialEasingDecel }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphSquashX"; to: 0.965; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphSquashX"; to: 1.0; duration: Math.round(root.collapseDur * 0.55); easing: root.spatialEasingDecel }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: musicPill; property: "morphLift"; to: 6; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
                        NumberAnimation { target: musicPill; property: "morphLift"; to: 0; duration: Math.round(root.collapseDur * 0.55); easing: root.spatialEasingDecel }
                    }
                }
            }
        ]
    }
}

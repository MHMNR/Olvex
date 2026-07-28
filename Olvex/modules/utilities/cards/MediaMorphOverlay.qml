pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import "../../../components/effects"
Item {
    id: root

    anchors.fill: parent

    required property ShellScreen screen

    property bool active: false
    property bool docked: false
    property bool suppressDismiss: false
    property bool dockLayoutReady: false
    property real _lastDockX: -1
    property real _lastDockY: -1
    property int _dockStableTicks: 0
    property int _dockSyncCount: 0
    readonly property string musicArtUrl: Players.active ? Players.getArtUrl(Players.active) : ""
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
    
    // Config properties for expanded card
    readonly property real endW: 340
    readonly property real endH: 160
    readonly property real endRadius: 24
    readonly property real startRadius: startW / 2
    readonly property real expandedControlsY: 68
    readonly property real expandedPlayY: 68
    readonly property real expandedSideButtonY: 72
    readonly property real expandedProgressY: 108
    readonly property real expandedProgressHeight: 52

    // M3 Expressive spatial springs — frame-stepped (vsync-aligned animation driver)
    readonly property real spatialSpring: 5.0
    readonly property real spatialDamping: 0.40
    readonly property real spatialEpsilon: 0.06
    readonly property int contentRevealDelay: 170
    readonly property int progressRevealDelay: 220

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

    function updateArtDisplaySource(): void {
        const url = root.musicArtUrl;
        if (!url) {
            root.artDisplaySource = "";
            return;
        }
        if (root.artIsLocal) {
            root.artDisplaySource = "";
            Qt.callLater(() => {
                if (root.musicArtUrl === url)
                    root.artDisplaySource = url;
            });
            return;
        }
        root.artDisplaySource = url + "#olvex-art=" + Players.artReloadNonce;
    }

    onMusicArtUrlChanged: root.updateArtDisplaySource()

    function lengthStr(length: real): string {
        if (length < 0)
            return "--:--";
        let l = length;
        if (l > 1000000)
            l /= 1000000;
        const hours = Math.floor(l / 3600);
        const mins = Math.floor((l % 3600) / 60);
        const secs = Math.floor(l % 60).toString().padStart(2, "0");
        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }
    readonly property real audioIntensity: {
        const values = Audio.cava?.values ?? [];
        if (!values.length)
            return Players.active?.isPlaying ? 0.25 : 0.08;

        let total = 0;
        for (const value of values)
            total += Math.max(0, Math.min(1, value));
        return Math.max(0.08, Math.min(1, total / values.length));
    }
    
    // Real pill element positions (set by start())
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
    
    // We compute the expanded X and Y to center the expansion or push it inward
    // Assuming taskbar is vertical and on the left or right:
    
    // Expose pill properties for Regions masking
    readonly property real pillX: musicPill.x
    readonly property real pillY: musicPill.y
    readonly property real pillW: musicPill.width
    readonly property real pillH: musicPill.height
    // If startX is small (left), expand to the right. If startX is large (right), expand to the left.
    property real endX: startX < root.width / 2 ? startX + startW + 24 : startX - endW - 24
    // Center it vertically based on the pill
    property real endY: startY + (startH - endH) / 2

    // Dismissal Layer
    MouseArea {
        z: 0
        anchors.fill: parent
        enabled: root.active && !root.suppressDismiss
        hoverEnabled: true
        onClicked: close()
    }

    function applyLayout(x: real, y: real, w: real, h: real, color: color,
                         artX: real, artY: real, artW: real, artH: real,
                         btn1X: real, btn1Y: real,
                         btn2X: real, btn2Y: real,
                         btn3X: real, btn3Y: real,
                         btnSize: real): void {
        startX = x;
        startY = y;
        startW = w;
        startH = h;
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
        docked = false;
        dockLayoutReady = false;
        _lastDockX = -1;
        _lastDockY = -1;
        _dockStableTicks = 0;
        _dockSyncCount = 0;
    }

    function syncDock(x: real, y: real, w: real, h: real, color: color,
                      artX: real, artY: real, artW: real, artH: real,
                      btn1X: real, btn1Y: real,
                      btn2X: real, btn2Y: real,
                      btn3X: real, btn3Y: real,
                      btnSize: real): void {
        if (root.active)
            return;

        applyLayout(x, y, w, h, color, artX, artY, artW, artH,
                    btn1X, btn1Y, btn2X, btn2Y, btn3X, btn3Y, btnSize);

        if (w <= 0 || h <= 0)
            return;

        if (Math.abs(x - _lastDockX) < 0.5 && Math.abs(y - _lastDockY) < 0.5)
            _dockStableTicks++;
        else
            _dockStableTicks = 0;

        _lastDockX = x;
        _lastDockY = y;
        _dockSyncCount++;

        if (_dockStableTicks >= 3 && _dockSyncCount >= 8)
            dockLayoutReady = true;

        if (!active)
            musicPill.state = "compact";
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
        hideTimer.stop();
        expandDeferred.stop();

        const w = startW > 0 ? startW : 48;
        const h = startH > 0 ? startH : 160;
        if (startW <= 0 || startH <= 0) {
            startW = w;
            startH = h;
        }

        musicPill.x = startX;
        musicPill.y = startY;
        musicPill.width = w;
        musicPill.height = h;
        musicPill.radius = w / 2;

        dockLayoutReady = true;
        docked = false;
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

    visible: !!Players.active
    z: 2000

    Connections {
        target: Players
        function onActiveChanged() {
            if (!Players.active) {
                root.active = false;
                root.resetDockLayout();
            } else {
                root.resetDockLayout();
            }
        }
    }

    Component.onCompleted: {
        Players.registerMediaMorph(root.screen.name, root);
        root.updateArtDisplaySource();
    }

    Connections {
        target: Players
        function onArtReloadNonceChanged() {
            root.updateArtDisplaySource();
        }
    }

    Component.onDestruction: {
        Players.unregisterMediaMorph(root.screen.name, root);
    }

    Timer {
        id: expandDeferred
        interval: 16
        repeat: false
        onTriggered: {
            if (!root.active)
                return;
            musicPill.state = "expanded";
            dismissGuard.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 520
        onTriggered: {
            root.active = false;
            root.docked = false;
            root.dockLayoutReady = false;
        }
    }

    Timer {
        id: dismissGuard
        interval: 200
        repeat: false
        onTriggered: root.suppressDismiss = false
    }

    Keys.onEscapePressed: close()



    readonly property bool needsCava: Players.active
        && (Players.active.isPlaying ?? false)

    Loader {
        active: root.needsCava
        sourceComponent: Component {
            Item {
                ServiceRef {
                    service: Audio.cava
                }
                Connections {
                    target: Audio.cava
                    function onValuesChanged(): void {
                        CpuProfile.bump("cavaValuesChanged");
                    }
                }
            }
        }
    }


    // ── The Morphing Card ────────────────────────────────────────────────────────
    Rectangle {
        id: musicPill

        z: 1
        opacity: root.active ? 1 : 0
        enabled: root.active

        // Initial setup
        x: root.startX
        y: root.startY
        width: root.startW
        height: root.startH
        radius: root.startRadius
        clip: true

        color: Qt.rgba(0, 0, 0, 0.96)
        
        state: "compact"

        // Dynamic Island squash — subtle horizontal bloom on expand, vertical on collapse
        property real morphSquashX: 1.0
        property real morphSquashY: 1.0

        transform: [
            Scale {
                origin.x: musicPill.width / 2
                origin.y: musicPill.height / 2
                xScale: musicPill.morphSquashX
                yScale: musicPill.morphSquashY
            }
        ]


        Rectangle {
            id: topShade
            anchors.fill: parent
            opacity: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.96) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.82) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        // ── Canvas-based Smooth Neon Visualizer (No bleed) ───────────────────────
        StyledClippingRect {
            id: visualizerContainer
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            NeonWaveVisualizer {
                anchors.fill: parent
                accentColor: root.resolvedVisualizerAccent
                numBands: 32
                maxHeightRatio: 0.8
                valueMultiplier: 1.5
                active: Players.active?.isPlaying ?? false
                frameInterval: musicPill.state === "expanded" ? 16 : 33
            }
        }

        // Absorb clicks on the card so the dismiss layer only fires outside the card
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => {
                mouse.accepted = true;
                if (root.seekPreview >= 0)
                    return;
                if (musicPill.state === "expanded")
                    return;
                if (!root.active)
                    root.expand();
            }
        }


        StyledClippingRect {
            id: musicIcon
            // No visible binding - it lives forever and morphs
            width: 34; height: 34; radius: 17
            color: root.hasMusicArt
                ? Qt.rgba(1, 1, 1, 0.08)
                : Qt.hsla(root.resolvedVisualizerAccent.hslHue, root.resolvedVisualizerAccent.hslSaturation, root.resolvedVisualizerAccent.hslLightness * 0.75, 1)
            x: 7
            y: 7

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
                color: root.hasMusicArt ? Qt.rgba(1, 1, 1, 0.4) : root.musicOnAccent
                font.pointSize: 14
                visible: !root.hasMusicArt || artImage.status !== Image.Ready
            }
        }

        // Track Info
        Column {
            id: trackInfo
            width: 204
            spacing: 2
            x: 116
            y: 18
            opacity: 0

            StyledText {
                width: parent.width
                text: Players.active ? (Players.active.trackTitle || "Unknown Title") : "Nothing Playing"
                color: Qt.rgba(1, 1, 1, 0.96); font.pointSize: Tokens.font.size.normal
                font.weight: 600; elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft
            }
            StyledText {
                width: parent.width
                text: Players.active ? (Players.active.trackArtist || "Unknown Artist") : ""
                color: Qt.rgba(1, 1, 1, 0.50); font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft
            }
        }

        // ── Controls ──────────────────────────────────────
        Rectangle {
            id: prevBtnContainer
            width: 30; height: 30; radius: 15; color: "transparent"
            scale: prevBtnState.pressed ? 0.85 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            MaterialIcon {
                id: prevBtn
                anchors.centerIn: parent
                text: "skip_previous"
                color: Players.active ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.25)
                font.pointSize: 14
            }
            StateLayer { id: prevBtnState; showRipple: false; enabled: Players.active !== null; onClicked: Players.previous(); radius: parent.radius }
        }

        Rectangle {
            id: playBtn
            width: 30; height: 30
            radius: (Players.active && Players.active.isPlaying) ? (musicPill.state === "expanded" ? 14 : 10) : height / 2
            color: Players.active ? root.resolvedPlayButtonBg : "transparent"
            clip: true
            scale: playBtnState.pressed ? 0.85 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    live: true
                    hideSource: false
                    sourceItem: Rectangle {
                        width: playBtn.width
                        height: playBtn.height
                        radius: playBtn.radius
                        color: "black"
                    }
                }
            }

            MaterialIcon {
                id: playIcon
                anchors.centerIn: parent
                text: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
                color: Players.active ? root.playIconColor : Qt.rgba(1, 1, 1, 0.4)
                font.pointSize: 16

                animate: true
                animateProp: "rotation"
                animateFrom: 90
                animateTo: 0
                animateDuration: 400
            }
            StateLayer { id: playBtnState; showRipple: false; radius: parent.radius; enabled: Players.active !== null; onClicked: Players.togglePlaying() }
        }

        Rectangle {
            id: nextBtnContainer
            width: 30; height: 30; radius: 15; color: "transparent"
            scale: nextBtnState.pressed ? 0.85 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            MaterialIcon {
                id: nextBtn
                anchors.centerIn: parent
                text: "skip_next"
                color: Players.active ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.25)
                font.pointSize: 14
            }
            StateLayer { id: nextBtnState; showRipple: false; enabled: Players.active !== null; onClicked: Players.next(); radius: parent.radius }
        }


        Item {
            id: expandedContent
            // No hardcoded visible binding — relies on opacity fades via trackInfo and expandedProgressWrap
            anchors.fill: parent

            // expandedArt was removed because musicIcon now morphs seamlessly into its position

            // expandedControls completely removed as morphed buttons (prevBtnContainer, playBtn, nextBtnContainer) 
            // now serve as the actual buttons in both states.

            Item {
                id: expandedProgressWrap
                x: 24
                y: root.expandedProgressY
                width: parent.width - 48
                height: root.expandedProgressHeight

                RowLayout {
                    id: progressTimes
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    StyledText {
                        text: root.lengthStr(Players.active ? root.displayPosition : -1)
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: root.lengthStr(root.playerLength > 0 ? root.playerLength : -1)
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: Font.Medium
                    }
                }

                Item {
                    id: progressBarArea
                    anchors.top: progressTimes.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    MouseArea {
                        id: progressSeekArea
                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        enabled: musicPill.state === "expanded" && root.canSeek
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        preventStealing: true
                        z: 10

                        function fractionAt(mouseX: real): real {
                            const w = progressBarArea.width;
                            if (w <= 0)
                                return 0;
                            return Math.max(0, Math.min(1, mouseX / w));
                        }

                        onPressed: (mouse) => {
                            root.seekPreview = fractionAt(mouse.x);
                            mouse.accepted = true;
                        }

                        onPositionChanged: (mouse) => {
                            if (pressed)
                                root.seekPreview = fractionAt(mouse.x);
                        }

                        onReleased: (mouse) => {
                            if (root.seekPreview >= 0)
                                Players.seekTo(root.seekPreview);
                            root.seekPreview = -1;
                            mouse.accepted = true;
                        }

                        onCanceled: root.seekPreview = -1
                    }

                    Rectangle {
                        id: expandedProgressTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3 + root.audioIntensity * 2
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.10 + root.audioIntensity * 0.05)
                        z: 1
                    }

                    Rectangle {
                        id: expandedProgressFill
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.hasProgressFill
                            ? Math.max(4, parent.width * root.displayProgress)
                            : 0
                        height: expandedProgressTrack.height
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.85 + root.audioIntensity * 0.12)
                        visible: root.hasProgressFill
                        z: 2

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.alpha(root.resolvedVisualizerAccent, 0.92)
                            shadowOpacity: 0.75 + root.audioIntensity * 0.20
                            shadowBlur: 0.85
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }

                    Rectangle {
                        id: expandedProgressThumb
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.hasProgressFill ? Math.max(0, expandedProgressFill.width - width / 2) : 0
                        width: expandedProgressTrack.height + 8
                        height: width
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.95 + root.audioIntensity * 0.03)
                        visible: root.hasProgressFill
                        z: 3

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.alpha(root.resolvedVisualizerAccent, 0.88)
                            shadowOpacity: 0.70 + root.audioIntensity * 0.25
                            shadowBlur: 0.80
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }
                }
            }
        }

        states: [
            State {
                name: "compact"
                PropertyChanges { target: musicPill; x: root.startX; y: root.startY; width: root.startW; height: root.startH; radius: root.startRadius }
                PropertyChanges { target: musicIcon; width: root.realArtW; height: root.realArtH; radius: root.realArtH / 2; x: root.realArtX; y: root.realArtY }
                PropertyChanges { target: trackInfo; opacity: 0 }
                PropertyChanges { target: expandedProgressWrap; opacity: 0 }
                // Compact buttons: visible at compact positions, compact styling
                PropertyChanges { target: prevBtnContainer; x: root.realBtn1X; y: root.realBtn1Y; opacity: 1; width: root.realBtnSize; height: root.realBtnSize; radius: root.realBtnSize / 2; color: "transparent" }
                PropertyChanges { target: playBtn; x: root.realBtn2X; y: root.realBtn2Y; width: root.realBtnSize; height: root.realBtnSize; color: root.resolvedPlayButtonBg }
                PropertyChanges { target: nextBtnContainer; x: root.realBtn3X; y: root.realBtn3Y; opacity: 1; width: root.realBtnSize; height: root.realBtnSize; radius: root.realBtnSize / 2; color: "transparent" }
                PropertyChanges { target: playIcon; font.pointSize: Tokens.font.size.larger; color: root.playIconColor }
                PropertyChanges { target: prevBtn; font.pointSize: Tokens.font.size.large; color: Colours.palette.m3onSurfaceVariant }
                PropertyChanges { target: nextBtn; font.pointSize: Tokens.font.size.large; color: Colours.palette.m3onSurfaceVariant }
            },
            State {
                name: "expanded"
                PropertyChanges { target: musicPill; x: root.endX; y: root.endY; width: root.endW; height: root.endH; radius: root.endRadius }
                PropertyChanges { target: musicIcon; width: 80; height: 80; radius: 16; x: 20; y: 20 }
                PropertyChanges { target: trackInfo; opacity: 1 }
                PropertyChanges { target: expandedProgressWrap; opacity: 1 }
                // Compact buttons morph INTO expanded style — no second button set needed
                PropertyChanges { target: prevBtnContainer; x: 138; y: root.expandedSideButtonY; opacity: 1; width: 40; height: 40; radius: 20; color: "transparent" }
                PropertyChanges { target: playBtn; x: 190; y: root.expandedPlayY; width: 48; height: 48; color: root.resolvedPlayButtonBg }
                PropertyChanges { target: nextBtnContainer; x: 250; y: root.expandedSideButtonY; opacity: 1; width: 40; height: 40; radius: 20; color: "transparent" }
                PropertyChanges { target: playIcon; font.pointSize: 24; color: root.playIconColor }
                PropertyChanges { target: prevBtn; font.pointSize: 20; color: Qt.rgba(1, 1, 1, 0.88) }
                PropertyChanges { target: nextBtn; font.pointSize: 20; color: Qt.rgba(1, 1, 1, 0.88) }
            }
        ]

        transitions: [
            // ── Expand: Dynamic Island horizontal bloom → content reveal ──
            Transition {
                id: expandTransition
                from: "compact"; to: "expanded"
                ParallelAnimation {
                    // Width + X lead the morph (island grows outward first)
                    SpringAnimation {
                        targets: [musicPill]
                        properties: "width,x"
                        spring: root.spatialSpring
                        damping: root.spatialDamping
                        epsilon: root.spatialEpsilon
                        mass: 0.85
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 44 }
                        SpringAnimation {
                            targets: [musicPill]
                            properties: "y,height,radius"
                            spring: 4.4
                            damping: 0.42
                            epsilon: root.spatialEpsilon
                            mass: 0.9
                        }
                    }
                    // Artwork scales up, then glides into expanded slot
                    SpringAnimation {
                        targets: [musicIcon]
                        properties: "width,height,radius"
                        spring: root.spatialSpring
                        damping: root.spatialDamping
                        epsilon: root.spatialEpsilon
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 36 }
                        SpringAnimation {
                            targets: [musicIcon]
                            properties: "x,y"
                            spring: 4.2
                            damping: 0.42
                            epsilon: root.spatialEpsilon
                        }
                    }
                    // Controls morph into horizontal row after shell opens
                    SequentialAnimation {
                        PauseAnimation { duration: 56 }
                        SpringAnimation {
                            targets: [prevBtnContainer, playBtn, nextBtnContainer]
                            properties: "x,y,width,height,radius"
                            spring: 4.6
                            damping: 0.40
                            epsilon: root.spatialEpsilon
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 72 }
                        SpringAnimation {
                            targets: [playIcon, prevBtn, nextBtn]
                            property: "font.pointSize"
                            spring: 4.0
                            damping: 0.45
                            epsilon: 0.08
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 64 }
                        ColorAnimation {
                            targets: [playBtn, playIcon, prevBtn, nextBtn]
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    // Subtle island breathe on expand
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 0.958
                            duration: 90
                            easing.type: Easing.OutCubic
                        }
                        SpringAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.0
                            spring: 3.6
                            damping: 0.38
                            epsilon: 0.05
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.032
                            duration: 90
                            easing.type: Easing.OutCubic
                        }
                        SpringAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.0
                            spring: 3.6
                            damping: 0.38
                            epsilon: 0.05
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: topShade; property: "opacity"; to: 0.10; duration: 100; easing.type: Easing.OutQuad }
                        NumberAnimation { target: topShade; property: "opacity"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    }
                    // Staggered content reveal — Dynamic Island pattern
                    SequentialAnimation {
                        PauseAnimation { duration: root.contentRevealDelay }
                        NumberAnimation {
                            target: trackInfo
                            property: "opacity"
                            to: 1
                            duration: 220
                            easing.type: Easing.OutQuint
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: root.progressRevealDelay }
                        NumberAnimation {
                            target: expandedProgressWrap
                            property: "opacity"
                            to: 1
                            duration: 180
                            easing.type: Easing.OutQuint
                        }
                    }
                }
            },

            // ── Collapse: content out → vertical contract → horizontal retract ──
            Transition {
                id: collapseTransition
                from: "expanded"; to: "compact"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [trackInfo, expandedProgressWrap]
                        property: "opacity"
                        to: 0
                        duration: 90
                        easing.type: Easing.OutQuint
                    }
                    SpringAnimation {
                        targets: [musicPill, musicIcon]
                        properties: "y,height,radius"
                        spring: 5.2
                        damping: 0.40
                        epsilon: root.spatialEpsilon
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 64 }
                        SpringAnimation {
                            targets: [musicPill, musicIcon]
                            properties: "width,x"
                            spring: 4.6
                            damping: 0.42
                            epsilon: root.spatialEpsilon
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 48 }
                        SpringAnimation {
                            targets: [prevBtnContainer, playBtn, nextBtnContainer]
                            properties: "x,y,width,height,radius"
                            spring: 4.8
                            damping: 0.40
                            epsilon: root.spatialEpsilon
                        }
                    }
                    SpringAnimation {
                        targets: [playIcon, prevBtn, nextBtn]
                        property: "font.pointSize"
                        spring: 4.2
                        damping: 0.45
                        epsilon: 0.08
                    }
                    ColorAnimation {
                        targets: [playBtn, playIcon, prevBtn, nextBtn]
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 0.968
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                        SpringAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.0
                            spring: 4.0
                            damping: 0.38
                            epsilon: 0.05
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 40 }
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.028
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                        SpringAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.0
                            spring: 4.0
                            damping: 0.38
                            epsilon: 0.05
                        }
                    }
                }
            }
        ]
    }
}
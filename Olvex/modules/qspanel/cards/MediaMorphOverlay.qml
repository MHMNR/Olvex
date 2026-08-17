
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Services.Mpris
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
    // Set true when collapse starts — lets bar pill appear before overlay fully hides
    property bool closingDown: false
    property real _lastDockX: -1
    property real _lastDockY: -1
    property int _dockStableTicks: 0
    property int _dockSyncCount: 0
    readonly property string musicArtUrl: Players.currentArtUrl
    property string artDisplaySource: ""
    readonly property bool artIsLocal: root.musicArtUrl.startsWith("file:") || root.musicArtUrl.startsWith("/")
    readonly property bool hasMusicArt: root.musicArtUrl !== ""
    readonly property color resolvedVisualizerAccent: Players.musicVisualizerAccent
    readonly property color resolvedPlayButtonBg: Players.musicPlayButtonBg
    readonly property color musicAccent: Players.musicVisualizerAccent
    readonly property color musicOnAccent: Players.musicOnAccent
    readonly property color playButtonBg: Players.musicPlayButtonBg
    readonly property color playIconColor: Players.musicPlayIconColor
    readonly property color timeTextColor: Qt.alpha(Players.musicOnSurfaceColor, 0.58)
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
    readonly property real expandedSideButtonSize: 40
    readonly property real expandedSideButtonRadius: expandedSideButtonSize / 2
    readonly property real expandedSideButtonIconSize: 19
    readonly property real compactSkipIconScale: 0.86
    readonly property real expandedSkipIconScale: 1.0
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
    readonly property bool ownsDockedPill: root.dockLayoutReady && !!Players.active
    // The overlay handles the full morph animation both ways
    readonly property bool overlayRendering: root.active || root.morphAnimating
    readonly property bool mediaVisualizerWarm: root.overlayRendering
    readonly property bool mediaVisualizerActive: root.mediaVisualizerWarm && Players.activeIsPlaying
    readonly property bool ownsVisualizer: VisualizerState.visibleOwner === "overlay"
    // Experiment: match the monitor's native refresh rate instead of a fixed
    // 60fps cap, now that the play-button spin/wavy-line pinning is removed.
    readonly property real _screenHz: Screen.refreshRate > 0 ? Screen.refreshRate : 60
    readonly property int visualizerFrameInterval: Math.max(1, Math.round(1000 / root._screenHz))
    property bool mediaVisualizerLoaded: mediaVisualizerActive

    readonly property real playerProgress: Players.interpolatedProgress
    readonly property real playerPosition: Players.interpolatedPosition
    readonly property real playerLength: Players.interpolatedLength
    property real seekPreview: -1
    readonly property real displayProgress: {
        const p = seekPreview >= 0 ? seekPreview : playerProgress;
        return p < 0.004 ? 0 : p;
    }
    readonly property bool hasProgressFill: root.displayProgress > 0
    readonly property real displayPosition: seekPreview >= 0 && playerLength > 0 ? seekPreview * playerLength : playerPosition
    readonly property bool canSeek: Players.active !== null && (Players.active.canSeek ?? false) && (Players.active.positionSupported ?? false)

    // ── Art source helpers ─────────────────────────────────────────────────────
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
    function applyLayout(x: real, y: real, w: real, h: real, color: color, artX: real, artY: real, artW: real, artH: real, btn1X: real, btn1Y: real, btn2X: real, btn2Y: real, btn3X: real, btn3Y: real, btnSize: real): void {
        startX = x;
        startY = y;
        startW = w;
        startH = h;
        realArtX = artX;
        realArtY = artY;
        realArtW = artW;
        realArtH = artH;
        realBtn1X = btn1X;
        realBtn1Y = btn1Y;
        realBtn2X = btn2X;
        realBtn2Y = btn2Y;
        realBtn3X = btn3X;
        realBtn3Y = btn3Y;
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

    function updateDockTarget(x: real, y: real, w: real, h: real, artX: real, artY: real, artW: real, artH: real, btn1X: real, btn1Y: real, btn2X: real, btn2Y: real, btn3X: real, btn3Y: real, btnSize: real): void {
        startX = x;
        startY = y;
        startW = w;
        startH = h;
        realArtX = artX;
        realArtY = artY;
        realArtW = artW;
        realArtH = artH;
        realBtn1X = btn1X;
        realBtn1Y = btn1Y;
        realBtn2X = btn2X;
        realBtn2Y = btn2Y;
        realBtn3X = btn3X;
        realBtn3Y = btn3Y;
        realBtnSize = btnSize;
    }

    function syncDock(x: real, y: real, w: real, h: real, color: color, artX: real, artY: real, artW: real, artH: real, btn1X: real, btn1Y: real, btn2X: real, btn2Y: real, btn3X: real, btn3Y: real, btnSize: real): void {
        if (root.active)
            return;
        applyLayout(x, y, w, h, color, artX, artY, artW, artH, btn1X, btn1Y, btn2X, btn2Y, btn3X, btn3Y, btnSize);
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

    function start(x: real, y: real, w: real, h: real, color: color, artX: real, artY: real, artW: real, artH: real, btn1X: real, btn1Y: real, btn2X: real, btn2Y: real, btn3X: real, btn3Y: real, btnSize: real): void {
        applyLayout(x, y, w, h, color, artX, artY, artW, artH, btn1X, btn1Y, btn2X, btn2Y, btn3X, btn3Y, btnSize);
        docked = true;
        expand();
    }

    function expand(): void {
        hideTimer.stop();
        expandDeferred.stop();
        closingDown = false;
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
        closingDown = true;
        if (typeof sourceSelector !== "undefined")
            sourceSelector.expanded = false;
        musicPill.state = "compact";
        hideTimer.start();
    }

    function syncVisualizerOwner(): void {
        VisualizerState.request("overlay", 30, root.mediaVisualizerActive);
    }

    // ── Connections / lifecycle ────────────────────────────────────────────────
    Connections {
        target: Players
        function onActiveChanged() {
            if (!Players.active) {
                root.active = false;
                root.resetDockLayout();
            } else
                root.resetDockLayout();
        }
    }

    Component.onCompleted: {
        Players.registerMediaMorph(root.screen.name, root);
        root.updateArtDisplaySource();
        root.syncVisualizerOwner();
    }

    Connections {
        target: Players
        function onCurrentArtUrlChanged() {
            root.updateArtDisplaySource();
        }
        function onArtReloadNonceChanged() {
            root.updateArtDisplaySource();
        }
    }

    Component.onDestruction: {
        Players.unregisterMediaMorph(root.screen.name, root);
        VisualizerState.release("overlay");
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
        interval: root.collapseDur
        onTriggered: {
            root.active = false;
            root.docked = false;
            root.closingDown = false;
        }
    }
    Timer {
        id: dismissGuard
        interval: 200
        repeat: false
        onTriggered: root.suppressDismiss = false
    }

    Timer {
        id: visualizerUnloadTimer
        interval: Math.max(root.visualizerFrameInterval * 28, 900)
        repeat: false
        onTriggered: root.mediaVisualizerLoaded = false
    }

    onMediaVisualizerActiveChanged: {
        root.syncVisualizerOwner();
        if (mediaVisualizerActive) {
            visualizerUnloadTimer.stop();
            mediaVisualizerLoaded = true;
        } else if (mediaVisualizerLoaded) {
            visualizerUnloadTimer.restart();
        }
    }

    Keys.onEscapePressed: close()

    // ── Dismiss layer ─────────────────────────────────────────────────────────
    MouseArea {
        z: 0
        anchors.fill: parent
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
        // Opacity tied directly to overlay rendering
        opacity: root.overlayRendering ? 1 : 0
        enabled: root.overlayRendering
        // No Behavior on opacity — swap instantly with bar pill when morph finishes
        x: root.startX
        y: root.startY
        width: root.startW
        height: root.startH
        radius: root.startRadius
        clip: true
        color: "transparent"

        property real morphSquashX: 1.0
        property real morphSquashY: 1.0
        property real morphLift: 0.0
        // Crossfades compact visual layer → card visual layer during morph (1=compact, 0=expanded)
        property real compactFade: 1.0

        transform: [
            Translate {
                x: root.opensRight ? musicPill.morphLift : -musicPill.morphLift
                y: 0
            },
            Scale {
                origin.x: root.opensRight ? 0 : musicPill.width
                origin.y: musicPill.height / 2
                xScale: musicPill.morphSquashX
                yScale: musicPill.morphSquashY
            }
        ]

        layer.enabled: false
        state: "compact"

        // ── Card background — matches pill: surfaceColor + m3surfaceTint tonal ──
        Rectangle {
            anchors.fill: parent
            radius: musicPill.radius
            antialiasing: true
            color: Players.musicSurfaceColor
            Behavior on color {
                ColorAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                antialiasing: true
                color: "transparent"
                border.width: musicPill.state === "expanded" ? 1 : 0
                border.color: Qt.alpha(Players.musicOnSurfaceColor, 0.07)
            }

            // Ambient glow — a soft, thumbnail-shaped light bloom behind the
            // art. Three overlapping rounded-square discs (wide faint halo →
            // body → hot core lifted toward white) are each individually
            // blurred, then clipped to the card's rounded shape by this
            // StyledClippingRect — a reliable stencil clip. (A MultiEffect
            // mask was tried but rendered a hard SQUARE corner at the top-
            // left; a per-disc blur inside a real rounded clip doesn't.)
            // Each disc owns its blur so its texture is sized to itself and
            // never corner-clips. Static, gated on playback (not expanded
            // state) so the mini/compact pill gets the glow too — geometry
            // already derives from musicIcon's live size, so it scales down
            // to the compact art tile automatically.
            StyledClippingRect {
                id: glowClip
                anchors.fill: parent
                radius: musicPill.radius // the pill/card rounding
                color: "transparent"
                // Present whenever a player is loaded — not gated on isPlaying,
                // so it doesn't disappear on pause.
                opacity: Players.active !== null ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                        easing: Tokens.anim.emphasizedDecel
                    }
                }

                Repeater {
                    // widest/faintest first (behind) → hot core last (on top)
                    model: [
                        { mult: 2.4,  dark: 1.5, alpha: 0.10, bmax: 56 }, // halo
                        { mult: 1.6,  dark: 1.8, alpha: 0.16, bmax: 44 }, // body
                        { mult: 1.05, dark: 2.2, alpha: 0.28, bmax: 30 }  // dark core
                    ]
                    delegate: Rectangle {
                        id: glowLayer
                        required property var modelData
                        readonly property real d: musicIcon.width * modelData.mult
                        width: d
                        height: d
                        // Shape the source like the album tile (its own
                        // rounded-square radius, scaled) — not a circle.
                        radius: musicIcon.radius * modelData.mult
                        x: musicIcon.x + musicIcon.width / 2 - d / 2
                        y: musicIcon.y + musicIcon.height / 2 - d / 2
                        color: Qt.alpha(Qt.darker(root.musicAccent, modelData.dark), modelData.alpha)
                        antialiasing: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: glowLayer.modelData.bmax
                        }
                    }
                }
            }
        }

        // ── Neon wave visualizer ───────────────────────────────────────────────
        StyledClippingRect {
            anchors.fill: parent
            radius: musicPill.radius
            color: "transparent"

            Loader {
                anchors.fill: parent
                active: root.mediaVisualizerLoaded
                asynchronous: true
                sourceComponent: Component {
                    Item {
                        NeonWaveVisualizer {
                            anchors.fill: parent
                            accentColor: root.resolvedVisualizerAccent
                            numBands: 32
                            maxHeightRatio: musicPill.state === "expanded" ? 0.46 : 0.76
                            topFadeRatio: musicPill.state === "expanded" ? 0.26 : 0.14
                            valueMultiplier: musicPill.state === "expanded" ? 1.24 : 1.42
                            active: root.mediaVisualizerActive && root.ownsVisualizer
                            frameInterval: root.visualizerFrameInterval
                        }
                    }
                }
            }
        }

        // ── Art — StyledClippingRect (backup pattern: default pos = pill pos, states drive everything) ──
        StyledClippingRect {
            id: musicIcon
            x: 7
            y: 7
            width: 34
            height: 34
            radius: 17
            color: root.hasMusicArt ? Qt.alpha(Players.musicOnSurfaceColor, 0.10) : Qt.alpha(root.musicAccent, 0.22)

            Image {
                id: artImage
                anchors.fill: parent
                source: root.artDisplaySource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: !root.artIsLocal
                // Fixed at the largest (expanded) art size the card ever displays at —
                // sourceSize must NOT track the live animated width/height, or the
                // decoder re-samples the source on every frame of the expand/collapse
                // morph, causing the visible blink during the transition.
                sourceSize: Qt.size(80, 80)
                opacity: status === Image.Ready && source !== "" ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
            }
            MaterialIcon {
                id: musicPlaceholderIcon
                anchors.centerIn: parent
                text: "music_note"
                color: root.hasMusicArt ? Qt.alpha(Players.musicOnSurfaceColor, 0.4) : root.musicOnAccent
                iconPointSize: 14
                visible: !root.hasMusicArt || artImage.status !== Image.Ready
            }
        }

        // ── Track info (title + artist) — single Column, backup pattern ──────────
        // titleChip = dummy for opacity animation compat with transitions
        Item {
            id: titleChip
            opacity: 0
        }

        Column {
            id: trackInfo
            x: 116
            y: 16
            width: Math.max(100, musicPill.width - x - 16)
            spacing: 2
            opacity: 0

            MarqueeText {
                width: parent.width
                text: Players.active ? (Players.active.trackTitle || qsTr("Unknown Title")) : ""
                color: Players.musicOnSurfaceColor
                textPointSize: Tokens.font.size.normal + 0.4
                font.weight: 760
                font.letterSpacing: 0.12
                running: musicPill.state === "expanded" && trackInfo.opacity > 0.95
            }
            StyledText {
                width: parent.width
                text: Players.active ? (Players.active.trackArtist || qsTr("Unknown Artist")) : ""
                color: Qt.alpha(Players.musicOnSurfaceColor, 0.42)
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.Medium
                font.letterSpacing: 0.08
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
        }

        // ── Controls surface ───────────────────────────────────────────────────
        Item {
            id: controlsSurface
            opacity: 0
        }

        // ── Buttons z:10 ──────────────────────────────────────────────────────
        MorphControlButton {
            id: prevBtnContainer
            z: 10
            iconName: "skip_previous"
            balancedSkipIcon: true
            skipIconScale: root.compactSkipIconScale
            // Not elevated — the expanded state sets secondaryProgress:1 on this
            // button, which (combined with elevated) painted a soft blurred
            // colored shadow around it. Flanking the play button, this and the
            // matching next-button shadow overlapped into one continuous glow
            // smear across the whole control row.
            secondaryShape: MaterialShape.Circle
            secondaryProgress: 0
            onClicked: Players.previous()
        }
        MorphControlButton {
            id: playBtn
            z: 10
            emphasized: true
            iconName: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
            onClicked: Players.togglePlaying()
        }
        MorphControlButton {
            id: nextBtnContainer
            z: 10
            iconName: "skip_next"
            balancedSkipIcon: true
            skipIconScale: root.compactSkipIconScale
            // Not elevated — see prevBtnContainer's comment above.
            secondaryShape: MaterialShape.Circle
            secondaryProgress: 0
            onClicked: Players.next()
        }

        // ── Click absorber z:5 ────────────────────────────────────────────────
        MouseArea {
            z: 5
            anchors.fill: parent
            hoverEnabled: true
            enabled: musicPill.state !== "expanded"
            onClicked: mouse => {
                mouse.accepted = true;
                if (root.seekPreview >= 0)
                    return;
                if (!root.active)
                    root.expand();
            }
        }

        // ── Progress bar ───────────────────────────────────────────────────────
        Item {
            id: expandedContent
            anchors.fill: parent
            opacity: 0

            Item {
                id: expandedProgressWrap
                x: 24
                y: root.expandedProgressY
                width: musicPill.width - 48
                height: root.expandedProgressHeight

                Text {
                    id: timeElapsed
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lengthStr(root.displayPosition)
                    color: root.timeTextColor
                    font.pixelSize: 11
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                }

                Text {
                    id: timeTotal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lengthStr(root.playerLength)
                    color: root.timeTextColor
                    font.pixelSize: 11
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                }

                Item {
                    id: progressTrackRow
                    anchors.left: timeElapsed.right
                    anchors.right: timeTotal.left
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28

                    // M3 Expressive slider & seekbar tokens (m3.material.io)
                    readonly property bool isInteracting: dragging || hoverArea.containsMouse
                    readonly property real trackThickness: 4
                    readonly property real activeThickness: 4
                    readonly property real inactiveThickness: 4
                    readonly property real gap: 6            // thumbTrackGapSize: 6dp
                    readonly property real stopIndicatorSize: 4 // trackStopIndicatorSize: 4dp
                    readonly property real thumbW: dragging ? 4 : (hoverArea.containsMouse ? 5 : 4)
                    readonly property real thumbH: dragging ? 24 : (hoverArea.containsMouse ? 20 : 16)
                    readonly property bool isPlaying: Players.active?.isPlaying ?? false
                    readonly property color activeColor: root.playButtonBg
                    property bool dragging: false

                    readonly property real fillW: Math.max(0, Math.min(width, width * root.displayProgress))
                    // Where the thumb center sits
                    readonly property real thumbX: fillW
                    readonly property bool waveActive: root.seekPreview < 0 && progressTrackRow.isPlaying

                    // ── Active indicator: thick wavy line (value-clipped, no Item clip) ──
                    WavyLine {
                        id: waveIndicator
                        z: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: progressTrackRow.height
                        visible: amplitudeMultiplier > 0.001

                        lineWidth: progressTrackRow.activeThickness
                        color: progressTrackRow.activeColor
                        frequency: 7
                        startX: 0
                        fullLength: progressTrackRow.width
                        // Draw wave only up to fill, leaving 6dp gap before handle
                        value: progressTrackRow.width > 0 ? Math.max(0, (progressTrackRow.fillW - progressTrackRow.gap) / progressTrackRow.width) : 0

                        amplitudeMultiplier: progressTrackRow.waveActive ? 1.6 : 0

                        Behavior on amplitudeMultiplier {
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                        Behavior on value {
                            NumberAnimation {
                                duration: 60
                                easing.type: Easing.OutCubic
                            }
                        }

                        Anim on waveProgress {
                            running: waveIndicator.amplitudeMultiplier > 0 && expandedContent.opacity > 0.01 && !LockState.locked
                            from: 0
                            to: 1
                            duration: 1400
                            easing.type: Easing.Linear
                            loops: Animation.Infinite
                        }
                    }

                    // ── Active flat fill — shown when paused/seeking (no wave) ──────
                    Rectangle {
                        z: 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, progressTrackRow.fillW - progressTrackRow.gap)
                        height: progressTrackRow.activeThickness
                        radius: height / 2
                        color: progressTrackRow.activeColor
                        visible: waveIndicator.amplitudeMultiplier <= 0.001

                        Behavior on width {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                    }

                    // ── Inactive (remaining) track — from thumb gap to right edge ──
                    Rectangle {
                        id: inactiveTrack
                        z: 0
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(progressTrackRow.thumbX + progressTrackRow.gap)
                        width: Math.max(0, progressTrackRow.width - x)
                        height: progressTrackRow.inactiveThickness
                        radius: height / 2
                        color: Qt.alpha(Players.musicOnSurfaceColor, 0.18)
                        visible: width > 0

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                                easing: Tokens.anim.expressiveFastEffects
                            }
                        }
                        Behavior on x {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                    }

                    // ── M3 Stop Indicator at Track Terminus ─────────────────────────
                    Rectangle {
                        z: 5
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: progressTrackRow.stopIndicatorSize
                        height: progressTrackRow.stopIndicatorSize
                        radius: width / 2
                        color: Qt.alpha(Players.musicOnSurfaceColor, progressTrackRow.isInteracting ? 0.40 : 0.25)
                        visible: (progressTrackRow.width - progressTrackRow.fillW) > progressTrackRow.gap * 2
                    }

                    // ── M3 Vertical Bar Handle ──────────────────────────────────────
                    Rectangle {
                        id: seekThumb
                        z: 20
                        visible: root.canSeek
                        x: Math.round(progressTrackRow.thumbX - width / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: progressTrackRow.thumbW
                        height: progressTrackRow.thumbH
                        radius: 2
                        color: progressTrackRow.activeColor
                        antialiasing: true

                        Behavior on x {
                            enabled: !progressTrackRow.dragging
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                        Behavior on width {
                            SpringAnimation {
                                spring: 5.5
                                damping: 0.65
                                epsilon: 0.001
                            }
                        }
                        Behavior on height {
                            SpringAnimation {
                                spring: 5.5
                                damping: 0.65
                                epsilon: 0.001
                            }
                        }
                    }

                    // ── Seek interaction ───────────────────────────────────────
                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        hoverEnabled: true
                        enabled: root.canSeek && musicPill.state === "expanded"
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        preventStealing: true
                        z: 25

                        function fractionAt(mouseX: real): real {
                            const w = progressTrackRow.width;
                            if (w <= 0)
                                return 0;
                            return Math.max(0, Math.min(1, mouseX / w));
                        }

                        onPressed: mouse => {
                            progressTrackRow.dragging = true;
                            root.seekPreview = fractionAt(mouse.x);
                            mouse.accepted = true;
                        }
                        onReleased: mouse => {
                            progressTrackRow.dragging = false;
                            if (root.seekPreview >= 0) {
                                Players.seekTo(root.seekPreview);
                                root.seekPreview = -1;
                            }
                            mouse.accepted = true;
                        }
                        onPositionChanged: mouse => {
                            if (pressed)
                                root.seekPreview = fractionAt(mouse.x);
                        }
                        onCanceled: {
                            progressTrackRow.dragging = false;
                            root.seekPreview = -1;
                        }
                    }
                }
            }
        }

        states: [
            State {
                name: "compact"
                PropertyChanges {
                    target: musicPill
                    x: root.startX
                    y: root.startY
                    width: root.startW
                    height: root.startH
                    radius: root.startRadius
                    compactFade: 1.0
                }
                PropertyChanges {
                    target: musicIcon
                    x: root.realArtX
                    y: root.realArtY
                    width: root.realArtW
                    height: root.realArtH
                    radius: root.realArtH / 2
                }
                PropertyChanges {
                    target: titleChip
                    opacity: 0
                }
                PropertyChanges {
                    target: trackInfo
                    opacity: 0
                    y: 24
                }
                PropertyChanges {
                    target: controlsSurface
                    opacity: 0
                }
                PropertyChanges {
                    target: expandedContent
                    opacity: 0
                }
                PropertyChanges {
                    target: prevBtnContainer
                    x: root.realBtn1X
                    y: root.realBtn1Y
                    width: root.realBtnSize
                    height: root.realBtnSize
                    radius: root.realBtnSize / 2
                    iconSize: Tokens.font.size.large
                    skipIconScale: root.compactSkipIconScale
                    secondaryProgress: 0
                }
                PropertyChanges {
                    target: playBtn
                    x: root.realBtn2X
                    y: root.realBtn2Y
                    width: root.realBtnSize
                    height: root.realBtnSize
                    radius: root.realBtnSize / 2
                    iconSize: Tokens.font.size.larger
                }
                PropertyChanges {
                    target: nextBtnContainer
                    x: root.realBtn3X
                    y: root.realBtn3Y
                    width: root.realBtnSize
                    height: root.realBtnSize
                    radius: root.realBtnSize / 2
                    iconSize: Tokens.font.size.large
                    skipIconScale: root.compactSkipIconScale
                    secondaryProgress: 0
                }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: musicPill
                    x: root.endX
                    y: root.endY
                    width: root.endW
                    height: root.endH
                    radius: root.endRadius
                    compactFade: 0.0
                }
                PropertyChanges {
                    target: musicIcon
                    x: 20
                    y: 20
                    width: 80
                    height: 80
                    radius: 18
                }
                PropertyChanges {
                    target: titleChip
                    opacity: 1
                }
                PropertyChanges {
                    target: trackInfo
                    opacity: 1
                    y: 16
                }
                PropertyChanges {
                    target: controlsSurface
                    opacity: 1
                }
                PropertyChanges {
                    target: expandedContent
                    opacity: 1
                }
                PropertyChanges {
                    target: prevBtnContainer
                    x: 162 - root.expandedSideButtonSize / 2
                    y: root.expandedSideButtonY
                    width: root.expandedSideButtonSize
                    height: root.expandedSideButtonSize
                    radius: root.expandedSideButtonRadius
                    iconSize: root.expandedSideButtonIconSize
                    skipIconScale: root.expandedSkipIconScale
                    secondaryProgress: 1
                }
                PropertyChanges {
                    target: playBtn
                    x: 190
                    y: root.expandedPlayY
                    width: 48
                    height: 48
                    radius: 24
                    iconSize: 22
                }
                PropertyChanges {
                    target: nextBtnContainer
                    x: 266 - root.expandedSideButtonSize / 2
                    y: root.expandedSideButtonY
                    width: root.expandedSideButtonSize
                    height: root.expandedSideButtonSize
                    radius: root.expandedSideButtonRadius
                    iconSize: root.expandedSideButtonIconSize
                    skipIconScale: root.expandedSkipIconScale
                    secondaryProgress: 1
                }
            }
        ]

        // ── Transitions ────────────────────────────────────────────────────────
        transitions: [
            Transition {
                id: expandTransition
                from: "compact"
                to: "expanded"
                ParallelAnimation {
                    // Container bounds travel — full expand duration (Layer 1)
                    NumberAnimation {
                        targets: [musicPill]
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing: root.spatialEasing
                    }
                    // Shape mask completes at 75% of expand (Container Transform shapeMaskProgressThresholds 0→0.75)
                    NumberAnimation {
                        targets: [musicPill]
                        properties: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing: root.spatialEasing
                    }
                    // Shared elements (art, buttons) travel full duration
                    NumberAnimation {
                        targets: [musicIcon]
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [musicIcon]
                        properties: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, playBtn, nextBtnContainer]
                        properties: "x,y,width,height"
                        duration: root.expandDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, playBtn, nextBtnContainer]
                        properties: "radius"
                        duration: Math.round(root.expandDur * 0.75)
                        easing: root.spatialEasing
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 60
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                targets: [prevBtnContainer, playBtn, nextBtnContainer]
                                property: "iconSize"
                                duration: 250
                                easing: root.spatialEasing
                            }
                            NumberAnimation {
                                targets: [prevBtnContainer, nextBtnContainer]
                                property: "skipIconScale"
                                duration: 250
                                easing: root.spatialEasing
                            }
                            NumberAnimation {
                                targets: [prevBtnContainer, nextBtnContainer]
                                property: "secondaryProgress"
                                duration: 250
                                easing: root.spatialEasing
                            }
                        }
                    }
                    // Morph squash/lift
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.045
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.0
                            duration: Math.round(root.expandDur * 0.58)
                            easing: root.spatialEasingDecel
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 0.965
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.0
                            duration: Math.round(root.expandDur * 0.58)
                            easing: root.spatialEasingDecel
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphLift"
                            to: 8
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphLift"
                            to: 0
                            duration: Math.round(root.expandDur * 0.58)
                            easing: root.spatialEasingDecel
                        }
                    }
                    // Compact layer crossfades to card layer simultaneously with bounds morph
                    NumberAnimation {
                        target: musicPill
                        property: "compactFade"
                        to: 0.0
                        duration: Math.round(root.expandDur * 0.6)
                        easing: root.spatialEasing
                    }
                    // Card content slides up from within the expanding container
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.contentRevealDelay
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                targets: [titleChip, trackInfo, controlsSurface]
                                property: "opacity"
                                to: 1
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                            NumberAnimation {
                                target: trackInfo
                                property: "y"
                                to: 16
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.progressRevealDelay
                        }
                        NumberAnimation {
                            target: expandedContent
                            property: "opacity"
                            to: 1
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                            easing: Tokens.anim.emphasizedDecel
                        }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"
                to: "compact"
                ParallelAnimation {
                    // Card content fades out immediately so it's gone before pill shifts position
                    NumberAnimation {
                        targets: [titleChip, trackInfo, controlsSurface, expandedContent]
                        property: "opacity"
                        to: 0
                        duration: Math.round(root.collapseDur * 0.35)
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: trackInfo
                        property: "y"
                        to: 24
                        duration: Math.round(root.collapseDur * 0.35)
                        easing: root.spatialEasing
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: Math.round(root.collapseDur * 0.6)
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "compactFade"
                            to: 1.0
                            duration: Math.round(root.collapseDur * 0.4)
                            easing: root.spatialEasing
                        }
                    }
                    NumberAnimation {
                        targets: [musicPill, musicIcon]
                        properties: "x,y,width,height,radius"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, playBtn, nextBtnContainer]
                        properties: "x,y,width,height,radius"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, playBtn, nextBtnContainer]
                        property: "iconSize"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, nextBtnContainer]
                        property: "skipIconScale"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        targets: [prevBtnContainer, nextBtnContainer]
                        property: "secondaryProgress"
                        duration: root.collapseDur
                        easing: root.spatialEasing
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.035
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashY"
                            to: 1.0
                            duration: Math.round(root.collapseDur * 0.55)
                            easing: root.spatialEasingDecel
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 0.965
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphSquashX"
                            to: 1.0
                            duration: Math.round(root.collapseDur * 0.55)
                            easing: root.spatialEasingDecel
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: musicPill
                            property: "morphLift"
                            to: 6
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: musicPill
                            property: "morphLift"
                            to: 0
                            duration: Math.round(root.collapseDur * 0.55)
                            easing: root.spatialEasingDecel
                        }
                    }
                }
            }
        ]
    }

    // ── Tap outside to dismiss expanded sourceSelector dropdown ────────────────
    MouseArea {
        anchors.fill: parent
        z: 99
        enabled: sourceSelector.expanded
        onClicked: sourceSelector.expanded = false
    }

    // ── Floating Media Source Selector Overlay (Unclipped M3 Expressive, z:100) ──
    Item {
        id: sourceSelector
        z: 100
        x: musicPill.x + musicPill.width - sourceSelector.width - 16
        y: musicPill.y + 39
        width: sourcePillWidth
        height: 24
        opacity: (musicPill.state === "expanded" && trackInfo.opacity > 0.90 && !root.closingDown) ? 1 : 0
        visible: opacity > 0.01

        readonly property real sourcePillWidth: Math.max(64, currentSourceText.implicitWidth + 20)
        property bool expanded: false

        state: expanded ? "expanded" : "collapsed"

        states: [
            State {
                name: "collapsed"
                PropertyChanges { target: sourceSelector; width: sourcePillWidth; height: 24 }
                PropertyChanges { target: selectorRect; radius: 12 }
                PropertyChanges { target: collapsedPillView; opacity: 1 }
                PropertyChanges { target: expandedListView; opacity: 0 }
            },
            State {
                name: "expanded"
                PropertyChanges { target: sourceSelector; width: 190; height: Math.min(180, sourceList.implicitHeight + 20) }
                PropertyChanges { target: selectorRect; radius: 16 }
                PropertyChanges { target: collapsedPillView; opacity: 0 }
                PropertyChanges { target: expandedListView; opacity: 1 }
            }
        ]

        transitions: [
            Transition {
                from: "collapsed"
                to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [sourceSelector]
                        properties: "width,height"
                        duration: 300
                        easing: root.spatialEasing
                    }
                    NumberAnimation {
                        target: selectorRect
                        property: "radius"
                        duration: 240
                        easing: root.spatialEasing
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: collapsedPillView
                            property: "opacity"
                            to: 0
                            duration: 90
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: expandedListView
                            property: "opacity"
                            to: 1
                            duration: 180
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            },
            Transition {
                from: "expanded"
                to: "collapsed"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [sourceSelector]
                        properties: "width,height"
                        duration: 250
                        easing: root.spatialEasingDecel
                    }
                    NumberAnimation {
                        target: selectorRect
                        property: "radius"
                        duration: 200
                        easing: root.spatialEasingDecel
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: expandedListView
                            property: "opacity"
                            to: 0
                            duration: 90
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: collapsedPillView
                            property: "opacity"
                            to: 1
                            duration: 160
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        ]

        StyledRect {
            id: selectorRect
            anchors.fill: parent
            radius: 12
            color: Players.musicSurfaceColor
            border.width: 1
            border.color: Qt.alpha(Players.musicOnSurfaceColor, 0.16)
            clip: true

            layer.enabled: sourceSelector.expanded
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.40)
                shadowOpacity: 0.35
                shadowBlur: 0.60
                shadowVerticalOffset: 4
            }

            // Collapsed Content (Light Cyan Pill matching play button)
            Item {
                id: collapsedPillView
                anchors.fill: parent
                opacity: 1
                visible: opacity > 0.01

                StyledRect {
                    anchors.fill: parent
                    radius: 12
                    color: root.playButtonBg
                }

                StyledText {
                    id: currentSourceText
                    anchors.centerIn: parent
                    text: Players.active ? (Players.getIdentity(Players.active) || "Media") : "Media"
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Normal
                    color: root.playIconColor
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    id: sourceHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (Mpris.players.values.length > 0)
                            sourceSelector.expanded = !sourceSelector.expanded;
                    }
                }
            }

            // Expanded Content (Source List Dropdown view on dark surface)
            Item {
                id: expandedListView
                anchors.fill: parent
                opacity: 0
                visible: opacity > 0.01

                Flickable {
                    anchors.fill: parent
                    contentHeight: sourceList.implicitHeight + 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sourceList
                        width: parent.width - 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        spacing: 4

                        StyledText {
                            text: qsTr("MEDIA SOURCE")
                            textPointSize: Tokens.font.size.smaller - 2
                            font.weight: Font.Medium
                            color: Qt.alpha(Players.musicOnSurfaceColor, 0.48)
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.topMargin: 2
                        }

                        Repeater {
                            model: Players.list

                            delegate: Rectangle {
                                id: sourceItem
                                required property var modelData
                                width: sourceList.width
                                height: 30
                                radius: 10
                                color: sourceItem.isActive ? root.playButtonBg : (itemHover.containsMouse ? Qt.alpha(Players.musicOnSurfaceColor, 0.12) : "transparent")

                                readonly property bool isActive: Players.active === modelData

                                Behavior on color {
                                    CAnim { duration: Tokens.anim.durations.expressiveFastEffects }
                                }

                                MouseArea {
                                    id: itemHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Players.manualActive = sourceItem.modelData;
                                        sourceSelector.expanded = false;
                                    }
                                }

                                StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: Text.AlignVCenter
                                    text: Players.getIdentity(sourceItem.modelData) || "Media App"
                                    textPointSize: Tokens.font.size.smaller
                                    font.weight: sourceItem.isActive ? Font.Medium : Font.Normal
                                    color: sourceItem.isActive ? root.playIconColor : Players.musicOnSurfaceColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSurface
        property real textPointSize: Tokens.font.size.normal
        property alias font: primaryLabel.font
        property bool running: true

        height: primaryLabel.implicitHeight
        clip: true

        readonly property real speed: 28
        readonly property bool needsMarquee: width > 0 && primaryLabel.implicitWidth > width + 1

        layer.enabled: needsMarquee
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: marqueeRoot.width
                    height: marqueeRoot.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.08
                            color: "black"
                        }
                        GradientStop {
                            position: 0.9
                            color: "black"
                        }
                        GradientStop {
                            position: 1.0
                            color: "transparent"
                        }
                    }
                }
            }
        }

        Row {
            id: marqueeRow

            spacing: 34
            property real scrollX: 0

            x: marqueeRoot.needsMarquee ? scrollX : 0
            height: parent.height

            StyledText {
                id: primaryLabel
                text: marqueeRoot.text
                color: marqueeRoot.color
                textPointSize: marqueeRoot.textPointSize
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideNone
            }

            StyledText {
                text: marqueeRoot.text
                color: marqueeRoot.color
                textPointSize: marqueeRoot.textPointSize
                font: primaryLabel.font
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                visible: marqueeRoot.needsMarquee
                elide: Text.ElideNone
            }
        }

        SequentialAnimation {
            id: marqueeAnim

            running: marqueeRoot.running && marqueeRoot.needsMarquee && marqueeRoot.visible && marqueeRoot.width > 0
            loops: Animation.Infinite

            PauseAnimation {
                duration: 1600
            }

            NumberAnimation {
                target: marqueeRow
                property: "scrollX"
                from: 0
                to: -(primaryLabel.implicitWidth + marqueeRow.spacing)
                duration: Math.max(3600, primaryLabel.implicitWidth * 1000 / marqueeRoot.speed)
                easing.type: Easing.Linear
            }

            PauseAnimation {
                duration: 900
            }

            PropertyAction {
                target: marqueeRow
                property: "scrollX"
                value: 0
            }
        }

        function restartMarquee(): void {
            marqueeAnim.stop();
            marqueeRow.scrollX = 0;
            if (needsMarquee && running)
                marqueeAnim.start();
        }

        onTextChanged: Qt.callLater(restartMarquee)
        onWidthChanged: Qt.callLater(restartMarquee)
        onNeedsMarqueeChanged: Qt.callLater(restartMarquee)
        onRunningChanged: Qt.callLater(restartMarquee)
    }
}

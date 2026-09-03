import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import M3Shapes
import Olvex.Components
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property var lock

    anchors.fill: parent

    readonly property bool hasActiveMedia: !!Players.active && Players.active.playbackStatus !== "Stopped"

    // ── Seek state — ported from MediaMorphOverlay's progress track ───────────
    property real seekPreview: -1
    readonly property real displayProgress: {
        const p = root.seekPreview >= 0 ? root.seekPreview : Players.interpolatedProgress;
        return p < 0.004 ? 0 : p;
    }
    readonly property real displayPosition: root.seekPreview >= 0 && Players.interpolatedLength > 0 ? root.seekPreview * Players.interpolatedLength : Players.interpolatedPosition
    readonly property bool canSeek: Players.active !== null && (Players.active.canSeek ?? false) && (Players.active.positionSupported ?? false)

    // ── Music-accent tokens ──────────────────────────────────────────────────
    readonly property color onSurfaceColor: Players.musicOnSurfaceColor
    readonly property color secondaryTextColor: Qt.alpha(Players.musicOnSurfaceColor, 0.45)
    readonly property color mutedIconColor: Qt.alpha(Players.musicOnSurfaceColor, 0.70)
    readonly property color timeTextColor: Qt.alpha(Players.musicOnSurfaceColor, 0.58)
    readonly property int artSize: 72

    // ── Background visualizer ownership ──────────────────────────────────────
    readonly property bool ownsVisualizer: VisualizerState.visibleOwner === "lockPill"
    readonly property real _screenHz: Screen.refreshRate > 0 ? Screen.refreshRate : 60
    readonly property int visualizerFrameInterval: Math.max(1, Math.round(1000 / root._screenHz))
    property bool visualizerLoaded: root.hasActiveMedia

    function syncVisualizerOwner() {
        VisualizerState.request("lockPill", 40, root.hasActiveMedia);
    }

    onHasActiveMediaChanged: {
        root.syncVisualizerOwner();
        if (root.hasActiveMedia) {
            visualizerUnloadTimer.stop();
            root.visualizerLoaded = true;
        } else if (root.visualizerLoaded) {
            visualizerUnloadTimer.restart();
        }
    }

    Component.onCompleted: root.syncVisualizerOwner()
    Component.onDestruction: VisualizerState.release("lockPill")

    Timer {
        id: visualizerUnloadTimer
        interval: 900
        repeat: false
        onTriggered: root.visualizerLoaded = false
    }

    function lengthStr(length) {
        if (length < 0) return "-1:-1";
        let l = length;
        if (l > 1000000) l /= 1000000;
        const hours = Math.floor(l / 3600);
        const mins = Math.floor((l % 3600) / 60);
        const secs = Math.floor(l % 60).toString().padStart(2, "0");
        if (hours > 0) return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    // ── M3 Surface Tonal Overlay (matches taskbar expanded media card) ────────
    Rectangle {
        anchors.fill: parent
        radius: 25
        antialiasing: true
        color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
    }

    // ── Ambient Glow (soft bloom behind the album art) ────────────────────────
    StyledClippingRect {
        id: glowClip
        anchors.fill: parent
        radius: 25
        color: "transparent"
        z: -2
        opacity: root.hasActiveMedia ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        readonly property point glowCenter: Qt.point(14 + root.artSize / 2, 12 + root.artSize / 2)

        Repeater {
            model: [
                { mult: 2.4,  dark: 1.5, alpha: 0.10, bmax: 36 },
                { mult: 1.6,  dark: 1.8, alpha: 0.16, bmax: 32 },
                { mult: 1.05, dark: 2.2, alpha: 0.28, bmax: 24 }
            ]
            delegate: Rectangle {
                id: glowLayer
                required property var modelData
                readonly property real d: root.artSize * modelData.mult
                width: d
                height: d
                radius: 16 * modelData.mult
                x: glowClip.glowCenter.x - d / 2
                y: glowClip.glowCenter.y - d / 2
                color: Qt.alpha(Qt.darker(Players.musicVisualizerAccent, modelData.dark), modelData.alpha)
                antialiasing: true
                layer.enabled: glowClip.opacity > 0.05 && (!root.lock || (root.lock.contentReady && !root.lock.unlocking))
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: glowLayer.modelData.bmax
                }
            }
        }
    }

    // ── Background Neon Wave Visualizer (anchored at bottom of card) ──────────
    Item {
        anchors.fill: parent
        z: -1
        visible: opacity > 0.01
        opacity: root.hasActiveMedia ? 1 : 0

        layer.enabled: visible
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: visualizerCardMask
        }

        Item {
            id: visualizerCardMask
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: 25
                color: "black"
                antialiasing: true
            }
        }

        Loader {
            anchors.fill: parent
            active: root.visualizerLoaded
            asynchronous: true
            sourceComponent: Component {
                NeonWaveVisualizer {
                    anchors.fill: parent
                    accentColor: Players.musicVisualizerAccent
                    numBands: 32
                    maxHeightRatio: 0.44
                    topFadeRatio: 0.28
                    valueMultiplier: 1.25
                    active: root.hasActiveMedia && root.ownsVisualizer && (!root.lock || (root.lock.contentReady && !root.lock.unlocking))
                    frameInterval: root.visualizerFrameInterval
                    externallyDriven: false
                }
            }
        }
    }

    // ── Main Card Content Layout ─────────────────────────────────────────────
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 12
        anchors.bottomMargin: 10
        spacing: 8

        // ── Upper Row: Album Art + (Typography & Transport) ──────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // Album Art Thumbnail
            Item {
                id: artFrame
                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize
                Layout.alignment: Qt.AlignVCenter

                StyledClippingRect {
                    id: artSurface
                    anchors.fill: parent
                    radius: 16
                    color: root.hasActiveMedia ? Qt.alpha(root.onSurfaceColor, 0.10) : Qt.alpha(Players.musicVisualizerAccent, 0.22)

                    FadeImage {
                        id: artImage
                        anchors.fill: parent
                        cache: false
                        source: root.hasActiveMedia ? Players.getArtUrl(Players.active) : ""
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: root.hasActiveMedia ? root.mutedIconColor : Players.musicOnAccent
                        iconPointSize: root.artSize * 0.4
                        visible: !root.hasActiveMedia || artImage.status !== Image.Ready
                    }
                }
            }

            // Text info & Control Buttons
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                // Track Title (Marquee)
                MarqueeText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active && Players.active.trackTitle ? Players.active.trackTitle : qsTr("Unknown Title")) : qsTr("No Active Media")
                    color: root.onSurfaceColor
                    textPointSize: 14.5
                    font.family: Tokens.font.family.sans
                    font.weight: 760
                    font.letterSpacing: 0.12
                    running: root.hasActiveMedia && (!root.lock || (root.lock.contentReady && !root.lock.unlocking))
                }

                // Track Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active && Players.active.trackArtist ? Players.active.trackArtist : qsTr("Unknown Artist")) : ""
                    color: root.secondaryTextColor
                    font.family: Tokens.font.family.sans
                    textPointSize: 11
                    font.weight: 500
                    font.letterSpacing: 0.08
                    elide: Text.ElideRight
                }

                // Transport Row (Matches taskbar expanded media card)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 12
                    visible: root.hasActiveMedia

                    MorphControlButton {
                        iconName: "skip_previous"
                        balancedSkipIcon: true
                        elevated: false
                        secondaryShape: MaterialShape.Circle
                        secondaryProgress: 1
                        width: 32
                        height: 32
                        iconSize: 16
                        onClicked: Players.previous()
                    }

                    MorphControlButton {
                        emphasized: true
                        elevated: true
                        iconName: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
                        width: 40
                        height: 40
                        iconSize: 22
                        onClicked: Players.togglePlaying()
                    }

                    MorphControlButton {
                        iconName: "skip_next"
                        balancedSkipIcon: true
                        elevated: false
                        secondaryShape: MaterialShape.Circle
                        secondaryProgress: 1
                        width: 32
                        height: 32
                        iconSize: 16
                        onClicked: Players.next()
                    }
                }
            }
        }

        // ── Lower Row: Progress / Seekbar (M3 Expressive) ────────────────────
        Item {
            id: progressWrap
            Layout.fillWidth: true
            implicitHeight: 20
            visible: root.hasActiveMedia

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
                text: root.lengthStr(Players.interpolatedLength > 0 ? Players.interpolatedLength : -1)
                color: root.timeTextColor
                font.pixelSize: 11
                font.family: Tokens.font.family.mono
                font.weight: Font.Medium
            }

            Item {
                id: progressTrackRow
                anchors.left: timeElapsed.right
                anchors.right: timeTotal.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 20

                // M3 Expressive seekbar tokens
                readonly property bool isPressed: dragging || hoverArea.pressed
                readonly property real activeThickness: isPressed ? 2.5 : 3.5
                readonly property real inactiveThickness: isPressed ? 2.5 : 3.5
                readonly property real waveHeight: 14 // 1 full wave visual height (3.5 * 1.5 * 2 + 3.5)
                readonly property real thumbW: isPressed ? 2.5 : 4
                readonly property real thumbH: waveHeight
                readonly property real gap: 5
                readonly property bool isPlaying: Players.active ? Players.active.isPlaying : false
                readonly property color activeColor: Players.musicPlayButtonBg
                property bool dragging: false

                readonly property real fillW: Math.max(0, Math.min(width, width * root.displayProgress))
                readonly property real thumbX: fillW
                readonly property bool waveActive: root.seekPreview < 0 && progressTrackRow.isPlaying

                // ── Active indicator: thick wavy line ───────────────────────
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
                    value: progressTrackRow.width > 0 ? Math.max(0, (progressTrackRow.fillW - progressTrackRow.gap) / progressTrackRow.width) : 0

                    amplitudeMultiplier: progressTrackRow.waveActive ? 1.5 : 0

                    Behavior on lineWidth {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

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

                    NumberAnimation on waveProgress {
                        running: waveIndicator.amplitudeMultiplier > 0.001 && (!root.lock || (root.lock.contentReady && !root.lock.unlocking))
                        from: 0
                        to: 1
                        duration: 1400
                        easing.type: Easing.Linear
                        loops: Animation.Infinite
                    }
                }

                // ── Active flat fill — shown when paused / seeking ──────────
                Rectangle {
                    z: 2
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, progressTrackRow.fillW - progressTrackRow.gap)
                    height: progressTrackRow.activeThickness
                    radius: height / 2
                    color: progressTrackRow.activeColor
                    visible: waveIndicator.amplitudeMultiplier <= 0.001

                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on width {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                // ── Inactive (remaining) track ──────────────────────────────
                Rectangle {
                    z: 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(progressTrackRow.thumbX + progressTrackRow.gap)
                    width: Math.max(0, progressTrackRow.width - x)
                    height: progressTrackRow.inactiveThickness
                    radius: height / 2
                    color: Qt.alpha(root.onSurfaceColor, 0.18)
                    visible: width > 0

                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on x {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                // ── Stop Indicator at terminus ──────────────────────────────
                Rectangle {
                    z: 5
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: Qt.alpha(root.onSurfaceColor, 0.28)
                    visible: (progressTrackRow.width - progressTrackRow.fillW) > progressTrackRow.gap * 2
                }

                // ── M3 Vertical Bar Handle ──────────────────────────────────
                Rectangle {
                    id: seekThumb
                    z: 20
                    visible: root.canSeek
                    x: Math.round(progressTrackRow.thumbX - width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: progressTrackRow.thumbW
                    height: progressTrackRow.thumbH
                    radius: width / 2
                    color: progressTrackRow.activeColor
                    antialiasing: true

                    Behavior on x {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                // ── Seek mouse interaction ──────────────────────────────────
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    hoverEnabled: true
                    enabled: root.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    preventStealing: true
                    z: 25

                    function fractionAt(mouseX) {
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

    // ── Marquee title helper ─────────────────────────────────────────────────
    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSurface
        property real textPointSize: Tokens.font.size.normal
        property alias font: primaryLabel.font
        property bool running: true

        height: primaryLabel.implicitHeight
        clip: true

        readonly property real speed: 26
        readonly property real overflow: Math.max(0, primaryLabel.implicitWidth - width)
        readonly property bool needsMarquee: width > 0 && overflow > 1
        property real scroll: 0

        layer.enabled: needsMarquee
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: marqueeRoot.width
                    height: marqueeRoot.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.05; color: "black" }
                        GradientStop { position: 0.95; color: "black" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        StyledText {
            id: primaryLabel
            text: marqueeRoot.text
            color: marqueeRoot.color
            textPointSize: marqueeRoot.textPointSize
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            x: marqueeRoot.needsMarquee ? marqueeRoot.scroll : 0
        }

        SequentialAnimation {
            id: marqueeAnim
            loops: Animation.Infinite

            PauseAnimation { duration: 2000 }
            NumberAnimation {
                target: marqueeRoot
                property: "scroll"
                from: 0
                to: -marqueeRoot.overflow
                duration: Math.max(1400, marqueeRoot.overflow * 1000 / marqueeRoot.speed)
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 2000 }
            NumberAnimation {
                target: marqueeRoot
                property: "scroll"
                from: -marqueeRoot.overflow
                to: 0
                duration: Math.max(1400, marqueeRoot.overflow * 1000 / marqueeRoot.speed)
                easing.type: Easing.InOutQuad
            }
        }

        function restartMarquee() {
            marqueeAnim.stop();
            marqueeRoot.scroll = 0;
            if (needsMarquee && running && visible && width > 0)
                marqueeAnim.start();
        }

        onTextChanged: Qt.callLater(restartMarquee)
        onWidthChanged: Qt.callLater(restartMarquee)
        onNeedsMarqueeChanged: Qt.callLater(restartMarquee)
        onRunningChanged: Qt.callLater(restartMarquee)
        Component.onCompleted: Qt.callLater(restartMarquee)
    }
}

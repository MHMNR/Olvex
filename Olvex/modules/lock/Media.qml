
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

    anchors.left: parent.left
    anchors.right: parent.right
    // Direct px, not Tokens.* — tweak these two numbers to change the
    // card's total height directly (this is top+bottom padding × 2).
    readonly property int cardVPadding: 10
    implicitHeight: layout.implicitHeight + root.cardVPadding * 2

    readonly property bool hasActiveMedia: !!Players.active && Players.active.playbackStatus !== "Stopped"

    // ── Seek state — ported from MediaMorphOverlay's progress track so
    // dragging previews the seek position before committing on release.
    property real seekPreview: -1
    readonly property real displayProgress: {
        const p = root.seekPreview >= 0 ? root.seekPreview : Players.interpolatedProgress;
        return p < 0.004 ? 0 : p;
    }
    readonly property real displayPosition: root.seekPreview >= 0 && Players.interpolatedLength > 0 ? root.seekPreview * Players.interpolatedLength : Players.interpolatedPosition
    readonly property bool canSeek: Players.active !== null && (Players.active.canSeek ?? false) && (Players.active.positionSupported ?? false)

    // ── Music-accent tokens ──────────────────────────────────────────────
    // The card background is Players.musicSurfaceColor (album-art driven, set
    // by the LockCard.bgColor override in Content.qml) — these keep every
    // foreground element paired to that same accent instead of the generic
    // wallpaper-theme tokens, so contrast holds regardless of the art's hue.
    readonly property color onSurfaceColor: Players.musicOnSurfaceColor
    readonly property color secondaryTextColor: Qt.alpha(Players.musicOnSurfaceColor, 0.42)
    readonly property color mutedIconColor: Qt.alpha(Players.musicOnSurfaceColor, 0.7)
    readonly property color timeTextColor: Qt.alpha(Players.musicOnSurfaceColor, 0.58)
    readonly property int artSize: 80

    // ── Background visualizer — ported from the taskbar's expanded media
    // card (MediaMorphOverlay.qml), same ownership arbitration as the
    // minimal lock screen's pill ("lockPill", priority 40 — the two lock
    // styles are mutually exclusive so reusing this owner name is safe).
    // externallyDriven:false + a throttled frameInterval are the exact fix
    // that stopped this component from re-pinning the window to the
    // display's full refresh rate earlier this session — reused verbatim.
    readonly property bool ownsVisualizer: VisualizerState.visibleOwner === "lockPill"
    // Experiment: match the monitor's native refresh rate instead of a fixed
    // 30fps cap, now that the play-button spin/wavy-line pinning is removed.
    readonly property real _screenHz: Screen.refreshRate > 0 ? Screen.refreshRate : 60
    readonly property int visualizerFrameInterval: Math.max(1, Math.round(1000 / root._screenHz))
    property bool visualizerLoaded: root.hasActiveMedia

    function syncVisualizerOwner(): void {
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

    // ── Ambient glow — a soft, thumbnail-shaped light bloom behind the art.
    // Three overlapping rounded-square discs (wide faint halo → body → hot
    // core lifted toward white, since bright light overwhelms hue at its
    // source) are each individually blurred into smooth domes, then clipped
    // to the card's rounded shape by this StyledClippingRect — a reliable
    // stencil clip. (A MultiEffect mask was tried but rendered a hard SQUARE
    // corner at the top-left; a per-disc blur inside a real rounded clip
    // doesn't.) Each disc owns its blur, so its texture is sized to itself
    // and never corner-clips. Static — re-rendered only on colour/size
    // change, so zero per-frame cost.
    StyledClippingRect {
        id: glowClip
        anchors.fill: parent
        radius: 25 // card rounding (Tokens.rounding.large)
        color: "transparent"
        z: -2
        opacity: root.hasActiveMedia ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        // artFrame is nested in the RowLayout — map its centre into this space.
        readonly property point glowCenter: artFrame.mapToItem(glowClip, artFrame.width / 2, artFrame.height / 2)

        Repeater {
            // widest/faintest first (drawn behind) → hot core last (on top)
            model: [
                { mult: 2.4,  dark: 1.5, alpha: 0.10, bmax: 56 }, // halo
                { mult: 1.6,  dark: 1.8, alpha: 0.16, bmax: 44 }, // body
                { mult: 1.05, dark: 2.2, alpha: 0.28, bmax: 30 }  // dark core
            ]
            delegate: Rectangle {
                id: glowLayer
                required property var modelData
                readonly property real d: root.artSize * modelData.mult
                width: d
                height: d
                // Shape the source like the album tile (a rounded square,
                // art radius 17) scaled up — not a circle — so the bloom
                // echoes the thumbnail's silhouette.
                radius: 17 * modelData.mult
                x: glowClip.glowCenter.x - d / 2
                y: glowClip.glowCenter.y - d / 2
                color: Qt.alpha(Qt.darker(Players.musicVisualizerAccent, modelData.dark), modelData.alpha)
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

    // ── Background visualizer — ported from the taskbar's expanded media
    // card. Sits behind everything else (z: -1), clipped to the card's own
    // rounding. Tuned down (lower maxHeightRatio, deeper top fade) versus the
    // taskbar's version since this card's content stack is denser.

    StyledClippingRect {
        anchors.fill: parent
        radius: 25 // matches the outer LockCard's rounding (Content.qml)
        color: "transparent"
        z: -1

        Loader {
            anchors.fill: parent
            active: root.visualizerLoaded
            asynchronous: true
            sourceComponent: Component {
                Item {
                    NeonWaveVisualizer {
                        anchors.fill: parent
                        accentColor: Players.musicVisualizerAccent
                        numBands: 32
                        maxHeightRatio: 0.38
                        topFadeRatio: 0.24
                        valueMultiplier: 1.25
                        active: root.hasActiveMedia && root.ownsVisualizer
                        frameInterval: root.visualizerFrameInterval
                        externallyDriven: false
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 10 // left/right margin (see root.cardVPadding above for top/bottom)
        spacing: 12 // gap between the art/info row and the progress row

        // ── Art & Info Row (M3 Expressive) ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 20 // gap between the art frame and the text/controls column

            // Hand-built art frame — deliberately NOT the shared CoverArt
            // component, which hardcodes a MaterialShape.Cookie12Sided clip
            // mask meant for circular avatar photos. That scallops a
            // rectangular, text-heavy album cover awkwardly. Every other
            // music surface in Olvex (bar pill, desktop overlay) masks art to
            // a plain rounded rect instead, so this mirrors that.
            Item {
                id: artFrame
                implicitWidth: root.artSize
                implicitHeight: root.artSize
                // Top-aligned, not centered — the row is taller than the art
                // (the text/controls column next to it is taller than 80px),
                // so centering pushed the art down and left its top gap
                // bigger than the side gap. Top-aligning makes the gap above
                // the art equal to the card's top padding, matching the side
                // margin.
                Layout.alignment: Qt.AlignTop

                StyledClippingRect {
                    id: artSurface
                    anchors.fill: parent
                    radius: 17
                    // Accent-tinted when there's no art to cover it (matches
                    // the taskbar card) instead of a flat gray placeholder —
                    // keeps the "tinted by the album" feel even with no cover.
                    color: root.hasActiveMedia ? Qt.alpha(root.onSurfaceColor, 0.10) : Qt.alpha(Players.musicVisualizerAccent, 0.22)

                    FadeImage {
                        id: artImage
                        anchors.fill: parent
                        source: root.hasActiveMedia ? Players.getArtUrl(Players.active) : ""
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        // Contrasting on-accent color over the tinted fallback
                        // bg; muted gray only while a real cover is loading.
                        color: root.hasActiveMedia ? root.mutedIconColor : Players.musicOnAccent
                        iconPointSize: root.artSize * 0.4
                        visible: !root.hasActiveMedia || artImage.status !== Image.Ready
                    }
                }
            }

            // Typography & Controls Stack
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 7 // gap between title and artist lines

                // Emphasized Typography — MarqueeText (ported from the
                // taskbar's expanded card) instead of a plain elided
                // StyledText: tuned weight/letter-spacing read as more
                // "designed" than a flat 800-weight cutoff, and long titles
                // scroll instead of just truncating with "...".
                MarqueeText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active?.trackTitle || "No media") : "No Active Media"
                    color: root.onSurfaceColor
                    textPointSize: 15
                    font.family: Tokens.font.family.sans
                    font.weight: 760
                    font.letterSpacing: 0.12
                    running: root.hasActiveMedia
                }
                
                StyledText {
                    Layout.fillWidth: true
                    text: root.hasActiveMedia ? (Players.active?.trackArtist || "") : ""
                    color: root.secondaryTextColor
                    font.family: Tokens.font.family.sans
                    textPointSize: 11
                    font.weight: 500
                    elide: Text.ElideRight
                }

                // Controls Row embedded next to text for compactness
                RowLayout {
                    Layout.topMargin: 2 // gap above the transport buttons — reduced to pull buttons up
                    spacing: 14 // gap between prev/play/next buttons
                    visible: root.hasActiveMedia

                    // Transport — the shared control button from the taskbar's
                    // music pill/card (identical morphing pill/circle shape,
                    // press physics, and spinning emphasized play button), so
                    // the lock card matches that design exactly rather than
                    // approximating it with generic IconButtons. Explicit
                    // sizes give a clear primary (play) vs secondary
                    // (prev/next) hierarchy — edit these numbers directly.
                    MorphControlButton {
                        iconName: "skip_previous"
                        balancedSkipIcon: true
                        elevated: true
                        secondaryShape: MaterialShape.Circle
                        secondaryProgress: 1
                        width: 32
                        height: 32
                        onClicked: Players.previous()
                    }

                    MorphControlButton {
                        emphasized: true
                        iconName: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
                        width: 40
                        height: 40
                        iconSize: 20
                        onClicked: Players.togglePlaying()
                    }

                    MorphControlButton {
                        iconName: "skip_next"
                        balancedSkipIcon: true
                        elevated: true
                        secondaryShape: MaterialShape.Circle
                        secondaryProgress: 1
                        width: 32
                        height: 32
                        onClicked: Players.next()
                    }
                }
            }
        }

        // ── Progress Bar — ported from MediaMorphOverlay's expanded seek
        // track (wavy-while-playing indicator, draggable stadium thumb),
        // adapted from its absolute-positioned card into this Layout-based
        // row. No "expanded state" gating needed — this card has no
        // compact/collapsed form, it's always fully shown.
        Item {
            id: progressWrap
            Layout.fillWidth: true
            implicitHeight: 28
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
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 28

                // M3 Expressive seekbar tokens
                readonly property real activeThickness: 4
                readonly property real inactiveThickness: 4
                readonly property real thumbW: dragging || hoverArea.containsMouse ? 7 : 4
                readonly property real thumbH: dragging || hoverArea.containsMouse ? 24 : 16
                readonly property real gap: 6 // thumb ↔ track gap
                readonly property bool isPlaying: Players.active?.isPlaying ?? false
                readonly property color activeColor: Players.musicPlayButtonBg
                property bool dragging: false

                readonly property real fillW: Math.max(0, Math.min(width, width * root.displayProgress))
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
                    // Draw wave only up to fill, leaving gap before thumb
                    value: progressTrackRow.width > 0 ? Math.max(0, (progressTrackRow.fillW - progressTrackRow.gap) / progressTrackRow.width) : 0

                    // Playing → wavy; seeking or paused → flat (rect below takes over)
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
                        // Gate on actually being visible/animating — this card
                        // only exists while its lock content is loaded (no
                        // hidden-behind-lock case to guard against, unlike the
                        // desktop overlay which stays resident in the drawers
                        // window), so amplitude alone is the right gate here.
                        running: waveIndicator.amplitudeMultiplier > 0 && LockState.locked
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
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(progressTrackRow.activeColor, 0.72) }
                        GradientStop { position: 1.0; color: progressTrackRow.activeColor }
                    }
                    visible: waveIndicator.amplitudeMultiplier <= 0.001
                    Behavior on width {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                // ── Inactive (remaining) track — from thumb gap to right edge ──
                Rectangle {
                    z: 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: progressTrackRow.thumbX + progressTrackRow.gap
                    width: Math.max(0, progressTrackRow.width - x)
                    height: progressTrackRow.inactiveThickness
                    radius: height / 2
                    color: Qt.alpha(root.onSurfaceColor, 0.22)
                    visible: width > 0

                    Behavior on x {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                // ── Stadium thumb — grows on press (M3 Expressive) ─────────────
                Rectangle {
                    id: seekThumb
                    z: 20
                    visible: root.canSeek
                    x: progressTrackRow.thumbX - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: progressTrackRow.thumbW
                    height: progressTrackRow.thumbH
                    radius: width / 2
                    color: progressTrackRow.activeColor
                    border.width: 1
                    border.color: Qt.alpha(root.onSurfaceColor, 0.26)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.alpha(progressTrackRow.activeColor, 0.58)
                        shadowOpacity: (visible && (progressTrackRow.dragging || hoverArea.containsMouse)) ? 0.46 : 0
                        shadowBlur: 0.7
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        Behavior on shadowOpacity { NumberAnimation { duration: 150 } }
                    }

                    Behavior on x {
                        enabled: !progressTrackRow.dragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        SpringAnimation { spring: 5.0; damping: 0.7; epsilon: 0.01 }
                    }
                    Behavior on height {
                        SpringAnimation { spring: 5.0; damping: 0.7; epsilon: 0.01 }
                    }
                }

                // ── Seek interaction ───────────────────────────────────────
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    hoverEnabled: true
                    enabled: root.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    preventStealing: true
                    z: 10

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

    // ── Marquee title — single-copy bounce. The taskbar's version draws
    // TWO copies of the text and scrolls continuously, which means the clip
    // window straddles the seam between copy-1's tail and copy-2's head at
    // rest — reading as glitched/garbled text on a static glance (e.g.
    // "…nium UI    Live TV P…"). A single label that slides to reveal the
    // end, pauses, then slides back never shows two fragments, so it always
    // looks intentional whether moving or still.
    component MarqueeText: Item {
        id: marqueeRoot

        required property string text
        property color color: Colours.palette.m3onSurface
        property real textPointSize: Tokens.font.size.normal
        property alias font: primaryLabel.font
        property bool running: true

        height: primaryLabel.implicitHeight
        clip: true

        readonly property real speed: 26 // px/sec
        readonly property real overflow: Math.max(0, primaryLabel.implicitWidth - width)
        readonly property bool needsMarquee: width > 0 && overflow > 1
        property real scroll: 0

        // Soft edge fade so the text melts in/out at the clip bounds instead
        // of hard-cutting mid-glyph (only while it actually scrolls).
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

        // Rest at start → ease to the end → rest → ease back. Idle entirely
        // for titles that fit (needsMarquee false).
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

        function restartMarquee(): void {
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

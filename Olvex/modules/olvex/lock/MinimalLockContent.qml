pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import M3Shapes
import Olvex.Components
import Olvex.Config
import "../../lock"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    anchors.fill: parent

    // Dismissal Layer (Collapses expanded pills on background tap)
    MouseArea {
        anchors.fill: parent
        enabled: musicPill.expanded || (typeof notifPill !== 'undefined' && notifPill.expanded)
        onClicked: {
            musicPill.expanded = false
            if (typeof notifPill !== 'undefined') notifPill.expanded = false
        }
    }

    required property var lock
    required property var pam
    required property var screen

    readonly property string userName: Paths.home.split("/").pop()
    // Settings → Lock → Element opacity (minimal style chrome only)
    readonly property real elementOpacity: {
        const v = GlobalConfig.lock.minimalOpacity;
        if (v === undefined || v === null || Number.isNaN(v))
            return 1;
        return Math.max(0.05, Math.min(1, v));
    }

    function formatSpeed(bps: real): string {
        if (bps <= 0) return "0 B/s";
        const mbs = bps / (1024 * 1024);
        if (mbs >= 1) return mbs.toFixed(1) + " MB/s";
        const kbs = bps / 1024;
        if (kbs >= 1) return kbs.toFixed(1) + " KB/s";
        return bps.toFixed(0) + " B/s";
    }

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        if (root.lock.contentReady) {
            entranceAnim.start();
        }
    }
    onActiveFocusChanged: {
        if (!activeFocus && !root.lock.unlocking)
            forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (root.lock.unlocking) return;
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
            inputField.placeholder.animate = false;
        root.pam.handleKey(event);
    }

    // ── Chain-reaction stagger controller ────────────────────────────────────
    readonly property int stagger: 70    // ms between each component
    readonly property int dur: 850        // slide duration
    readonly property int exitDur: 650   // exit duration
    // Full screen dimensions, not fixed px — a fixed 500/200px offset wasn't
    // always enough to fully clear wide/tall screens, so the slide looked
    // like it "stuck" once the animation reached its end value while the
    // element was still partly on-screen.
    readonly property int offset: root.screen ? root.screen.width : 500    // off-screen start for horizontal
    readonly property int vOffset: root.screen ? root.screen.height : 200  // off-screen start for vertical

    Connections {
        target: root.lock
        function onContentReadyChanged(): void {
            if (root.lock.contentReady) entranceAnim.start()
        }
        function onUnlockingChanged(): void {
            if (root.lock.unlocking) {
                entranceAnim.stop()
                exitAnim.start()
            } else {
                exitAnim.stop()
                // reset for next cycle
                clockTrans.x = 0
                authTrans.x = 0
                topBarTrans.y = 0
                bottomBarTrans.y = 0
            }
        }
    }

    // ── ENTER: chain reaction, staggered entrance ────────────────────────────
    ParallelAnimation {
        id: entranceAnim

        // Top bar slides down first
        SequentialAnimation {
            NumberAnimation { target: topBarTrans; property: "y"; from: -root.vOffset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }

        // Clock slides from left (staggered by 60ms)
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: clockTrans; property: "x"; from: -root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }

        // Auth card slides from right (staggered by 120ms)
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: authTrans; property: "x"; from: root.offset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }

        // Power dock slides from bottom (staggered by 180ms)
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: bottomBarTrans; property: "y"; from: root.vOffset; to: 0; duration: root.dur; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
    }

    // ── EXIT: reverse chain reaction on unlock ────────────────────────────────
    ParallelAnimation {
        id: exitAnim

        // Top bar slides up
        SequentialAnimation {
            NumberAnimation { target: topBarTrans; property: "y"; to: -root.vOffset; duration: root.exitDur; easing.type: Easing.InExpo }
        }

        // Clock slides left
        SequentialAnimation {
            PauseAnimation { duration: 50 }
            NumberAnimation { target: clockTrans; property: "x"; to: -root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }

        // Auth card slides right
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: authTrans; property: "x"; to: root.offset; duration: root.exitDur; easing.type: Easing.InExpo }
        }

        // Power dock slides down
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: bottomBarTrans; property: "y"; to: root.vOffset; duration: root.exitDur; easing.type: Easing.InExpo }
        }
    }

    // ── TOP STATS BAR ──────────────────────────────────────────────────────────
    Item {
        id: topBar

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 32

        implicitWidth: topBarRow.implicitWidth
        implicitHeight: 48
        clip: false
        opacity: root.elementOpacity
        transform: Translate { id: topBarTrans; y: -root.vOffset }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Row {
            id: topBarRow
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // ── Music Pill (left) — proper container-transform, unrolled horizontal ──
            // Container-transform layering (see container-transform skill):
            //   Layer 1: pill width/height/radius = the morphing "container" bounds
            //   Shared element: artFrame — ONE Image, decode size fixed at the max
            //     (expanded) art size always, so it's never re-decoded mid-resize
            //     (that re-decode is what causes the taskbar pill/card morph's own
            //     blink — see the matching fix in MediaMorphOverlay.qml)
            //   Layer 3: trackInfo/controls — absolutely positioned (not row-flowed,
            //     so they can't vanish from a layout-reflow edge case), fade in on a
            //     short delay decoupled from the (slower) bounds animation
            Item {
                id: musicPill
                z: 10
                anchors.top: parent.top
                anchors.topMargin: 0

                property bool expanded: false
                property real pillScale: 1.0
                property bool visualizerLoaded: musicPill.isPlaying
                readonly property bool isPlaying: Players.active !== null && Players.activeIsPlaying

                // True for the duration of the expand/collapse morph. The visualizer
                // Canvas is Timer-driven independently of this animation, but it still
                // lives inside pillSurface (a StyledClippingRect) whose own bounds are
                // ALSO animating for these 400ms — Quickshell's clip is a layered/
                // textured mask, so any change to it forces the whole clipped subtree
                // to recomposite every frame. Stacking the visualizer's own repaints on
                // top of that (only while a track is playing) is what caused the
                // intermittent stutter — matching the bar pill's own fix
                // (mediaVisualizerActive excludes mediaMorphRendering in
                // ActiveWindow.qml), pause the visualizer for just the morph window.
                property bool morphing: false

                onExpandedChanged: {
                    musicPill.morphing = true;
                    morphSettleTimer.restart();
                }

                Timer {
                    id: morphSettleTimer
                    interval: musicPill.boundsDur
                    repeat: false
                    onTriggered: musicPill.morphing = false
                }
                // Participate in VisualizerState arbitration like the bar/overlay do,
                // so only ONE visualizer ever runs. The lock content only exists while
                // locked, so requesting the top priority (above overlay=30/bar=20/
                // background=10) can't interfere with normal unlocked operation — it
                // just guarantees the on-screen lock pill wins and the now-covered bar
                // and desktop-background visualizers go idle underneath.
                readonly property bool ownsVisualizer: VisualizerState.visibleOwner === "lockPill"
                // Experiment: match the monitor's native refresh rate instead of a
                // fixed 30fps cap, now that the play-button spin/wavy-line pinning
                // is removed.
                readonly property real _screenHz: Screen.refreshRate > 0 ? Screen.refreshRate : 60
                readonly property int visualizerFrameInterval: Math.max(1, Math.round(1000 / musicPill._screenHz))

                // M3 emphasized spatial spline — see olvex-m3-expressive skill §2
                readonly property var spatialEasing: [0.2, 0.0, 0.0, 1.0, 1, 1]
                readonly property int boundsDur: 400

                readonly property int compactW: 168
                readonly property int compactH: 48
                readonly property int expandedW: 360
                // +24px over the old 96 to fit the progress row below the buttons.
                readonly property int expandedH: 120
                readonly property int compactArt: 34
                readonly property int expandedArt: 64

                // ── Seek state — ported from Media.qml's progress track so
                // dragging previews the seek position before committing on release.
                property real seekPreview: -1
                readonly property real displayProgress: {
                    const p = musicPill.seekPreview >= 0 ? musicPill.seekPreview : Players.interpolatedProgress;
                    return p < 0.004 ? 0 : p;
                }
                readonly property real displayPosition: musicPill.seekPreview >= 0 && Players.interpolatedLength > 0 ? musicPill.seekPreview * Players.interpolatedLength : Players.interpolatedPosition
                readonly property bool canSeek: Players.active !== null && (Players.active.canSeek ?? false) && (Players.active.positionSupported ?? false)

                function lengthStr(length) {
                    if (length < 0)
                        return "-1:-1";
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

                width: musicPill.compactW
                height: musicPill.compactH

                transform: Scale {
                    origin.x: musicPill.width / 2
                    origin.y: musicPill.height / 2
                    xScale: musicPill.pillScale
                    yScale: musicPill.pillScale
                }

                // ── Ported from the taskbar's pill↔card morph (MediaMorphOverlay.qml
                // musicIcon/musicPill states+transitions): container bounds, shape
                // mask, and the shared-element art all animate as explicit per-state
                // target values grouped into ONE synchronized NumberAnimation each,
                // instead of live derived formulas + separate per-property Behaviors.
                // The old artFrame.y was `(musicPill.height - height)/2 - offset` — a
                // value computed from TWO other independently-animating properties,
                // which doesn't trace a clean eased path (a composed curve, not a
                // single interpolation) and is why the thumbnail didn't morph
                // smoothly. Fixed target coordinates + a shared animation group fix
                // that, matching the taskbar's approach exactly.
                state: musicPill.expanded ? "expanded" : "compact"
                states: [
                    State {
                        name: "compact"
                        PropertyChanges { target: musicPill; width: musicPill.compactW; height: musicPill.compactH }
                        PropertyChanges { target: pillSurface; radius: 24 }
                        PropertyChanges { target: artFrame; x: 8; y: 7; width: musicPill.compactArt; height: musicPill.compactArt }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges { target: musicPill; width: musicPill.expandedW; height: musicPill.expandedH }
                        PropertyChanges { target: pillSurface; radius: 28 }
                        // y:16 = old formula's steady-state result — (120-64)/2 - 12 —
                        // kept identical so the approved thumbnail position doesn't move.
                        PropertyChanges { target: artFrame; x: 20; y: 16; width: musicPill.expandedArt; height: musicPill.expandedArt }
                    }
                ]
                transitions: [
                    Transition {
                        from: "*"; to: "*"
                        ParallelAnimation {
                            // Container bounds — full duration (Layer 1)
                            NumberAnimation {
                                targets: [musicPill]
                                properties: "width,height"
                                duration: musicPill.boundsDur
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: musicPill.spatialEasing
                            }
                            // Shape mask completes at 75% (container-transform
                            // shapeMaskProgressThresholds ≈ 0→0.75), same as before.
                            NumberAnimation {
                                targets: [pillSurface]
                                properties: "radius"
                                duration: Math.round(musicPill.boundsDur * 0.75)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: musicPill.spatialEasing
                            }
                            // Shared element (art) — grouped x/y/width/height in one
                            // animation, guaranteeing frame-perfect sync between them.
                            NumberAnimation {
                                targets: [artFrame]
                                properties: "x,y,width,height"
                                duration: musicPill.boundsDur
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: musicPill.spatialEasing
                            }
                        }
                    }
                ]

                function syncVisualizerOwner(): void {
                    VisualizerState.request("lockPill", 40, musicPill.isPlaying);
                }

                onIsPlayingChanged: {
                    musicPill.syncVisualizerOwner();
                    if (musicPill.isPlaying) {
                        visualizerUnloadTimer.stop();
                        musicPill.visualizerLoaded = true;
                    } else if (musicPill.visualizerLoaded) {
                        visualizerUnloadTimer.restart();
                    }
                }

                Component.onCompleted: musicPill.syncVisualizerOwner()
                Component.onDestruction: VisualizerState.release("lockPill")

                Timer {
                    id: visualizerUnloadTimer
                    interval: 900
                    repeat: false
                    onTriggered: musicPill.visualizerLoaded = false
                }

                SequentialAnimation {
                    id: pillPressSpring
                    NumberAnimation { target: musicPill; property: "pillScale"; to: 0.94; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: musicPill; property: "pillScale"; to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                // ── Pill clip + background + visualizer ONLY. Kept minimal on
                // purpose: Quickshell's ClippingRectangle (StyledClippingRect) clips
                // via a layered/textured mask, so anything animating inside it forces
                // the WHOLE clipped subtree to re-render every frame. With the
                // continuously-updating visualizer previously sharing this container
                // with the art's drop-shadow and the buttons, every visualizer frame
                // was also repainting all of that static content — that's the
                // playback-time lag. Art/track-info/buttons now live as plain
                // siblings below (outside this clip), so the scene graph can cache
                // them independently instead of getting dragged along every frame.
                StyledClippingRect {
                    id: pillSurface
                    anchors.fill: parent
                    radius: 24 // animated via musicPill's states/transitions above
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        color: Players.musicSurfaceColor

                        Rectangle {
                            anchors.fill: parent
                            radius: musicPill.expanded ? 28 : 24
                            color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
                        }
                    }

                    // Ambient glow — a soft, circular light bloom behind the
                    // art (this pill's thumbnail is a circle, so the glow is
                    // too). Three overlapping discs (wide faint halo → body →
                    // hot core lifted toward white, since bright light
                    // overwhelms hue at its source) are each individually
                    // blurred into smooth domes, drawn directly inside
                    // pillSurface — which is itself a StyledClippingRect, so
                    // its reliable stencil clip already trims the glow to the
                    // pill's rounded shape (no separate mask needed; a
                    // MultiEffect mask rendered a hard square corner). Each
                    // disc owns its blur so its texture never corner-clips.
                    // Static, no per-frame cost.
                    Item {
                        anchors.fill: parent
                        // Present whenever a player is loaded — not gated on
                        // isPlaying, so it doesn't disappear on pause.
                        opacity: Players.active !== null ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        Repeater {
                            // widest/faintest first (behind) → hot core last (top)
                            model: [
                                { mult: 2.4,  dark: 1.5, alpha: 0.10, bmax: 56 }, // halo
                                { mult: 1.6,  dark: 1.8, alpha: 0.16, bmax: 44 }, // body
                                { mult: 1.05, dark: 2.2, alpha: 0.28, bmax: 30 }  // dark core
                            ]
                            delegate: Rectangle {
                                id: glowLayer
                                required property var modelData
                                readonly property real d: artFrame.width * modelData.mult
                                width: d
                                height: d
                                radius: d / 2 // circle, matching the round thumbnail
                                x: artFrame.x + artFrame.width / 2 - d / 2
                                y: artFrame.y + artFrame.height / 2 - d / 2
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

                    // Stays loaded through the expand/collapse morph — anchors.fill
                    // means it resizes every frame right along with pillSurface, so
                    // it morphs continuously instead of unloading/reloading (popping
                    // off then back on) around the transition.
                    Loader {
                        anchors.fill: parent
                        active: musicPill.visualizerLoaded
                        asynchronous: true
                        sourceComponent: Component {
                            Item {
                                NeonWaveVisualizer {
                                    anchors.fill: parent
                                    accentColor: Players.musicVisualizerAccent
                                    numBands: 32
                                    maxHeightRatio: 0.7
                                    topFadeRatio: 0.12
                                    valueMultiplier: 1.3
                                    // Gate on ownership (matching the bar) so the
                                    // covered bar/background visualizers stop while
                                    // this one is on screen — exactly one runs. Also
                                    // paused during the expand/collapse morph (see
                                    // musicPill.morphing) — matches the bar pill's own
                                    // mediaVisualizerActive excluding mediaMorphRendering.
                                    active: musicPill.isPlaying && musicPill.ownsVisualizer && !musicPill.morphing
                                    frameInterval: musicPill.visualizerFrameInterval
                                    // Drive from the C++ internal QTimer at
                                    // frameInterval instead of a per-vsync
                                    // FrameAnimation, so the visualizer never re-pins
                                    // the lock window to the monitor's 144Hz refresh —
                                    // it only requests renders at 30fps. Critical on
                                    // the fill-rate-limited iGPU lock surface.
                                    externallyDriven: false
                                }
                            }
                        }
                    }

                    // ── Tap-to-expand. artFrame/trackInfo/buttons paint on top of
                    // this (later siblings of musicPill), so they still get click
                    // priority over this background toggle.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: mouse => {
                            mouse.accepted = true;
                            musicPill.expanded = !musicPill.expanded;
                            pillPressSpring.start();
                        }
                    }
                }

                // ── Shared element: album art — one Image, fixed decode size.
                // Sibling of pillSurface (not inside its clip) so its shadow layer
                // is cached independently instead of re-rendering every visualizer
                // frame. Shadow itself is a plain non-layered ring — a blurred
                // MultiEffect shadow here was the other big always-on GPU cost
                // whenever a track was playing.
                Item {
                    id: artFrame
                    // x/y/width/height animated via musicPill's states/transitions
                    // above (grouped NumberAnimation, matching the taskbar's
                    // musicIcon technique) — these are just the initial/compact
                    // values for the first paint, before `state` is applied.
                    x: 8
                    y: 7
                    width: musicPill.compactArt
                    height: musicPill.compactArt

                    StyledClippingRect {
                        anchors.fill: parent
                        // Fixed radius (not width/2) — matches MediaMorphOverlay's
                        // art tile convention: circular at the small compact size
                        // (34/2 = 17), rounded-square once the art grows to the
                        // expanded size, same as every other music surface.
                        radius: 17
                        color: Players.active ? Qt.alpha(Players.musicOnSurfaceColor, 0.10) : Qt.alpha(Players.musicVisualizerAccent, 0.22)

                        Image {
                            id: lockArtImage
                            anchors.fill: parent
                            source: Players.active ? Players.getArtUrl(Players.active) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            // Fixed at the largest (expanded) size this pill ever
                            // shows art at — must NOT track the live animated
                            // width/height, or the image is re-decoded every frame
                            // of the resize, which is what causes morph blinking.
                            sourceSize: Qt.size(musicPill.expandedArt, musicPill.expandedArt)
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: Players.active ? Qt.alpha(Players.musicOnSurfaceColor, 0.4) : Players.musicOnAccent
                            iconPointSize: Tokens.font.size.normal
                            fill: 1
                            visible: !Players.active || lockArtImage.status !== Image.Ready
                        }
                    }
                }

                // ── Track info — absolutely positioned, delayed fade-in ──
                Column {
                    id: trackInfo
                    x: 98
                    y: musicPill.expanded ? 12 : 20
                    width: musicPill.width - x - 12
                    spacing: 0
                    opacity: musicPill.expanded ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: 70 }
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                    }

                    MarqueeText {
                        width: parent.width
                        text: Players.active ? (Players.active.trackTitle || "Unknown Title") : "Nothing Playing"
                        color: Qt.rgba(1, 1, 1, 0.95); textPointSize: Tokens.font.size.normal
                        font.weight: Font.DemiBold
                        running: musicPill.expanded && trackInfo.opacity > 0.95
                    }
                    StyledText {
                        width: parent.width
                        text: Players.active ? (Players.active.trackArtist || "Unknown Artist") : ""
                        color: Qt.rgba(1, 1, 1, 0.50); textPointSize: Tokens.font.size.small
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft
                        visible: text !== ""
                        anchors.topMargin: -2
                    }
                }

                // ── Controls — ALWAYS visible (compact AND expanded), just
                // slide between the compact position (right after the art) and
                // the expanded position (past the track info). Matches how the
                // bar pill (ActiveWindow.qml) always shows its controls — this
                // pill's "expanded" state only ever reveals the track-info text,
                // never the controls themselves.
                // MorphControlButton: same component as the bar pill and
                // MediaMorphOverlay card, so transport control motion/shape
                // language stays identical everywhere in Olvex.
                MorphControlButton {
                    x: musicPill.expanded ? 242 : 50
                    y: musicPill.expanded ? 44 : 9
                    Behavior on x { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    Behavior on y { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    iconName: "skip_previous"
                    balancedSkipIcon: true
                    skipIconScale: 0.86
                    iconSize: Tokens.font.size.large
                    onClicked: Players.previous()
                }

                MorphControlButton {
                    x: musicPill.expanded ? 280 : 86
                    y: musicPill.expanded ? 44 : 9
                    Behavior on x { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    Behavior on y { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    emphasized: true
                    // No spin — infinite RotationAnimator pins the lock window to
                    // 144Hz while playing (iGPU lag). Static circle, like backup.
                    spinning: false
                    animateSpin: false
                    iconName: musicPill.isPlaying ? "pause" : "play_arrow"
                    iconSize: Tokens.font.size.larger
                    onClicked: Players.togglePlaying()
                }

                MorphControlButton {
                    x: musicPill.expanded ? 318 : 122
                    y: musicPill.expanded ? 44 : 9
                    Behavior on x { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    Behavior on y { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    iconName: "skip_next"
                    balancedSkipIcon: true
                    skipIconScale: 0.86
                    iconSize: Tokens.font.size.large
                    onClicked: Players.next()
                }

                // ── Progress bar — ported from the card lock screen's seek
                // track (wavy-while-playing indicator, draggable stadium
                // thumb). Only shown expanded — matches trackInfo's own
                // gating, no room for it in the compact pill.
                Item {
                    id: progressWrap
                    x: 20
                    y: 82
                    width: musicPill.width - 40
                    height: 28
                    opacity: musicPill.expanded ? 1 : 0
                    visible: opacity > 0.01 && Players.active !== null

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: 70 }
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        id: timeElapsed
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: musicPill.lengthStr(musicPill.displayPosition)
                        color: Qt.alpha(Players.musicOnSurfaceColor, 0.58)
                        font.pixelSize: 11
                        font.family: Tokens.font.family.mono
                        font.weight: Font.Medium
                    }

                    Text {
                        id: timeTotal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: musicPill.lengthStr(Players.interpolatedLength > 0 ? Players.interpolatedLength : -1)
                        color: Qt.alpha(Players.musicOnSurfaceColor, 0.58)
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
                        readonly property bool isPlaying: musicPill.isPlaying
                        readonly property color activeColor: Players.musicPlayButtonBg
                        property bool dragging: false

                        readonly property real fillW: Math.max(0, Math.min(width, width * musicPill.displayProgress))
                        readonly property real thumbX: fillW
                        readonly property bool waveActive: musicPill.seekPreview < 0 && progressTrackRow.isPlaying

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
                                running: waveIndicator.amplitudeMultiplier > 0
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
                            color: Qt.alpha(Players.musicOnSurfaceColor, 0.22)
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
                            visible: musicPill.canSeek
                            x: progressTrackRow.thumbX - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: progressTrackRow.thumbW
                            height: progressTrackRow.thumbH
                            radius: width / 2
                            color: progressTrackRow.activeColor
                            border.width: 1
                            border.color: Qt.alpha(Players.musicOnSurfaceColor, 0.26)
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
                            enabled: musicPill.canSeek && musicPill.expanded
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
                                musicPill.seekPreview = fractionAt(mouse.x);
                                mouse.accepted = true;
                            }
                            onReleased: mouse => {
                                progressTrackRow.dragging = false;
                                if (musicPill.seekPreview >= 0) {
                                    Players.seekTo(musicPill.seekPreview);
                                    musicPill.seekPreview = -1;
                                }
                                mouse.accepted = true;
                            }
                            onPositionChanged: mouse => {
                                if (pressed)
                                    musicPill.seekPreview = fractionAt(mouse.x);
                            }
                            onCanceled: {
                                progressTrackRow.dragging = false;
                                musicPill.seekPreview = -1;
                            }
                        }
                    }
                }
            }

            // System Pill
            Rectangle {
                id: systemPill
                implicitWidth: statsRow.implicitWidth + 48
                implicitHeight: 48
                radius: height / 2
                
                // Sleek Material Card Background
                color: Colours.palette.m3surfaceContainerHigh

                Row {
                    id: statsRow
                    anchors.centerIn: parent
                    spacing: 16

                    // Distro/system label
                    StyledText {
                        id: osLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: SysInfo.osPrettyName || SysInfo.osName || "Linux"
                        color: Qt.rgba(1, 1, 1, 0.90)
                        textPointSize: Tokens.font.size.normal
                        font.weight: Font.Light
                        rightPadding: 8
                    }

                    // Separator
                    Rectangle {
                        width: 1; height: 22; color: Qt.rgba(1, 1, 1, 0.10)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // CPU
                    StatWidget { label: "CPU"; value: SystemUsage.cpuPerc }
                    // GPU
                    StatWidget { label: "GPU"; value: SystemUsage.gpuPerc }
                    // RAM
                    StatWidget { label: "RAM"; value: SystemUsage.memPerc }

                    // Separator
                    Rectangle {
                        width: 1; height: 22; color: Qt.rgba(1, 1, 1, 0.10)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Network
                    Row {
                        id: netRow
                        spacing: 14
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            MaterialIcon {
                                text: "arrow_downward"
                                color: Colours.current.m3primary
                                iconPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: root.formatSpeed(NetworkUsage.downloadSpeed)
                                color: Qt.rgba(1, 1, 1, 0.90)
                                textPointSize: Tokens.font.size.small
                                width: 72
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            MaterialIcon {
                                text: "arrow_upward"
                                color: Colours.current.m3primary
                                iconPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: root.formatSpeed(NetworkUsage.uploadSpeed)
                                color: Qt.rgba(1, 1, 1, 0.90)
                                textPointSize: Tokens.font.size.small
                                width: 72
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        width: 1; height: 22; color: Qt.rgba(1, 1, 1, 0.10)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: batRow.visible
                    }

                    // Battery (visible only when device has a battery)
                    Row {
                        id: batRow
                        spacing: 8
                        opacity: UPower.displayDevice.isLaptopBattery ? 1 : 0
                        visible: opacity > 0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                        // macOS-style vertical battery icon
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -2
                            width: 14
                            height: 28

                            readonly property real pct: UPower.displayDevice.percentage
                            readonly property bool charging: [
                                UPowerDeviceState.Charging,
                                UPowerDeviceState.FullyCharged,
                                UPowerDeviceState.PendingCharge
                            ].includes(UPower.displayDevice.state)
                            readonly property color fillColor: charging
                                ? "#30d158"
                                : pct <= 0.20 ? "#ff453a"
                                : pct <= 0.40 ? "#ffd60a"
                                : Qt.rgba(1, 1, 1, 0.88)

                            // Nub on top
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 5
                                height: 3
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.55)
                            }

                            // Body
                            Rectangle {
                                id: battBody
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 13
                                height: 24
                                radius: 3
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.55)
                                border.width: 1.5
                                clip: true

                                // Fill bar (rises from bottom)
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 2
                                    height: Math.max(2, (parent.height - 4) * parent.parent.pct)
                                    radius: 1.5
                                    color: parent.parent.fillColor

                                    Behavior on height { SmoothedAnimation { velocity: 50 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                // Charging bolt
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: parent.parent.charging
                                    text: "bolt"
                                    color: parent.parent.pct > 0.55
                                        ? Qt.rgba(0, 0, 0, 0.75)
                                        : Qt.rgba(1, 1, 1, 0.95)
                                    iconPointSize: 8
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText {
                                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                                color: Qt.rgba(1, 1, 1, 0.90)
                                textPointSize: Tokens.font.size.small + 1
                                font.bold: true
                            }
                            StyledText {
                                text: {
                                    const s = UPower.displayDevice.state;
                                    if ([UPowerDeviceState.Charging,
                                         UPowerDeviceState.PendingCharge].includes(s))
                                        return "Charging";
                                    if (s === UPowerDeviceState.FullyCharged)
                                        return "Full";
                                    return "Discharging";
                                }
                                color: Qt.rgba(1, 1, 1, 0.45)
                                textPointSize: Math.max(7, Tokens.font.size.small - 2)
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }

            // ── Notification Pill (right) ──────────────────────────────────────
            Rectangle {
                id: notifPill
                z: 10
                anchors.top: parent.top
                anchors.topMargin: 0
                clip: true

                color: Colours.palette.m3surfaceContainerHigh
                property bool expanded: false

                width: expanded ? 340 : (notifHeaderRow.width + 16)
                height: expanded ? Math.min(320, Math.max(120, Notifs.notClosed.length * 66 + 64)) : 48
                radius: expanded ? 28 : 24

                // Same curve as musicPill — M3 emphasized spatial spline, not the
                // old OutBack overshoot bounce.
                Behavior on width { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                Behavior on height { NumberAnimation { duration: musicPill.boundsDur; easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                // Shape-mask completes ahead of the bounds (container-transform
                // shapeMaskProgressThresholds ≈ 0→0.75), matching musicPill's own
                // pillSurface radius timing.
                Behavior on radius { NumberAnimation { duration: Math.round(musicPill.boundsDur * 0.75); easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }

                // Header
                Row {
                    id: notifHeaderRow
                    anchors.top: parent.top
                    // Corner radius grows 24→28 on expand — the inset needs to grow
                    // with it (~radius × 0.3) or the icon crowds the rounded corner.
                    anchors.topMargin: notifPill.expanded ? 8 : 6
                    anchors.left: parent.left
                    anchors.leftMargin: notifPill.expanded ? 9 : 7
                    Behavior on anchors.topMargin { NumberAnimation { duration: Math.round(musicPill.boundsDur * 0.75); easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    Behavior on anchors.leftMargin { NumberAnimation { duration: Math.round(musicPill.boundsDur * 0.75); easing.type: Easing.BezierSpline; easing.bezierCurve: musicPill.spatialEasing } }
                    spacing: 12
                    z: 20

                    TapHandler { onTapped: notifPill.expanded = !notifPill.expanded }

                    Item {
                        width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.08); border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                        }
                        MaterialIcon {
                            anchors.centerIn: parent; text: "notifications"
                            color: (notifPill.expanded || Notifs.notClosed.length > 0) ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.3)
                            iconPointSize: 15
                        }
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: Colours.current.m3primary
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: -2; anchors.rightMargin: -2
                            visible: Notifs.notClosed.length > 0 && !notifPill.expanded
                            StyledText { anchors.centerIn: parent; text: Notifs.notClosed.length > 9 ? "9+" : Notifs.notClosed.length.toString(); color: Colours.current.m3onPrimary; textPointSize: 7; font.bold: true }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.notClosed.length === 0 ? "No Notifications" : (Notifs.notClosed.length + (Notifs.notClosed.length === 1 ? " New Notification" : " New Notifications"))
                        color: (notifPill.expanded || Notifs.notClosed.length > 0) ? Qt.rgba(1, 1, 1, 0.90) : Qt.rgba(1, 1, 1, 0.40)
                        textPointSize: Tokens.font.size.normal - 1; font.weight: Font.Medium
                    }
                }

                // Notification List
                ListView {
                    id: notifList
                    anchors.top: notifHeaderRow.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 16; anchors.topMargin: 10; spacing: 8
                    opacity: notifPill.expanded ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    model: Notifs.notClosed

                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    property real wheelOvershoot: 0
                    Behavior on wheelOvershoot { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    readonly property real overscroll: {
                        if (contentY < -originY) return -originY - contentY;
                        const bottomLimit = contentHeight - height;
                        if (contentY > bottomLimit) return contentY - bottomLimit;
                        return Math.abs(wheelOvershoot);
                    }

                    transform: Scale {
                        origin.y: (notifList.contentY < 0 || notifList.wheelOvershoot > 0) ? 0 : notifList.height
                        yScale: 1 + (Math.abs(notifList.overscroll) / 1500)
                    }

                    WheelHandler {
                        onWheel: (event) => {
                            if ((notifList.atYBeginning && event.angleDelta.y > 0) || (notifList.atYEnd && event.angleDelta.y < 0)) {
                                notifList.wheelOvershoot += event.angleDelta.y / 2;
                                wheelReset.restart();
                            }
                        }
                    }
                    Timer { id: wheelReset; interval: 10; onTriggered: notifList.wheelOvershoot = 0 }

                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width; height: 58
                        Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(1, 1, 1, 0.05) }
                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            // Real thumbnail/app-icon, matching the card lock screen's
                            // NotifGroup.qml priority: image > appIcon > generic fallback.
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.10)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    visible: modelData.image.length > 0
                                    source: modelData.image.length > 0 ? Qt.resolvedUrl(modelData.image) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }

                                ColouredIcon {
                                    anchors.centerIn: parent
                                    visible: modelData.image.length === 0 && modelData.appIcon.length > 0
                                    implicitSize: 18
                                    source: modelData.appIcon.length > 0 ? Quickshell.iconPath(modelData.appIcon) : ""
                                    colour: Qt.rgba(1, 1, 1, 0.7)
                                    layer.enabled: modelData.appIcon.endsWith("symbolic")
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: modelData.image.length === 0 && modelData.appIcon.length === 0
                                    text: "info"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    iconPointSize: 14
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 52
                                spacing: 2
                                StyledText {
                                    width: parent.width
                                    text: modelData.summary || "Notification"
                                    color: Qt.rgba(1, 1, 1, 0.90)
                                    textPointSize: Tokens.font.size.normal - 1
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    width: parent.width
                                    text: modelData.body || ""
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    textPointSize: Tokens.font.size.small
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── MAIN ROW: Clock (left) + Auth card (right) ────────────────────────────
    RowLayout {
        id: mainRow

        anchors {
            top: topBar.bottom
            bottom: bottomBar.top
            left: parent.left
            right: parent.right
            topMargin: 20
            bottomMargin: 20
            leftMargin: 32
            rightMargin: 32
        }

        spacing: 0
        opacity: root.elementOpacity

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        // Clock + Date block (left half)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            transform: Translate { id: clockTrans; x: -root.offset }

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 0
                spacing: 24

                // Hour + Minutes column + AM/PM
                Row {
                    spacing: 0

                    // Big hour
                    StyledText {
                        text: Time.hourStr
                        color: Colours.current.m3onSurface
                        textPointSize: Math.min(180, parent.parent.parent.parent.height * 0.22)
                        font.weight: Font.Bold
                        font.family: Tokens.font.family.clock
                        font.letterSpacing: -4
                        anchors.bottom: minuteCol.bottom
                    }

                    // Minutes + divider + AM/PM
                    Column {
                        id: minuteCol
                        spacing: 6
                        anchors.bottom: parent.bottom
                        bottomPadding: 10

                        StyledText {
                            text: Time.minuteStr
                            color: Qt.alpha(Colours.current.m3primary, 0.65)
                            textPointSize: Math.min(84, parent.parent.parent.parent.height * 0.10)
                            font.weight: Font.Medium
                            font.family: Tokens.font.family.clock
                        }

                        Rectangle {
                            width: parent.width
                            height: 2
                            color: Qt.alpha(Colours.current.m3primary, 0.30)
                        }

                        Loader {
                            active: GlobalConfig.services.useTwelveHourClock
                            visible: active
                            sourceComponent: StyledText {
                                text: Time.amPmStr
                                color: Qt.alpha(Colours.current.m3primary, 0.50)
                                textPointSize: Tokens.font.size.small + 2
                                font.bold: true
                                font.letterSpacing: 5
                                font.capitalization: Font.AllUppercase
                            }
                        }
                    }
                }

                // Date with leading gradient line
                Row {
                    spacing: 14

                    Rectangle {
                        width: 80
                        height: 2
                        anchors.verticalCenter: parent.verticalCenter
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: Qt.alpha(Colours.current.m3primary, 0.45)
                            }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    StyledText {
                        text: Time.format("MMMM d").toUpperCase()
                        color: Colours.current.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.extraLarge
                        font.letterSpacing: 6
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Auth Card (right)
        Item {
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            transform: Translate { id: authTrans; x: root.offset }

            Item {
                anchors.centerIn: parent
                width: 360
                implicitHeight: authCol.implicitHeight + 64

                // Sleek Material Card Background
                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: Colours.palette.m3surfaceContainerHigh
                }

                Column {
                    id: authCol
                    anchors.centerIn: parent
                    width: parent.width - 56
                    spacing: 22

                    // Avatar with Dashboard-style spinning mask
                    Item {
                        id: avatarHost
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 100
                        height: 100

                        // Single shared spin phase for the ring + mask, advanced by
                        // one 60fps Timer instead of two vsync-locked (144Hz)
                        // NumberAnimations. Same 360°/20s = 18°/s spin, but the lock
                        // window no longer re-composites at the monitor's full refresh
                        // rate — at ~0.29°/tick the motion is sub-pixel, visually
                        // identical, while relaxing the per-frame deadline enough for
                        // the visualizer to stay within budget on a 144Hz iGPU.
                        property real spin: 0
                        readonly property real spinStep: 360 * 16 / 20000  // ≈0.288°/16ms

                        Timer {
                            interval: 16
                            running: true
                            repeat: true
                            onTriggered: avatarHost.spin = (avatarHost.spin - avatarHost.spinStep + 360) % 360
                        }

                        // Spinning 12-sided ring
                        MaterialShape {
                            id: avatarRing
                            anchors.fill: parent
                            z: 0
                            implicitSize: 100
                            shape: MaterialShape.Cookie12Sided
                            color: Colours.layer(Colours.palette.m3primaryContainer, 1)
                            rotation: avatarHost.spin
                        }

                        // Spinning mask for clipping
                        Item {
                            id: avatarMaskWrap
                            anchors.fill: parent
                            visible: false
                            z: 0
                            layer.enabled: true

                            MaterialShape {
                                implicitSize: 100
                                shape: MaterialShape.Cookie12Sided
                                color: "white"
                                rotation: avatarHost.spin
                            }
                        }

                        // Fallback avatar (when no image)
                        Item {
                            id: avatarFallback
                            anchors.fill: parent
                            visible: face.status !== Image.Ready
                            z: 1
                            layer.enabled: true
                            layer.effect: Mask {
                                maskSource: avatarMaskWrap
                            }

                            MaterialShape {
                                anchors.centerIn: parent
                                implicitSize: 72
                                shape: MaterialShape.Circle
                                color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.55)
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "person"
                                color: Colours.palette.m3onPrimaryContainer
                                iconPointSize: 34
                            }
                        }

                        // Actual user face image
                        CachingImage {
                            id: face
                            anchors.fill: parent
                            z: 1
                            path: `${Paths.home}/.face`
                            layer.enabled: true
                            layer.effect: Mask {
                                maskSource: avatarMaskWrap
                            }
                        }
                    }

                    // Username + status/hint
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.userName
                            color: "white"
                            textPointSize: Tokens.font.size.extraLarge
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            id: hintText
                            anchors.horizontalCenter: parent.horizontalCenter

                            readonly property string defaultMsg: qsTr("Enter password or use fingerprint")
                            readonly property bool isError: {
                                const p = root.pam;
                                return p.state === "error" || p.state === "fail"
                                    || p.fprintState === "error" || p.fprintState === "fail";
                            }

                            text: {
                                const p = root.pam;
                                if (p.fprintState === "error")
                                    return qsTr("FP Error: %1").arg(p.fprint.message);
                                if (p.state === "error")
                                    return qsTr("Error: %1").arg(p.passwd.message);
                                if (p.lockMessage) return p.lockMessage;
                                if (p.state === "fail")
                                    return p.fprint.available
                                        ? qsTr("Incorrect password. Try fingerprint.")
                                        : qsTr("Incorrect password. Try again.");
                                if (p.fprintState === "fail")
                                    return qsTr("Fingerprint not recognized. Use password.");
                                return defaultMsg;
                            }

                            color: isError ? Colours.current.m3error : Qt.rgba(1, 1, 1, 0.55)
                            textPointSize: Tokens.font.size.normal - 1
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere

                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // Password input row
                    Rectangle {
                        id: inputRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: pwdLayout.implicitHeight + 20
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.07)
                        border.color: root.activeFocus
                            ? Colours.current.m3primary
                            : Colours.current.m3outlineVariant
                        border.width: root.activeFocus ? 2 : 1

                        scale: 1.0

                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on border.width { NumberAnimation { duration: 150 } }
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                        }

                        TapHandler {
                            onTapped: {
                                root.forceActiveFocus();
                                inputRow.scale = 0.97;
                                pulseBack.restart();
                            }
                        }

                        Timer {
                            id: pulseBack
                            interval: 120
                            onTriggered: inputRow.scale = 1.0
                        }

                        RowLayout {
                            id: pwdLayout
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 8

                            // Fingerprint / lock icon + spinner
                            Item {
                                implicitWidth: fprintIcon.implicitWidth + 8
                                implicitHeight: fprintIcon.implicitHeight

                                MaterialIcon {
                                    id: fprintIcon
                                    anchors.centerIn: parent
                                    animate: true
                                    text: {
                                        if (root.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries)
                                            return "fingerprint_off";
                                        if (root.pam.fprint.active)
                                            return "fingerprint";
                                        return "lock";
                                    }
                                    color: root.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries
                                        ? Colours.current.m3error
                                        : Qt.rgba(1, 1, 1, 0.45)
                                    iconPointSize: Tokens.font.size.normal
                                    opacity: root.pam.passwd.active ? 0 : 1
                                    Behavior on opacity { Anim {} }
                                }

                                CircularIndicator {
                                    anchors.fill: parent
                                    running: root.pam.passwd.active
                                }
                            }

                            InputField {
                                id: inputField
                                Layout.fillWidth: true
                                pam: root.pam
                            }

                            // Submit arrow button
                            Rectangle {
                                implicitWidth: 38
                                implicitHeight: 38
                                radius: 19
                                color: root.pam.buffer
                                    ? Colours.current.m3primary
                                    : Qt.rgba(1, 1, 1, 0.10)

                                Behavior on color { ColorAnimation { duration: 200 } }

                                StateLayer {
                                    radius: parent.radius
                                    color: root.pam.buffer
                                        ? Colours.current.m3onPrimary
                                        : Colours.current.m3onSurface
                                    onClicked: root.pam.passwd.start()
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "arrow_forward"
                                    color: root.pam.buffer
                                        ? Colours.current.m3onPrimary
                                        : Qt.rgba(1, 1, 1, 0.55)
                                    iconPointSize: Tokens.font.size.normal
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    // PAM flash message (errors)
                    Connections {
                        function onFlashMsg(): void {
                            flashAnim.restart();
                        }
                        target: root.pam
                    }

                    SequentialAnimation {
                        id: flashAnim
                        loops: 2
                        NumberAnimation { target: hintText; property: "opacity"; to: 0.2; duration: 80 }
                        NumberAnimation { target: hintText; property: "opacity"; to: 1.0; duration: 80 }
                    }
                }
            }
        }
    }

    // Bottom buttons dock
    Item {
        id: bottomBar

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 32

        implicitWidth: actRow.implicitWidth + 32
        implicitHeight: actRow.implicitHeight + 20
        opacity: root.elementOpacity
        transform: Translate { id: bottomBarTrans; y: root.vOffset }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Colours.palette.m3surfaceContainerHigh
        }

        RowLayout {
            id: actRow
            anchors.centerIn: parent
            spacing: 12

            ActionBtn {
                icon: Config.session.icons.shutdown
                label: qsTr("Power")
                command: Config.session.commands.shutdown
            }

            ActionBtn {
                icon: Config.session.icons.reboot
                label: qsTr("Reboot")
                command: Config.session.commands.reboot
            }

            ActionBtn {
                icon: Config.session.icons.suspend || "bedtime"
                label: qsTr("Sleep")
                command: Config.session.commands.suspend
            }

            ActionBtn {
                icon: Config.session.icons.logout
                label: qsTr("Logout")
                command: Config.session.commands.logout
            }
        }
    }

    // ── SUB-COMPONENTS ────────────────────────────────────────────────────────

    // Stat widget: label + value % + thin progress bar
    component StatWidget: Column {
        required property string label
        required property real value   // 0..1

        spacing: 3
        width: 60

        Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

        Row {
            width: parent.width
            spacing: 0

            StyledText {
                width: parent.width - 20 // approximate for percentage text
                text: label
                color: Qt.rgba(1, 1, 1, 0.55)
                textPointSize: Math.max(7, Tokens.font.size.small - 1)
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            StyledText {
                text: Math.round(value * 100) + "%"
                color: Colours.current.m3primary
                textPointSize: Math.max(7, Tokens.font.size.small - 1)
                font.bold: true
            }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.10)

            Rectangle {
                width: parent.width * value
                height: parent.height
                radius: parent.radius
                color: Colours.current.m3primary

                Behavior on width { SmoothedAnimation { velocity: 40 } }
            }
        }
    }

    // Action button for bottom bar
    component ActionBtn: Item {
        required property string icon
        required property string label
        required property list<string> command

        implicitWidth: hov.hovered ? row.implicitWidth + 36 : 52
        implicitHeight: 52

        Behavior on implicitWidth {
            NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
        }

        Rectangle {
            id: btnBg
            anchors.fill: parent
            radius: height / 2
            color: hov.hovered ? Colours.current.m3primary : Qt.rgba(1, 1, 1, 0.08)
            border.color: hov.hovered ? Qt.alpha("white", 0.2) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: hov.hovered ? 10 : 0

            Behavior on spacing {
                NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.icon
                color: hov.hovered ? Colours.current.m3onPrimary : Colours.current.m3primary
                iconPointSize: 20
                animate: true

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Item {
                id: labelWrapper
                width: hov.hovered ? btnLabel.implicitWidth : 0
                height: 52
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Behavior on width {
                    NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                }

                StyledText {
                    id: btnLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.parent.parent.label
                    color: hov.hovered ? Colours.current.m3onPrimary : "white"
                    textPointSize: 10
                    font.weight: hov.hovered ? Font.Bold : Font.DemiBold
                    font.letterSpacing: 1.0
                    opacity: hov.hovered ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }
                }
            }
        }

        StateLayer {
            radius: btnBg.radius
            onClicked: Quickshell.execDetached(parent.command)
        }

        HoverHandler {
            id: hov
        }
    }

    // Ported verbatim from MediaMorphOverlay.qml/Media.qml — MarqueeText is a
    // file-local `component`, not a shared type, so each user defines its own copy.
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

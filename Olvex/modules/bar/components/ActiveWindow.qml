
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import M3Shapes
import Olvex
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.images
import qs.services
import qs.utils
import "../../../components/effects"

Item {
    id: root

    readonly property color pillColor: root.playerActive ? Players.musicSurfaceColor : Colours.tPalette.m3surfaceContainer
    readonly property real pillRadius: root.musicPillRadius

    required property var bar
    required property Brightness.Monitor monitor
    readonly property var mediaMorph: root.bar?.mediaMorph ?? Players.mediaMorphForScreen(root.bar?.screen?.name ?? "")
    property color colour: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3primary

    readonly property bool hasMusicPlayer: !!Players.active
    readonly property bool isMusicPlaying: Players.active && Players.activeIsPlaying
    // Pill stays mounted permanently — it just collapses to activewindow height
    // when no player is running instead of disappearing.
    readonly property bool showMusicPill: true
    // Internal: gates morph, visualizer, accent — needs actual player
    readonly property bool playerActive: hasMusicPlayer
    readonly property bool mediaMorphOwnsPill: root.playerActive && (root.mediaMorph?.dockLayoutReady ?? false)
    readonly property bool mediaMorphCollapsing: root.playerActive && (root.mediaMorph?.closingDown ?? false)
    readonly property bool mediaMorphRendering: root.playerActive && ((root.mediaMorph?.active ?? false) || (root.mediaMorph?.morphAnimating ?? false))
    readonly property bool mediaVisualizerWarm: root.playerActive
    readonly property bool mediaVisualizerActive: root.playerActive && root.isMusicPlaying
    readonly property bool ownsVisualizer: VisualizerState.visibleOwner === "pill"
    property bool mediaVisualizerLoaded: mediaVisualizerActive
    readonly property string musicArtUrl: Players.currentArtUrl
    property string barArtSource: ""
    readonly property bool barArtIsLocal: root.musicArtUrl.startsWith("file:") || root.musicArtUrl.startsWith("/")
    readonly property bool hasMusicArt: root.musicArtUrl !== ""
    readonly property color musicAccent: root.showMusicPill ? Players.musicVisualizerAccent : Colours.palette.m3primaryContainer
    readonly property color musicOnAccent: Players.musicOnAccent
    property color playButtonBg: Colours.palette.m3primary
    property color playIconColor: Colours.palette.m3onPrimary
    property bool _syncingBarAccent: false
    property bool _accentRefreshPending: false
    property bool isLoaded: false
    readonly property int musicPillWidth: 48
    readonly property int musicPillHeight: 160
    readonly property int musicArtSize: 40
    readonly property int musicButtonSize: 30
    readonly property int pillSideMargin: (root.musicPillWidth - root.musicArtSize) / 2
    readonly property real musicPillRadius: root.musicPillWidth / 2
    // Experiment: match the monitor's native refresh rate instead of a fixed
    // 60fps cap, now that the play-button spin/wavy-line pinning is removed.
    readonly property real _screenHz: (root.bar && root.bar.screen && root.bar.screen.refreshRate > 0) ? root.bar.screen.refreshRate : (Screen.refreshRate > 0 ? Screen.refreshRate : 60)
    readonly property int visualizerFrameInterval: Math.max(1, Math.round(1000 / root._screenHz))
    property real _lastMorphDockX: -1
    property real _lastMorphDockY: -1
    property real _lastMorphDockW: -1
    property real _lastMorphDockH: -1

    function refreshAccentColors(): void {
        if (!root.playerActive) {
            root.playButtonBg = Colours.palette.m3primary;
            root.playIconColor = Colours.palette.m3onPrimary;
            return;
        }
        if (barAccentPicker.accentReady) {
            root.playButtonBg = barAccentPicker.playButtonBg;
            root.playIconColor = barAccentPicker.playIconColor;
        } else if (Players.musicAccentReady) {
            root.playButtonBg = Players.musicPlayButtonBg;
            root.playIconColor = Players.musicPlayIconColor;
        }
    }

    function queueAccentRefresh(): void {
        if (root._accentRefreshPending)
            return;
        root._accentRefreshPending = true;
        Qt.callLater(() => {
            root._accentRefreshPending = false;
            root.refreshAccentColors();
        });
    }

    function syncBarAccent(): void {
        if (root._syncingBarAccent)
            return;
        root._syncingBarAccent = true;
        barAccentPicker.setArtUrl(Players.currentArtUrl);
        root.refreshAccentColors();
        root._syncingBarAccent = false;
    }

    function updateBarArtSource(): void {
        const url = root.musicArtUrl;
        if (!url) {
            root.barArtSource = "";
            return;
        }
        if (root.barArtIsLocal) {
            root.barArtSource = url;
            return;
        }
        root.barArtSource = url + "#olvex-art=" + Players.artReloadNonce;
    }

    function syncMorphDock(immediate: bool): void {
        if (root.mediaMorph?.active)
            return;
        if (immediate)
            dockSyncDebounce.stop();
        else {
            dockSyncDebounce.restart();
            return;
        }
        applyMorphDock();
    }

    function applyMorphDock(): void {
        if (!root.mediaMorph || !root.playerActive || root.mediaMorph.active)
            return;
        if (musicPill.width <= 0 || musicPill.height <= 0)
            return;

        const morph = root.mediaMorph;
        const anchor = morph.parent ?? morph;
        const pos = musicPill.mapToItem(anchor, 0, 0);
        if (Math.abs(pos.x - root._lastMorphDockX) < 0.5 && Math.abs(pos.y - root._lastMorphDockY) < 0.5 && Math.abs(musicPill.width - root._lastMorphDockW) < 0.5 && Math.abs(musicPill.height - root._lastMorphDockH) < 0.5 && morph.dockLayoutReady) {
            return;
        }

        CpuProfile.bump("syncMorphDock");
        const artPos = artFrame.mapToItem(anchor, 0, 0);
        const b1 = prevSkipBtn.mapToItem(anchor, 0, 0);
        const b2 = playPillBtn.mapToItem(anchor, 0, 0);
        const b3 = nextSkipBtn.mapToItem(anchor, 0, 0);

        morph.syncDock(pos.x, pos.y, musicPill.width, musicPill.height, root.musicAccent, artPos.x - pos.x, artPos.y - pos.y, artFrame.width, artFrame.height, b1.x - pos.x, b1.y - pos.y, b2.x - pos.x, b2.y - pos.y, b3.x - pos.x, b3.y - pos.y, root.musicButtonSize);
        root._lastMorphDockX = pos.x;
        root._lastMorphDockY = pos.y;
        root._lastMorphDockW = musicPill.width;
        root._lastMorphDockH = musicPill.height;
    }

    Timer {
        id: dockSyncDebounce
        interval: 80
        repeat: false
        onTriggered: root.applyMorphDock()
    }

    Timer {
        id: visualizerUnloadTimer
        interval: Math.max(root.visualizerFrameInterval * 28, 900)
        repeat: false
        onTriggered: root.mediaVisualizerLoaded = false
    }

    function syncVisualizerOwner(): void {
        VisualizerState.request("pill", 20, root.mediaVisualizerActive);
    }

    onWidthChanged: syncMorphDock(false)
    onHeightChanged: syncMorphDock(false)
    onXChanged: syncMorphDock(false)
    onYChanged: syncMorphDock(false)

    function kickDockSync(): void {
        if (!root.playerActive || !root.mediaMorph)
            return;
        root._lastMorphDockX = -1;
        root._lastMorphDockY = -1;
        root._lastMorphDockW = -1;
        root._lastMorphDockH = -1;
        dockSyncTimer.attempts = 0;
        dockSyncTimer.start();
    }

    function triggerPillExpand(): void {
        // No-op without music: skip the press spring and the morph entirely.
        // Otherwise a click on the active-window state would squeeze the pill
        // and try to start a morph that returns early anyway.
        if (!root.playerActive)
            return;
        dockSyncDebounce.stop();
        dockSyncTimer.stop();
        pillPressSpring.start();
        root.expandMusicMorph();
    }

    function expandMusicMorph(): void {
        if (!root.playerActive)
            return;

        const morph = root.bar?.mediaMorph ?? Players.mediaMorphForScreen(root.bar?.screen?.name ?? "");
        if (!morph?.start)
            return;

        dockSyncDebounce.stop();
        dockSyncTimer.stop();

        const anchor = morph.parent ?? morph;
        const pos = musicPill.mapToItem(anchor, 0, 0);
        const artPos = artFrame.mapToItem(anchor, 0, 0);
        const b1 = prevSkipBtn.mapToItem(anchor, 0, 0);
        const b2 = playPillBtn.mapToItem(anchor, 0, 0);
        const b3 = nextSkipBtn.mapToItem(anchor, 0, 0);

        morph.start(pos.x, pos.y, musicPill.width, musicPill.height, root.musicAccent, artPos.x - pos.x, artPos.y - pos.y, artFrame.width, artFrame.height, b1.x - pos.x, b1.y - pos.y, b2.x - pos.x, b2.y - pos.y, b3.x - pos.x, b3.y - pos.y, root.musicButtonSize);
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

    property bool isMusicClosing: false
    Timer {
        id: musicCloseTimer
        interval: Tokens.anim.durations.expressiveDefaultSpatial
        onTriggered: root.isMusicClosing = false
    }

    onPlayerActiveChanged: {
        root.syncBarAccent();
        root.kickDockSync();
        
        if (!root.playerActive) {
            root.isMusicClosing = true;
            musicCloseTimer.restart();
        } else {
            root.isMusicClosing = false;
            musicCloseTimer.stop();
        }
    }

    onMediaMorphChanged: {
        root.syncBarAccent();
        root.kickDockSync();
    }

    onIsNotificationPushedChanged: {
        if (root.isNotificationPushed && root.playerActive) {
            const morph = root.bar?.mediaMorph ?? Players.mediaMorphForScreen(root.bar?.screen?.name ?? "");
            if (morph?.active) {
                Qt.callLater(() => {
                    const anchor = morph.parent ?? morph;
                    const pos = musicPill.mapToItem(anchor, 0, 0);
                    const artPos = artFrame.mapToItem(anchor, 0, 0);
                    const b1 = prevSkipBtn.mapToItem(anchor, 0, 0);
                    const b2 = playPillBtn.mapToItem(anchor, 0, 0);
                    const b3 = nextSkipBtn.mapToItem(anchor, 0, 0);
                    if (typeof morph.updateDockTarget === "function") {
                        morph.updateDockTarget(
                            pos.x, pos.y, root.musicPillWidth, root.musicPillWidth,
                            artPos.x - pos.x, artPos.y - pos.y, artFrame.width, artFrame.height,
                            b1.x - pos.x, b1.y - pos.y,
                            b2.x - pos.x, b2.y - pos.y,
                            b3.x - pos.x, b3.y - pos.y,
                            root.musicButtonSize
                        );
                    }
                });
            }
        }
    }

    Connections {
        target: barAccentPicker
        function onAccentColorsChanged() {
            root.queueAccentRefresh();
        }
    }

    Component.onCompleted: {
        root.updateBarArtSource();
        root.syncBarAccent();
        root.kickDockSync();
        root.syncVisualizerOwner();

        Qt.callLater(() => root.isLoaded = true);
    }

    Component.onDestruction: {
        VisualizerState.release("pill");
    }

    Connections {
        target: Players
        function onCurrentArtUrlChanged() {
            root.updateBarArtSource();
            root.syncBarAccent();
        }
        function onCurrentTrackKeyChanged() {
            // Defer until next event loop tick so currentArtUrl has time to settle
            // before setArtUrl() runs analysis. Without this, analysis fires on the
            // OLD artUrl but with the NEW trackKey — wrong image, wrong color.
            Qt.callLater(() => root.syncBarAccent());
        }
        function onArtReloadNonceChanged() {
            root.updateBarArtSource();
        }
    }

    Timer {
        id: dockSyncTimer
        interval: 80
        repeat: true
        property int attempts: 0

        onTriggered: {
            CpuProfile.bump("dockSyncTimer");
            if (!root.playerActive || !root.mediaMorph) {
                stop();
                attempts = 0;
                return;
            }
            root.applyMorphDock();
            attempts++;
            if (root.mediaMorph.dockLayoutReady)
                stop();
            else if (attempts >= 16)
                stop();
        }
    }

    Connections {
        target: Players
        function onActiveChanged() {
            root.syncBarAccent();
            if (Players.active)
                root.kickDockSync();
        }
        function onMediaAccentPrewarmed() {
            if (!barAccentPicker.accentReady)
                root.syncBarAccent();
        }
        function onMediaAccentRevisionChanged() {
            if (!barAccentPicker.accentReady)
                root.syncBarAccent();
        }
        function onBootAccentLoadedChanged() {
            if (!barAccentPicker.accentReady)
                root.syncBarAccent();
        }
    }

    Connections {
        target: root.mediaMorph
        enabled: root.mediaMorph !== null
        function onActiveChanged() {
            if (root.mediaMorph.active) {
                dockSyncDebounce.stop();
                dockSyncTimer.stop();
            } else {
                Qt.callLater(() => root.syncMorphDock(true));
            }
        }
    }

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return qsTr("Desktop");
        if (Config.bar.activeWindow.compact) {
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxHeight: {
        const otherModules = (bar?.children ?? []).filter(c => c && c.id && c.item !== this && c.id !== "spacer");
        const otherHeight = otherModules.reduce((acc, curr) => acc + ((curr?.item?.nonAnimHeight ?? curr?.height) || 0), 0);
        // Length - 2 cause repeater counts as a child
        return (bar?.height ?? 0) - otherHeight - (bar?.spacing ?? 0) * (((bar?.children?.length ?? 1) - 1)) - (bar?.vPadding ?? 0) * 2;
    }
    readonly property int availableTitleHeight: Math.max(0, root.maxHeight - Tokens.spacing.small * 4)
    readonly property int preferredTitleHeight: Math.max(64, Math.round((bar?.height ?? 0) * 0.18))
    // Non-music pill is flex-sized by Bar.qml (Layout.fillHeight: true), so
    // the title spans whatever the pill actually rendered, not a calc against
    // the full bar height. 64px floor keeps the title legible if the bar is
    // crushed by a fully-expanded workspace pill.
    readonly property int titleSlotHeight: root.playerActive
        ? 0
        : Math.max(64, root.height - icon.height - Tokens.spacing.small * 4)

    readonly property bool isNotificationPushed: Notifs.hasBarNotif

    clip: false
    anchors.fill: parent
    implicitWidth: root.playerActive ? root.musicPillWidth : Tokens.sizes.bar.innerWidth

    implicitHeight: icon.implicitHeight + root.titleSlotHeight + Tokens.spacing.small
    property real animatedMaxHeight: root.maxHeight

    states: [
        State {
            name: "notification"
            when: root.isNotificationPushed
            // Shrink to circle — bottom stays locked, shrinks upward
            PropertyChanges { target: musicPill; height: root.musicPillWidth }
            PropertyChanges { target: icon; y: ((root.musicPillWidth - icon.height) / 2) }
        },
        State {
            name: "music"
            when: root.playerActive && !root.isNotificationPushed
            // Center pill vertically: shift it up from the bottom by half the
            // remaining space so it sits in the middle of the available height.
            PropertyChanges {
                target: musicPill
                height: root.musicPillHeight
                // Offset upward from the bottom anchor so it appears centered
                anchors.bottomMargin: Math.max(0, (root.height - root.musicPillHeight) / 2)
            }
            PropertyChanges { target: icon; y: ((root.musicPillHeight - (icon.height + Tokens.spacing.small + windowTitleText.height)) / 2) }
        },
        State {
            name: "default"
            when: !root.playerActive && !root.isNotificationPushed
            // Full height, bottom locked — the pill fills root from top
            PropertyChanges { target: musicPill; height: root.height; anchors.bottomMargin: 0 }
            PropertyChanges { target: icon; y: ((root.height - (icon.height + Tokens.spacing.small + windowTitleText.height)) / 2) }
        }
    ]

    transitions: [
        Transition {
            enabled: root.isLoaded
            // No AnchorAnimation needed — anchor itself never changes, only bottomMargin & height
            Anim { targets: [musicPill]; properties: "height,anchors.bottomMargin"; type: Anim.DefaultSpatial }
            Anim { targets: [icon]; properties: "y"; type: Anim.DefaultSpatial }
        }
    ]

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: false
    }

    MediaThumbnailAccentPicker {
        id: barAccentPicker
        z: -1
    }

    // Top: Notification Pill (flexible, fills available space down to musicPill circle)
    NotificationPill {
        id: notifPill
        bar: root.bar
        anchors.top: parent.top
        anchors.bottom: root.isNotificationPushed ? musicPill.top : undefined
        anchors.bottomMargin: root.isNotificationPushed ? Tokens.spacing.small : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.musicPillWidth
        height: root.isNotificationPushed ? undefined : 0
        opacity: root.isNotificationPushed ? 1 : 0
        visible: opacity > 0.01

        Behavior on anchors.bottomMargin {
            Anim { type: Anim.DefaultSpatial }
        }
    }

    // Bottom: Active Window / Music Pill (shrinks to 48x48 circle at parent.bottom, expands upwards)
    StyledRect {
        id: musicPill

        color: root.pillColor
        radius: Math.min(width / 2, height / 2)
        opacity: root.mediaMorphRendering ? 0 : 1
        visible: true

        Behavior on color {
            CAnim {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.playerActive ? root.musicPillWidth : parent.width

        Behavior on radius {
            Anim { type: Anim.DefaultSpatial }
        }

        property real pillAlpha: 1

        // ── Pill background tint ───────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: musicPill.radius
            color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
            antialiasing: true
            smooth: true
        }

        // ── Ambient Glow (Clipped to pill boundary) ─────────────────────
        StyledClippingRect {
            id: glowClip
            anchors.fill: parent
            radius: musicPill.radius
            color: "transparent"
            opacity: root.playerActive ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveDefaultEffects
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            Repeater {
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
                    radius: d / 2
                    // Center on the artFrame
                    x: artFrame.x + artFrame.width / 2 - d / 2
                    y: artFrame.y + artFrame.height / 2 - d / 2
                    color: Qt.alpha(Qt.darker(root.musicAccent, modelData.dark), modelData.alpha)
                    antialiasing: true
                    layer.enabled: glowClip.opacity > 0.01
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: glowLayer.modelData.bmax
                    }
                }
            }
        }

        Item {
            id: visualizerContainer
            anchors.fill: parent
            
            // Fades in/out smoothly without destroying the item
            visible: opacity > 0.01
            opacity: root.mediaVisualizerActive ? 1 : 0
            Behavior on opacity {
                Anim { type: Anim.DefaultSpatial }
            }

            // Keeps the mask active during the fade-out, fixing the clipping leak!
            layer.enabled: visible
            layer.smooth: true
            layer.effect: OpacityMask {
                maskSource: visualizerMask
            }

            Item {
                id: visualizerMask
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: musicPill.radius
                    color: "black"
                    antialiasing: true
                    smooth: true
                }
            }

            NeonWaveVisualizer {
                anchors.fill: parent
                accentColor: root.musicAccent
                numBands: 32
                maxHeightRatio: 0.76
                topFadeRatio: 0.12
                valueMultiplier: 1.42
                active: root.mediaVisualizerActive && (root.ownsVisualizer || root.mediaMorphCollapsing)
                frameInterval: root.visualizerFrameInterval
            }
        }

        // ── Tap-to-expand — z:0, buttons are z:2 so they get events first ──
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: mouse => {
                mouse.accepted = true;
                root.triggerPillExpand();
            }
        }

            // ── Art + controls — z:2 guarantees events hit buttons first ──
            Item {
                id: controlsRow
                z: 2
                anchors.fill: parent
                opacity: root.playerActive ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim { type: Anim.DefaultSpatial }
                }

                Item {
                    id: artFrame
                    x: (parent.width - width) / 2
                    y: root.isNotificationPushed ? ((parent.height - height) / 2) : 4
                    width: root.musicArtSize
                    height: root.musicArtSize

                    Behavior on y {
                        Anim { type: Anim.DefaultSpatial }
                    }

                    // Ambient glow moved to StyledClippingRect at musicPill level

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        radius: width / 2
                        color: Qt.alpha(Colours.palette.m3shadow, 0.26)
                        antialiasing: true
                        opacity: root.hasMusicArt ? 0.46 : 0.0
                        layer.enabled: opacity > 0.01
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.42)
                            shadowOpacity: 0.34
                            shadowBlur: 0.55
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 2
                        }
                    }

                    Item {
                        id: barArtContainer
                        anchors.fill: parent

                        layer.enabled: true
                        layer.effect: CircleMask {}

                        Rectangle {
                            anchors.fill: parent
                            color: root.hasMusicArt ? Qt.alpha(Players.musicOnSurfaceColor, 0.10) : Qt.alpha(root.musicAccent, 0.22)
                        }

                        Image {
                            id: barArtImage
                            anchors.fill: parent
                            source: root.barArtSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: !root.barArtIsLocal
                            sourceSize: Qt.size(width, height)
                            opacity: status === Image.Ready && source !== "" ? 1 : 0
                            onStatusChanged: {
                                if (status === Image.Ready)
                                    barAccentPicker.scheduleAnalysis();
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: root.hasMusicArt ? Qt.alpha(Players.musicOnSurfaceColor, 0.4) : root.musicOnAccent
                            iconPointSize: Tokens.font.size.normal
                            fill: 1
                            visible: !root.hasMusicArt || barArtImage.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Players.musicOnSurfaceColor, 0.12)
                            antialiasing: true
                        }
                    }
                }

                // Transport controls — smooth slide & fade during circle ↔ pill morph
                Column {
                    id: transportControls
                    anchors.top: parent.top
                    anchors.topMargin: 50
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    opacity: root.isNotificationPushed ? 0 : 1
                    visible: opacity > 0.01

                    Behavior on opacity {
                        Anim { type: transportControls.opacity === 0 ? Anim.FastEffects : Anim.DefaultEffects }
                    }

                    transform: Translate {
                        y: root.isNotificationPushed ? 18 : 0
                        Behavior on y {
                            Anim { type: Anim.DefaultSpatial }
                        }
                    }

                    // prev
                    MorphControlButton {
                        id: prevSkipBtn
                        iconName: "skip_previous"
                        balancedSkipIcon: true
                        skipIconScale: 0.86
                        iconSize: Tokens.font.size.large
                        onClicked: Players.previous()
                    }

                    // play
                    MorphControlButton {
                        id: playPillBtn
                        emphasized: true
                        iconName: root.isMusicPlaying ? "pause" : "play_arrow"
                        iconSize: Tokens.font.size.larger
                        onClicked: Players.togglePlaying()
                    }

                    // next
                    MorphControlButton {
                        id: nextSkipBtn
                        iconName: "skip_next"
                        balancedSkipIcon: true
                        skipIconScale: 0.86
                        iconSize: Tokens.font.size.large
                        onClicked: Players.next()
                    }
                }
            }
            // ── Window info — shown when no music player is active ──
            Item {
                anchors.fill: parent
                opacity: root.playerActive ? 0 : 1
                visible: opacity > 0.01

                Behavior on opacity {
                    Anim { type: parent.opacity === 0 ? Anim.FastEffects : Anim.DefaultEffects }
                }

                MaterialIcon {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    animate: true
                    text: root.isMusicPlaying ? "music_note" : Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
                    color: root.colour
                }

                StyledText {
                    id: windowTitleText
                    anchors.horizontalCenter: icon.horizontalCenter
                    anchors.top: icon.bottom
                    anchors.topMargin: Tokens.spacing.small
                    textPointSize: Tokens.font.size.smaller
                    font.family: Tokens.font.family.mono
                    color: root.colour
                    width: implicitHeight
                    height: implicitWidth
                    visible: opacity > 0.01
                    opacity: (root.playerActive || root.isNotificationPushed) ? 0 : 1

                    Behavior on opacity {
                        Anim { type: windowTitleText.opacity === 0 ? Anim.FastEffects : Anim.DefaultEffects }
                    }

                    transform: [
                        Translate {
                            x: root.Config.bar.activeWindow.inverted ? -windowTitleText.implicitWidth + windowTitleText.implicitHeight : 0
                        },
                        Rotation {
                            angle: root.Config.bar.activeWindow.inverted ? 270 : 90
                            origin.x: windowTitleText.implicitHeight / 2
                            origin.y: windowTitleText.implicitHeight / 2
                        }
                    ]

                    TextMetrics {
                        id: metrics
                        text: root.windowTitle
                        font.pointSize: Tokens.font.size.smaller
                        font.family: Tokens.font.family.mono
                        elide: Qt.ElideRight
                        elideWidth: root.titleSlotHeight
                        onTextChanged: windowTitleText.text = elidedText
                        onElideWidthChanged: windowTitleText.text = elidedText
                    }
                }
            }

        property real pillScale: 1.0

        transform: [
            Scale {
                origin.x: musicPill.width / 2
                origin.y: musicPill.height / 2
                xScale: musicPill.pillScale
                yScale: musicPill.pillScale
            }
        ]

        SequentialAnimation {
            id: pillPressSpring
            NumberAnimation {
                target: musicPill
                property: "pillScale"
                to: 0.94
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastSpatial
            }
            NumberAnimation {
                target: musicPill
                property: "pillScale"
                to: 1.0
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }
    }

    Behavior on implicitWidth {
        Anim { type: Anim.SlowSpatial }
    }
}

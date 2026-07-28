pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    required property var bar
    required property Brightness.Monitor monitor
    readonly property var mediaMorph: root.bar?.mediaMorph
        ?? Players.mediaMorphForScreen(root.bar?.screen?.name ?? "")
    property color colour: Colours.palette.m3primary

    readonly property bool hasMusicPlayer: !!Players.active
    readonly property bool isMusicPlaying: Players.active && Players.activeIsPlaying
    readonly property bool showMusicPill: hasMusicPlayer
    readonly property string musicArtUrl: Players.currentArtUrl
    property string barArtSource: ""
    readonly property bool barArtIsLocal: root.musicArtUrl.startsWith("file:")
        || root.musicArtUrl.startsWith("/")
    readonly property bool hasMusicArt: root.musicArtUrl !== ""
    readonly property color musicAccent: root.showMusicPill
        ? Players.musicVisualizerAccent
        : Colours.palette.m3primaryContainer
    readonly property color musicOnAccent: Players.musicOnAccent
    property color playButtonBg: Colours.palette.m3primary
    property color playIconColor: Colours.palette.m3onPrimary
    property bool _syncingBarAccent: false
    property bool _accentRefreshPending: false
    readonly property int musicPillWidth: 48
    readonly property int musicPillHeight: 160
    readonly property int musicArtSize: 34
    readonly property int musicButtonSize: 30
    readonly property int pillSideMargin: (root.musicPillWidth - root.musicArtSize) / 2

    function refreshAccentColors(): void {
        if (!root.showMusicPill) {
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
            root.barArtSource = "";
            Qt.callLater(() => {
                if (root.musicArtUrl === url)
                    root.barArtSource = url;
            });
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
        CpuProfile.bump("syncMorphDock");
        if (!root.mediaMorph || !root.showMusicPill || root.mediaMorph.active)
            return;
        if (musicPill.width <= 0 || musicPill.height <= 0)
            return;

        const morph = root.mediaMorph;
        const anchor = morph.parent ?? morph;
        const pos = musicPill.mapToItem(anchor, 0, 0);
        const artPos = artFrame.mapToItem(anchor, 0, 0);
        const b1 = prevSkipBtn.mapToItem(anchor, 0, 0);
        const b2 = playPillBtn.mapToItem(anchor, 0, 0);
        const b3 = nextSkipBtn.mapToItem(anchor, 0, 0);

        morph.syncDock(
            pos.x, pos.y, musicPill.width, musicPill.height, root.musicAccent,
            artPos.x - pos.x, artPos.y - pos.y, artFrame.width, artFrame.height,
            b1.x - pos.x, b1.y - pos.y,
            b2.x - pos.x, b2.y - pos.y,
            b3.x - pos.x, b3.y - pos.y,
            root.musicButtonSize
        );
    }

    Timer {
        id: dockSyncDebounce
        interval: 80
        repeat: false
        onTriggered: root.applyMorphDock()
    }

    onWidthChanged: syncMorphDock(false)
    onHeightChanged: syncMorphDock(false)
    onXChanged: syncMorphDock(false)
    onYChanged: syncMorphDock(false)

    function kickDockSync(): void {
        if (!root.showMusicPill || !root.mediaMorph)
            return;
        dockSyncTimer.attempts = 0;
        dockSyncTimer.start();
    }

    function triggerPillExpand(): void {
        dockSyncDebounce.stop();
        dockSyncTimer.stop();
        pillPressSpring.start();
        root.expandMusicMorph();
    }

    function expandMusicMorph(): void {
        if (!root.showMusicPill)
            return;

        const morph = root.bar?.mediaMorph
            ?? Players.mediaMorphForScreen(root.bar?.screen?.name ?? "");
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

        morph.start(
            pos.x, pos.y, musicPill.width, musicPill.height, root.musicAccent,
            artPos.x - pos.x, artPos.y - pos.y, artFrame.width, artFrame.height,
            b1.x - pos.x, b1.y - pos.y,
            b2.x - pos.x, b2.y - pos.y,
            b3.x - pos.x, b3.y - pos.y,
            root.musicButtonSize
        );
    }

    onShowMusicPillChanged: {
        root.syncBarAccent();
        root.kickDockSync();
    }

    onMediaMorphChanged: {
        root.syncBarAccent();
        root.kickDockSync();
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
    }

    Connections {
        target: Players
        function onCurrentArtUrlChanged() {
            root.updateBarArtSource();
            root.syncBarAccent();
        }
        function onCurrentTrackKeyChanged() {
            root.syncBarAccent();
        }
        function onArtReloadNonceChanged() {
            root.updateBarArtSource();
        }
    }

    Timer {
        id: dockSyncTimer
        interval: 50
        repeat: true
        property int attempts: 0

        onTriggered: {
            CpuProfile.bump("dockSyncTimer");
            if (!root.showMusicPill || !root.mediaMorph) {
                stop();
                attempts = 0;
                return;
            }
            root.applyMorphDock();
            attempts++;
            if (root.mediaMorph.dockLayoutReady)
                stop();
            else if (attempts >= 50)
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
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
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
    property Title current: text1

    clip: true
    // Use TextMetrics — Title width/height swap caused implicitWidth ↔ implicitHeight binding recursion.
    implicitWidth: showMusicPill ? root.musicPillWidth : Math.max(icon.implicitWidth, metrics.height)
    implicitHeight: showMusicPill ? root.musicPillHeight
        : Math.min(root.maxHeight, icon.implicitHeight + metrics.width + Tokens.spacing.small)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover && !root.showMusicPill

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MediaThumbnailAccentPicker {
        id: barAccentPicker
        z: -1
    }

    Item {
        id: musicPill

        width: root.musicPillWidth
        height: root.musicPillHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showMusicPill
        property real pillAlpha: 1
        opacity: (root.mediaMorph?.active ?? false) ? 0 : musicPill.pillAlpha

            // ── Pill clip + background ─────────────────────────────────────
            StyledClippingRect {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Players.musicSurfaceColor

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(Colours.palette.m3surfaceTint, 0.08)
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root.isMusicPlaying
                    sourceComponent: Component {
                        NeonWaveVisualizer {
                            anchors.fill: parent
                            accentColor: root.musicAccent
                            numBands: 32
                            maxHeightRatio: 0.8
                            active: root.isMusicPlaying
                            frameInterval: (root.mediaMorph?.active ?? false) ? 16 : 33
                        }
                    }
                }

                // ── Tap-to-expand — z:0, buttons are z:2 so they get events first ──
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.triggerPillExpand()
                    }
                }

                // ── Art + controls — z:2 guarantees events hit buttons first ──
                ColumnLayout {
                    id: controlsRow
                    z: 2
                    anchors.fill: parent
                    anchors.margins: root.pillSideMargin
                    spacing: 2

                    Item {
                        id: artFrame
                        Layout.preferredWidth: root.musicArtSize
                        Layout.preferredHeight: root.musicArtSize
                        Layout.minimumWidth: root.musicArtSize
                        Layout.minimumHeight: root.musicArtSize
                        Layout.alignment: Qt.AlignHCenter

                        StyledClippingRect {
                            anchors.fill: parent
                            radius: width / 2
                            clip: true
                            color: root.hasMusicArt
                                ? Qt.alpha(Players.musicOnSurfaceColor, 0.10)
                                : Qt.alpha(root.musicAccent, 0.22)

                            Image {
                                id: barArtImage
                                anchors.fill: parent
                                source: root.barArtSource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: !root.barArtIsLocal
                                sourceSize: Qt.size(width, height)
                                opacity: status === Image.Ready && source !== "" ? 1 : 0
                                onStatusChanged: { if (status === Image.Ready) barAccentPicker.scheduleAnalysis(); }
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "music_note"
                                color: root.hasMusicArt
                                    ? Qt.alpha(Players.musicOnSurfaceColor, 0.4)
                                    : root.musicOnAccent
                                iconPointSize: Tokens.font.size.normal
                                fill: 1
                                visible: !root.hasMusicArt || barArtImage.status !== Image.Ready
                            }
                        }
                    }

                    // prev — referenced by id in morph sync (artFrame shifts child indices)
                    MorphControlButton {
                        id: prevSkipBtn
                        iconName: "skip_previous"
                        iconSize: Tokens.font.size.large
                        onClicked: Players.previous()
                    }

                    // play — emphasized to match the card's compact play button
                    MorphControlButton {
                        id: playPillBtn
                        emphasized: true
                        spinning: root.isMusicPlaying
                        iconName: root.isMusicPlaying ? "pause" : "play_arrow"
                        iconSize: Tokens.font.size.larger
                        onClicked: Players.togglePlaying()
                    }

                    // next
                    MorphControlButton {
                        id: nextSkipBtn
                        iconName: "skip_next"
                        iconSize: Tokens.font.size.large
                        onClicked: Players.next()
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

    MaterialIcon {
        id: icon

        visible: !root.showMusicPill
        anchors.horizontalCenter: parent.horizontalCenter

        animate: true
        text: root.isMusicPlaying ? "music_note" : Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
        visible: !root.showMusicPill
    }

    Title {
        id: text2
        visible: !root.showMusicPill
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font.pixelSize: Math.max(10, Math.round(root.Tokens.font.size.smaller * 96 / 72))
        font.family: root.Tokens.font.family.mono
        elide: Qt.ElideRight
        elideWidth: root.maxHeight - icon.height

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    component Title: StyledText {
        id: text

        visible: !root.showMusicPill
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.top: icon.bottom
        anchors.topMargin: Tokens.spacing.small

        textPointSize: metrics.font.pixelSize * 72 / 96
        font.family: metrics.font.family
        color: root.colour
        opacity: root.current === this ? 1 : 0

        transform: [
            Translate {
                x: root.Config.bar.activeWindow.inverted
                    ? -metrics.width + metrics.height : 0
            },
            Rotation {
                angle: root.Config.bar.activeWindow.inverted ? 270 : 90
                origin.x: metrics.height / 2
                origin.y: metrics.height / 2
            }
        ]

        width: metrics.height
        height: metrics.width

        Behavior on opacity {
            Anim {}
        }
    }

}

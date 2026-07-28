pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Olvex
import Olvex.Config
import Olvex.Services
import qs.components
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
    readonly property bool isMusicPlaying: Players.active && (Players.active.playbackStatus === "Playing" || Players.active.playbackState === 0 || Players.active.isPlaying)
    readonly property bool showMusicPill: hasMusicPlayer
    readonly property string musicArtUrl: Players.active ? Players.getArtUrl(Players.active) : ""
    property string barArtSource: ""
    readonly property bool barArtIsLocal: root.musicArtUrl.startsWith("file:")
        || root.musicArtUrl.startsWith("/")
    readonly property bool hasMusicArt: root.musicArtUrl !== ""
    readonly property color musicAccent: root.showMusicPill
        ? Players.musicVisualizerAccent
        : Colours.palette.m3primaryContainer
    readonly property color musicOnAccent: Players.musicOnAccent
    readonly property color playButtonBg: root.showMusicPill
        ? barAccentPicker.playButtonBg
        : Colours.palette.m3primary
    readonly property color playIconColor: root.showMusicPill
        ? barAccentPicker.playIconColor
        : Qt.rgba(0, 0, 0, 0.92)
    readonly property int musicPillWidth: 48
    readonly property int musicPillHeight: 160
    readonly property int musicArtSize: 34
    readonly property int musicButtonSize: 30
    readonly property int pillSideMargin: (root.musicPillWidth - root.musicArtSize) / 2

    function syncBarAccent(): void {
        if (!Players.active) {
            barAccentPicker.setArtUrl("");
            return;
        }
        barAccentPicker.setArtUrl(Players.getArtUrl(Players.active));
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
        const b1 = controlsRow.children[0].mapToItem(anchor, 0, 0);
        const b2 = controlsRow.children[1].mapToItem(anchor, 0, 0);
        const b3 = controlsRow.children[2].mapToItem(anchor, 0, 0);

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
        const b1 = controlsRow.children[0].mapToItem(anchor, 0, 0);
        const b2 = controlsRow.children[1].mapToItem(anchor, 0, 0);
        const b3 = controlsRow.children[2].mapToItem(anchor, 0, 0);

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

    onMusicArtUrlChanged: {
        root.updateBarArtSource();
        root.syncBarAccent();
    }

    onMediaMorphChanged: {
        root.syncBarAccent();
        root.kickDockSync();
    }

    Component.onCompleted: {
        root.updateBarArtSource();
        root.syncBarAccent();
        root.kickDockSync();
    }

    Connections {
        target: Players
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
        target: Players.active
        enabled: Players.active !== null
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root.syncBarAccent();
        }
        function onTrackArtUrlChanged() {
            root.syncBarAccent();
        }
        function onTrackArtistChanged() {
            root.syncBarAccent();
        }
        function onTrackAlbumChanged() {
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
    implicitWidth: showMusicPill ? root.musicPillWidth : Math.max(icon.implicitWidth, current.implicitHeight)
    implicitHeight: showMusicPill ? root.musicPillHeight : icon.implicitHeight + current.implicitWidth + current.anchors.topMargin

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
        opacity: !(root.mediaMorph?.active ?? false) ? musicPill.pillAlpha : 0

        StyledClippingRect {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.96)
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

            // Expand on any non-button pill body hit (buttons sit above in ColumnLayout)
            StateLayer {
                anchors.fill: parent
                radius: parent.width / 2
                showHoverBackground: false
                onClicked: root.triggerPillExpand()
            }

            ColumnLayout {
                id: pillRow

                anchors.fill: parent
                anchors.margins: (root.musicPillWidth - root.musicArtSize) / 2
                spacing: 8

                Item {
                    id: artFrame

                    Layout.preferredWidth: root.musicArtSize
                    Layout.preferredHeight: root.musicArtSize
                    Layout.minimumWidth: root.musicArtSize
                    Layout.minimumHeight: root.musicArtSize

                    StyledClippingRect {
                        anchors.fill: parent
                        radius: width / 2
                        clip: true
                        color: root.hasMusicArt
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.hsla(root.musicAccent.hslHue,
                                root.musicAccent.hslSaturation,
                                root.musicAccent.hslLightness * 0.75, 1)

                        Image {
                            id: barArtImage
                            anchors.fill: parent
                            source: root.barArtSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: !root.barArtIsLocal
                            opacity: status === Image.Ready && source !== "" ? 1 : 0

                            onStatusChanged: {
                                if (status === Image.Ready)
                                    barAccentPicker.scheduleAnalysis();
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: root.hasMusicArt
                                ? Qt.rgba(1, 1, 1, 0.4)
                                : root.musicOnAccent
                            font.pointSize: Tokens.font.size.normal
                            visible: !root.hasMusicArt || barArtImage.status !== Image.Ready
                        }
                    }
                }

                ColumnLayout {
                    id: controlsRow

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter

                    MediaButton {
                        iconName: "skip_previous"
                        onClicked: Players.previous()
                    }

                    MediaButton {
                        iconName: root.isMusicPlaying ? "pause" : "play_arrow"
                        filled: true
                        onClicked: Players.togglePlaying()
                    }

                    MediaButton {
                        iconName: "skip_next"
                        onClicked: Players.next()
                    }
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
                to: 0.93
                duration: 70
                easing.type: Easing.OutCubic
            }
            SpringAnimation {
                target: musicPill
                property: "pillScale"
                to: 1.0
                spring: 4.2
                damping: 0.38
                epsilon: 0.05
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
        font.pointSize: root.Tokens.font.size.smaller
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

        font.pointSize: metrics.font.pointSize
        font.family: metrics.font.family
        color: root.colour
        opacity: root.current === this ? 1 : 0

        transform: [
            Translate {
                x: root.Config.bar.activeWindow.inverted ? -text.implicitWidth + text.implicitHeight : 0
            },
            Rotation {
                angle: root.Config.bar.activeWindow.inverted ? 270 : 90
                origin.x: text.implicitHeight / 2
                origin.y: text.implicitHeight / 2
            }
        ]

        width: implicitHeight
        height: implicitWidth

        Behavior on opacity {
            Anim {}
        }
    }

    component MediaButton: Rectangle {
        id: button

        signal clicked()
        required property string iconName
        property bool filled

        Layout.preferredWidth: root.musicButtonSize
        Layout.preferredHeight: root.musicButtonSize
        Layout.minimumWidth: root.musicButtonSize
        Layout.minimumHeight: root.musicButtonSize
        Layout.maximumWidth: root.musicButtonSize
        Layout.maximumHeight: root.musicButtonSize
        Layout.alignment: Qt.AlignHCenter
        clip: true
        radius: filled ? (root.isMusicPlaying ? 10 : width / 2) : width / 2
        color: button.filled ? root.playButtonBg : "transparent"

        MaterialIcon {
            id: baseIcon
            anchors.centerIn: parent
            visible: !button.filled
            text: button.iconName
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: parent.width
            height: parent.height
            fill: 0
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.large
            font.weight: 500
            animate: true
        }

        Item {
            id: filledVisual
            visible: button.filled
            anchors.centerIn: parent
            width: 16
            height: 16

            opacity: 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // Match expanded card style: rotation animation
            MaterialIcon {
                id: filledPlayIcon
                anchors.fill: parent
                anchors.margins: 0
                text: button.iconName
                color: root.playIconColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                animate: true
                animateProp: "rotation"
                animateFrom: 90
                animateTo: 0
                animateDuration: 400
            }
        }

        // Minimal icon-change animation: fade out -> fade in
        SequentialAnimation {
            id: iconChangeAnimOutlined
            NumberAnimation { target: baseIcon; property: "opacity"; to: 0.3; duration: 100 }
            NumberAnimation { target: baseIcon; property: "opacity"; to: 1.0; duration: 150 }
        }

        onIconNameChanged: {
            // trigger both; only the visible one will show the effect
            if (!button.filled)
                iconChangeAnimOutlined.start();
        }
        
        Behavior on radius {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Press animation to match lockscreen: small spring/back scale
        ScaleAnimator {
            id: mediaPressAnim
            target: button
            from: 0.88
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
            running: false
        }

        StateLayer {
            id: stateLayer
            radius: button.radius
            showHoverBackground: button.filled
            showRipple: false
            onClicked: {
                // play press animation then emit clicked
                mediaPressAnim.running = true
                button.clicked()
            }
        }

        // Rotation animations for filled icons (minimal lockscreen-style rotate)
        SequentialAnimation {
            id: filledPlayRotateAnim
            NumberAnimation { target: filledPlayIcon; property: "rotation"; to: 180; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: filledPlayIcon; property: "rotation"; to: 0; duration: 220; easing.type: Easing.OutElastic; easing.overshoot: 0.6 }
        }

        SequentialAnimation {
            id: filledPauseRotateAnim
            NumberAnimation { target: filledPlayIcon; property: "rotation"; to: 180; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: filledPlayIcon; property: "rotation"; to: 0; duration: 220; easing.type: Easing.OutElastic; easing.overshoot: 0.6 }
        }
    }
}

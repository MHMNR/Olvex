pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import M3Shapes
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
    readonly property int offset: 500    // px off-screen start for horizontal
    readonly property int vOffset: 200   // px off-screen start for vertical

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
        anchors.topMargin: 24

        implicitWidth: topBarRow.implicitWidth
        implicitHeight: 48
        clip: false
        transform: Translate { id: topBarTrans; y: -root.vOffset }

        Row {
            id: topBarRow
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // ── Music Pill (left) ──────────────────────────────────────────────
            Rectangle {
                id: musicPill
                z: 10
                anchors.top: parent.top
                anchors.topMargin: 0
                width: 48; height: 48; radius: 24
                clip: true
                transform: Translate { id: musicMomentum; x: 0; y: 0 }
                
                // Sleek Material Card Background
                color: GlobalConfig.lock.minimalOpacity === 1 ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.current.m3surface, GlobalConfig.lock.minimalOpacity)
                state: expanded ? "expanded" : "compact"
                property bool expanded: false

                TapHandler { onTapped: musicPill.expanded = !musicPill.expanded }

                // ── SHARED ELEMENTS ──────────────────────────────────────

                // Album art
                Rectangle {
                    id: musicIcon
                    width: 34; height: 34; radius: 17
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    anchors.left: parent.left
                    anchors.leftMargin: 8

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: ShaderEffectSource {
                            live: true
                            hideSource: true
                            sourceItem: Rectangle {
                                width: musicIcon.width
                                height: musicIcon.height
                                radius: musicIcon.radius
                                color: "black"
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: Players.active ? Players.getArtUrl(Players.active) : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                    MaterialIcon {
                        id: musicPlaceholderIcon
                        anchors.centerIn: parent
                        text: "music_note"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        iconPointSize: 14
                        visible: !Players.active || parent.children[0].status !== Image.Ready
                    }
                }

                // Track Info (Fixed coordinates, Zero movement fade)
                Column {
                    id: trackInfo
                    width: 188
                    spacing: 2
                    anchors.left: parent.left
                    anchors.top: parent.top
                    // Compact: Hidden behind/next to icon
                    // Expanded: x: 145, y: 32
                    anchors.leftMargin: 145
                    anchors.topMargin: 32
                    opacity: 0
                    visible: opacity > 0

                    StyledText {
                        width: parent.width
                        text: Players.active ? (Players.active.trackTitle || "Unknown Title") : "Nothing Playing"
                        color: Qt.rgba(1, 1, 1, 0.95); textPointSize: Tokens.font.size.normal
                        font.weight: Font.SemiBold; elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft
                    }
                    StyledText {
                        width: parent.width
                        text: Players.active ? (Players.active.trackArtist || "Unknown Artist") : ""
                        color: Qt.rgba(1, 1, 1, 0.50); textPointSize: Tokens.font.size.small
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft
                    }
                }

                // Controls Row (Absolute Positioning)
                Row {
                    id: controlsRow
                    spacing: 40
                    anchors.left: parent.left
                    anchors.top: parent.top
                    // Compact: x: 52, y: 8
                    // Expanded: x: 100, y: 105 (Horizontal Center of card)
                    anchors.leftMargin: 52
                    anchors.topMargin: 8

                    Rectangle {
                        id: prevBtnContainer
                        width: playBtn.width; height: playBtn.height; radius: width/2; color: "transparent"
                        MaterialIcon {
                            id: prevBtn
                            anchors.centerIn: parent
                            text: "skip_previous"
                            color: Players.active ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.25)
                            iconPointSize: 13
                        }
                        StateLayer { enabled: Players.active !== null; onClicked: Players.previous(); radius: parent.radius }
                    }

                    Rectangle {
                        id: playBtn
                        width: 32; height: 32
                        radius: (Players.active && Players.active.isPlaying) ? (musicPill.expanded ? 14 : 10) : height / 2
                        color: Players.active ? Colours.palette.m3primary : "transparent"
                        clip: true

                        // Force clipping to respect radius even for StateLayer
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                live: true
                                hideSource: true
                                sourceItem: Rectangle {
                                    width: playBtn.width
                                    height: playBtn.height
                                    radius: playBtn.radius
                                    color: "black"
                                }
                            }
                        }

                        Behavior on radius {
                            // Disable during expansion to prevent "ghost morph"
                            enabled: !(musicPill.width > 185 && musicPill.width < 335)
                            NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                        }

                        MaterialIcon {
                            id: playIcon
                            anchors.centerIn: parent
                            text: (Players.active && Players.active.isPlaying) ? "pause" : "play_arrow"
                            color: Players.active ? ((Players.active.isPlaying) ? Colours.palette.m3onPrimary : Qt.alpha(Colours.palette.m3onPrimary, 0.7)) : "white"
                            iconPointSize: 16

                            animate: true
                            animateProp: "rotation"
                            animateFrom: 90
                            animateTo: 0
                            animateDuration: 400
                        }
                        StateLayer { radius: parent.radius; enabled: Players.active !== null; onClicked: Players.togglePlaying() }
                    }

                    Rectangle {
                        id: nextBtnContainer
                        width: playBtn.width; height: playBtn.height; radius: width/2; color: "transparent"
                        MaterialIcon {
                            id: nextBtn
                            anchors.centerIn: parent
                            text: "skip_next"
                            color: Players.active ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.25)
                            iconPointSize: 13
                        }
                        StateLayer { enabled: Players.active !== null; onClicked: Players.next(); radius: parent.radius }
                    }
                }

                // ── STATES & TRANSITIONS ─────────────────────────────────
                states: [
                    State {
                        name: "compact"
                        PropertyChanges { target: musicPill; width: 180; height: 48; radius: 24 }
                        PropertyChanges { target: musicIcon; width: 34; height: 34; radius: 17; anchors.leftMargin: 8; anchors.topMargin: 7 }
                        PropertyChanges { target: trackInfo; opacity: 0; anchors.leftMargin: 145; anchors.topMargin: 32 }
                        PropertyChanges { target: controlsRow; spacing: 8; anchors.leftMargin: 52; anchors.topMargin: 8 }
                        PropertyChanges { target: playBtn; width: 32; height: 32 }
                        PropertyChanges { target: playIcon; iconPointSize: 16 }
                        PropertyChanges { target: prevBtn; iconPointSize: 14 }
                        PropertyChanges { target: nextBtn; iconPointSize: 14 }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges { target: musicPill; width: 340; height: 160; radius: 28 }
                        PropertyChanges { target: musicIcon; width: 108; height: 108; radius: 26; anchors.leftMargin: 24; anchors.topMargin: 26 }
                        PropertyChanges { target: trackInfo; opacity: 1; anchors.leftMargin: 148; anchors.topMargin: 32 }
                        PropertyChanges { target: controlsRow; spacing: 18; anchors.leftMargin: 136; anchors.topMargin: 92 }
                        PropertyChanges { target: playBtn; width: 48; height: 48; color: Players.active ? Colours.current.palette.m3primary : "transparent" }
                        PropertyChanges { target: playIcon; iconPointSize: 24 }
                        PropertyChanges { target: prevBtn; iconPointSize: 20 }
                        PropertyChanges { target: nextBtn; iconPointSize: 20 }
                    }
                ]

                transitions: [
                    Transition {
                        from: "compact"; to: "expanded"
                        ParallelAnimation {
                            // Width expands snappier first
                            SpringAnimation {
                                targets: [musicPill, musicIcon, playBtn]
                                property: "width"
                                spring: 5.5; damping: 0.35; epsilon: 0.1
                            }
                            // Height delay: expands vertically second to create beautiful horizontal-then-vertical fluid morphing
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    targets: [musicPill, musicIcon, playBtn]
                                    property: "height"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Radius matches the height animation timeline
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    targets: [musicPill, musicIcon]
                                    property: "radius"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Internal geometry details
                            SequentialAnimation {
                                PauseAnimation { duration: 50 }
                                SpringAnimation {
                                    targets: [musicPill, musicIcon, playIcon, trackInfo, controlsRow, playBtn]
                                    properties: "anchors.leftMargin,anchors.topMargin,spacing,textPointSize"
                                    spring: 4.0; damping: 0.45; epsilon: 0.1
                                }
                            }
                            ColorAnimation { target: playBtn; duration: 350 }
                            // Stagger content fade-in to prevent visual clutter
                            SequentialAnimation {
                                PauseAnimation { duration: 180 }
                                NumberAnimation { targets: [trackInfo, controlsRow]; property: "opacity"; duration: 250; easing.type: Easing.OutQuint }
                            }
                        }
                    },
                    Transition {
                        from: "expanded"; to: "compact"
                        ParallelAnimation {
                            // Content fades out instantly
                            NumberAnimation { target: trackInfo; property: "opacity"; duration: 100; easing.type: Easing.OutQuint }
                            // Height collapses vertically first
                            SpringAnimation {
                                targets: [musicPill, musicIcon, playBtn]
                                property: "height"
                                spring: 5.5; damping: 0.40; epsilon: 0.1
                            }
                            SpringAnimation {
                                targets: [musicPill, musicIcon]
                                property: "radius"
                                spring: 5.5; damping: 0.40; epsilon: 0.1
                            }
                            // Width delay: collapses horizontally second to create spectacular retracting effect
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    targets: [musicPill, musicIcon, playBtn]
                                    property: "width"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Internal geometry details
                            SequentialAnimation {
                                PauseAnimation { duration: 40 }
                                SpringAnimation {
                                    targets: [musicPill, musicIcon, playIcon, trackInfo, controlsRow, playBtn]
                                    properties: "anchors.leftMargin,anchors.topMargin,spacing,textPointSize"
                                    spring: 4.5; damping: 0.45; epsilon: 0.1
                                }
                            }
                            ColorAnimation { target: playBtn; duration: 350 }
                        }
                    }
                ]
            }

            // System Pill
            Rectangle {
                id: systemPill
                implicitWidth: statsRow.implicitWidth + 48
                implicitHeight: 48
                radius: height / 2
                
                // Sleek Material Card Background
                color: GlobalConfig.lock.minimalOpacity === 1 ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.current.m3surface, GlobalConfig.lock.minimalOpacity)

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
                width: 48; height: 48; radius: 24
                clip: true
                transform: Translate { id: notifMomentum; x: 0; y: 0 }
                
                // Sleek Material Card Background
                color: GlobalConfig.lock.minimalOpacity === 1 ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.current.m3surface, GlobalConfig.lock.minimalOpacity)
                state: expanded ? "expanded" : "compact"
                property bool expanded: false



                // ── SHARED HEADER ────────────────────────────────────────
                Row {
                    id: notifHeaderRow
                    anchors.top: parent.top
                    anchors.topMargin: 6 // (48 - 36) / 2
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    spacing: 12
                    z: 20

                    TapHandler { onTapped: notifPill.expanded = !notifPill.expanded }

                    Item {
                        id: notifIconBox
                        width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.08); border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                        }
                        MaterialIcon {
                            id: mainNotifIcon
                            anchors.centerIn: parent; text: "notifications"
                            color: (notifPill.expanded || Notifs.notClosed.length > 0) ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.3)
                            iconPointSize: 15
                        }
                        Rectangle {
                            id: notifBadge
                            width: 18; height: 18; radius: 9; color: Colours.current.m3primary
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: -2; anchors.rightMargin: -2
                            visible: Notifs.notClosed.length > 0 && !notifPill.expanded
                            StyledText { anchors.centerIn: parent; text: Notifs.notClosed.length > 9 ? "9+" : Notifs.notClosed.length.toString(); color: Colours.current.m3onPrimary; textPointSize: 7; font.bold: true }
                        }
                    }

                    StyledText {
                        id: notifLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.notClosed.length === 0 ? "No Notifications" : (Notifs.notClosed.length + (Notifs.notClosed.length === 1 ? " New Notification" : " New Notifications"))
                        color: (notifPill.expanded || Notifs.notClosed.length > 0) ? Qt.rgba(1, 1, 1, 0.90) : Qt.rgba(1, 1, 1, 0.40)
                        textPointSize: Tokens.font.size.normal - 1; font.weight: Font.Medium
                    }
                }

                // ── EXPANDED LIST (Scrollable) ───────────────────────────
                ListView {
                    id: notifList
                    anchors.top: notifHeaderRow.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 16; anchors.topMargin: 10; spacing: 8
                    opacity: 0; visible: opacity > 0
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    model: Notifs.notClosed

                    // Android-style Stretch Logic
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

                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width; height: 58
                        Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(1, 1, 1, 0.05) }
                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Rectangle { width: 32; height: 32; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.10); MaterialIcon { anchors.centerIn: parent; text: "info"; color: Qt.rgba(1, 1, 1, 0.5); iconPointSize: 14 } }
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

                // ── STATES & TRANSITIONS ─────────────────────────────────
                states: [
                    State {
                        name: "compact"
                        PropertyChanges { target: notifPill; width: (notifHeaderRow.width + 16); height: 48; radius: 24 }
                        PropertyChanges { target: mainNotifIcon; iconPointSize: 15 }
                        PropertyChanges { target: notifLabel; font.weight: Font.Medium; textPointSize: Tokens.font.size.normal - 1 }
                        PropertyChanges { target: notifList; opacity: 0 }
                        PropertyChanges { target: notifBadge; opacity: 1 }
                        PropertyChanges { target: notifHeaderRow; anchors.topMargin: 6; anchors.leftMargin: 7 }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges { 
                            target: notifPill
                            width: 340
                            height: Math.min(320, Math.max(120, Notifs.notClosed.length * 66 + 64))
                            radius: 28
                        }
                        PropertyChanges { target: mainNotifIcon; iconPointSize: 14 }
                        PropertyChanges { target: notifLabel; font.weight: Font.SemiBold }
                        PropertyChanges { target: notifList; opacity: 1 }
                        PropertyChanges { target: notifBadge; opacity: 0 }
                        PropertyChanges { target: notifHeaderRow; anchors.topMargin: 16; anchors.leftMargin: 16 }
                    }
                ]
                transitions: [
                    Transition {
                        from: "compact"; to: "expanded"
                        ParallelAnimation {
                            // Width expands snappier first
                            SpringAnimation {
                                target: notifPill
                                property: "width"
                                spring: 5.5; damping: 0.35; epsilon: 0.1
                            }
                            // Height delay: expands vertically second to create horizontal-then-vertical fluid morphing
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    target: notifPill
                                    property: "height"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Radius matches the height animation timeline
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    target: notifPill
                                    property: "radius"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Internal geometry details
                            SequentialAnimation {
                                PauseAnimation { duration: 50 }
                                SpringAnimation {
                                    target: notifPill
                                    properties: "anchors.topMargin,anchors.leftMargin"
                                    spring: 4.0; damping: 0.45; epsilon: 0.1
                                }
                            }
                            NumberAnimation { properties: "opacity,textPointSize,font.letterSpacing"; duration: 250; easing.type: Easing.OutQuint }
                        }
                    },
                    Transition {
                        from: "expanded"; to: "compact"
                        ParallelAnimation {
                            // Height collapses vertically first
                            SpringAnimation {
                                target: notifPill
                                property: "height"
                                spring: 5.5; damping: 0.40; epsilon: 0.1
                            }
                            SpringAnimation {
                                target: notifPill
                                property: "radius"
                                spring: 5.5; damping: 0.40; epsilon: 0.1
                            }
                            // Width delay: collapses horizontally second to create spectacular retracting effect
                            SequentialAnimation {
                                PauseAnimation { duration: 80 }
                                SpringAnimation {
                                    target: notifPill
                                    property: "width"
                                    spring: 4.2; damping: 0.45; epsilon: 0.1
                                }
                            }
                            // Internal geometry details
                            SequentialAnimation {
                                PauseAnimation { duration: 40 }
                                SpringAnimation {
                                    target: notifPill
                                    properties: "anchors.topMargin,anchors.leftMargin"
                                    spring: 4.5; damping: 0.45; epsilon: 0.1
                                }
                            }
                            NumberAnimation { properties: "opacity,textPointSize,font.letterSpacing"; duration: 200; easing.type: Easing.OutQuint }
                        }
                    }
                ]
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
            leftMargin: 100
            rightMargin: 80
        }

        spacing: 0

        // Clock + Date block (left half)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            transform: Translate { id: clockTrans; x: -root.offset }

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 32
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
                    color: GlobalConfig.lock.minimalOpacity === 1 ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.current.m3surface, GlobalConfig.lock.minimalOpacity)
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

                        // Spinning 12-sided ring
                        MaterialShape {
                            id: avatarRing
                            anchors.fill: parent
                            z: 0
                            implicitSize: 100
                            shape: MaterialShape.Cookie12Sided
                            color: Colours.layer(Colours.palette.m3primaryContainer, 1)

                            Anim on rotation {
                                running: true
                                from: 360
                                to: 0
                                duration: 20000
                                easing.type: Easing.Linear
                                loops: Animation.Infinite
                            }
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

                                Anim on rotation {
                                    running: true
                                    from: 360
                                    to: 0
                                    duration: 20000
                                    easing.type: Easing.Linear
                                    loops: Animation.Infinite
                                }
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
                            font.weight: Font.SemiBold
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
        anchors.bottomMargin: 48

        implicitWidth: actRow.implicitWidth + 32
        implicitHeight: actRow.implicitHeight + 20
        transform: Translate { id: bottomBarTrans; y: root.vOffset }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: GlobalConfig.lock.minimalOpacity === 1 ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.current.m3surface, GlobalConfig.lock.minimalOpacity)
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
                font.weight: Font.SemiBold
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
}

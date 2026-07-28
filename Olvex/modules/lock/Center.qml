pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: 0

    // ── Entrance/Exit Animations ─────────────────────────────────────────────
    Connections {
        target: root.lock
        function onContentReadyChanged(): void {
            if (root.lock.contentReady) entranceAnim.start()
        }
        function onUnlockingChanged(): void {
            if (root.lock.unlocking) {
                entranceAnim.stop()
                exitAnim.restart()
            } else {
                exitAnim.stop()
                // reset positions for next lock
                clockTrans.y = -800
                authTrans.y = 800
            }
        }
    }

    ParallelAnimation {
        id: entranceAnim
        
        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation { 
                target: clockTrans
                property: "y"
                from: -800
                to: 0
                duration: 900
                easing.type: Easing.OutBack
                easing.overshoot: 0.7
            }
        }
        
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { 
                target: authTrans
                property: "y"
                from: 800
                to: 0
                duration: 900
                easing.type: Easing.OutBack
                easing.overshoot: 0.7
            }
        }
    }

    ParallelAnimation {
        id: exitAnim
        
        NumberAnimation { target: clockTrans; property: "y"; to: -800; duration: 700; easing.type: Easing.InExpo }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: authTrans; property: "y"; to: 800; duration: 700; easing.type: Easing.InExpo }
        }
    }

    // ── Clock & Date (Top Aligned) ──────────────────────────────────────────
    ColumnLayout {
        id: clockCol
        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
        Layout.topMargin: 20
        spacing: Tokens.spacing.small
        
        transform: Translate { id: clockTrans; y: -800 }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            StyledText {
                text: Time.hourStr
                color: Colours.current.m3onSurface
                textPointSize: Math.floor(Tokens.font.size.extraLarge * 4.0 * root.centerScale)
                font.family: Tokens.font.family.clock
                font.bold: true
            }

            StyledText {
                text: ":"
                color: Colours.current.m3primary
                textPointSize: Math.floor(Tokens.font.size.extraLarge * 4.0 * root.centerScale)
                font.family: Tokens.font.family.clock
                font.bold: true
            }

            StyledText {
                text: Time.minuteStr
                color: Colours.current.m3primary
                textPointSize: Math.floor(Tokens.font.size.extraLarge * 4.0 * root.centerScale)
                font.family: Tokens.font.family.clock
                font.bold: true
            }

            Loader {
                asynchronous: true
                active: GlobalConfig.services.useTwelveHourClock
                visible: active
                sourceComponent: StyledText {
                    text: Time.amPmStr
                    color: Colours.current.m3primary
                    textPointSize: Math.floor(Tokens.font.size.extraLarge * 1.8 * root.centerScale)
                    font.family: Tokens.font.family.clock
                    font.bold: true
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd, d MMMM yyyy")
            color: Colours.current.m3onSurfaceVariant
            textPointSize: Math.floor(Tokens.font.size.extraLarge * 1.2 * root.centerScale)
            font.family: Tokens.font.family.mono
            font.bold: true
        }
    }

    // ── Spacer to push auth card to bottom ──────────────────────────────────
    Item {
        Layout.fillHeight: true
    }

    // ── Messages Area ────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.large
        implicitHeight: Math.max(message.implicitHeight, stateMessage.implicitHeight)

        StyledText {
            id: stateMessage
            anchors.centerIn: parent
            width: parent.width
            readonly property string msg: {
                if (Hypr.kbLayout !== Hypr.defaultKbLayout) return qsTr("Kb layout: %1").arg(Hypr.kbLayoutFull);
                if (Hypr.capsLock) return qsTr("Caps lock is ON.");
                return "";
            }
            text: msg
            opacity: msg ? 1 : 0
            color: Colours.current.m3onSurfaceVariant
            font.family: Tokens.font.family.mono
            horizontalAlignment: Qt.AlignHCenter
            Behavior on opacity { Anim {} }
        }

        StyledText {
            id: message
            anchors.centerIn: parent
            width: parent.width
            readonly property Pam pam: root.lock.pam
            text: pam.passwd.message || pam.fprint.message || ""
            opacity: text ? 1 : 0
            color: Colours.current.m3error
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.mono
            horizontalAlignment: Qt.AlignHCenter
            Behavior on opacity { Anim {} }
        }
    }

    // ── Auth Card (Bottom Aligned) ──────────────────────────────────────────
    Rectangle {
        id: authCard
        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.bottomMargin: 0
        
        transform: Translate { id: authTrans; y: 800 }
        
        implicitWidth: 360
        implicitHeight: authContent.implicitHeight + Tokens.padding.large * 2
        
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        
        ColumnLayout {
            id: authContent
            anchors.centerIn: parent
            spacing: Tokens.spacing.large

            // ── Spinning Cookie Avatar (matches dashboard & minimal lockscreen) ──
            Item {
                id: avatarHost
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 100
                implicitHeight: 100

                // Outer spinning ring
                MaterialShape {
                    id: avatarRing
                    anchors.fill: parent
                    z: 0
                    implicitSize: 100
                    shape: MaterialShape.Cookie12Sided
                    color: Colours.layer(Colours.current.m3primaryContainer, 1)

                    Anim on rotation {
                        running: true
                        from: 360
                        to: 0
                        duration: 20000
                        easing.type: Easing.Linear
                        loops: Animation.Infinite
                    }
                }

                // Invisible spinning mask (clips pfp + fallback icon)
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

                // Fallback — shown when no .face image
                Item {
                    id: avatarFallback
                    anchors.fill: parent
                    visible: pfp.status !== Image.Ready
                    z: 1
                    layer.enabled: true
                    layer.effect: Mask {
                        maskSource: avatarMaskWrap
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        implicitSize: 72
                        shape: MaterialShape.Circle
                        color: Qt.alpha(Colours.current.m3surface, 0.2)
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "person"
                        color: Colours.current.m3onSurfaceVariant
                        iconPointSize: 40
                    }
                }

                // Profile picture clipped to spinning Cookie mask
                CachingImage {
                    id: pfp
                    anchors.fill: parent
                    z: 1
                    path: `${Paths.home}/.face`
                    layer.enabled: true
                    layer.effect: Mask {
                        maskSource: avatarMaskWrap
                    }
                }
            }

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 300
                implicitHeight: input.implicitHeight + Tokens.padding.small * 2
                color: Qt.alpha(Colours.current.m3surfaceContainerLowest, 0.6) // Darker, more distinct shade
                radius: Tokens.rounding.full

                StateLayer {
                    onClicked: parent.forceActiveFocus()
                    hoverEnabled: false
                    cursorShape: Qt.IBeamCursor
                }

                RowLayout {
                    id: input
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.normal

                    Item {
                        implicitWidth: implicitHeight
                        implicitHeight: fprintIcon.implicitHeight + Tokens.padding.small * 2

                        MaterialIcon {
                            id: fprintIcon
                            anchors.centerIn: parent
                            animate: true
                            text: {
                                if (root.lock.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries)
                                    return "fingerprint_off";
                                if (root.lock.pam.fprint.active)
                                    return "fingerprint";
                                return "lock";
                            }
                            color: root.lock.pam.fprint.tries >= GlobalConfig.lock.maxFprintTries ? Colours.current.m3error : Qt.rgba(1, 1, 1, 0.45)
                            opacity: root.lock.pam.passwd.active ? 0 : 1
                            Behavior on opacity { Anim {} }
                        }

                        CircularIndicator {
                            anchors.fill: parent
                            running: root.lock.pam.passwd.active
                        }
                    }

                    InputField {
                        id: inputField
                        pam: root.lock.pam
                    }

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: enterIcon.implicitHeight + Tokens.padding.small * 2
                        color: root.lock.pam.buffer ? Colours.current.m3primary : Qt.rgba(1, 1, 1, 0.10)
                        radius: Tokens.rounding.full

                        StateLayer {
                            color: root.lock.pam.buffer ? Colours.current.m3onPrimary : Colours.current.m3onSurface
                            onClicked: root.lock.pam.passwd.start()
                        }

                        MaterialIcon {
                            id: enterIcon
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            color: root.lock.pam.buffer ? Colours.current.m3onPrimary : Qt.rgba(1, 1, 1, 0.55)
                            font.weight: 500
                        }
                    }
                }
            }
        }
    }
}

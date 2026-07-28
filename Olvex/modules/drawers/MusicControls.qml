pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import Olvex.Services
import qs.components
import qs.utils

Row {
    id: root
    spacing: 8

    property bool playing: Players.active?.isPlaying ?? false

    signal previousRequested()
    signal playPauseToggled()
    signal nextRequested()

    // ── helper: shared animated icon button ──────────────────
    component MusicBtn: Item {
        id: btn
        implicitWidth: 44
        implicitHeight: 44

        property string iconName: ""
        property bool   active: false
        signal tapped()

        StateLayer {
            id: sl
            anchors.fill: parent
            anchors.margins: -4
            radius: Tokens.rounding.normal
            hoverEnabled: true
            onClicked: {
                bounceAnim.start()
                btn.tapped()
            }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 10
            color: sl.containsMouse || btn.active
                ? Colours.layer(Colours.palette.m3surfaceVariant, 0.8)
                : "transparent"
            border.color: sl.containsMouse || btn.active
                ? Qt.alpha(Colours.palette.m3onSurface, 0.12)
                : "transparent"
            border.width: 1

            scale: sl.containsMouse ? 1.12 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            Behavior on color       { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            MaterialIcon {
                id: micon
                text: btn.iconName
                anchors.fill: parent
                anchors.margins: 10
                color: btn.active
                    ? Colours.palette.m3primary
                    : Colours.palette.m3onSurface

                Behavior on color { ColorAnimation { duration: 150 } }

                SequentialAnimation {
                    id: bounceAnim
                    ScaleAnimator {
                        target: micon; from: 1.0; to: 1.35
                        duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.3
                    }
                    ScaleAnimator {
                        target: micon; from: 1.35; to: 1.0
                        duration: 180; easing.type: Easing.OutElastic; easing.overshoot: 0.5
                    }
                }
            }
        }
    }

    // ── Previous ─────────────────────────────────────────────
    MusicBtn {
        iconName: "skip_previous"
        onTapped: {
            slideAnim.from = 0; slideAnim.to = -5; slideAnim.running = true
            root.previousRequested()
            Players.previous()
        }

        NumberAnimation {
            id: slideAnim
            target: parent; property: "x"
            duration: 120; easing.type: Easing.OutQuad
            onFinished: {
                if (slideAnim.to === -5) { slideAnim.from = -5; slideAnim.to = 0; slideAnim.running = true }
            }
        }
    }

    // ── Play / Pause ──────────────────────────────────────────
    Item {
        implicitWidth: 52
        implicitHeight: 52

        StateLayer {
            id: playSL
            anchors.fill: parent
            anchors.margins: -4
            radius: Tokens.rounding.normal
            hoverEnabled: true
            onClicked: {
                playPressAnim.running = true
                root.playing = !root.playing
                root.playPauseToggled()
                Players.togglePlaying()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.alpha(Colours.palette.m3primary, playSL.containsMouse ? 0.95 : 1.0)
            border.color: Qt.alpha(Colours.palette.m3primary, 0.3)
            border.width: 1

            scale: playSL.containsMouse ? 1.08 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }

            ScaleAnimator on scale {
                id: playPressAnim
                running: false
                from: 0.88; to: 1.0
                duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4
            }

            // Play icon
            MaterialIcon {
                text: "play_arrow"
                anchors.fill: parent
                anchors.margins: 12
                color: Colours.palette.m3onPrimary

                opacity: root.playing ? 0.0 : 1.0
                scale:   root.playing ? 0.5 : 1.0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            }

            // Pause icon
            MaterialIcon {
                text: "pause"
                anchors.fill: parent
                anchors.margins: 12
                color: Colours.palette.m3onPrimary

                opacity: root.playing ? 1.0 : 0.0
                scale:   root.playing ? 1.0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            }
        }
    }

    // ── Next ──────────────────────────────────────────────────
    MusicBtn {
        iconName: "skip_next"
        onTapped: {
            slideNextAnim.from = 0; slideNextAnim.to = 5; slideNextAnim.running = true
            root.nextRequested()
            Players.next()
        }

        NumberAnimation {
            id: slideNextAnim
            target: parent; property: "x"
            duration: 120; easing.type: Easing.OutQuad
            onFinished: {
                if (slideNextAnim.to === 5) { slideNextAnim.from = 5; slideNextAnim.to = 0; slideNextAnim.running = true }
            }
        }
    }
}

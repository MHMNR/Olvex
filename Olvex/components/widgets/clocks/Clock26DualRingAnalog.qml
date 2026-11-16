import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Concentric Dark, 1: Tonal Core
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real dialSize: Math.round(172 * clockScale)
    readonly property color outerBg: Colours.palette.m3surfaceContainerHigh
    readonly property color innerBg: variant === 0
        ? Colours.palette.m3surfaceContainerHighest
        : Colours.palette.m3primaryContainer
    readonly property color handCol: variant === 0
        ? root.primaryColor
        : Colours.palette.m3onPrimaryContainer

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: root.outerBg

        // Outer 12 dot markers
        Repeater {
            model: 12
            Item {
                anchors.fill: parent
                rotation: index * 30

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(root.dialSize * 0.06)
                    width: (index % 3 === 0) ? Math.max(4, Math.round(root.dialSize * 0.04)) : Math.max(2, Math.round(root.dialSize * 0.02))
                    height: width
                    radius: width / 2
                    color: index === 0 ? root.tertiaryColor : Qt.alpha(root.onSurfaceColor, index % 3 === 0 ? 0.72 : 0.30)
                }
            }
        }

        // Inner concentric tonal ring
        StyledRect {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.68)
            height: width
            radius: width / 2
            color: root.innerBg
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: root.dialSize * 0.24
            handWidth: Math.max(4, root.dialSize * 0.056)
            handColor: root.handCol
            slotColor: root.innerBg
        }

        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: root.dialSize * 0.35
            handWidth: Math.max(3, root.dialSize * 0.04)
            handColor: root.variant === 0 ? root.onSurfaceColor : root.handCol
            slotColor: root.innerBg
        }

        ContinuousSecondHand {
            handLength: root.dialSize * 0.40
            handWidth: Math.max(1.5, 2 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, Math.round(root.dialSize * 0.07))
            height: width
            radius: width / 2
            color: root.tertiaryColor
        }
    }
}


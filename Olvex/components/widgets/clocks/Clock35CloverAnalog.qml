import QtQuick
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: 8-Leaf Clover, 1: Puffy Cloud
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real dialSize: Math.round(172 * clockScale)
    readonly property color dialBg: variant === 0
        ? root.surfaceColor
        : Colours.palette.m3secondaryContainer
    readonly property color handCol: variant === 0
        ? root.primaryColor
        : Colours.palette.m3onSecondaryContainer

    implicitWidth: dialSize
    implicitHeight: dialSize

    MaterialShape {
        anchors.fill: parent
        implicitSize: root.dialSize
        color: root.dialBg
        shape: root.variant === 0 ? MaterialShape.Clover8Leaf : MaterialShape.Puffy
    }

    Repeater {
        model: 4
        Item {
            anchors.fill: parent
            rotation: index * 90

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(root.dialSize * 0.13)
                width: Math.max(4, Math.round(root.dialSize * 0.04))
                height: width
                radius: width / 2
                color: index === 0 ? root.tertiaryColor : Qt.alpha(root.handCol, 0.6)
            }
        }
    }

    SlottedHand {
        angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
        handLength: root.dialSize * 0.24
        handWidth: Math.max(4, root.dialSize * 0.056)
        handColor: root.handCol
        slotColor: root.dialBg
    }

    SlottedHand {
        angleDeg: Time.minutes * 6 + Time.seconds * 0.1
        handLength: root.dialSize * 0.35
        handWidth: Math.max(3, root.dialSize * 0.042)
        handColor: root.handCol
        slotColor: root.dialBg
    }

    ContinuousSecondHand {
        handLength: root.dialSize * 0.39
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


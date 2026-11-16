import QtQuick
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Soft Burst, 1: Tonal Flower, 2: 4-Leaf Clover
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real dialSize: Math.round(172 * clockScale)
    readonly property color shapeColor: variant === 1
        ? Colours.palette.m3primaryContainer
        : Colours.palette.m3surfaceContainerHigh
    readonly property color handColor: variant === 1
        ? Colours.palette.m3onPrimaryContainer
        : root.primaryColor

    implicitWidth: dialSize
    implicitHeight: dialSize

    MaterialShape {
        id: petalDial
        anchors.fill: parent
        implicitSize: root.dialSize
        color: root.shapeColor
        shape: {
            if (root.variant === 1) return MaterialShape.Flower;
            if (root.variant === 2) return MaterialShape.Clover4Leaf;
            return MaterialShape.SoftBurst;
        }
    }

    // Minimalist M3 cardinal dot markers
    Repeater {
        model: 4
        Item {
            anchors.fill: parent
            rotation: index * 90

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(root.dialSize * 0.12)
                width: Math.max(4, Math.round(root.dialSize * 0.042))
                height: width
                radius: width / 2
                color: index === 0 ? root.tertiaryColor : Qt.alpha(root.handColor, 0.55)
            }
        }
    }

    SlottedHand {
        angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
        handLength: root.dialSize * 0.25
        handWidth: Math.max(4, root.dialSize * 0.062)
        handColor: root.handColor
        slotColor: root.shapeColor
    }

    SlottedHand {
        angleDeg: Time.minutes * 6 + Time.seconds * 0.1
        handLength: root.dialSize * 0.36
        handWidth: Math.max(3.5, root.dialSize * 0.046)
        handColor: root.handColor
        slotColor: root.shapeColor
    }

    ContinuousSecondHand {
        handLength: root.dialSize * 0.39
        handWidth: Math.max(1.5, 2.2 * root.clockScale)
        handColor: root.tertiaryColor
        active: root.visible
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(6, Math.round(root.dialSize * 0.075))
        height: width
        radius: width / 2
        color: root.tertiaryColor
    }
}


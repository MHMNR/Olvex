import QtQuick
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Sunny, 1: Gem
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real dialSize: Math.round(172 * clockScale)
    readonly property color dialColor: variant === 0
        ? Colours.palette.m3surfaceContainerHigh
        : Colours.palette.m3secondaryContainer
    readonly property color handColor: variant === 0
        ? root.primaryColor
        : Colours.palette.m3onSecondaryContainer

    implicitWidth: dialSize
    implicitHeight: dialSize

    MaterialShape {
        anchors.fill: parent
        implicitSize: root.dialSize
        color: root.dialColor
        shape: root.variant === 0 ? MaterialShape.Sunny : MaterialShape.Gem
    }

    // 12 minimalist radial tick pills
    Repeater {
        model: 12
        Item {
            anchors.fill: parent
            rotation: index * 30

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(root.dialSize * 0.14)
                width: (index % 3 === 0) ? Math.max(3, Math.round(root.dialSize * 0.028)) : Math.max(2, Math.round(root.dialSize * 0.016))
                height: (index % 3 === 0) ? Math.round(root.dialSize * 0.075) : Math.round(root.dialSize * 0.04)
                radius: width / 2
                color: index === 0 ? root.tertiaryColor : Qt.alpha(root.handColor, index % 3 === 0 ? 0.78 : 0.35)
            }
        }
    }

    // Chunky pill hour hand
    Item {
        anchors.fill: parent
        rotation: (Time.hours % 12) * 30 + Time.minutes * 0.5
        Behavior on rotation {
            Anim { duration: Tokens.anim.durations.normal }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height + width / 2
            width: Math.max(5, Math.round(root.dialSize * 0.056))
            height: Math.round(root.dialSize * 0.25)
            radius: width / 2
            color: root.handColor
        }
    }

    // Sleek minute hand
    Item {
        anchors.fill: parent
        rotation: Time.minutes * 6 + Time.seconds * 0.1
        Behavior on rotation {
            Anim { duration: Tokens.anim.durations.normal }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height + width / 2
            width: Math.max(3.5, Math.round(root.dialSize * 0.036))
            height: Math.round(root.dialSize * 0.35)
            radius: width / 2
            color: root.handColor
        }
    }

    ContinuousSecondHand {
        handLength: root.dialSize * 0.38
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


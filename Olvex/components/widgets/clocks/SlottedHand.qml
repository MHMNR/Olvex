import QtQuick
import qs.services

Item {
    id: root

    property real angleDeg: 0
    property real handLength: 70
    property real handWidth: 12
    property color handColor: Colours.palette.m3primary
    property color slotColor: Colours.palette.m3surfaceContainerHigh
    property bool hollow: false

    width: Math.max(4, handWidth)
    height: Math.max(10, handLength)
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.verticalCenter : undefined
    transformOrigin: Item.Bottom
    rotation: angleDeg

    Behavior on rotation {
        SpringAnimation {
            spring: 4.5
            damping: 0.42
            modulus: 360
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: -root.width * 0.28
        radius: width / 2
        color: root.hollow ? Qt.alpha(root.handColor, 0.22) : root.handColor
        border.width: 0

        Rectangle {
            visible: !root.hollow
            width: Math.max(2, parent.width * 0.34)
            height: parent.height * 0.52
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.14
            color: root.slotColor
        }
    }
}


pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.services

// Compact vertical battery glyph for the bar status stack.
// API: percentage (0–1), charging, color, animate — unchanged for SystemPill.
Item {
    id: root

    property real percentage: 0
    property bool charging: false
    property color color: Colours.palette.m3onSurfaceVariant
    property bool animate: true

    // Optical box ~ same footprint as a Material icon at normal size
    implicitWidth: 12
    implicitHeight: 18

    readonly property color fillColor: {
        if (root.charging)
            return Colours.palette.m3primary;
        if (root.percentage < 0.15)
            return Colours.palette.m3error;
        if (root.percentage < 0.25)
            return Colours.palette.m3tertiary;
        return root.color;
    }

    // Cap
    Rectangle {
        id: cap
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.38
        height: 1.5
        radius: 0.75
        color: root.color
        opacity: 0.75
    }

    // Body
    Rectangle {
        id: body
        anchors.top: cap.bottom
        anchors.topMargin: 1
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        radius: 2.5
        border.width: 1.25
        border.color: root.color
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1.25
            radius: 1.5
            color: root.color
            opacity: 0.08
        }

        Rectangle {
            id: fillRect
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1.25
            anchors.left: parent.left
            anchors.leftMargin: 1.25
            anchors.right: parent.right
            anchors.rightMargin: 1.25
            height: Math.max(2, (parent.height - 2.5) * Math.min(1, Math.max(0.06, root.percentage)))
            radius: 1.25
            color: root.fillColor

            Behavior on height {
                enabled: root.animate
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on color {
                enabled: root.animate
                ColorAnimation {
                    duration: 400
                }
            }
        }

        MaterialIcon {
            visible: root.charging
            anchors.centerIn: parent
            text: "bolt"
            iconPointSize: 7
            color: Colours.palette.m3onPrimary
            fill: 1
        }
    }
}

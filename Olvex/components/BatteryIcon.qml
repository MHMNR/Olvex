pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config

Item {
    id: root

    property real percentage: 0
    property bool charging: false
    property color color: Colours.palette.m3secondary
    property bool animate: true

    implicitWidth: 14
    implicitHeight: 24

    // Cap
    Rectangle {
        id: cap
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.4
        height: 2
        radius: 1
        color: root.color
        opacity: 0.8
    }

    // Body
    Rectangle {
        id: body
        anchors.top: cap.bottom
        anchors.topMargin: 1
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        radius: 3
        border.width: 1.5
        border.color: root.color
        color: "transparent"

        // Fill background (slight tint)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1.5
            radius: 2
            color: root.color
            opacity: 0.1
        }

        // Fill
        Rectangle {
            id: fillRect
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1.5
            anchors.left: parent.left
            anchors.leftMargin: 1.5
            anchors.right: parent.right
            anchors.rightMargin: 1.5
            
            // Ensure a minimum height for the radius to look right
            height: Math.max(radius * 1, (parent.height - 3) * Math.min(1, Math.max(0.05, root.percentage)))
            radius: 1.5
            
            color: {
                if (root.charging) return "#34C759" // macOS Green
                if (root.percentage < 0.15) return "#FF3B30" // macOS Red
                if (root.percentage < 0.25) return "#FFCC00" // macOS Yellow
                return root.color
            }

            Behavior on height {
                enabled: root.animate
                NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
            }
            
            Behavior on color {
                enabled: root.animate
                ColorAnimation { duration: 500 }
            }
        }

        // Charging Indicator (Bolt)
        Text {
            visible: root.charging
            anchors.centerIn: parent
            text: "bolt"
            font.family: Tokens.font.family.material
            font.pixelSize: 10
            color: "white"
            
            // Slight shadow to make it pop
            layer.enabled: true
        }
    }
}

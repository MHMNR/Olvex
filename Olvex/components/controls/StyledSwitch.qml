import QtQuick
import QtQuick.Shapes
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

Switch {
    id: root

    property int cLayer: 1

    implicitWidth: implicitIndicatorWidth
    implicitHeight: implicitIndicatorHeight

    indicator: StyledRect {
        id: indicator
        radius: Tokens.rounding.full
        
        color: {
            if (!root.enabled) return "transparent"
            return root.checked ? Colours.palette.m3primary : "transparent"
        }
        
        border.width: root.checked ? 0 : 2
        border.color: Colours.palette.m3outline

        implicitWidth: 52
        implicitHeight: 32

        StyledRect {
            id: thumb
            readonly property real nonAnimWidth: root.checked ? 24 : 16
            readonly property real margin: (parent.implicitHeight - nonAnimWidth) / 2

            radius: Tokens.rounding.full
            color: {
                if (!root.enabled) return Qt.alpha(Colours.palette.m3onSurface, 0.38)
                return root.checked ? Qt.tint("#ffffff", Qt.alpha(Colours.palette.m3primary, 0.1)) : Colours.palette.m3outline
            }

            x: root.checked ? parent.implicitWidth - nonAnimWidth - margin : margin
            implicitWidth: nonAnimWidth
            implicitHeight: nonAnimWidth
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on x { Anim { type: Anim.DefaultSpatial } }
            Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
            Behavior on color { ColorAnimation { duration: 200 } }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.checked ? "check" : "close"
                color: root.checked ? Colours.palette.m3primary : Colours.palette.m3surface
                iconPointSize: parent.implicitWidth * 0.45
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // Ripple/Hover Effect
        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurface
            opacity: root.pressed ? 0.1 : root.hovered ? 0.08 : 0
            Behavior on opacity { Anim {} }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }
}

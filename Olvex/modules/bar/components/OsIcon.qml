import QtQuick
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: Tokens.sizes.bar.innerWidth

    // Track state for interaction animations
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed

    // macOS-style rounded square background matching dock/launcher items
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        radius: pressed ? 11 : width / 2
        color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
        border.width: 1

        // Premium shrink-on-click and bounce-on-hover interaction animations
        scale: hovered ? 1.08 : 1.0

        Behavior on radius {
            Anim { type: Anim.FastSpatial }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const visibilities = Visibilities.getForActive();
                visibilities.launcher = !visibilities.launcher;
            }
        }

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            sourceComponent: SysInfo.isDefaultLogo ? olvexLogo : distroIcon
        }
    }

    Component {
        id: olvexLogo

        Logo {
            implicitWidth: Math.round(Tokens.font.size.large * 1.5)
            implicitHeight: Math.round(Tokens.font.size.large * 1.5)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Tokens.font.size.large * 1.2)
            colour: Colours.palette.m3tertiary
        }
    }
}


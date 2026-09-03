import QtQuick
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    property DrawerVisibilities visibilities: null
    readonly property bool isLauncherOpen: visibilities ? visibilities.launcher : (Visibilities.getForActive() ? Visibilities.getForActive().launcher : false)

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: Tokens.sizes.bar.innerWidth

    // Track state for interaction animations
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed

    // macOS-style rounded square background matching dock/launcher items
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        radius: isLauncherOpen ? 11 : (pressed ? 10 : (hovered ? 13 : width / 2))
        color: isLauncherOpen ? Colours.palette.m3primary : (pressed ? Colours.layer(Colours.palette.m3surfaceVariant, 0.8) : (hovered ? Colours.layer(Colours.palette.m3surfaceVariant, 0.65) : Colours.layer(Colours.palette.m3surfaceVariant, 0.5)))
        border.color: "transparent"
        border.width: 0

        // Premium shrink-on-click and bounce-on-hover interaction animations
        scale: pressed ? 0.90 : (hovered ? 1.08 : (isLauncherOpen ? 1.04 : 1.0))

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
            anchors.bottomMargin: -Tokens.padding.large
            anchors.leftMargin: -Tokens.padding.large
            anchors.rightMargin: -Tokens.padding.large
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const v = root.visibilities ?? Visibilities.getForActive();
                if (v)
                    v.launcher = !v.launcher;
            }
        }

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            sourceComponent: distroIcon
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
            colour: root.isLauncherOpen ? Colours.palette.m3onPrimary : Colours.palette.m3tertiary
            Behavior on colour {
                ColorAnimation { duration: 150 }
            }
        }
    }
}


import QtQuick
import Olvex
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

    // Move MouseArea to root level so hover hit area remains stable during scale animation
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const v = root.visibilities ?? Visibilities.getForActive();
            if (v)
                v.launcher = !v.launcher;
        }
    }

    readonly property color fgColor: root.isLauncherOpen 
        ? Colours.palette.m3onPrimary 
        : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3primary)

    readonly property color bgColor: root.isLauncherOpen 
        ? Colours.palette.m3primary 
        : Colours.tileSurface

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        transformOrigin: Item.Center
        radius: Tokens.rounding.full
        color: root.bgColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3onSurface
            opacity: root.pressed ? 0.14 : (root.hovered ? 0.08 : 0)
            visible: !root.isLauncherOpen
            antialiasing: true
            smooth: true

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // Premium shrink-on-click and bounce-on-hover interaction animations
        scale: pressed ? 0.90 : (hovered ? 1.08 : (isLauncherOpen ? 1.04 : 1.0))

        Behavior on radius {
            Anim { type: Anim.FastSpatial }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (SysInfo.isOlvexLogo)
                    return olvexLogo;
                if (SysInfo.hasCustomImage)
                    return customImageIcon;
                return glyphIcon;
            }
        }
    }

    Component {
        id: olvexLogo

        Item {
            anchors.fill: parent

            Logo {
                anchors.centerIn: parent
                implicitWidth: Math.round(Tokens.font.size.large * 1.65)
                implicitHeight: Math.round(Tokens.font.size.large * 1.38)
                topColour: root.isLauncherOpen ? Colours.palette.m3onPrimary : (Colours.light ? Colours.palette.m3primary : Colours.palette.m3primary)
                bottomColour: root.isLauncherOpen ? Colours.palette.m3onPrimary : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3tertiary)
            }
        }
    }

    Component {
        id: glyphIcon

        Item {
            anchors.fill: parent

            Text {
                id: glyphText
                anchors.centerIn: parent
                // Dynamic pixel-accurate optical center calculated from font metrics in CUtils
                anchors.horizontalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphHOffset === "function") ? CUtils.glyphHOffset(text, font.pixelSize, font.family) : 0.0
                anchors.verticalCenterOffset: (typeof CUtils !== "undefined" && typeof CUtils.glyphVOffset === "function") ? CUtils.glyphVOffset(text, font.pixelSize, font.family) : 0.0
                text: SysInfo.osGlyph || "\uf31a"
                color: root.fgColor
                font.family: Tokens.font.family.mono
                font.pixelSize: Math.round(Tokens.font.size.large * 1.35)
                renderType: Text.QtRendering
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    Component {
        id: customImageIcon

        Item {
            anchors.fill: parent

            ColouredIcon {
                anchors.centerIn: parent
                source: SysInfo.osLogo
                implicitSize: Math.round(Tokens.font.size.large * 1.2)
                colour: root.fgColor
                Behavior on colour {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }
}


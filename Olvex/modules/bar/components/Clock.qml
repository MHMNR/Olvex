pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color accentColour: Colours.palette.m3tertiary
    readonly property color mutedColour: Colours.palette.m3onSurfaceVariant
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.normal : Tokens.padding.small

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    // Match SystemPill glass language (tonal fill when background on)
    color: Config.bar.clock.background
        ? Colours.tPalette.m3surfaceContainer
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full
    border.width: 1
    border.color: hoverArea.containsMouse
        ? Qt.alpha(root.accentColour, 0.32)
        : Qt.alpha(Colours.palette.m3outlineVariant, 0.14)
    scale: hoverArea.containsMouse ? 1.02 : 1.0

    // Light shadow only — depth mostly from rim + sheen (same as status stack)
    layer.enabled: Config.bar.clock.background
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.35)
        shadowBlur: 0.28
        shadowVerticalOffset: 2
        shadowOpacity: hoverArea.containsMouse ? 0.4 : 0.22
    }

    Behavior on scale {
        SpringAnimation {
            spring: 4.2
            damping: 0.7
            mass: 1.0
            epsilon: 0.005
        }
    }

    Behavior on border.color {
        CAnim {}
    }

    // Soft top sheen — pairs with SystemPill
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 1
        }
        height: Math.min(parent.height * 0.26, 28)
        radius: parent.radius
        visible: Config.bar.clock.background || hoverArea.containsMouse
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.alpha(Colours.palette.m3onSurface, 0.07)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.04)
        visible: Config.bar.clock.background
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.smaller


        // Date — a quiet caption; the time below is the hero.
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: Config.bar.clock.showDate

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format("ddd\nd")
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.sans
            font.letterSpacing: 0.4
            color: root.mutedColour
        }

        // Soft fading hairline instead of a flat divider.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Config.bar.clock.showDate
            width: parent.width * 0.72
            height: visible ? 1 : 0

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.alpha(root.accentColour, 0.0)
                    }
                    GradientStop {
                        position: 0.5
                        color: Qt.alpha(root.accentColour, 0.4)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.alpha(root.accentColour, 0.0)
                    }
                }
            }
        }

        // Time — the hero: bigger, bolder, accent-coloured, with a subtle
        // tick pulse on every minute change (StyledText's built-in `animate`).
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            animate: true
            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh\nmm\nA" : "hh\nmm")
            textPointSize: Tokens.font.size.normal
            font.family: Tokens.font.family.mono
            font.weight: Font.DemiBold
            color: root.accentColour
        }
    }
}

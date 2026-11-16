import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Trio, 1: Surface Stack
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale
    readonly property real gap: Math.round(8 * s)

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: Math.round(216 * s)
    implicitHeight: Math.round(134 * s)

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        // Left: Oversized Hour Tile
        StyledRect {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(112 * root.s)
            radius: Math.round(26 * root.s)
            color: root.variant === 0
                ? Colours.palette.m3primaryContainer
                : Colours.palette.m3surfaceContainerHigh

            StyledText {
                anchors.centerIn: parent
                text: Time.hourStr
                color: root.variant === 0
                    ? Colours.palette.m3onPrimaryContainer
                    : root.primaryColor
                textPointSize: Math.max(16, Math.round(48 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
            }
        }

        // Right: Stacked Minute + Date/Seconds Tiles
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: root.gap

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.round(22 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3secondaryContainer
                    : Colours.palette.m3surfaceContainerHighest

                StyledText {
                    anchors.centerIn: parent
                    text: Time.minuteStr
                    color: root.variant === 0
                        ? Colours.palette.m3onSecondaryContainer
                        : root.onSurfaceColor
                    textPointSize: Math.max(12, Math.round(30 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Bold
                }
            }

            StyledRect {
                visible: root.showDatePill
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(38 * root.s)
                radius: height / 2
                color: root.variant === 0
                    ? Colours.palette.m3tertiaryContainer
                    : root.primaryColor

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Math.round(5 * root.s)

                    StyledRect {
                        width: Math.max(4, Math.round(6 * root.s))
                        height: width
                        radius: width / 2
                        color: root.variant === 0
                            ? Colours.palette.m3onTertiaryContainer
                            : Colours.palette.m3onPrimary
                        opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.35
                        Behavior on opacity {
                            Anim { duration: Tokens.anim.durations.small }
                        }
                    }

                    StyledText {
                        text: Time.format("ddd d").toUpperCase()
                        color: root.variant === 0
                            ? Colours.palette.m3onTertiaryContainer
                            : Colours.palette.m3onPrimary
                        textPointSize: Math.max(7, Math.round(10 * root.s))
                        font.weight: Font.Bold
                        font.letterSpacing: 0.7 * root.s
                    }
                }
            }
        }
    }
}


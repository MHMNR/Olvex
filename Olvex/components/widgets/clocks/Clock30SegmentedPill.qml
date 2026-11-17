import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Segments, 1: Surface Segments
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Math.round(8 * root.s)

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(4 * root.s)

            // Left outer pill (Hour)
            StyledRect {
                width: Math.round(68 * root.s)
                height: Math.round(66 * root.s)
                topLeftRadius: Math.round(33 * root.s)
                bottomLeftRadius: Math.round(33 * root.s)
                topRightRadius: Math.round(8 * root.s)
                bottomRightRadius: Math.round(8 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3primaryContainer
                    : root.surfaceColor

                StyledText {
                    anchors.centerIn: parent
                    text: Time.hourStr
                    color: root.variant === 0 ? Colours.palette.m3onPrimaryContainer : root.primaryColor
                    textPointSize: Math.max(12, Math.round(28 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }
            }

            // Middle block (Minute)
            StyledRect {
                width: Math.round(68 * root.s)
                height: Math.round(66 * root.s)
                radius: Math.round(8 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3secondaryContainer
                    : root.surfaceHighColor

                StyledText {
                    anchors.centerIn: parent
                    text: Time.minuteStr
                    color: root.variant === 0 ? Colours.palette.m3onSecondaryContainer : root.onSurfaceColor
                    textPointSize: Math.max(12, Math.round(28 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }
            }

            // Right outer pill (Seconds)
            StyledRect {
                width: Math.round(54 * root.s)
                height: Math.round(66 * root.s)
                topLeftRadius: Math.round(8 * root.s)
                bottomLeftRadius: Math.round(8 * root.s)
                topRightRadius: Math.round(33 * root.s)
                bottomRightRadius: Math.round(33 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3tertiaryContainer
                    : Colours.palette.m3primaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: String(Time.seconds).padStart(2, "0")
                    color: root.variant === 0 ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onPrimaryContainer
                    textPointSize: Math.max(10, Math.round(20 * root.s))
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Bold
                }
            }
        }

        StyledText {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            text: (Time.format("dddd") + " • " + Time.format("d MMM")).toUpperCase()
            color: root.secondaryColor
            textPointSize: Math.max(6, Math.round(9 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1 * root.s
        }
    }
}


import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Surface, 1: Accent Flap
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.88 * clockScale

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
            spacing: Math.round(8 * root.s)

            // Hour Flap Tile
            StyledRect {
                width: Math.round(92 * root.s)
                height: Math.round(104 * root.s)
                radius: Math.round(20 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3surfaceContainerHigh
                    : Colours.palette.m3primaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: Time.hourStr
                    color: root.variant === 0
                        ? root.primaryColor
                        : Colours.palette.m3onPrimaryContainer
                    textPointSize: Math.max(16, Math.round(44 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }

                // Split-flap horizontal seam
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(1.5, Math.round(2 * root.s))
                    color: Colours.palette.m3surfaceContainerLowest
                    opacity: 0.65
                }
            }

            // Minute Flap Tile
            StyledRect {
                width: Math.round(92 * root.s)
                height: Math.round(104 * root.s)
                radius: Math.round(20 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3surfaceContainerHigh
                    : Colours.palette.m3secondaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: Time.minuteStr
                    color: root.variant === 0
                        ? root.onSurfaceColor
                        : Colours.palette.m3onSecondaryContainer
                    textPointSize: Math.max(16, Math.round(44 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }

                // Split-flap horizontal seam
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(1.5, Math.round(2 * root.s))
                    color: Colours.palette.m3surfaceContainerLowest
                    opacity: 0.65
                }
            }
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(dateRow.implicitWidth + 18 * root.s)
            implicitHeight: Math.round(dateRow.implicitHeight + 6 * root.s)
            radius: height / 2
            color: Colours.palette.m3surfaceContainerHighest

            RowLayout {
                id: dateRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.s)

                StyledRect {
                    width: Math.max(4, Math.round(5.5 * root.s))
                    height: width
                    radius: width / 2
                    color: root.tertiaryColor
                    opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.35
                    Behavior on opacity {
                        Anim { duration: Tokens.anim.durations.small }
                    }
                }

                StyledText {
                    text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                    color: root.onSurfaceColor
                    textPointSize: Math.max(6, Math.round(8.5 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9 * root.s
                }
            }
        }
    }
}


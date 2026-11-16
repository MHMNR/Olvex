import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Staggered Capsules, 1: Split Stadium
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: variant === 0 ? staggeredCol.implicitWidth : stadiumCol.implicitWidth
    implicitHeight: variant === 0 ? staggeredCol.implicitHeight : stadiumCol.implicitHeight

    // Variant 0: Staggered M3 Capsules
    Column {
        id: staggeredCol
        anchors.centerIn: parent
        visible: root.variant === 0
        spacing: Math.round(8 * root.s)

        StyledRect {
            x: 0
            width: Math.round(166 * root.s)
            height: Math.round(62 * root.s)
            radius: height / 2
            color: Colours.palette.m3primaryContainer

            RowLayout {
                anchors.centerIn: parent
                spacing: Math.round(10 * root.s)

                StyledText {
                    text: Time.hourStr
                    color: Colours.palette.m3onPrimaryContainer
                    textPointSize: Math.max(14, Math.round(34 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }

                StyledText {
                    visible: root.showDatePill
                    text: Time.format("ddd").toUpperCase()
                    color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.72)
                    textPointSize: Math.max(7, Math.round(11 * root.s))
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2 * root.s
                }
            }
        }

        StyledRect {
            x: Math.round(28 * root.s)
            width: Math.round(166 * root.s)
            height: Math.round(62 * root.s)
            radius: height / 2
            color: Colours.palette.m3tertiaryContainer

            RowLayout {
                anchors.centerIn: parent
                spacing: Math.round(10 * root.s)

                StyledRect {
                    width: Math.max(5, Math.round(7 * root.s))
                    height: width
                    radius: width / 2
                    color: Colours.palette.m3onTertiaryContainer
                    opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.3
                    Behavior on opacity {
                        Anim { duration: Tokens.anim.durations.small }
                    }
                }

                StyledText {
                    text: Time.minuteStr
                    color: Colours.palette.m3onTertiaryContainer
                    textPointSize: Math.max(14, Math.round(34 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }

                StyledText {
                    text: Time.amPmStr || Time.format("AP")
                    color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.72)
                    textPointSize: Math.max(7, Math.round(10 * root.s))
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Variant 1: Side-by-Side Split Stadium
    ColumnLayout {
        id: stadiumCol
        anchors.centerIn: parent
        visible: root.variant === 1
        spacing: Math.round(8 * root.s)

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(8 * root.s)

            StyledRect {
                width: Math.round(92 * root.s)
                height: Math.round(74 * root.s)
                radius: height / 2
                color: Colours.palette.m3surfaceContainerHigh

                StyledText {
                    anchors.centerIn: parent
                    text: Time.hourStr
                    color: root.primaryColor
                    textPointSize: Math.max(14, Math.round(34 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }
            }

            StyledRect {
                width: Math.round(92 * root.s)
                height: Math.round(74 * root.s)
                radius: height / 2
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: Time.minuteStr
                    color: Colours.palette.m3onSecondaryContainer
                    textPointSize: Math.max(14, Math.round(34 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }
            }
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(dateTxt.implicitWidth + 18 * root.s)
            implicitHeight: Math.round(dateTxt.implicitHeight + 6 * root.s)
            radius: height / 2
            color: Colours.palette.m3surfaceContainerHighest

            StyledText {
                id: dateTxt
                anchors.centerIn: parent
                text: (Time.format("dddd") + " • " + Time.format("d MMM")).toUpperCase()
                color: root.onSurfaceColor
                textPointSize: Math.max(6, Math.round(8.5 * root.s))
                font.weight: Font.DemiBold
                font.letterSpacing: 1.0 * root.s
            }
        }
    }
}


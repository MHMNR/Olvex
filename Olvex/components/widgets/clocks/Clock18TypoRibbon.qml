import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Horizontal Ribbon, 1: Vertical Ribbon
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: variant === 0 ? horizRow.implicitWidth : vertCol.implicitWidth
    implicitHeight: variant === 0 ? horizRow.implicitHeight : vertCol.implicitHeight

    // Variant 0: Horizontal Kinetic Ribbon
    RowLayout {
        id: horizRow
        anchors.centerIn: parent
        visible: root.variant === 0
        spacing: Math.round(10 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.hourStr
            color: root.primaryColor
            textPointSize: Math.max(18, Math.round(54 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(ribbonColH.implicitWidth + 18 * root.s)
            implicitHeight: Math.round(ribbonColH.implicitHeight + 12 * root.s)
            radius: Math.round(14 * root.s)
            color: Colours.palette.m3secondaryContainer
            rotation: -10

            ColumnLayout {
                id: ribbonColH
                anchors.centerIn: parent
                spacing: Math.round(2 * root.s)

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("ddd").toUpperCase()
                    color: Colours.palette.m3onSecondaryContainer
                    textPointSize: Math.max(7, Math.round(9.5 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0 * root.s
                    renderType: Text.QtRendering
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("d MMM").toUpperCase()
                    color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.78)
                    textPointSize: Math.max(6, Math.round(8 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Medium
                    renderType: Text.QtRendering
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.minuteStr
            color: root.tertiaryColor
            textPointSize: Math.max(18, Math.round(54 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }
    }

    // Variant 1: Vertical Kinetic Ribbon
    ColumnLayout {
        id: vertCol
        anchors.centerIn: parent
        visible: root.variant === 1
        spacing: Math.round(-6 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: root.primaryColor
            textPointSize: Math.max(18, Math.round(54 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            z: 2
            implicitWidth: Math.round(ribbonRowV.implicitWidth + 20 * root.s)
            implicitHeight: Math.round(ribbonRowV.implicitHeight + 8 * root.s)
            radius: height / 2
            color: Colours.palette.m3tertiaryContainer
            rotation: -5

            RowLayout {
                id: ribbonRowV
                anchors.centerIn: parent
                spacing: Math.round(6 * root.s)

                StyledRect {
                    width: Math.max(4, Math.round(5.5 * root.s))
                    height: width
                    radius: width / 2
                    color: Colours.palette.m3onTertiaryContainer
                    opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.3
                    Behavior on opacity {
                        Anim { duration: Tokens.anim.durations.small }
                    }
                }

                StyledText {
                    text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                    color: Colours.palette.m3onTertiaryContainer
                    textPointSize: Math.max(7, Math.round(9.5 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0 * root.s
                    renderType: Text.QtRendering
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: root.onSurfaceColor
            textPointSize: Math.max(18, Math.round(54 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }
    }
}


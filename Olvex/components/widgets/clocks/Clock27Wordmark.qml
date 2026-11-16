import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Capsule Day, 1: Minimal Typo
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Math.round(4 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr + ":" + Time.minuteStr
            color: root.onSurfaceColor
            textPointSize: Math.max(18, Math.round(46 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
            font.letterSpacing: -1.0 * root.s
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(dayTxt.implicitWidth + 24 * root.s)
            implicitHeight: Math.round(dayTxt.implicitHeight + 8 * root.s)
            radius: height / 2
            color: root.variant === 0 ? Colours.palette.m3primaryContainer : "transparent"

            StyledText {
                id: dayTxt
                anchors.centerIn: parent
                text: Time.format("dddd").toUpperCase()
                color: root.variant === 0 ? Colours.palette.m3onPrimaryContainer : root.primaryColor
                textPointSize: Math.max(8, Math.round(13 * root.s))
                font.family: Tokens.font.family.sans
                font.weight: Font.Black
                font.letterSpacing: 2.0 * root.s
            }
        }

        StyledText {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(2 * root.s)
            text: Time.format("d MMMM yyyy").toUpperCase()
            color: root.secondaryColor
            textPointSize: Math.max(6, Math.round(8.5 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2 * root.s
        }
    }
}


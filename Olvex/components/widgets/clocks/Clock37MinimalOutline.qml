import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Watermark Hours, 1: Watermark Day
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    implicitWidth: Math.round(220 * s)
    implicitHeight: Math.round(140 * s)

    // Giant translucent background watermark
    StyledText {
        anchors.centerIn: parent
        text: root.variant === 0 ? Time.hourStr : Time.format("d")
        color: Qt.alpha(root.primaryColor, 0.16)
        textPointSize: Math.max(36, Math.round(92 * root.s))
        font.family: Tokens.font.family.clock
        font.weight: Font.Black
    }

    // Crisp foreground time + tonal date capsule
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Math.round(6 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr + ":" + Time.minuteStr
            color: root.onSurfaceColor
            textPointSize: Math.max(16, Math.round(38 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.Black
            font.letterSpacing: -1.0 * root.s
        }

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(dateLbl.implicitWidth + 18 * root.s)
            implicitHeight: Math.round(dateLbl.implicitHeight + 6 * root.s)
            radius: height / 2
            color: Colours.palette.m3tertiaryContainer

            StyledText {
                id: dateLbl
                anchors.centerIn: parent
                text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                color: Colours.palette.m3onTertiaryContainer
                textPointSize: Math.max(6, Math.round(8.5 * root.s))
                font.family: Tokens.font.family.sans
                font.weight: Font.Bold
                font.letterSpacing: 1.0 * root.s
            }
        }
    }
}


import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Italic Block, 1: Ghost Italic
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
        spacing: Math.round(-4 * root.s)

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(8 * root.s)

            StyledText {
                text: Time.hourStr
                color: root.primaryColor
                textPointSize: Math.max(18, Math.round(52 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
                font.italic: true
                font.letterSpacing: -1.5 * root.s
            }

            StyledRect {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Math.round(8 * root.s)
                implicitWidth: Math.round(secTxt.implicitWidth + 12 * root.s)
                implicitHeight: Math.round(secTxt.implicitHeight + 4 * root.s)
                radius: height / 2
                color: root.surfaceHighColor

                StyledText {
                    id: secTxt
                    anchors.centerIn: parent
                    text: ":" + String(Time.seconds).padStart(2, "0")
                    color: root.tertiaryColor
                    textPointSize: Math.max(7, Math.round(10 * root.s))
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Bold
                }
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(minTxt.implicitWidth + (root.variant === 0 ? 28 * root.s : 8 * root.s))
            implicitHeight: Math.round(minTxt.implicitHeight + (root.variant === 0 ? 4 * root.s : 0))
            radius: Math.round(18 * root.s)
            color: root.variant === 0 ? Colours.palette.m3tertiaryContainer : "transparent"

            StyledText {
                id: minTxt
                anchors.centerIn: parent
                text: Time.minuteStr
                color: root.variant === 0 ? Colours.palette.m3onTertiaryContainer : root.onSurfaceColor
                textPointSize: Math.max(18, Math.round(50 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
                font.italic: true
                font.letterSpacing: -1.5 * root.s
            }
        }

        StyledText {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(8 * root.s)
            text: (Time.format("dddd") + " • " + Time.format("d MMM")).toUpperCase()
            color: root.secondaryColor
            textPointSize: Math.max(6, Math.round(9 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1 * root.s
        }
    }
}


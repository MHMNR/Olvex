import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Stacked Editorial, 1: Asymmetric Split
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true
    property string dateDetailFormat: "d MMM"

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: variant === 0 ? stackedCol.implicitWidth : splitRow.implicitWidth
    implicitHeight: variant === 0 ? stackedCol.implicitHeight : splitRow.implicitHeight

    // Variant 0: Stacked High-Contrast Editorial Serif + Sans
    ColumnLayout {
        id: stackedCol
        anchors.centerIn: parent
        visible: root.variant === 0
        spacing: Math.round(-6 * root.s)

        StyledRect {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Math.round(10 * root.s)
            implicitWidth: Math.round(pillLabel.implicitWidth + 18 * root.s)
            implicitHeight: Math.round(pillLabel.implicitHeight + 6 * root.s)
            radius: height / 2
            color: Colours.palette.m3secondaryContainer

            StyledText {
                id: pillLabel
                anchors.centerIn: parent
                text: (Time.format("ddd") + " • " + Time.format(root.dateDetailFormat)).toUpperCase()
                color: Colours.palette.m3onSecondaryContainer
                textPointSize: Math.max(7, Math.round(9 * root.s))
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1 * root.s
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: root.primaryColor
            textPointSize: Math.max(20, Math.round(62 * root.s))
            font.family: "Noto Serif Display"
            font.weight: Font.Bold
            font.italic: true
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: root.onSurfaceColor
            textPointSize: Math.max(18, Math.round(52 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.Light
            font.letterSpacing: 2 * root.s
        }
    }

    // Variant 1: Asymmetric Split with Vertical Accent Bar
    RowLayout {
        id: splitRow
        anchors.centerIn: parent
        visible: root.variant === 1
        spacing: Math.round(12 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.hourStr
            color: root.primaryColor
            textPointSize: Math.max(22, Math.round(68 * root.s))
            font.family: "Noto Serif Display"
            font.weight: Font.Black
            font.italic: true
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            width: Math.max(3, Math.round(4 * root.s))
            height: Math.round(64 * root.s)
            radius: width / 2
            color: root.tertiaryColor
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(2 * root.s)

            StyledText {
                text: Time.minuteStr
                color: root.onSurfaceColor
                textPointSize: Math.max(14, Math.round(38 * root.s))
                font.family: Tokens.font.family.sans
                font.weight: Font.Medium
            }

            RowLayout {
                spacing: Math.round(6 * root.s)

                StyledRect {
                    width: Math.max(4, Math.round(6 * root.s))
                    height: width
                    radius: width / 2
                    color: root.tertiaryColor
                    opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.35
                    Behavior on opacity {
                        Anim { duration: Tokens.anim.durations.small }
                    }
                }

                StyledText {
                    text: String(Time.seconds).padStart(2, "0") + " • " + Time.format("ddd").toUpperCase()
                    color: root.secondaryColor
                    textPointSize: Math.max(7, Math.round(9.5 * root.s))
                    font.family: Tokens.font.family.mono
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}


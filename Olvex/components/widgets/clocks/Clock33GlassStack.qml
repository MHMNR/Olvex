import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Layered Tonal, 1: Primary Back
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: Math.round(216 * s)
    implicitHeight: Math.round(134 * s)

    // Back tonal layer (offset down-right, zero shadow/border)
    StyledRect {
        x: Math.round(10 * root.s)
        y: Math.round(10 * root.s)
        width: Math.round(202 * root.s)
        height: Math.round(120 * root.s)
        radius: Math.round(26 * root.s)
        color: root.variant === 0
            ? Colours.palette.m3secondaryContainer
            : Colours.palette.m3primaryContainer
    }

    // Front tonal card
    StyledRect {
        x: 0
        y: 0
        width: Math.round(202 * root.s)
        height: Math.round(120 * root.s)
        radius: Math.round(26 * root.s)
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * root.s)

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr
                color: root.primaryColor
                textPointSize: Math.max(16, Math.round(40 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
            }

            RowLayout {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
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
                    text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                    color: root.onSurfaceColor
                    textPointSize: Math.max(6, Math.round(9 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0 * root.s
                }
            }
        }
    }
}


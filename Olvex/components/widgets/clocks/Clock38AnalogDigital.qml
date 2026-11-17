import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Date Complication, 1: Digital Complication
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real dialSize: Math.round(174 * clockScale)

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: root.surfaceColor

        // 12 crisp M3 ticks
        Repeater {
            model: 12
            Item {
                anchors.fill: parent
                rotation: index * 30

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(root.dialSize * 0.055)
                    width: (index % 3 === 0) ? Math.max(3, Math.round(root.dialSize * 0.025)) : Math.max(1.5, Math.round(root.dialSize * 0.014))
                    height: (index % 3 === 0) ? Math.round(root.dialSize * 0.075) : Math.round(root.dialSize * 0.04)
                    radius: width / 2
                    color: index === 0 ? root.tertiaryColor : Qt.alpha(root.onSurfaceColor, index % 3 === 0 ? 0.78 : 0.35)
                }
            }
        }

        // 6 o'clock embedded complication pill
        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.dialSize * 0.17)
            implicitWidth: Math.round(compTxt.implicitWidth + 14 * root.clockScale)
            implicitHeight: Math.round(compTxt.implicitHeight + 4 * root.clockScale)
            radius: height / 2
            color: root.surfaceHighColor

            StyledText {
                id: compTxt
                anchors.centerIn: parent
                text: root.variant === 0
                    ? (Time.format("ddd") + " " + Time.format("d")).toUpperCase()
                    : (Time.hourStr + ":" + Time.minuteStr)
                color: root.primaryColor
                textPointSize: Math.max(6, Math.round(9 * root.clockScale))
                font.family: Tokens.font.family.mono
                font.weight: Font.Bold
            }
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: root.dialSize * 0.25
            handWidth: Math.max(4, root.dialSize * 0.056)
            handColor: root.primaryColor
            slotColor: root.surfaceColor
        }

        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: root.dialSize * 0.36
            handWidth: Math.max(3, root.dialSize * 0.042)
            handColor: root.onSurfaceColor
            slotColor: root.surfaceColor
        }

        ContinuousSecondHand {
            handLength: root.dialSize * 0.41
            handWidth: Math.max(1.5, 2 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, Math.round(root.dialSize * 0.07))
            height: width
            radius: width / 2
            color: root.tertiaryColor
        }
    }
}


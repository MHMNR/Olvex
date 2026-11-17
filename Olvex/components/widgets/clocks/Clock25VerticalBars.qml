import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Bars, 1: Accent Bars
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real s: 0.90 * clockScale
    property real smoothSeconds: 0

    function syncSeconds() {
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: syncSeconds()

    FrameAnimation {
        running: root.visible
        onTriggered: root.syncSeconds()
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(10 * root.s)

        Repeater {
            model: [
                {
                    val: Time.hourStr,
                    frac: ((Time.hours % 12) + Time.minutes / 60.0) / 12.0,
                    fillCol: root.variant === 0 ? Colours.palette.m3primaryContainer : root.primaryColor,
                    txtCol: root.variant === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary
                },
                {
                    val: Time.minuteStr,
                    frac: Time.minutes / 60.0,
                    fillCol: root.variant === 0 ? Colours.palette.m3secondaryContainer : root.secondaryColor,
                    txtCol: root.variant === 0 ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSecondary
                },
                {
                    val: String(Time.seconds).padStart(2, "0"),
                    frac: root.smoothSeconds / 60.0,
                    fillCol: root.variant === 0 ? Colours.palette.m3tertiaryContainer : root.tertiaryColor,
                    txtCol: root.variant === 0 ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onTertiary
                }
            ]

            StyledRect {
                required property var modelData
                width: Math.round(52 * root.s)
                height: Math.round(132 * root.s)
                radius: width / 2
                color: root.surfaceColor
                clip: true

                StyledRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(width * 0.55, parent.height * Math.min(1.0, Math.max(0.08, modelData.frac)))
                    radius: width / 2
                    color: modelData.fillCol
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(14 * root.s)
                    text: modelData.val
                    color: modelData.txtCol
                    textPointSize: Math.max(11, Math.round(20 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }
            }
        }
    }
}


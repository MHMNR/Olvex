import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Stadium, 1: Primary Header
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale
    property real smoothSeconds: 0

    function syncSeconds() {
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: {
        Time.secondsRefCount++;
        syncSeconds();
    }
    Component.onDestruction: Time.secondsRefCount--

    FrameAnimation {
        running: root.visible
        onTriggered: root.syncSeconds()
    }

    implicitWidth: Math.round(236 * s)
    implicitHeight: Math.round(118 * s)

    StyledRect {
        anchors.fill: parent
        radius: Math.round(28 * root.s)
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(12 * root.s)
            spacing: Math.round(8 * root.s)

            // Top pill: Time readout
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.round(18 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3surfaceContainerHighest
                    : Colours.palette.m3primaryContainer

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.s)

                    StyledText {
                        text: Time.hourStr + ":" + Time.minuteStr
                        color: root.variant === 0 ? root.primaryColor : Colours.palette.m3onPrimaryContainer
                        textPointSize: Math.max(14, Math.round(30 * root.s))
                        font.family: Tokens.font.family.sans
                        font.weight: Font.Black
                    }

                    StyledText {
                        text: ":" + String(Time.seconds).padStart(2, "0")
                        color: root.variant === 0 ? root.tertiaryColor : Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.72)
                        textPointSize: Math.max(10, Math.round(16 * root.s))
                        font.family: Tokens.font.family.mono
                        font.weight: Font.Bold
                    }
                }
            }

            // Bottom: Sweeping seconds rail + Date
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(4 * root.s)

                StyledRect {
                    Layout.fillWidth: true
                    height: Math.max(4, Math.round(5 * root.s))
                    radius: height / 2
                    color: Qt.alpha(root.onSurfaceColor, 0.12)

                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, (parent.width - width) * (root.smoothSeconds / 60.0))
                        width: Math.round(18 * root.s)
                        height: parent.height
                        radius: height / 2
                        color: root.tertiaryColor
                    }
                }

                StyledText {
                    visible: root.showDatePill
                    Layout.alignment: Qt.AlignHCenter
                    text: (Time.format("dddd") + " • " + Time.format("d MMMM")).toUpperCase()
                    color: root.secondaryColor
                    textPointSize: Math.max(6, Math.round(8.5 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0 * root.s
                }
            }
        }
    }
}


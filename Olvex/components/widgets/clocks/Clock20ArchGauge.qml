import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Arch, 1: Inverted Arch
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

    Component.onCompleted: syncSeconds()

    FrameAnimation {
        running: root.visible
        onTriggered: root.syncSeconds()
    }

    implicitWidth: Math.round(162 * s)
    implicitHeight: Math.round(184 * s)

    MaterialShape {
        anchors.fill: parent
        implicitSize: width
        shape: MaterialShape.Arch
        color: root.variant === 0
            ? Colours.palette.m3surfaceContainerHigh
            : Colours.palette.m3primaryContainer
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(2 * root.s)
        spacing: Math.round(-6 * root.s)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: root.variant === 0
                ? root.primaryColor
                : Colours.palette.m3onPrimaryContainer
            textPointSize: Math.max(14, Math.round(38 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: root.variant === 0
                ? root.onSurfaceColor
                : Colours.palette.m3onPrimaryContainer
            textPointSize: Math.max(14, Math.round(38 * root.s))
            font.family: Tokens.font.family.clock
            font.weight: Font.Light
        }

        // Smooth continuous seconds progress bar inside arch base
        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(8 * root.s)
            width: Math.round(72 * root.s)
            height: Math.max(3, Math.round(4 * root.s))
            radius: height / 2
            color: Qt.alpha(root.variant === 0 ? root.onSurfaceColor : Colours.palette.m3onPrimaryContainer, 0.16)

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(height, parent.width * (root.smoothSeconds / 60.0))
                radius: height / 2
                color: root.variant === 0 ? root.tertiaryColor : Colours.palette.m3onPrimaryContainer
            }
        }

        StyledText {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(6 * root.s)
            text: Time.format("ddd d").toUpperCase()
            color: root.variant === 0
                ? root.secondaryColor
                : Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.78)
            textPointSize: Math.max(6, Math.round(8.5 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 1.0 * root.s
        }
    }
}


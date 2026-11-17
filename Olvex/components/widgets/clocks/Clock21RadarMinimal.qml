import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Radar Sweep, 1: Clean Bauhaus
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real dialSize: Math.round(170 * clockScale)
    property real smoothSeconds: 0

    function syncSeconds() {
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: syncSeconds()

    FrameAnimation {
        running: root.visible && root.variant === 0
        onTriggered: root.syncSeconds()
    }

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        id: dial
        anchors.fill: parent
        radius: width / 2
        color: root.surfaceColor

        // Soft trailing radar sector behind continuous second hand
        Canvas {
            anchors.fill: parent
            visible: root.variant === 0
            property real secVal: root.smoothSeconds
            property color sweepCol: root.tertiaryColor
            onSecValChanged: requestPaint()
            onSweepColChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                if (w <= 8 || h <= 8)
                    return;

                const cx = w / 2;
                const cy = h / 2;
                const r = w * 0.44;
                const endA = -Math.PI / 2 + (secVal / 60.0) * Math.PI * 2;
                const steps = 12;
                const span = Math.PI * 0.45;
                for (let i = 0; i < steps; i++) {
                    const a0 = endA - span * (1 - i / steps);
                    const a1 = endA - span * (1 - (i + 1) / steps);
                    ctx.fillStyle = Qt.alpha(sweepCol, 0.018 * (i + 1));
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.arc(cx, cy, r, a0, a1);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        // Bauhaus 12 & 6 markers + 3 & 9 bars
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(dial.height * 0.08)
            text: "12"
            color: root.primaryColor
            textPointSize: Math.max(8, Math.round(13 * root.clockScale))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(dial.height * 0.08)
            text: "6"
            color: Qt.alpha(root.onSurfaceColor, 0.65)
            textPointSize: Math.max(8, Math.round(13 * root.clockScale))
            font.family: Tokens.font.family.clock
            font.weight: Font.Black
        }

        Repeater {
            model: [90, 270]
            Item {
                required property int modelData
                anchors.fill: parent
                rotation: modelData

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(dial.height * 0.11)
                    width: Math.max(3, Math.round(dial.width * 0.025))
                    height: Math.round(dial.height * 0.08)
                    radius: width / 2
                    color: Qt.alpha(root.onSurfaceColor, 0.45)
                }
            }
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: dial.height * 0.25
            handWidth: Math.max(4, dial.width * 0.056)
            handColor: root.primaryColor
            slotColor: root.surfaceColor
        }

        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: dial.height * 0.36
            handWidth: Math.max(3, dial.width * 0.042)
            handColor: root.onSurfaceColor
            slotColor: root.surfaceColor
        }

        ContinuousSecondHand {
            handLength: dial.height * 0.41
            handWidth: Math.max(1.5, 2 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, Math.round(dial.width * 0.07))
            height: width
            radius: width / 2
            color: root.tertiaryColor
        }
    }
}


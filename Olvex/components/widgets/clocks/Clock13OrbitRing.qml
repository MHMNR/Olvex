import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Orbit Arc, 1: Dual Track
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real dialSize: Math.round(172 * clockScale)
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

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHigh

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            property real secVal: root.smoothSeconds
            property int minVal: Time.minutes
            property int varIdx: root.variant
            property color colTrack: Qt.alpha(root.onSurfaceColor, 0.10)
            property color colSec: root.tertiaryColor
            property color colMin: root.primaryColor

            onSecValChanged: requestPaint()
            onMinValChanged: requestPaint()
            onVarIdxChanged: requestPaint()
            onColTrackChanged: requestPaint()
            onColSecChanged: requestPaint()
            onColMinChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                if (w <= 8 || h <= 8)
                    return;

                const cx = w / 2;
                const cy = h / 2;
                const startA = -Math.PI / 2;
                const secFrac = secVal / 60.0;
                const secAngle = startA + secFrac * Math.PI * 2;

                // Outer second track
                const rOuter = w * 0.435;
                const lwOuter = Math.max(2, w * 0.032);
                ctx.lineCap = "round";

                ctx.strokeStyle = colTrack;
                ctx.lineWidth = lwOuter;
                ctx.beginPath();
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2);
                ctx.stroke();

                if (varIdx === 0) {
                    ctx.strokeStyle = colSec;
                    ctx.lineWidth = lwOuter;
                    ctx.beginPath();
                    ctx.arc(cx, cy, rOuter, startA, secAngle);
                    ctx.stroke();
                } else {
                    // Variant 1: Inner minute progress ring + outer orbit dot
                    const rInner = w * 0.375;
                    const lwInner = Math.max(2, w * 0.026);
                    ctx.strokeStyle = colTrack;
                    ctx.lineWidth = lwInner;
                    ctx.beginPath();
                    ctx.arc(cx, cy, rInner, 0, Math.PI * 2);
                    ctx.stroke();

                    const minAngle = startA + (minVal / 60.0) * Math.PI * 2;
                    ctx.strokeStyle = colMin;
                    ctx.lineWidth = lwInner;
                    ctx.beginPath();
                    ctx.arc(cx, cy, rInner, startA, minAngle);
                    ctx.stroke();
                }

                // Orbiting second dot
                const dotX = cx + Math.cos(secAngle) * rOuter;
                const dotY = cy + Math.sin(secAngle) * rOuter;
                ctx.fillStyle = colSec;
                ctx.beginPath();
                ctx.arc(dotX, dotY, Math.max(3, w * 0.036), 0, Math.PI * 2);
                ctx.fill();
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(4 * root.clockScale)

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr
                color: root.primaryColor
                textPointSize: Math.max(12, Math.round(30 * root.clockScale))
                font.family: Tokens.font.family.clock
                font.weight: Font.Bold
                font.letterSpacing: -0.5 * root.clockScale
            }

            StyledRect {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(dateBadge.implicitWidth + 14 * root.clockScale)
                implicitHeight: Math.round(dateBadge.implicitHeight + 4 * root.clockScale)
                radius: height / 2
                color: Colours.palette.m3surfaceContainerHighest

                StyledText {
                    id: dateBadge
                    anchors.centerIn: parent
                    text: Time.format("ddd d").toUpperCase()
                    color: root.onSurfaceColor
                    textPointSize: Math.max(6, Math.round(8.5 * root.clockScale))
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8 * root.clockScale
                }
            }
        }
    }
}


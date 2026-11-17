import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Horizon Card, 1: Tonal Split
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
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

    implicitWidth: Math.round(236 * s)
    implicitHeight: Math.round(118 * s)

    StyledRect {
        anchors.fill: parent
        radius: Math.round(28 * root.s)
        color: root.variant === 0
            ? root.surfaceColor
            : Colours.palette.m3secondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.s)
            spacing: Math.round(12 * root.s)

            // Left: Semi-circle horizon seconds gauge
            Canvas {
                Layout.alignment: Qt.AlignVCenter
                width: Math.round(78 * root.s)
                height: Math.round(78 * root.s)
                property real secVal: root.smoothSeconds
                property color trackCol: Qt.alpha(root.onSurfaceColor, 0.14)
                property color arcCol: root.variant === 0 ? root.primaryColor : Colours.palette.m3onSecondaryContainer
                property color dotCol: root.tertiaryColor
                onSecValChanged: requestPaint()
                onTrackColChanged: requestPaint()
                onArcColChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    if (w <= 4 || h <= 4)
                        return;

                    const cx = w / 2, cy = h * 0.65;
                    const r = w * 0.42;
                    const lw = Math.max(3, w * 0.09);
                    ctx.lineCap = "round";

                    ctx.strokeStyle = trackCol;
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, Math.PI, Math.PI * 2);
                    ctx.stroke();

                    const endA = Math.PI + (secVal / 60.0) * Math.PI;
                    ctx.strokeStyle = arcCol;
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, Math.PI, endA);
                    ctx.stroke();

                    const dx = cx + Math.cos(endA) * r;
                    const dy = cy + Math.sin(endA) * r;
                    ctx.fillStyle = dotCol;
                    ctx.beginPath();
                    ctx.arc(dx, dy, lw * 0.65, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                spacing: Math.round(2 * root.s)

                StyledText {
                    text: Time.hourStr + ":" + Time.minuteStr
                    color: root.variant === 0 ? root.primaryColor : Colours.palette.m3onSecondaryContainer
                    textPointSize: Math.max(14, Math.round(30 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Black
                }

                StyledText {
                    visible: root.showDatePill
                    text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                    color: root.variant === 0 ? root.secondaryColor : Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.78)
                    textPointSize: Math.max(6, Math.round(9 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9 * root.s
                }
            }
        }
    }
}


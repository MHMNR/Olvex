import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Wavy Ring, 1: Progress Wave
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real dialSize: Math.round(176 * clockScale)
    property real wavePhase: 0
    property real smoothSeconds: 0

    function tick(dt) {
        wavePhase += dt * 3.2;
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: tick(0)

    FrameAnimation {
        running: root.visible
        onTriggered: root.tick(frameTime)
    }

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHigh

        Canvas {
            anchors.fill: parent
            property real phase: root.wavePhase
            property real secVal: root.smoothSeconds
            property int varIdx: root.variant
            property color colWave: root.primaryColor
            property color colTrack: Qt.alpha(root.onSurfaceColor, 0.12)
            property color colAccent: root.tertiaryColor

            onPhaseChanged: requestPaint()
            onSecValChanged: requestPaint()
            onVarIdxChanged: requestPaint()
            onColWaveChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                if (w <= 8 || h <= 8)
                    return;

                const cx = w / 2;
                const cy = h / 2;
                const baseR = w * 0.415;
                const amp = w * 0.022;
                const waves = 12;
                const lw = Math.max(2, w * 0.026);
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                if (varIdx === 1) {
                    ctx.strokeStyle = colTrack;
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.arc(cx, cy, baseR, 0, Math.PI * 2);
                    ctx.stroke();
                }

                const maxFrac = varIdx === 0 ? 1.0 : Math.max(0.03, secVal / 60.0);
                const steps = 160;
                const totalSteps = Math.max(4, Math.round(steps * maxFrac));

                ctx.strokeStyle = varIdx === 0 ? colWave : colAccent;
                ctx.lineWidth = lw;
                ctx.beginPath();
                for (let i = 0; i <= totalSteps; i++) {
                    const t = i / steps;
                    const angle = -Math.PI / 2 + t * Math.PI * 2;
                    const r = baseR + Math.sin(angle * waves + phase) * amp;
                    const x = cx + Math.cos(angle) * r;
                    const y = cy + Math.sin(angle) * r;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                if (varIdx === 0)
                    ctx.closePath();
                ctx.stroke();
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(2 * root.clockScale)

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr
                color: root.primaryColor
                textPointSize: Math.max(12, Math.round(28 * root.clockScale))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
            }

            StyledText {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("ddd d").toUpperCase()
                color: root.secondaryColor
                textPointSize: Math.max(6, Math.round(9 * root.clockScale))
                font.family: Tokens.font.family.sans
                font.weight: Font.DemiBold
                font.letterSpacing: 1.0 * root.clockScale
            }
        }
    }
}


import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Hex, 1: Primary Hex
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real dialSize: Math.round(172 * clockScale)
    readonly property color dialBg: variant === 0
        ? root.surfaceColor
        : Colours.palette.m3primaryContainer
    readonly property color handCol: variant === 0
        ? root.primaryColor
        : Colours.palette.m3onPrimaryContainer

    implicitWidth: dialSize
    implicitHeight: dialSize

    Canvas {
        anchors.fill: parent
        property color fillCol: root.dialBg
        property color dotCol: Qt.alpha(root.handCol, 0.55)
        property color topCol: root.tertiaryColor
        onFillColChanged: requestPaint()
        onDotColChanged: requestPaint()
        onTopColChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            if (w <= 8 || h <= 8)
                return;

            const cx = w / 2, cy = h / 2;
            const r = w * 0.46;
            const corner = w * 0.08;
            const pts = [];
            for (let i = 0; i < 6; i++) {
                const a = -Math.PI / 2 + i * (Math.PI / 3);
                pts.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r });
            }

            ctx.fillStyle = fillCol;
            ctx.beginPath();
            for (let i = 0; i < 6; i++) {
                const pPrev = pts[(i + 5) % 6];
                const pCurr = pts[i];
                const pNext = pts[(i + 1) % 6];
                const v1x = pCurr.x - pPrev.x, v1y = pCurr.y - pPrev.y;
                const d1 = Math.hypot(v1x, v1y);
                const v2x = pNext.x - pCurr.x, v2y = pNext.y - pCurr.y;
                const d2 = Math.hypot(v2x, v2y);
                const sx = pCurr.x - (v1x / d1) * corner;
                const sy = pCurr.y - (v1y / d1) * corner;
                const ex = pCurr.x + (v2x / d2) * corner;
                const ey = pCurr.y + (v2y / d2) * corner;
                if (i === 0)
                    ctx.moveTo(sx, sy);
                else
                    ctx.lineTo(sx, sy);
                ctx.quadraticCurveTo(pCurr.x, pCurr.y, ex, ey);
            }
            ctx.closePath();
            ctx.fill();

            // 6 vertex markers
            for (let i = 0; i < 6; i++) {
                const a = -Math.PI / 2 + i * (Math.PI / 3);
                const mr = w * 0.36;
                ctx.fillStyle = i === 0 ? topCol : dotCol;
                ctx.beginPath();
                ctx.arc(cx + Math.cos(a) * mr, cy + Math.sin(a) * mr, Math.max(2, w * 0.022), 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    SlottedHand {
        angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
        handLength: root.dialSize * 0.25
        handWidth: Math.max(4, root.dialSize * 0.056)
        handColor: root.handCol
        slotColor: root.dialBg
    }

    SlottedHand {
        angleDeg: Time.minutes * 6 + Time.seconds * 0.1
        handLength: root.dialSize * 0.36
        handWidth: Math.max(3, root.dialSize * 0.042)
        handColor: root.handCol
        slotColor: root.dialBg
    }

    ContinuousSecondHand {
        handLength: root.dialSize * 0.40
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


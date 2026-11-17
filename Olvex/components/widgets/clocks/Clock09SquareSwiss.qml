import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Dark Dial, 1: Accent Dial
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real boxSize: Math.round(168 * clockScale)
    readonly property color bgCol: variant === 0 ? root.surfaceColor : root.primaryColor
    readonly property color fgCol: variant === 0 ? root.primaryColor : Colours.palette.m3onPrimary
    readonly property color subCol: variant === 0 ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onPrimary

    implicitWidth: boxSize
    implicitHeight: boxSize

    StyledRect {
        id: sqDial
        anchors.fill: parent
        radius: Math.round(width * 0.16)
        color: root.bgCol

        Canvas {
            anchors.fill: parent
            property color tickColor: root.fgCol
            onTickColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function squareRayHit(cx, cy, dx, dy, size, pad) {
                const tx = dx > 0 ? (size - pad - cx) / dx : (dx < 0 ? (pad - cx) / dx : 1e9);
                const ty = dy > 0 ? (size - pad - cy) / dy : (dy < 0 ? (pad - cy) / dy : 1e9);
                const t = Math.min(Math.abs(tx), Math.abs(ty));
                return { x: cx + dx * t, y: cy + dy * t };
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const sz = width;
                if (sz <= 4)
                    return;
                const cx = sz / 2, cy = sz / 2;

                for (let i = 0; i < 60; i++) {
                    const isHour = (i % 5 === 0);
                    const ang = (i * 6 - 90) * Math.PI / 180.0;
                    const dx = Math.cos(ang), dy = Math.sin(ang);

                    const pOut = squareRayHit(cx, cy, dx, dy, sz, sz * 0.04);
                    const innerPad = isHour ? sz * 0.19 : sz * 0.11;
                    const pIn = squareRayHit(cx, cy, dx, dy, sz, innerPad);

                    ctx.strokeStyle = Qt.rgba(tickColor.r, tickColor.g, tickColor.b, isHour ? 0.92 : 0.35);
                    ctx.lineWidth = Math.max(1.0, (isHour ? 2.0 : 1.1) * root.clockScale);
                    ctx.beginPath();
                    ctx.moveTo(pOut.x, pOut.y);
                    ctx.lineTo(pIn.x, pIn.y);
                    ctx.stroke();
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            text: "12"
            color: root.fgCol
            textPixelSize: Math.max(8, Math.round(parent.height * 0.12))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.72
            text: "6"
            color: root.fgCol
            textPixelSize: Math.max(8, Math.round(parent.height * 0.12))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            x: parent.width * 0.19
            anchors.verticalCenter: parent.verticalCenter
            text: "9"
            color: root.fgCol
            textPixelSize: Math.max(8, Math.round(parent.height * 0.12))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            x: parent.width * 0.74
            anchors.verticalCenter: parent.verticalCenter
            text: "3"
            color: root.fgCol
            textPixelSize: Math.max(8, Math.round(parent.height * 0.12))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.34
            text: Time.format("ddd").toUpperCase()
            color: root.subCol
            opacity: 0.78
            textPixelSize: Math.max(6, Math.round(parent.height * 0.065))
            font.weight: Font.Bold
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.58
            text: Time.format("d MMM").toUpperCase()
            color: root.subCol
            opacity: 0.78
            textPixelSize: Math.max(6, Math.round(parent.height * 0.065))
            font.weight: Font.Bold
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: sqDial.height * 0.25
            handWidth: sqDial.width * 0.042
            handColor: root.fgCol
            slotColor: root.bgCol
        }
        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: sqDial.height * 0.35
            handWidth: sqDial.width * 0.035
            handColor: root.fgCol
            slotColor: root.bgCol
        }
        ContinuousSecondHand {
            handLength: sqDial.height * 0.38
            handWidth: Math.max(1.4, 1.6 * root.clockScale)
            handColor: root.variant === 0 ? root.tertiaryColor : Colours.palette.m3onPrimary
            active: root.visible
        }
    }
}


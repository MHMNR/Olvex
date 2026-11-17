import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: 12-Ray Minimal, 1: 60-Tick + Date Badge
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
    property bool showDatePill: true

    readonly property real w: Math.round(256 * clockScale)
    readonly property real h: Math.round(w * 0.54)

    implicitWidth: w
    implicitHeight: h

    StyledRect {
        id: dial
        anchors.fill: parent
        radius: Math.round(height * 0.16)
        color: root.surfaceColor
        clip: true

        Canvas {
            anchors.fill: parent
            property int vMode: root.variant
            property color lineCol: root.primaryColor
            onVModeChanged: requestPaint()
            onLineColChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function rayBorderHit(cx, cy, dx, dy, rw, rh, pad) {
                const tx = dx > 0 ? (rw - pad - cx) / dx : (dx < 0 ? (pad - cx) / dx : 1e9);
                const ty = dy > 0 ? (rh - pad - cy) / dy : (dy < 0 ? (pad - cy) / dy : 1e9);
                const t = Math.min(Math.abs(tx), Math.abs(ty));
                return { x: cx + dx * t, y: cy + dy * t };
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const rw = width, rh = height;
                if (rw <= 4 || rh <= 4)
                    return;
                const cx = rw / 2, cy = rh / 2;

                if (vMode === 1) {
                    ctx.strokeStyle = Qt.rgba(lineCol.r, lineCol.g, lineCol.b, 0.25);
                    ctx.lineWidth = Math.max(1.0, 1.1 * root.clockScale);
                    for (let m = 0; m < 60; m++) {
                        if (m % 5 === 0)
                            continue;
                        const angM = (m * 6 - 90) * Math.PI / 180.0;
                        const dxM = Math.cos(angM), dyM = Math.sin(angM);
                        const pOutM = rayBorderHit(cx, cy, dxM, dyM, rw, rh, 5 * root.clockScale);
                        const pInM = rayBorderHit(cx, cy, dxM, dyM, rw, rh, 16 * root.clockScale);
                        ctx.beginPath();
                        ctx.moveTo(pOutM.x, pOutM.y);
                        ctx.lineTo(pInM.x, pInM.y);
                        ctx.stroke();
                    }
                }

                ctx.strokeStyle = Qt.rgba(lineCol.r, lineCol.g, lineCol.b, 0.85);
                ctx.lineWidth = Math.max(1.2, 1.7 * root.clockScale);
                for (let i = 0; i < 12; i++) {
                    const ang = (i * 30 - 90) * Math.PI / 180.0;
                    const dx = Math.cos(ang), dy = Math.sin(ang);
                    const pOut = rayBorderHit(cx, cy, dx, dy, rw, rh, 5 * root.clockScale);
                    const isCardinal = (i % 3 === 0);
                    const innerRx = isCardinal ? rw * 0.39 : rw * 0.24;
                    const innerRy = isCardinal ? rh * 0.39 : rh * 0.26;
                    const pIn = { x: cx + dx * innerRx, y: cy + dy * innerRy };

                    ctx.beginPath();
                    ctx.moveTo(pOut.x, pOut.y);
                    ctx.lineTo(pIn.x, pIn.y);
                    ctx.stroke();
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.10
            text: "12"
            color: root.primaryColor
            textPixelSize: Math.max(9, Math.round(parent.height * 0.16))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.70
            text: "6"
            color: root.primaryColor
            textPixelSize: Math.max(9, Math.round(parent.height * 0.16))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            x: parent.width * 0.13
            anchors.verticalCenter: parent.verticalCenter
            text: "9"
            color: root.primaryColor
            textPixelSize: Math.max(9, Math.round(parent.height * 0.16))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }
        StyledText {
            x: parent.width * 0.81
            anchors.verticalCenter: parent.verticalCenter
            text: "3"
            color: root.primaryColor
            textPixelSize: Math.max(9, Math.round(parent.height * 0.16))
            font.family: Tokens.font.family.clock
            font.weight: Font.Bold
        }

        StyledText {
            visible: root.variant === 1 && root.showDatePill
            x: parent.width * 0.61
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("ddd d").toUpperCase()
            color: root.onSurfaceColor
            textPixelSize: Math.max(7, Math.round(parent.height * 0.085))
            font.weight: Font.Bold
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: dial.height * 0.25
            handWidth: dial.height * 0.05
            handColor: root.primaryColor
            slotColor: root.surfaceColor
        }
        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: dial.height * 0.36
            handWidth: dial.height * 0.04
            handColor: root.primaryColor
            slotColor: root.surfaceColor
        }

        ContinuousSecondHand {
            handLength: dial.height * 0.38
            handWidth: Math.max(1.5, 1.8 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }
    }
}


import QtQuick
import Olvex.Config
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Contour Outline, 1: Duo-Tone Solid
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real s: 0.82 * clockScale

    implicitWidth: Math.round(190 * s)
    implicitHeight: Math.round(186 * s)

    Canvas {
        anchors.fill: parent

        property string hStr: Time.hourStr
        property string mStr: Time.minuteStr
        property int mode: root.variant
        property color colPrimary: root.primaryColor
        property color colSecondary: root.secondaryColor
        property color colDarkStroke: Colours.palette.m3surfaceContainerLowest
        property string fontFam: Tokens.font.family.clock

        onHStrChanged: requestPaint()
        onMStrChanged: requestPaint()
        onModeChanged: requestPaint()
        onColPrimaryChanged: requestPaint()
        onColSecondaryChanged: requestPaint()
        onFontFamChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 4 || height <= 4)
                return;
            const sc = root.s;
            const cssFam = /^(serif|sans-serif|monospace)$/i.test(fontFam) ? fontFam.toLowerCase() : ("'" + fontFam + "', sans-serif");
            ctx.font = "900 " + Math.round(92 * sc) + "px " + cssFam;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.lineJoin = "round";

            const positions = [
                { ch: hStr.charAt(0), x: 64 * sc,  y: 56 * sc,  tone: 0 },
                { ch: hStr.charAt(1), x: 126 * sc, y: 56 * sc,  tone: 1 },
                { ch: mStr.charAt(0), x: 64 * sc,  y: 130 * sc, tone: 1 },
                { ch: mStr.charAt(1), x: 126 * sc, y: 130 * sc, tone: 0 }
            ];

            for (let i = 0; i < positions.length; i++) {
                const p = positions[i];
                if (mode === 0) {
                    ctx.fillStyle = Qt.rgba(colPrimary.r, colPrimary.g, colPrimary.b, 0.22);
                    ctx.strokeStyle = colPrimary;
                    ctx.lineWidth = 3.8 * sc;
                    ctx.fillText(p.ch, p.x, p.y);
                    ctx.strokeText(p.ch, p.x, p.y);
                } else {
                    ctx.strokeStyle = colDarkStroke;
                    ctx.lineWidth = 6 * sc;
                    ctx.strokeText(p.ch, p.x, p.y);
                    ctx.fillStyle = (p.tone === 0) ? colPrimary : colSecondary;
                    ctx.fillText(p.ch, p.x, p.y);
                }
            }
        }
    }
}


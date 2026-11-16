import QtQuick
import Olvex.Config
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Solid Fill + Contour, 1: Hollow Outline
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real s: 0.85 * clockScale

    implicitWidth: Math.round(256 * s)
    implicitHeight: Math.round(118 * s)

    Canvas {
        id: chunkyCanvas
        anchors.fill: parent

        property string hStr: Time.hourStr
        property string mStr: Time.minuteStr
        property int mode: root.variant
        property color colFill: root.primaryColor
        property color colDark: Colours.palette.m3surfaceContainerLowest
        property string fontFam: Tokens.font.family.clock

        onHStrChanged: requestPaint()
        onMStrChanged: requestPaint()
        onModeChanged: requestPaint()
        onColFillChanged: requestPaint()
        onColDarkChanged: requestPaint()
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
            ctx.font = "900 " + Math.round(78 * sc) + "px " + cssFam;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.lineJoin = "round";

            const chars = [
                { ch: hStr.charAt(0), x: 42 * sc },
                { ch: hStr.charAt(1), x: 90 * sc },
                { ch: ":",            x: 128 * sc },
                { ch: mStr.charAt(0), x: 166 * sc },
                { ch: mStr.charAt(1), x: 214 * sc }
            ];
            const cy = height / 2;

            for (let i = 0; i < chars.length; i++) {
                if (mode === 0) {
                    ctx.strokeStyle = colDark;
                    ctx.lineWidth = 6 * sc;
                    ctx.strokeText(chars[i].ch, chars[i].x, cy);
                    ctx.fillStyle = colFill;
                    ctx.fillText(chars[i].ch, chars[i].x, cy);
                } else {
                    ctx.strokeStyle = colFill;
                    ctx.lineWidth = 3 * sc;
                    ctx.strokeText(chars[i].ch, chars[i].x, cy);
                }
            }
        }
    }
}

import QtQuick
import Olvex.Config
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Solid Giant Numerals, 1: Wireframe Outlined Numerals
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real s: 0.82 * clockScale

    implicitWidth: Math.round(200 * s)
    implicitHeight: Math.round(200 * s)

    Item {
        anchors.fill: parent

        Canvas {
            anchors.fill: parent
            property int mode: root.variant
            property color col: root.primaryColor
            property string fontFam: Tokens.font.family.clock
            onModeChanged: requestPaint()
            onColChanged: requestPaint()
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
                ctx.font = "900 " + Math.round(70 * sc) + "px " + cssFam;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.lineJoin = "round";

                const nums = [
                    { n: "12", x: 100 * sc, y: 44 * sc },
                    { n: "9",  x: 44 * sc,  y: 98 * sc },
                    { n: "3",  x: 156 * sc, y: 98 * sc },
                    { n: "6",  x: 100 * sc, y: 152 * sc }
                ];

                for (let i = 0; i < nums.length; i++) {
                    if (mode === 0) {
                        ctx.fillStyle = col;
                        ctx.fillText(nums[i].n, nums[i].x, nums[i].y);
                    } else {
                        ctx.strokeStyle = col;
                        ctx.lineWidth = 2.6 * sc;
                        ctx.strokeText(nums[i].n, nums[i].x, nums[i].y);
                    }
                }
            }
        }

        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: 68 * root.s
            handWidth: 12 * root.s
            handColor: root.primaryColor
            slotColor: Colours.palette.m3surfaceContainer
            hollow: root.variant === 1
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: 48 * root.s
            handWidth: 8.5 * root.s
            handColor: root.primaryColor
            slotColor: Colours.palette.m3surfaceContainer
            hollow: root.variant === 1
        }

        ContinuousSecondHand {
            handLength: 70 * root.s
            handWidth: Math.max(1.5, 2 * root.s)
            handColor: root.variant === 0 ? root.tertiaryColor : root.primaryColor
            active: root.visible
        }

        Rectangle {
            width: Math.max(5, 10 * root.s)
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.variant === 0 ? root.primaryColor : Colours.palette.m3surfaceContainerLowest
        }
    }
}


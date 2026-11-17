import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Compass, 1: Primary Ring
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
    readonly property color fgCol: variant === 0
        ? root.primaryColor
        : Colours.palette.m3onPrimaryContainer

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: root.dialBg

        // 4 cardinal diamond ticks + 8 minor dots
        Repeater {
            model: 12
            Item {
                anchors.fill: parent
                rotation: index * 30

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(root.dialSize * 0.06)
                    width: (index % 3 === 0) ? Math.max(5, Math.round(root.dialSize * 0.045)) : Math.max(2, Math.round(root.dialSize * 0.018))
                    height: width
                    radius: (index % 3 === 0) ? Math.round(width * 0.2) : width / 2
                    rotation: (index % 3 === 0) ? 45 : 0
                    color: index === 0 ? root.tertiaryColor : Qt.alpha(root.fgCol, index % 3 === 0 ? 0.85 : 0.35)
                }
            }
        }

        // Tapered compass hour hand
        Item {
            anchors.fill: parent
            rotation: (Time.hours % 12) * 30 + Time.minutes * 0.5
            Behavior on rotation {
                Anim { duration: Tokens.anim.durations.normal }
            }

            Canvas {
                anchors.fill: parent
                property color col: root.fgCol
                onColChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    if (w <= 4)
                        return;
                    const cx = w / 2, cy = h / 2;
                    ctx.fillStyle = col;
                    ctx.beginPath();
                    ctx.moveTo(cx, cy - h * 0.27);
                    ctx.lineTo(cx + w * 0.036, cy);
                    ctx.lineTo(cx, cy + h * 0.06);
                    ctx.lineTo(cx - w * 0.036, cy);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        // Tapered compass minute hand
        Item {
            anchors.fill: parent
            rotation: Time.minutes * 6 + Time.seconds * 0.1
            Behavior on rotation {
                Anim { duration: Tokens.anim.durations.normal }
            }

            Canvas {
                anchors.fill: parent
                property color col: root.variant === 0 ? root.onSurfaceColor : root.fgCol
                onColChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    if (w <= 4)
                        return;
                    const cx = w / 2, cy = h / 2;
                    ctx.fillStyle = col;
                    ctx.beginPath();
                    ctx.moveTo(cx, cy - h * 0.38);
                    ctx.lineTo(cx + w * 0.025, cy);
                    ctx.lineTo(cx, cy + h * 0.07);
                    ctx.lineTo(cx - w * 0.025, cy);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        ContinuousSecondHand {
            handLength: root.dialSize * 0.41
            handWidth: Math.max(1.5, 2 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, Math.round(root.dialSize * 0.065))
            height: width
            radius: width / 2
            color: root.tertiaryColor
        }
    }
}


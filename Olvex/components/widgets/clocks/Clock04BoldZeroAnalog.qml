import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Filled Ticks, 1: Hollow Ticks, 2: Light High-Contrast, 3: Deep Tonal
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest

    readonly property real dialSize: Math.round(168 * clockScale)
    readonly property color dialBg: {
        if (variant === 2) return "#ECEEF2";
        if (variant === 3) return root.surfaceHighColor;
        return root.surfaceColor;
    }
    readonly property color fgColor: variant === 2 ? "#191C20" : root.primaryColor

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        id: dial
        anchors.fill: parent
        radius: width / 2
        color: root.dialBg

        Repeater {
            model: 12
            Item {
                anchors.fill: parent
                visible: (index % 3) !== 0
                rotation: index * 30

                Canvas {
                    width: dial.width * 0.09
                    height: dial.height * 0.14
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: dial.height * 0.035
                    property color c: root.fgColor
                    property bool hollow: root.variant === 1
                    onCChanged: requestPaint()
                    onHollowChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height;
                        if (w <= 2 || h <= 2)
                            return;
                        ctx.beginPath();
                        ctx.moveTo(w * 0.12, 0);
                        ctx.lineTo(w * 0.88, 0);
                        ctx.lineTo(w * 0.65, h);
                        ctx.lineTo(w * 0.35, h);
                        ctx.closePath();
                        if (hollow) {
                            ctx.strokeStyle = c;
                            ctx.lineWidth = Math.max(1.2, w * 0.14);
                            ctx.stroke();
                        } else {
                            ctx.fillStyle = c;
                            ctx.fill();
                        }
                    }
                }
            }
        }

        Repeater {
            model: [
                { label: "0", xF: 0.50, yF: 0.15 },
                { label: "3", xF: 0.84, yF: 0.50 },
                { label: "6", xF: 0.50, yF: 0.84 },
                { label: "9", xF: 0.16, yF: 0.50 }
            ]
            StyledText {
                required property var modelData
                x: dial.width * modelData.xF - width / 2
                y: dial.height * modelData.yF - height / 2
                text: modelData.label
                color: root.fgColor
                textPixelSize: Math.max(10, Math.round(dial.width * 0.21))
                font.family: Tokens.font.family.clock
                font.weight: Font.DemiBold
            }
        }

        SlottedHand {
            angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
            handLength: dial.height * 0.27
            handWidth: dial.width * 0.055
            handColor: root.fgColor
            slotColor: root.dialBg
        }

        SlottedHand {
            angleDeg: Time.minutes * 6 + Time.seconds * 0.1
            handLength: dial.height * 0.38
            handWidth: dial.width * 0.045
            handColor: root.fgColor
            slotColor: root.dialBg
        }

        ContinuousSecondHand {
            handLength: dial.height * 0.42
            handWidth: Math.max(1.5, 2 * root.clockScale)
            handColor: root.tertiaryColor
            active: root.visible
        }

        Rectangle {
            width: Math.max(5, dial.width * 0.055)
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.fgColor
        }
    }
}


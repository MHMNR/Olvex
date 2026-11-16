import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true
    property string dateDetailFormat: "d MMM"

    readonly property real s: 0.86 * clockScale

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Math.round(10 * root.s)

        StyledText {
            visible: root.variant === 1 && root.showDatePill
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Time.format("dddd") + " • " + Time.format(root.dateDetailFormat)).toUpperCase()
            color: root.onSurfaceColor
            textPointSize: Math.max(7, Math.round(9.5 * root.s))
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1 * root.s
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(10 * root.s)

            // Left Tile (Hours)
            Item {
                width: Math.round(92 * root.s)
                height: width

                StyledRect {
                    anchors.fill: parent
                    visible: root.variant === 0
                    radius: Math.round(26 * root.s)
                    color: root.primaryColor
                }

                Canvas {
                    anchors.fill: parent
                    visible: root.variant === 1
                    property color fillCol: root.primaryColor
                    onFillColChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height;
                        if (w <= 2 || h <= 2)
                            return;
                        ctx.fillStyle = fillCol;
                        ctx.beginPath();
                        ctx.moveTo(w * 0.25, h * 0.04);
                        ctx.quadraticCurveTo(w * 0.50, h * 0.13, w * 0.75, h * 0.04);
                        ctx.quadraticCurveTo(w * 0.98, h * 0.02, w * 0.96, h * 0.25);
                        ctx.quadraticCurveTo(w * 0.87, h * 0.50, w * 0.96, h * 0.75);
                        ctx.quadraticCurveTo(w * 0.98, h * 0.98, w * 0.75, h * 0.96);
                        ctx.quadraticCurveTo(w * 0.50, h * 0.87, w * 0.25, h * 0.96);
                        ctx.quadraticCurveTo(w * 0.02, h * 0.98, w * 0.04, h * 0.75);
                        ctx.quadraticCurveTo(w * 0.13, h * 0.50, w * 0.04, h * 0.25);
                        ctx.quadraticCurveTo(w * 0.02, h * 0.02, w * 0.25, h * 0.04);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Time.hourStr
                    color: Colours.palette.m3onPrimary
                    textPointSize: Math.max(12, Math.round(36 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Bold
                }
            }

            // Right Tile (Minutes)
            Item {
                width: Math.round(92 * root.s)
                height: width

                Canvas {
                    anchors.fill: parent
                    visible: root.variant === 0
                    property color fillCol: root.primaryColor
                    onFillColChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height;
                        if (w <= 2 || h <= 2)
                            return;
                        ctx.fillStyle = fillCol;
                        ctx.beginPath();
                        ctx.moveTo(w * 0.25, h * 0.04);
                        ctx.quadraticCurveTo(w * 0.50, h * 0.13, w * 0.75, h * 0.04);
                        ctx.quadraticCurveTo(w * 0.98, h * 0.02, w * 0.96, h * 0.25);
                        ctx.quadraticCurveTo(w * 0.87, h * 0.50, w * 0.96, h * 0.75);
                        ctx.quadraticCurveTo(w * 0.98, h * 0.98, w * 0.75, h * 0.96);
                        ctx.quadraticCurveTo(w * 0.50, h * 0.87, w * 0.25, h * 0.96);
                        ctx.quadraticCurveTo(w * 0.02, h * 0.98, w * 0.04, h * 0.75);
                        ctx.quadraticCurveTo(w * 0.13, h * 0.50, w * 0.04, h * 0.25);
                        ctx.quadraticCurveTo(w * 0.02, h * 0.02, w * 0.25, h * 0.04);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Canvas {
                    anchors.fill: parent
                    visible: root.variant === 1
                    property color strokeCol: root.primaryColor
                    onStrokeColChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height;
                        if (w <= 2 || h <= 2)
                            return;
                        const lw = Math.max(1.5, 2.8 * root.s);
                        const pad = lw / 2;
                        const r = Math.min(Math.round(25 * root.s), (w - lw) / 2);
                        ctx.strokeStyle = strokeCol;
                        ctx.lineWidth = lw;
                        ctx.beginPath();
                        ctx.roundedRect(pad, pad, w - lw, h - lw, r, r);
                        ctx.stroke();
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Time.minuteStr
                    color: root.variant === 0 ? Colours.palette.m3onPrimary : root.primaryColor
                    textPointSize: Math.max(12, Math.round(36 * root.s))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Bold
                }
            }
        }

        StyledText {
            visible: root.variant === 0 && root.showDatePill
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Time.format("dddd") + " • " + Time.format(root.dateDetailFormat)).toUpperCase()
            color: root.primaryColor
            textPointSize: Math.max(7, Math.round(10 * root.s))
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2 * root.s
        }
    }
}


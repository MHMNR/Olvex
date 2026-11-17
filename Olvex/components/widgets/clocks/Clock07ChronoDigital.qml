import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Dual Labels, 1: Minimal
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
    property bool showDatePill: true

    readonly property real dialSize: Math.round(172 * clockScale)

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: dialSize
    implicitHeight: dialSize

    StyledRect {
        id: chronoCircle
        anchors.fill: parent
        radius: width / 2
        color: root.surfaceColor

        Repeater {
            model: 60
            Item {
                anchors.fill: parent
                rotation: index * 6
                readonly property bool isActiveTick: index <= Time.seconds
                readonly property bool isMajor: (index % 5 === 0) && (root.variant === 0)

                Rectangle {
                    width: Math.max(1.4, (parent.isMajor ? 2.6 : 1.8) * root.clockScale)
                    height: chronoCircle.height * (parent.isMajor ? 0.055 : 0.038)
                    radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: chronoCircle.height * 0.035
                    color: root.primaryColor
                    opacity: parent.isActiveTick ? 0.95 : 0.25
                }
            }
        }

        StyledText {
            visible: root.variant === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.17
            text: Time.format("t").toUpperCase()
            color: root.primaryColor
            textPixelSize: Math.max(8, Math.round(parent.height * 0.068))
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Canvas {
            anchors.centerIn: parent
            width: chronoCircle.width * 0.72
            height: chronoCircle.height * 0.44
            property string timeTxt: Time.hourStr + ":" + Time.minuteStr
            property color txtCol: root.primaryColor
            property string fontFam: Tokens.font.family.clock
            onTimeTxtChanged: requestPaint()
            onTxtColChanged: requestPaint()
            onFontFamChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (width <= 4 || height <= 4)
                    return;
                ctx.save();
                ctx.translate(width / 2, height / 2);
                ctx.scale(0.68, 1.25);
                const cssFam = /^(serif|sans-serif|monospace)$/i.test(fontFam) ? fontFam.toLowerCase() : ("'" + fontFam + "', sans-serif");
                ctx.font = "800 " + Math.round(height * 0.72) + "px " + cssFam;
                ctx.fillStyle = txtCol;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText(timeTxt, 0, 0);
                ctx.restore();
            }
        }

        StyledText {
            visible: root.showDatePill
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.75
            text: root.variant === 0
                ? Time.format("ddd, d MMM").toUpperCase()
                : Time.format("t").toUpperCase()
            color: root.primaryColor
            textPixelSize: Math.max(8, Math.round(parent.height * 0.068))
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }
    }
}


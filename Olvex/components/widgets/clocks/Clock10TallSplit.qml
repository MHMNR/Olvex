import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Rounded Square Card, 1: Frameless Floating
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface

    readonly property real boxSize: Math.round(170 * clockScale)

    implicitWidth: boxSize
    implicitHeight: boxSize

    StyledRect {
        id: splitCard
        anchors.fill: parent
        radius: Math.round(width * 0.16)
        color: root.variant === 0 ? Colours.palette.m3surfaceContainerHigh : "transparent"

        readonly property string hourStr: Time.hourStr
        readonly property string minStr: Time.minuteStr
        readonly property string apStr: Time.amPmStr || Time.format("AP")
        readonly property color pillBg: root.variant === 0
            ? Qt.alpha(Colours.palette.m3onSurface, 0.14)
            : Colours.palette.m3surfaceContainerHigh

        readonly property real contentW: Math.round(root.boxSize * 0.73)
        readonly property real contentH: Math.round(root.boxSize * 0.75)
        readonly property real leftW: Math.round(root.boxSize * 0.43)
        readonly property real rightW: Math.round(root.boxSize * 0.25)
        readonly property real minH: Math.round(contentH * 0.51)
        readonly property real pillH: Math.round(contentH * 0.39)

        TextMetrics {
            id: hourMetrics
            font.family: Tokens.font.family.sans
            font.pixelSize: Math.round(root.boxSize * 0.72)
            font.weight: Font.Bold
            font.letterSpacing: Math.round(root.boxSize * 0.01)
            text: splitCard.hourStr
        }

        TextMetrics {
            id: minMetrics
            font.family: Tokens.font.family.sans
            font.pixelSize: Math.round(root.boxSize * 0.38)
            font.weight: Font.Bold
            font.letterSpacing: Math.round(root.boxSize * 0.008)
            text: splitCard.minStr
        }

        TextMetrics {
            id: apMetrics
            font.family: Tokens.font.family.sans
            font.pixelSize: Math.round(root.boxSize * 0.175)
            font.weight: Font.Bold
            font.letterSpacing: Math.round(root.boxSize * 0.004)
            text: splitCard.apStr
        }

        Item {
            anchors.centerIn: parent
            width: splitCard.contentW
            height: splitCard.contentH

            // Left: Full-height condensed hours, exact tight-bounds fit
            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: splitCard.leftW

                Text {
                    id: hourText
                    anchors.centerIn: parent
                    text: splitCard.hourStr
                    color: root.primaryColor
                    font: hourMetrics.font
                    renderType: Text.QtRendering
                    readonly property real sx: hourMetrics.tightBoundingRect.width > 0
                        ? (parent.width / hourMetrics.tightBoundingRect.width) : 0.48
                    readonly property real sy: hourMetrics.tightBoundingRect.height > 0
                        ? (parent.height / hourMetrics.tightBoundingRect.height) : 1.45
                    readonly property real visualOffsetY: (hourMetrics.tightBoundingRect.y - hourMetrics.boundingRect.y) + hourMetrics.tightBoundingRect.height / 2 - height / 2
                    transform: [
                        Translate { y: -hourText.visualOffsetY },
                        Scale {
                            origin.x: hourText.width / 2
                            origin.y: hourText.height / 2
                            xScale: hourText.sx
                            yScale: hourText.sy
                        }
                    ]
                }
            }

            // Right Top: Condensed minutes flush to top
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                width: splitCard.rightW
                height: splitCard.minH

                Text {
                    id: minText
                    anchors.centerIn: parent
                    text: splitCard.minStr
                    color: root.tertiaryColor
                    font: minMetrics.font
                    renderType: Text.QtRendering
                    readonly property real sx: minMetrics.tightBoundingRect.width > 0
                        ? (parent.width / minMetrics.tightBoundingRect.width) : 0.50
                    readonly property real sy: minMetrics.tightBoundingRect.height > 0
                        ? (parent.height / minMetrics.tightBoundingRect.height) : 1.38
                    readonly property real visualOffsetY: (minMetrics.tightBoundingRect.y - minMetrics.boundingRect.y) + minMetrics.tightBoundingRect.height / 2 - height / 2
                    transform: [
                        Translate { y: -minText.visualOffsetY },
                        Scale {
                            origin.x: minText.width / 2
                            origin.y: minText.height / 2
                            xScale: minText.sx
                            yScale: minText.sy
                        }
                    ]
                }
            }

            // Right Bottom: Portrait rounded AM/PM pill flush to bottom
            StyledRect {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: splitCard.rightW
                height: splitCard.pillH
                radius: Math.round(width * 0.25)
                color: splitCard.pillBg

                Text {
                    id: apText
                    anchors.centerIn: parent
                    text: splitCard.apStr
                    color: root.primaryColor
                    font: apMetrics.font
                    renderType: Text.QtRendering
                    readonly property real sx: apMetrics.tightBoundingRect.width > 0
                        ? ((parent.width * 0.58) / apMetrics.tightBoundingRect.width) : 0.56
                    readonly property real sy: apMetrics.tightBoundingRect.height > 0
                        ? ((parent.height * 0.48) / apMetrics.tightBoundingRect.height) : 1.30
                    readonly property real visualOffsetY: (apMetrics.tightBoundingRect.y - apMetrics.boundingRect.y) + apMetrics.tightBoundingRect.height / 2 - height / 2
                    transform: [
                        Translate { y: -apText.visualOffsetY },
                        Scale {
                            origin.x: apText.width / 2
                            origin.y: apText.height / 2
                            xScale: apText.sx
                            yScale: apText.sy
                        }
                    ]
                }
            }
        }
    }
}


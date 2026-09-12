import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    readonly property real designWidth: 180
    readonly property real designHeight: 155

    property color leftBeamColour: Colours.palette.m3primary
    property color rightBeamColour: Colours.palette.m3tertiary
    property color waveColour: Colours.palette.m3onSurface

    // Backwards compatibility aliases
    property alias topColour: root.leftBeamColour
    property alias bottomColour: root.rightBeamColour

    implicitWidth: 24
    implicitHeight: 20

    Shape {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        // Left roof beam
        ShapePath {
            strokeColor: root.leftBeamColour
            strokeWidth: 28
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            startX: 28
            startY: 114
            PathLine { x: 73; y: 20 }
        }

        // Right roof beam
        ShapePath {
            strokeColor: root.rightBeamColour
            strokeWidth: 28
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            startX: 152
            startY: 114
            PathLine { x: 107; y: 20 }
        }

        // Wavy signal line (M3 Expressive wave)
        ShapePath {
            strokeColor: root.waveColour
            strokeWidth: 10
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            startX: 10
            startY: 130
            PathCubic {
                control1X: 40
                control1Y: 116
                control2X: 60
                control2Y: 144
                x: 90
                y: 130
            }
            PathCubic {
                control1X: 120
                control1Y: 116
                control2X: 140
                control2Y: 144
                x: 170
                y: 130
            }
        }
    }
}

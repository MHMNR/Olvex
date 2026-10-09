import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property real brightness: 0.5 // 0.0 to 1.0
    property bool nightMode: false // false = Sun, true = Crescent Moon
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    QtObject {
        id: smoothBrightness
        property real val: root.brightness
        Behavior on val {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }

    QtObject {
        id: smoothMoonMorph
        property real val: root.nightMode ? 1.0 : 0.0
        Behavior on val {
            NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0.0, 1.0] }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        property color uColor: root.color
        property real uBrightness: smoothBrightness.val
        property real uTransition: 0.0
        property real uTime: 0.0

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_brightness.frag.qsb")

        Behavior on uColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    FrameAnimation {
        running: root.visible && (shader.uMoonMorph < 0.99)
        onTriggered: shader.uTime += frameTime
    }
}

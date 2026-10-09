import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property bool muted: false
    property real inputLevel: 0.0 // 0.0 to 1.0
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    QtObject {
        id: smoothMuted
        property real val: root.muted ? 1.0 : 0.0
        Behavior on val {
            NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0.0, 1.0] }
        }
    }

    QtObject {
        id: smoothInput
        property real val: root.inputLevel
        Behavior on val {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        property color uColor: root.color
        property real uMuted: smoothMuted.val
        property real uInputLevel: smoothInput.val
        property real uTransition: 0.0
        property real uTime: 0.0

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_mic.frag.qsb")

        Behavior on uColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    FrameAnimation {
        running: root.visible && (shader.uInputLevel > 0.02)
        onTriggered: shader.uTime += frameTime
    }
}

import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property real volume: 0.5 // 0.0 to 1.0
    property bool muted: false
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    property real transitionTrigger: 0.0
    onMutedChanged: bounceAnim.restart()

    NumberAnimation {
        id: bounceAnim
        target: root
        property: "transitionTrigger"
        from: 0.0
        to: 1.0
        duration: 320
        easing.type: Easing.OutCubic
    }

    QtObject {
        id: smoothVolume
        property real val: root.volume
        Behavior on val {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    QtObject {
        id: smoothMuted
        property real val: root.muted ? 1.0 : 0.0
        Behavior on val {
            NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.35, 0.64, 1.0] }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        property color uColor: root.color
        property real uVolume: smoothVolume.val
        property real uMuted: smoothMuted.val
        property real uTransition: root.transitionTrigger
        property real uTime: 0.0

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_volume.frag.qsb")

        Behavior on uColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    FrameAnimation {
        running: root.visible && (shader.uVolume > 0.01 || shader.uMuted > 0.01 || bounceAnim.running)
        onTriggered: shader.uTime += frameTime
    }
}

import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property real strength: 1.0     // 0.0 to 1.0 (maps to 0-4 bars)
    property bool searching: false  // true = searching wave animation
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    QtObject {
        id: smoothStrength
        property real val: root.strength
        Behavior on val {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        property color uColor: root.color
        property real uStrength: smoothStrength.val
        property real uSearching: root.searching ? 1.0 : 0.0
        property real uTime: 0.0

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_cellular.frag.qsb")

        Behavior on uColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    FrameAnimation {
        running: root.visible && root.searching
        onTriggered: shader.uTime += frameTime
    }
}

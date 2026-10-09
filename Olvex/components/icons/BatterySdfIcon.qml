import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property real level: 0.75       // 0.0 to 1.0 (battery level)
    property bool charging: false   // true = charging bolt
    property real size: 24

    implicitWidth: Math.round(size * 1.15)
    implicitHeight: size
    width: Math.round(size * 1.15)
    height: size

    readonly property color fillColor: {
        if (root.charging)
            return (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3primary : "#a8c7fa";
        if (root.level <= 0.20)
            return (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3error : "#ffb4ab";
        return (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3primary : "#a8c7fa";
    }

    QtObject {
        id: smoothLevel
        property real val: root.level
        Behavior on val {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    QtObject {
        id: smoothCharging
        property real val: root.charging ? 1.0 : 0.0
        Behavior on val {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        property color uColor: root.color
        property color uFillColor: root.fillColor
        property real uLevel: smoothLevel.val
        property real uCharging: smoothCharging.val
        property real uTransition: 0.0
        property real uTime: 0.0

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_battery.frag.qsb")

        Behavior on uColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on uFillColor {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    FrameAnimation {
        running: root.visible && (shader.uCharging > 0.05)
        onTriggered: shader.uTime += frameTime
    }
}

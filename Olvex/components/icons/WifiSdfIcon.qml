import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#e2e2e6"
    property real strength: 1.0     // 0.0 to 1.0 (signal strength)
    property bool connected: true   // true = connected, false = disconnected
    property bool connecting: false // true = animated scanning/connecting radar wave
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Elastic Scale Pulse on toggle (0.95x -> 1.08x -> 1.0x)
    onConnectedChanged: togglePulse.restart()

    SequentialAnimation {
        id: togglePulse
        NumberAnimation { target: iconScale; property: "xScale"; to: 0.95; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "yScale"; to: 0.95; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.08; duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.08; duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1.0] }
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.00; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.00; duration: 120; easing.type: Easing.OutQuad }
    }

    Item {
        id: iconContainer
        anchors.fill: parent
        transform: Scale {
            id: iconScale
            origin.x: iconContainer.width / 2
            origin.y: iconContainer.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        QtObject {
            id: smoothStrength
            property real val: root.strength
            Behavior on val {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        QtObject {
            id: smoothConnected
            property real val: root.connected ? 1.0 : 0.0
            Behavior on val {
                NumberAnimation {
                    duration: root.connected ? 320 : 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.8, 0.2, 1.0]
                }
            }
        }

        QtObject {
            id: smoothConnecting
            property real val: root.connecting ? 1.0 : 0.0
            Behavior on val {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        ShaderEffect {
            id: shader
            anchors.fill: parent

            property color uColor: root.color
            property real uStrength: smoothStrength.val
            property real uConnected: smoothConnected.val
            property real uConnecting: smoothConnecting.val
            property real uTransition: togglePulse.running ? 1.0 : 0.0
            property real uTime: 0.0

            fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_wifi.frag.qsb")

            Behavior on uColor {
                ColorAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1.0] }
            }
        }

        FrameAnimation {
            running: root.visible && (root.connecting || root.connected)
            onTriggered: shader.uTime += frameTime
        }
    }
}

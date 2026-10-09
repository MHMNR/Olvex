import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ff3b30"
    property bool muted: true       // true = Silent Active (Red), false = Normal Ringer
    property bool swinging: false   // Ringing / Alert swing
    property bool hasBadge: false   // Notification indicator dot
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Exact Frame-by-Frame Motion State Trigger
    onMutedChanged: {
        if (muted) {
            // OFF -> ON: Slash draws in (150ms), then triggers 100ms haptic shake (3 cycles)
            shakeDelayTimer.restart()
        } else {
            // ON -> OFF: Slash erases (180ms) + Bell expansion bounce 1.0x -> 1.08x -> 1.0x
            unmuteExpansion.restart()
        }
    }

    Timer {
        id: shakeDelayTimer
        interval: 140
        onTriggered: hapticMicroShake.restart()
    }

    // 100ms 3-cycle horizontal micro-shake (±2px)
    SequentialAnimation {
        id: hapticMicroShake
        NumberAnimation { target: iconContainer; property: "x"; to: -2; duration: 18; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 2; duration: 20; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.5; duration: 18; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 1.5; duration: 16; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.0; duration: 14; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 0; duration: 14; easing.type: Easing.OutQuad }
    }

    // Unmute Expansion Bounce (1.0x -> 1.08x -> 1.0x)
    SequentialAnimation {
        id: unmuteExpansion
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.08; duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.08; duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.00; duration: 80; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.00; duration: 80; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
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
            id: smoothMuted
            property real val: root.muted ? 1.0 : 0.0
            Behavior on val {
                // 150ms draw-in (Overshoot Spring) / 180ms erase (Ease Out)
                NumberAnimation {
                    duration: root.muted ? 150 : 180
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.muted ? [0.34, 1.56, 0.64, 1.0] : [0.25, 1.0, 0.5, 1.0]
                }
            }
        }

        QtObject {
            id: smoothSwing
            property real val: root.swinging ? 1.0 : 0.0
            Behavior on val {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }

        ShaderEffect {
            id: shader
            anchors.fill: parent

            property color uColor: root.color
            property real uMuted: smoothMuted.val
            property real uSwing: smoothSwing.val
            property real uHasBadge: root.hasBadge ? 1.0 : 0.0
            property real uTime: 0.0

            fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_bell.frag.qsb")

            Behavior on uColor {
                ColorAnimation {
                    duration: root.muted ? 150 : 180
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
                }
            }
        }

        FrameAnimation {
            running: root.visible && (shader.uSwing > 0.01)
            onTriggered: shader.uTime += frameTime
        }
    }
}

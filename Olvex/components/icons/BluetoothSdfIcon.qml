import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property bool connected: true   // true = connected (Blue/White), false = off (Gray)
    property bool searching: false  // true = pairing / searching beacon pulse
    property real size: 22

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Frame-by-Frame Spring Physics on State Switch
    onConnectedChanged: {
        if (connected) {
            // OFF -> ON: 0.85x -> 1.15x -> 1.0x overshoot spring
            enableSpring.restart()
        } else {
            // ON -> OFF: 2-3px downward push + 0.90x micro-compress
            disableCompress.restart()
        }
    }

    SequentialAnimation {
        id: enableSpring
        NumberAnimation { target: iconScale; property: "xScale"; to: 0.85; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "yScale"; to: 0.85; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: iconScale
            property: "xScale"
            to: 1.15
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0]
        }
        NumberAnimation {
            target: iconScale
            property: "yScale"
            to: 1.15
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0]
        }
        NumberAnimation {
            target: iconScale
            property: "xScale"
            to: 1.00
            duration: 100
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
        }
        NumberAnimation {
            target: iconScale
            property: "yScale"
            to: 1.00
            duration: 100
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
        }
    }

    SequentialAnimation {
        id: disableCompress
        ParallelAnimation {
            NumberAnimation { target: iconContainer; property: "y"; to: 2.5; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconScale; property: "xScale"; to: 0.90; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconScale; property: "yScale"; to: 0.90; duration: 70; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: iconContainer; property: "y"; to: 0.0; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
            NumberAnimation { target: iconScale; property: "xScale"; to: 1.00; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
            NumberAnimation { target: iconScale; property: "yScale"; to: 1.00; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
        }
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
            id: smoothConnected
            property real val: root.connected ? 1.0 : 0.0
            Behavior on val {
                NumberAnimation {
                    duration: root.connected ? 280 : 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.connected ? [0.34, 1.56, 0.64, 1.0] : [0.25, 1.0, 0.5, 1.0]
                }
            }
        }

        QtObject {
            id: smoothSearching
            property real val: root.searching ? 1.0 : 0.0
            Behavior on val {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        ShaderEffect {
            id: shader
            anchors.fill: parent

            property color uColor: root.color
            property real uConnected: smoothConnected.val
            property real uSearching: smoothSearching.val
            property real uTransition: (enableSpring.running || disableCompress.running) ? 1.0 : 0.0
            property real uTime: 0.0

            fragmentShader: Qt.resolvedUrl("../../assets/shaders/icons/icon_bluetooth.frag.qsb")

            Behavior on uColor {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
                }
            }
        }

        FrameAnimation {
            running: root.visible && root.searching
            onTriggered: shader.uTime += frameTime
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

// ListView with smooth wheel physics + optional populate transitions.
// Edge gradient fades off by default (set edgeFades: true to re-enable).
// Opt out: smoothWheel / animatePopulate
// Not for text editors.
ListView {
    id: root

    // --- Edge gradients (off by default) ---
    property bool edgeFades: false
    property color fadeColor: Colours.palette.m3surface
    property real topFadeHeight: 50
    property real bottomFadeHeight: 100
    property real fadeScrollRange: 50

    // --- Wheel physics (browser-like, not raw Qt flick) ---
    property bool smoothWheel: true
    property real scrollLineStep: 48
    property real scrollLinesPerNotch: 3
    property int wheelAnimMs: 280
    property int touchpadAnimMs: 120

    property bool animatePopulate: true

    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2800
    maximumFlickVelocity: 2800
    clip: true

    rebound: Transition {
        Anim {
            properties: "x,y"
        }
    }

    // React Bits gradient opacity (0 = no overlay, 1 = full)
    property real topGradientOpacity: {
        if (!edgeFades)
            return 0;
        if (contentHeight + topMargin + bottomMargin <= height + 1)
            return 0;
        return Math.min(Math.max(contentY / fadeScrollRange, 0), 1);
    }
    property real bottomGradientOpacity: {
        if (!edgeFades)
            return 0;
        if (contentHeight + topMargin + bottomMargin <= height + 1)
            return 0;
        const bottomDistance = contentHeight - (contentY + height);
        return Math.min(Math.max(bottomDistance / fadeScrollRange, 0), 1);
    }

    // --- populate transitions (AnimatedItem enter/leave) ---
    add: root.animatePopulate ? addTrans : null
    addDisplaced: root.animatePopulate ? displaceTrans : null
    displaced: root.animatePopulate ? displaceTrans : null
    remove: root.animatePopulate ? removeTrans : null
    removeDisplaced: root.animatePopulate ? displaceTrans : null

    Transition {
        id: addTrans
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 0.7
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Transition {
        id: removeTrans
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            property: "scale"
            to: 0.7
            duration: 160
            easing.type: Easing.InCubic
        }
    }

    Transition {
        id: displaceTrans
        NumberAnimation {
            properties: "x,y"
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            properties: "opacity,scale"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    // --- Smooth scroll physics ---
    NumberAnimation {
        id: smoothScrollAnim
        target: root
        property: "contentY"
        duration: root.wheelAnimMs
        easing.type: Easing.OutCubic
    }

    onMovementStarted: smoothScrollAnim.stop()
    onFlickStarted: smoothScrollAnim.stop()

    function clampScrollY(y: real): real {
        const maxScroll = Math.max(0, contentHeight - height);
        return Math.max(0, Math.min(maxScroll, y));
    }

    function applyScrollDelta(deltaPx: real, animate: bool, animMs: int): void {
        const base = smoothScrollAnim.running ? smoothScrollAnim.to : contentY;
        const targetY = clampScrollY(base + deltaPx);
        if (Math.abs(targetY - contentY) < 0.5 && !smoothScrollAnim.running)
            return;
        if (animate) {
            smoothScrollAnim.stop();
            smoothScrollAnim.duration = animMs;
            smoothScrollAnim.from = contentY;
            smoothScrollAnim.to = targetY;
            smoothScrollAnim.start();
        } else {
            smoothScrollAnim.stop();
            contentY = targetY;
        }
    }

    WheelHandler {
        enabled: root.smoothWheel && root.orientation === ListView.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (event) {
            const dev = event.device;
            const isTouchPad = dev && dev.type === PointerDevice.TouchPad;

            if (isTouchPad && event.pixelDelta.y !== 0) {
                root.applyScrollDelta(-event.pixelDelta.y, true, root.touchpadAnimMs);
                event.accepted = true;
                return;
            }

            const angleY = event.angleDelta.y;
            if (angleY === 0)
                return;

            if (isTouchPad) {
                root.applyScrollDelta(-(angleY / 120) * root.scrollLineStep * 1.25, true, root.touchpadAnimMs);
            } else {
                const notchPx = -(angleY / 120) * root.scrollLineStep * root.scrollLinesPerNotch;
                root.applyScrollDelta(notchPx, true, root.wheelAnimMs);
            }
            event.accepted = true;
        }
    }

    // Viewport overlays (reparent out of contentItem so they don't scroll)
    Rectangle {
        id: topGradient
        z: 1000
        height: root.topFadeHeight
        opacity: root.topGradientOpacity
        visible: root.edgeFades && opacity > 0.001
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.fadeColor
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0)
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Component.onCompleted: {
            parent = root;
            anchors.top = root.top;
            anchors.left = root.left;
            anchors.right = root.right;
        }
    }

    Rectangle {
        id: bottomGradient
        z: 1000
        height: root.bottomFadeHeight
        opacity: root.bottomGradientOpacity
        visible: root.edgeFades && opacity > 0.001
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0)
            }
            GradientStop {
                position: 1
                color: root.fadeColor
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Component.onCompleted: {
            parent = root;
            anchors.bottom = root.bottom;
            anchors.left = root.left;
            anchors.right = root.right;
        }
    }
}

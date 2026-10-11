
import QtQuick
import qs.components
import qs.components.controls
import qs.services

// Flickable with smooth wheel physics and responsive touchpad gestures.
// Edge gradient fades off by default (set edgeFades: true to re-enable).
// Opt out: smoothWheel, showScrollBar
// Do NOT use for pure text editors — use plain Flickable/TextEdit there.
Flickable {
    id: root

    property bool edgeFades: false
    property color fadeColor: Colours.palette.m3surface
    property real topFadeHeight: 50
    property real bottomFadeHeight: 100
    property real fadeScrollRange: 50

    property bool smoothWheel: true
    property real scrollLineStep: 48
    property real scrollLinesPerNotch: 3
    property real scrollStep: scrollLineStep * scrollLinesPerNotch
    property int wheelAnimMs: 260

    property bool showScrollBar: true

    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 2200
    maximumFlickVelocity: 3200
    clip: true

    rebound: Transition {
        Anim {
            properties: "x,y"
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
        visible: root.showScrollBar && (root.contentHeight > root.height)
    }

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

    // Material 3 Expressive Smooth Momentum Scroll (exact AppList physics)
    NumberAnimation {
        id: smoothScrollAnim
        target: root
        property: "contentY"
        duration: root.wheelAnimMs
        easing.type: Easing.OutCubic

        onStopped: root.checkOverscrollBounds()
    }

    // Elastic Overscroll Rebound Spring
    SpringAnimation {
        id: bounceBackSpring
        target: root
        property: "contentY"
        spring: 4.8
        damping: 0.70
        epsilon: 0.15
    }

    property real touchpadVelocity: 0

    Timer {
        id: touchpadReleaseTimer
        interval: 85
        repeat: false
        onTriggered: {
            const maxScroll = Math.max(0, root.contentHeight - root.height);
            if (Math.abs(root.touchpadVelocity) > 4 && root.contentY >= 0 && root.contentY <= maxScroll) {
                const glideDist = root.touchpadVelocity * 6;
                let glideTarget = root.contentY + glideDist;
                glideTarget = Math.max(0, Math.min(maxScroll, glideTarget));
                root.touchpadVelocity = 0;
                smoothScrollAnim.stop();
                smoothScrollAnim.duration = 220;
                smoothScrollAnim.from = root.contentY;
                smoothScrollAnim.to = glideTarget;
                smoothScrollAnim.start();
            } else {
                root.touchpadVelocity = 0;
                root.checkOverscrollBounds();
            }
        }
    }

    onDraggingChanged: {
        if (dragging) {
            smoothScrollAnim.stop();
            bounceBackSpring.stop();
            touchpadReleaseTimer.stop();
            touchpadVelocity = 0;
        }
    }
    onFlickEnded: root.checkOverscrollBounds()
    onMovementEnded: root.checkOverscrollBounds()

    function checkOverscrollBounds() {
        const maxScroll = Math.max(0, root.contentHeight - root.height);
        if (root.contentY < 0) {
            smoothScrollAnim.stop();
            bounceBackSpring.stop();
            bounceBackSpring.from = root.contentY;
            bounceBackSpring.to = 0;
            bounceBackSpring.start();
        } else if (root.contentY > maxScroll) {
            smoothScrollAnim.stop();
            bounceBackSpring.stop();
            bounceBackSpring.from = root.contentY;
            bounceBackSpring.to = maxScroll;
            bounceBackSpring.start();
        }
    }

    function applyScrollDelta(deltaPx, animate) {
        const maxScroll = Math.max(0, root.contentHeight - root.height);
        const base = smoothScrollAnim.running ? smoothScrollAnim.to : root.contentY;
        let nextTarget = base + deltaPx;
        const maxOvershoot = 36;
        if (nextTarget < -maxOvershoot)
            nextTarget = -maxOvershoot;
        else if (nextTarget > maxScroll + maxOvershoot)
            nextTarget = maxScroll + maxOvershoot;

        bounceBackSpring.stop();
        touchpadReleaseTimer.stop();
        root.touchpadVelocity = 0;

        if (animate) {
            smoothScrollAnim.stop();
            smoothScrollAnim.duration = root.wheelAnimMs;
            smoothScrollAnim.from = root.contentY;
            smoothScrollAnim.to = nextTarget;
            smoothScrollAnim.start();
        } else {
            smoothScrollAnim.stop();
            root.contentY = nextTarget;
            root.checkOverscrollBounds();
        }
    }

    WheelHandler {
        target: null
        enabled: root.smoothWheel && root.flickableDirection !== Flickable.HorizontalFlick
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            const delta = event.angleDelta.y;
            const pDelta = event.pixelDelta ? event.pixelDelta.y : 0;
            if (!delta && !pDelta)
                return;

            const effectiveDelta = delta !== 0 ? delta : (pDelta * 4);
            const maxScroll = Math.max(0, root.contentHeight - root.height);
            const isDiscrete = Math.abs(effectiveDelta) >= 120;
            const direction = effectiveDelta > 0 ? -1 : 1;

            if (isDiscrete) {
                // Discrete mouse wheel notch: fluid momentum step (AppList physics)
                bounceBackSpring.stop();
                touchpadReleaseTimer.stop();
                root.touchpadVelocity = 0;

                const step = root.scrollStep;
                const base = smoothScrollAnim.running ? smoothScrollAnim.to : root.contentY;
                let nextTarget = base + direction * step;

                // Allow elastic overscroll bounce up to 36px past edge limits
                const maxOvershoot = 36;
                if (nextTarget < -maxOvershoot) {
                    nextTarget = -maxOvershoot;
                } else if (nextTarget > maxScroll + maxOvershoot) {
                    nextTarget = maxScroll + maxOvershoot;
                }

                smoothScrollAnim.stop();
                smoothScrollAnim.duration = root.wheelAnimMs;
                smoothScrollAnim.from = root.contentY;
                smoothScrollAnim.to = nextTarget;
                smoothScrollAnim.start();
            } else {
                // Smooth pixel touchpad scrolling with elastic edge resistance (AppList physics)
                smoothScrollAnim.stop();
                bounceBackSpring.stop();

                let dy = pDelta !== 0 ? -pDelta : -effectiveDelta * 0.65;
                root.touchpadVelocity = dy;

                let newY = root.contentY + dy;
                if (newY < 0) {
                    newY = root.contentY + dy * 0.35;
                } else if (newY > maxScroll) {
                    newY = root.contentY + dy * 0.35;
                }

                root.contentY = newY;
                touchpadReleaseTimer.restart();
            }

            event.accepted = true;
        }
    }

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

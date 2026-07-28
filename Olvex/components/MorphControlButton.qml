pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

// Shared media control button — identical design in the bar music pill and the
// MediaMorphOverlay card, so the pill→card morph stays seamless.
Item {
    id: control

    signal clicked()
    required property string iconName
    property bool emphasized: false
    property bool expandedTone: false
    property bool spinning: false
    property bool animateSpin: false
    property real iconSize: 14
    property real clickScale: 1.0
    // Decoupled X/Y scale for the rubber squash animation on the icon
    property real iconScaleX: 1.0
    property real iconScaleY: 1.0
    property real radius: Math.min(width, height) / 2
    readonly property real visualScale: clickScale
        * (stateLayer.containsMouse ? 1.05 : 1.0)
    readonly property real innerPad: control.emphasized ? 0 : 4
    readonly property color activeIconColor: control.emphasized
        ? Players.musicPlayIconColor
        : Qt.alpha(Players.musicOnSurfaceColor, stateLayer.containsMouse ? 0.98 : 0.78)
    readonly property color disabledIconColor: Qt.alpha(Players.musicOnSurfaceColor, 0.25)
    readonly property color containerTone: control.emphasized
        ? Players.musicPlayButtonBg
        : (control.expandedTone
            ? Qt.alpha(Players.musicOnSurfaceColor, stateLayer.containsMouse ? 0.18 : 0.075)
            : "transparent")
    readonly property color strokeColor: control.emphasized
        ? Qt.alpha(Players.musicPlayIconColor, stateLayer.pressed ? 0.30 : 0.16)
        : (control.expandedTone
            ? Qt.alpha(Players.musicOnSurfaceColor, stateLayer.containsMouse ? 0.24 : 0.10)
            : "transparent")

    width: 30; height: 30
    scale: visualScale

    // Layout hints — honoured when placed in a Layout (bar pill), ignored when
    // x/y positioned (morph card states).
    Layout.preferredWidth: width
    Layout.preferredHeight: height
    Layout.minimumWidth: width
    Layout.minimumHeight: height
    Layout.alignment: Qt.AlignHCenter

    MaterialShape {
        id: controlShape
        anchors.centerIn: parent
        implicitSize: Math.max(1, Math.min(parent.width, parent.height) - control.innerPad)
        shape: control.spinning
            ? MaterialShape.Cookie12Sided
            : (control.emphasized ? MaterialShape.Circle : MaterialShape.Pill)
        color: control.containerTone
        strokeColor: control.strokeColor
        strokeWidth: 0
        animationDuration: Tokens.anim.durations.expressiveFastSpatial
        animationEasing: Tokens.anim.expressiveFastSpatial
        Behavior on color { ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastEffects } }
        Behavior on strokeColor { ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastEffects } }
    }

    RotationAnimator {
        target: controlShape
        to: 360
        duration: 8000
        loops: Animation.Infinite
        running: control.animateSpin && control.spinning && control.visible && control.opacity > 0
        easing.type: Easing.Linear
        onRunningChanged: {
            if (!running)
                controlShape.rotation = 0
        }
    }

    Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.62; mass: 1.0; epsilon: 0.004 } }

    MaterialIcon {
        id: controlIcon
        anchors.centerIn: parent
        text: control.iconName
        color: Players.active ? control.activeIconColor : control.disabledIconColor
        iconPointSize: control.iconSize
        fill: 1
        font.weight: control.emphasized ? 850 : 300
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        animate: control.emphasized
        animateProp: "rotation"
        animateFrom: 90; animateTo: 0; animateDuration: 320

        // Rubber squash: decoupled X/Y transform, pivot stays at center
        transform: Scale {
            origin.x: controlIcon.width / 2
            origin.y: controlIcon.height / 2
            xScale: control.iconScaleX
            yScale: control.iconScaleY
        }
    }

    // Press: fast squeeze in X, slight compress in Y (80ms OutQuad)
    // Release: spring-back with elastic X-stretch overshoot, Y settles faster
    states: [
        State {
            name: "pressed"
            when: stateLayer.pressed
            PropertyChanges { target: control; iconScaleX: 0.72; iconScaleY: 0.94 }
        },
        State {
            name: "idle"
            when: !stateLayer.pressed
            PropertyChanges { target: control; iconScaleX: 1.0; iconScaleY: 1.0 }
        }
    ]

    transitions: [
        Transition {
            from: "idle"; to: "pressed"
            NumberAnimation { properties: "iconScaleX,iconScaleY"; duration: 80; easing.type: Easing.OutQuad }
        },
        Transition {
            from: "pressed"; to: "idle"
            ParallelAnimation {
                // X: rubbery overshoot — low damping = elastic wobble
                SpringAnimation { target: control; property: "iconScaleX"; to: 1.0; spring: 4.5; damping: 0.22; epsilon: 0.005 }
                // Y: snappier settle — higher damping prevents vertical flap
                SpringAnimation { target: control; property: "iconScaleY"; to: 1.0; spring: 5.0; damping: 0.38; epsilon: 0.005 }
            }
        }
    ]

    SequentialAnimation {
        id: pressSpring
        ParallelAnimation {
            NumberAnimation { target: control; property: "clickScale"; to: 0.88; duration: Tokens.anim.durations.expressiveFastEffects; easing: Tokens.anim.expressiveFastSpatial }
        }
        SpringAnimation { target: control; property: "clickScale"; to: 1.0; spring: 5.6; damping: 0.58; mass: 1.0; epsilon: 0.004 }
    }

    StateLayer {
        id: stateLayer
        radius: parent.radius
        showHoverBackground: false
        showRipple: false
        stateOpacity: 0
        color: control.emphasized ? control.activeIconColor : Players.musicOnSurfaceColor
        enabled: Players.active !== null
        onPressed: pressSpring.restart()
        onClicked: control.clicked()
    }
}

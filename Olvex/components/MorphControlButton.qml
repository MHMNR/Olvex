pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import M3Shapes
import Olvex.Config
import qs.components
import qs.services

// Shared media control button — identical design in the bar music pill and the
// MediaMorphOverlay card, so the pill→card morph stays seamless.
Item {
    id: control

    signal clicked
    required property string iconName
    property bool emphasized: false
    property bool expandedTone: false
    property bool balancedSkipIcon: false
    property bool elevated: false
    property bool cookieMorphOnClick: false
    property real secondaryProgress: expandedTone ? 1.0 : 0.0
    property int secondaryShape: MaterialShape.Pill
    property int clickMorphShape: MaterialShape.Cookie12Sided
    property bool clickMorphActive: false
    property real skipIconScale: 1.0
    property real iconSize: 14
    property real clickScale: 1.0
    // Decoupled X/Y scale for the rubber squash animation on the icon
    property real iconScaleX: 1.0
    property real iconScaleY: 1.0
    property real radius: Math.min(width, height) / 2
    readonly property bool isSkipIcon: balancedSkipIcon && (iconName === "skip_previous" || iconName === "skip_next")
    readonly property bool isPauseIcon: iconName === "pause"
    readonly property bool isPreviousIcon: iconName === "skip_previous"
    readonly property real iconPixelSize: Math.max(12, Math.round(iconSize * 96 / 72))
    readonly property real skipBarWidth: Math.max(2, Math.round(iconPixelSize * 0.115))
    readonly property real skipBarHeight: Math.max(9, Math.round(iconPixelSize * 0.66))
    readonly property real skipGlyphGap: Math.max(1, Math.round(iconPixelSize * 0.055))
    readonly property real skipTriangleWidth: Math.max(8, Math.round(iconPixelSize * 0.46))
    readonly property real skipTriangleHeight: Math.max(10, Math.round(iconPixelSize * 0.68))
    readonly property real skipTriangleCorner: Math.max(1.2, Math.min(skipTriangleWidth, skipTriangleHeight) * 0.16)
    readonly property real skipGlyphWidth: skipTriangleWidth + skipGlyphGap + skipBarWidth
    readonly property real skipGlyphHeight: Math.max(skipTriangleHeight, skipBarHeight)
    readonly property real pauseBarWidth: Math.max(3, Math.round(iconPixelSize * 0.20))
    readonly property real pauseBarHeight: Math.max(10, Math.round(iconPixelSize * 0.62))
    readonly property real pauseBarGap: Math.max(3, Math.round(iconPixelSize * 0.16))
    readonly property real pauseBarRadius: Math.min(Tokens.rounding.extraSmall, pauseBarWidth / 2)
    readonly property real shapeSize: Math.max(1, Math.min(width, height) - control.innerPad)
    readonly property real secondaryMix: Math.max(0, Math.min(1, secondaryProgress))
    readonly property real visualScale: clickScale
    readonly property real innerPad: control.emphasized ? 0 : 4
    readonly property color activeIconColor: control.emphasized ? Players.musicPlayIconColor : Qt.alpha(Players.musicOnSurfaceColor, stateLayer.containsMouse ? 0.98 : 0.78 + 0.12 * control.secondaryMix)
    readonly property color disabledIconColor: Qt.alpha(Players.musicOnSurfaceColor, 0.25)
    readonly property color containerTone: control.emphasized ? Players.musicPlayButtonBg : Qt.alpha(Players.musicPlayButtonBg, (stateLayer.pressed ? 0.28 : (stateLayer.containsMouse ? 0.20 : 0.12)) * control.secondaryMix)
    readonly property color strokeColor: control.emphasized ? Qt.alpha(Players.musicPlayIconColor, stateLayer.pressed ? 0.30 : 0.16) : "transparent"
    readonly property real secondaryShadowOpacity: control.elevated ? (stateLayer.containsMouse ? 0.18 : 0.11) * control.secondaryMix : 0

    width: 30
    height: 30
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
        implicitSize: control.shapeSize
        antialiasing: true
        smooth: true
        rotation: control.emphasized ? 90 : 0
        shape: control.emphasized ? (control.isPauseIcon ? MaterialShape.Bun : MaterialShape.Arrow) : (control.clickMorphActive ? control.clickMorphShape : (control.secondaryMix > 0.02 ? control.secondaryShape : MaterialShape.Pill))
        color: control.containerTone
        strokeColor: control.strokeColor
        strokeWidth: control.emphasized ? control.secondaryMix : 0
        animationDuration: Tokens.anim.durations.expressiveFastSpatial
        animationEasing: Tokens.anim.expressiveFastSpatial
        layer.enabled: control.secondaryShadowOpacity > 0.001
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Players.musicPlayButtonBg, 0.65)
            shadowOpacity: control.secondaryShadowOpacity
            shadowBlur: 0.62
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }
        Behavior on color {
            ColorAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastEffects
            }
        }
        Behavior on strokeColor {
            ColorAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastEffects
            }
        }
        Behavior on strokeWidth {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastEffects
            }
        }
    }

    MaterialIcon {
        id: controlIcon
        anchors.centerIn: parent
        visible: !control.isSkipIcon
        text: control.iconName
        color: Players.active ? control.activeIconColor : control.disabledIconColor
        iconPointSize: control.iconSize
        fill: 1
        font.weight: control.emphasized ? 850 : 300
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        animate: control.emphasized
        animateProp: "rotation"
        animateFrom: 90
        animateTo: 0
        animateDuration: 320

        // Rubber squash: decoupled X/Y transform, pivot stays at center
        transform: Scale {
            origin.x: controlIcon.width / 2
            origin.y: controlIcon.height / 2
            xScale: control.iconScaleX
            yScale: control.iconScaleY
        }
    }

    Item {
        id: skipIcon
        anchors.centerIn: parent
        visible: control.isSkipIcon
        width: control.skipGlyphWidth
        height: control.skipGlyphHeight

        readonly property color glyphColor: Players.active ? control.activeIconColor : control.disabledIconColor

        Item {
            id: skipGlyph
            anchors.centerIn: parent
            width: control.skipGlyphWidth
            height: control.skipGlyphHeight
            transformOrigin: Item.Center
            scale: control.isPreviousIcon ? -1 : 1

            Shape {
                id: skipTriangle
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: control.skipTriangleWidth
                height: control.skipTriangleHeight
                preferredRendererType: Shape.CurveRenderer
                readonly property real edgeLength: Math.sqrt(width * width + (height / 2) * (height / 2))
                readonly property real cornerDx: control.skipTriangleCorner * width / edgeLength
                readonly property real cornerDy: control.skipTriangleCorner * (height / 2) / edgeLength

                ShapePath {
                    fillColor: skipIcon.glyphColor
                    strokeColor: "transparent"
                    strokeWidth: 0
                    startX: skipTriangle.cornerDx
                    startY: skipTriangle.cornerDy

                    PathLine {
                        x: skipTriangle.width - skipTriangle.cornerDx
                        y: skipTriangle.height / 2 - skipTriangle.cornerDy
                    }
                    PathQuad {
                        controlX: skipTriangle.width
                        controlY: skipTriangle.height / 2
                        x: skipTriangle.width - skipTriangle.cornerDx
                        y: skipTriangle.height / 2 + skipTriangle.cornerDy
                    }
                    PathLine {
                        x: skipTriangle.cornerDx
                        y: skipTriangle.height - skipTriangle.cornerDy
                    }
                    PathQuad {
                        controlX: 0
                        controlY: skipTriangle.height
                        x: 0
                        y: skipTriangle.height - control.skipTriangleCorner
                    }
                    PathLine {
                        x: 0
                        y: control.skipTriangleCorner
                    }
                    PathQuad {
                        controlX: 0
                        controlY: 0
                        x: skipTriangle.cornerDx
                        y: skipTriangle.cornerDy
                    }

                    Behavior on fillColor {
                        ColorAnimation {
                            duration: Tokens.anim.durations.expressiveFastEffects
                            easing: Tokens.anim.expressiveFastEffects
                        }
                    }
                }
            }

            Rectangle {
                x: control.skipTriangleWidth + control.skipGlyphGap
                anchors.verticalCenter: parent.verticalCenter
                width: control.skipBarWidth
                height: control.skipBarHeight
                radius: width / 2
                color: skipIcon.glyphColor
                antialiasing: true

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.anim.durations.expressiveFastEffects
                        easing: Tokens.anim.expressiveFastEffects
                    }
                }
            }
        }

        transform: Scale {
            origin.x: skipIcon.width / 2
            origin.y: skipIcon.height / 2
            xScale: control.iconScaleX * control.skipIconScale
            yScale: control.iconScaleY * control.skipIconScale
        }
    }

    // Press: fast squeeze in X, slight compress in Y (80ms OutQuad)
    // Release: spring-back with elastic X-stretch overshoot, Y settles faster
    states: [
        State {
            name: "pressed"
            when: stateLayer.pressed
            PropertyChanges {
                target: control
                iconScaleX: 0.72
                iconScaleY: 0.94
            }
        },
        State {
            name: "idle"
            when: !stateLayer.pressed
            PropertyChanges {
                target: control
                iconScaleX: 1.0
                iconScaleY: 1.0
            }
        }
    ]

    transitions: [
        Transition {
            from: "idle"
            to: "pressed"
            NumberAnimation {
                properties: "iconScaleX,iconScaleY"
                duration: 80
                easing.type: Easing.OutQuad
            }
        },
        Transition {
            from: "pressed"
            to: "idle"
            SequentialAnimation {
                ParallelAnimation {
                    // X: rubbery overshoot — low damping = elastic wobble
                    SpringAnimation {
                        target: control
                        property: "iconScaleX"
                        to: 1.0
                        spring: 4.5
                        damping: 0.22
                        epsilon: 0.001
                    }
                    // Y: snappier settle — higher damping prevents vertical flap
                    SpringAnimation {
                        target: control
                        property: "iconScaleY"
                        to: 1.0
                        spring: 5.0
                        damping: 0.38
                        epsilon: 0.001
                    }
                }
                PropertyAction {
                    target: control
                    properties: "iconScaleX,iconScaleY"
                    value: 1.0
                }
            }
        }
    ]

    SequentialAnimation {
        id: pressSpring
        ParallelAnimation {
            NumberAnimation {
                target: control
                property: "clickScale"
                to: 0.88
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveFastSpatial
            }
        }
        SpringAnimation {
            target: control
            property: "clickScale"
            to: 1.0
            spring: 5.6
            damping: 0.58
            mass: 1.0
            epsilon: 0.001
        }
        PropertyAction {
            target: control
            property: "clickScale"
            value: 1.0
        }
    }

    SequentialAnimation {
        id: clickShapeMorph
        running: false

        PropertyAction {
            target: control
            property: "clickMorphActive"
            value: true
        }
        PauseAnimation {
            duration: Tokens.anim.durations.expressiveFastEffects
        }
        PropertyAction {
            target: control
            property: "clickMorphActive"
            value: false
        }
    }

    StateLayer {
        id: stateLayer
        radius: parent.radius
        showHoverBackground: false
        showRipple: false
        stateOpacity: 0
        color: control.emphasized ? control.activeIconColor : Players.musicOnSurfaceColor
        // Use interactive (not enabled override) so hand cursor stays in sync
        interactive: Players.active !== null
        onPressed: pressSpring.restart()
        onClicked: {
            if (control.cookieMorphOnClick && control.secondaryMix > 0.02)
                clickShapeMorph.restart();
            control.clicked();
        }
    }
}

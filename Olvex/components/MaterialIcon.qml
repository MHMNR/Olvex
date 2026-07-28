import QtQuick
import Olvex.Config
import qs.services

Text {
    id: root

    property bool animate: false
    property string animateProp: "scale"
    property real animateFrom: 0
    property real animateTo: 1
    // Guarded — see StyledText.qml for why: Tokens may not be attached yet on
    // the very first construction tick, transiently producing "Unable to
    // assign [undefined] to int" otherwise.
    property int animateDuration: Tokens?.anim?.durations?.normal ?? 300
    property real fill
    property int grade: Colours.light ? 0 : -25
    property real iconPointSize: Tokens.font.size.larger

    readonly property int iconPixelSize: Math.max(12, Math.round(iconPointSize * 96 / 72))

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface

    font.family: Tokens.font.family.material
    font.pixelSize: iconPixelSize
    font.variableAxes: ({
            FILL: fill.toFixed(1),
            GRAD: grade,
            opsz: iconPixelSize,
            wght: 400
        })

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                to: root.animateFrom
                easing: Tokens.anim.standardAccel
            }
            PropertyAction {}
            Anim {
                to: root.animateTo
                easing: Tokens.anim.standardDecel
            }
        }
    }

    component Anim: NumberAnimation {
        target: root
        property: root.animateProp
        duration: root.animateDuration / 2
    }
}

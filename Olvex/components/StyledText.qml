
import QtQuick
import Olvex.Config
import qs.services

Text {
    id: root

    property bool animate: false
    property string animateProp: "scale"
    property real animateFrom: 0
    property real animateTo: 1
    // Guarded: the Tokens attached property isn't guaranteed attached yet on the
    // very first construction tick of a freshly-created item, so a bare
    // `Tokens.anim.durations.normal` read here can transiently be undefined
    // ("Unable to assign [undefined] to int"). Falls back once, then this
    // rebinds correctly as soon as Tokens attaches.
    property int animateDuration: Tokens?.anim?.durations?.normal ?? 300
    property real textPointSize: -1
    property int textPixelSize: -1

    readonly property int resolvedPixelSize: {
        if (textPixelSize > 0)
            return textPixelSize;
        if (textPointSize > 0)
            return Math.max(10, Math.round(textPointSize * 96 / 72));
        return Math.max(10, Math.round(Tokens.font.size.smaller * 96 / 72));
    }

    renderType: Text.QtRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface
    font.family: Tokens.font.family.sans
    font.pixelSize: resolvedPixelSize
    font.hintingPreference: Font.PreferFullHinting

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

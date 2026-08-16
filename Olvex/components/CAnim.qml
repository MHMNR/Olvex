import QtQuick
import Olvex.Config
import qs.services

ColorAnimation {
    duration: Colours.themeTransitioning ? 0 : Tokens.anim.durations.expressiveDefaultEffects
    easing: Tokens.anim.expressiveDefaultEffects
}

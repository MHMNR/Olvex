import QtQuick
import Olvex.Config
import qs.services

ColorAnimation {
    duration: Colours.themeTransitioning ? 0 : Tokens.anim.durations.normal
    easing: Tokens.anim.standard
}

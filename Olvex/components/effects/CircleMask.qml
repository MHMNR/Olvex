import QtQuick
import Quickshell

ShaderEffect {
    property var source: null

    fragmentShader: Quickshell.shellPath("assets/shaders/circle_mask.frag.qsb")
}

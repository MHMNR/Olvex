import QtQuick
import Quickshell

ShaderEffect {
    required property Item source

    fragmentShader: Quickshell.shellPath("assets/shaders/circle_mask.frag.qsb")
}

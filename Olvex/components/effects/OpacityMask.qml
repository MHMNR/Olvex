import QtQuick
import Quickshell

ShaderEffect {
    property var source: null
    property var maskSource: null

    fragmentShader: Quickshell.shellPath("assets/shaders/opacitymask.frag.qsb")
}

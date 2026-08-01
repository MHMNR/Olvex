pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Source rect (in Panels root coordinates)
    property bool active: false
    property real srcX: 0
    property real srcY: 0
    property real srcW: 0
    property real srcH: 0

    // Destination rect (Panels will compute these when morph starts)
    property real dstX: 0
    property real dstY: 0
    property real dstW: 0
    property real dstH: 0

    // Optional color for the morphing card
    property color color: "transparent"

    function start(sx, sy, sw, sh, colorIn) {
        srcX = sx; srcY = sy; srcW = sw; srcH = sh;
        dstX = 0; dstY = 0; dstW = 0; dstH = 0;
        color = colorIn || "transparent";
        active = true;
    }

    function stop() {
        active = false;
    }
}

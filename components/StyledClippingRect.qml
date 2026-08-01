import QtQuick
import Quickshell.Widgets

ClippingRectangle {
    id: root

    color: "transparent"
    antialiasing: true
    smooth: true

    Behavior on color {
        CAnim {}
    }
}

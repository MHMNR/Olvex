pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property real innerRadius: Tokens.rounding.normal
    property real thickness: 1
    property real leftThickness: thickness
    property real topThickness: thickness
    property real rightThickness: thickness
    property real bottomThickness: thickness

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Qt.alpha(Colours.tPalette.m3outline, 0.15)
        border.width: Math.max(root.leftThickness, root.topThickness, root.rightThickness, root.bottomThickness)
        radius: root.innerRadius
        antialiasing: true
    }
}

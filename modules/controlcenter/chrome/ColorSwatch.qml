pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property color swatch: Colours.palette.m3primary
    property bool active: false

    signal clicked

    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.centerIn: parent
        width: root.active ? 30 : 26
        height: width
        radius: width / 2
        color: root.swatch
        border.width: root.active ? 2 : 0
        border.color: Colours.palette.m3onSurface

        Behavior on width {
            Anim { type: Anim.DefaultSpatial }
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: width / 2
        onClicked: root.clicked()
    }
}

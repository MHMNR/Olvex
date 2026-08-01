pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: visibilities.session && Config.session.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    opacity: 1 - offsetScale
    scale: 0.95 + (0.05 * (1 - offsetScale))

    anchors.fill: parent

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content
        anchors.fill: parent
        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }
}

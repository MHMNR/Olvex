pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: visibilities.powermenu && Config.powermenu.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    property bool contentPrewarmed: false

    Timer {
        id: prewarmTimer
        interval: 2400
        running: true
        repeat: false
        onTriggered: root.contentPrewarmed = true
    }

    property bool _forceRender: false
    Timer {
        id: forceRenderTimer
        interval: 250
        onTriggered: root._forceRender = false
    }

    visible: root._forceRender || offsetScale < 1
    opacity: (root._forceRender && offsetScale === 1) ? 1 : (1 - offsetScale)
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
        asynchronous: true
        active: root.contentPrewarmed || root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }

        onStatusChanged: {
            if (status === Loader.Ready && !root.shouldBeActive) {
                if (root.contentPrewarmed) {
                    root._forceRender = true;
                    forceRenderTimer.start();
                }
            }
        }
    }
}

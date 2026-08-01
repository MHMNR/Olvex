pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: visibilities.notificationcenter && Config.notificationcenter.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    property bool contentPrewarmed: false

    Timer {
        id: prewarmTimer
        interval: 2000
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
    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: (root._forceRender && offsetScale === 1) ? 1 : (1 - offsetScale)

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large
        anchors.bottomMargin: 0

        asynchronous: true
        active: root.contentPrewarmed || root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - Tokens.padding.large * 2
            props: root.props
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

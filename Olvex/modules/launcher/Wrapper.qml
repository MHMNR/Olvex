pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - ((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).thickness * 2 - Tokens.spacing.large;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    Timer {
        id: teardownGrace

        interval: Tokens.anim.durations.large + 100
    }

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            teardownGrace.stop();
            implicitHeight = Qt.binding(() => content.implicitHeight);
            implicitWidth = Qt.binding(() => content.implicitWidth || 630);
            Qt.callLater(() => Apps.warmCatalog());
        } else {
            content.item?.suspendLists?.();
            teardownGrace.restart();
            implicitHeight = implicitHeight; // Break binding during close anim
            implicitWidth = implicitWidth; // Break binding during close anim
        }
    }

    function navigateUp() { content.item?.navigateUp?.(); }
    function navigateDown() { content.item?.navigateDown?.(); }
    function navigateLeft() { content.item?.navigateLeft?.(); }
    function navigateRight() { content.item?.navigateRight?.(); }
    function navigateEnter() { content.item?.navigateEnter?.(); }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Component.onCompleted: Qt.callLater(() => Apps.warmCatalog())

    Component {
        id: contentComponent

        Content {
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: true
        asynchronous: true
        sourceComponent: contentComponent
    }
}

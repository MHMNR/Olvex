
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
    readonly property bool contentActive: root.shouldBeActive || teardownGrace.running

    readonly property real maxHeight: {
        let max = screen.height - ((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {
                        thickness: 0,
                        rounding: 0,
                        minThickness: 0,
                        floating: false,
                        smoothing: 0,
                        clampedThickness: 0
                    })) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {
                    thickness: 0,
                    rounding: 0,
                    minThickness: 0,
                    floating: false,
                    smoothing: 0,
                    clampedThickness: 0
                }) : ({
                    thickness: 0,
                    rounding: 0,
                    minThickness: 0,
                    floating: false,
                    smoothing: 0,
                    clampedThickness: 0
                })).thickness * 2 - Tokens.spacing.large;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1
    property real cachedImplicitHeight: 590
    property real cachedImplicitWidth: 630
    readonly property bool closingAnimationActive: !shouldBeActive && teardownGrace.running

    function syncCachedSize(): void {
        if (content.implicitHeight > 0)
            cachedImplicitHeight = content.implicitHeight;
        if (content.implicitWidth > 0)
            cachedImplicitWidth = content.implicitWidth;
    }

    Timer {
        id: teardownGrace

        interval: Tokens.anim.durations.large + 100
        onTriggered: {
            if (!root.shouldBeActive)
                content.item?.suspendLists?.();
        }
    }

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            teardownGrace.stop();
            Qt.callLater(() => {
                content.item?.resumeLists?.();
            });
        } else {
            teardownGrace.restart();
        }
    }

    function navigateUp() {
        content.item?.navigateUp?.();
    }
    function navigateDown() {
        content.item?.navigateDown?.();
    }
    function navigateLeft() {
        content.item?.navigateLeft?.();
    }
    function navigateRight() {
        content.item?.navigateRight?.();
    }
    function navigateEnter() {
        content.item?.navigateEnter?.();
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: closingAnimationActive ? cachedImplicitHeight : (content.implicitHeight || cachedImplicitHeight)
    implicitWidth: closingAnimationActive ? cachedImplicitWidth : (content.implicitWidth || cachedImplicitWidth)
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

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

        asynchronous: true
        active: root.contentActive
        sourceComponent: contentComponent

        onImplicitHeightChanged: root.syncCachedSize()
        onImplicitWidthChanged: root.syncCachedSize()
    }
}

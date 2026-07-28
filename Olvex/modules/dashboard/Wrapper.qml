pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex
import Olvex.Config
import qs.components
import qs.components.filedialog
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property bool needsKeyboard: (content.item as Content)?.needsKeyboard ?? false
    readonly property DashboardState dashState: DashboardState {
        reloadableId: "dashboardState"
    }
    readonly property FileDialog facePicker: FileDialog {
        title: qsTr("Select a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        readonly property list<string> faceRoot: AccountFaces.bundledRoot ? [AccountFaces.bundledRoot] : ["Home"]
        initialCwd: faceRoot
        cwd: faceRoot
        resetCwdOnOpen: true

        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(AccountFaces.customPath))) {
                AccountFaces.faceRevision++
                AccountFaces.faceChanged()
                Quickshell.execDetached([
                    "notify-send", "-a", "olvex-shell", "-u", "low",
                    "-h", `STRING:image-path:${path}`,
                    qsTr("Profile picture changed"),
                    qsTr("Profile picture changed to %1").arg(Paths.shortenHome(path))
                ]);
            } else
                Quickshell.execDetached([
                    "notify-send", "-a", "olvex-shell", "-u", "critical",
                    qsTr("Unable to change profile picture"),
                    qsTr("Failed to change profile picture to %1").arg(Paths.shortenHome(path))
                ]);
        }
    }

    property real cachedImplicitWidth: 854
    property real cachedImplicitHeight: 480
    readonly property real nonAnimHeight: (content.item as Content)?.nonAnimHeight ?? cachedImplicitHeight
    readonly property bool shouldBeActive: visibilities.dashboard && Config.dashboard.enabled
    readonly property bool contentVisible: offsetScale < 1
    readonly property bool dashboardActive: shouldBeActive || contentVisible
    readonly property bool contentActive: dashboardActive || closeGrace.running
    property real offsetScale: shouldBeActive ? 0 : 1
    property bool hovered: false

    function syncCachedSize(): void {
        if (content.implicitWidth > 0)
            cachedImplicitWidth = content.implicitWidth;
        if (content.implicitHeight > 0)
            cachedImplicitHeight = content.implicitHeight;
    }

    Connections {
        target: visibilities
        function onDashboardChanged() {
            if (visibilities.dashboard) {
                closeGrace.stop();
                Qt.callLater(root.syncCachedSize);
            } else {
                closeGrace.restart();
                dashState.currentDate = new Date()
            }
        }
    }

    Timer {
        id: closeGrace

        interval: Tokens.anim.durations.expressiveDefaultSpatial + 80
    }

    visible: offsetScale < 1 || (peekOffset > 0 && Config.dashboard.enabled)
    
    // Top margin defaults to fully hiding the panel (-implicitHeight - 10)
    // If hovered and inactive, we peek 7px by adding 17 (10 + 7) to the top margin
    property real peekOffset: (hovered && !shouldBeActive) ? 17 : 0

    Behavior on peekOffset {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    anchors.topMargin: (-implicitHeight - 10 + peekOffset) * offsetScale
    
    // Stabilize dimensions to prevent jitter during first load
    implicitHeight: Math.max(480, contentActive ? (content.implicitHeight || cachedImplicitHeight) : cachedImplicitHeight)
    implicitWidth: Math.max(854, contentActive ? (content.implicitWidth || cachedImplicitWidth) : cachedImplicitWidth)
    opacity: (hovered || peekOffset > 0) ? 1 : 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: root.shouldBeActive ? Anim.DefaultSpatial : Anim.EmphasizedLarge
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        active: root.contentActive

        onImplicitWidthChanged: root.syncCachedSize()
        onImplicitHeightChanged: root.syncCachedSize()
        onStatusChanged: {
            if (status === Loader.Ready)
                root.syncCachedSize();
        }

        sourceComponent: Content {
            dashboardActive: root.dashboardActive
            visibilities: root.visibilities
            dashState: root.dashState
            facePicker: root.facePicker
        }
    }
}

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
                AccountFaces.faceRevision++;
                AccountFaces.faceChanged();
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "low", "-h", `STRING:image-path:${path}`, qsTr("Profile picture changed"), qsTr("Profile picture changed to %1").arg(Paths.shortenHome(path))]);
            } else
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Unable to change profile picture"), qsTr("Failed to change profile picture to %1").arg(Paths.shortenHome(path))]);
        }
    }

    readonly property real nonAnimHeight: (content.item as Content)?.nonAnimHeight ?? 480
    readonly property bool shouldBeActive: visibilities.dashboard && Config.dashboard.enabled
    readonly property bool dashboardActive: root.shouldBeActive || closeGrace.running
    property real offsetScale: shouldBeActive ? 0 : 1
    property bool hovered: false

    Connections {
        target: visibilities
        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                closeGrace.stop();
            } else {
                closeGrace.restart();
                root.dashState.currentDate = new Date();
            }
        }
    }

    Timer {
        id: closeGrace

        interval: Math.max(Tokens.anim.durations.large, Tokens.anim.durations.expressiveDefaultSpatial) + 120
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
    implicitHeight: Math.max(480, content.implicitHeight)
    implicitWidth: Math.max(854, content.implicitWidth)
    // Match launcher: linear 1-offsetScale (snaps to fully opaque at rest).
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        active: true

        sourceComponent: Content {
            dashboardActive: root.dashboardActive
            visibilities: root.visibilities
            dashState: root.dashState
            facePicker: root.facePicker
        }
    }
}

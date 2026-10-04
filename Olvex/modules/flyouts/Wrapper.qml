
import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property bool sidebarOrSessionVisible
    property Item screenCapture: null

    property bool hovered
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: visibilities.flyouts && Config.flyouts.enabled && !(visibilities.qspanel && Config.qspanel.enabled)
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarOffset: sidebarOrSessionVisible ? 12 : 0

    property real volume
    property bool muted
    property real sourceVolume
    property bool sourceMuted
    property real brightness

    function show() {
        visibilities.flyouts = true;
        timer.restart();
    }

    Component.onCompleted: {
        volume = Audio.volume;
        muted = Audio.muted;
        sourceVolume = Audio.sourceVolume;
        sourceMuted = Audio.sourceMuted;
        brightness = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
    }

    visible: offsetScale < 1
    layer.enabled: offsetScale > 0 && offsetScale < 1
    layer.smooth: true
    anchors.rightMargin: (-implicitWidth - 6 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Connections {
        function onMutedChanged() {
            root.muted = Audio.muted;
        }

        function onVolumeChanged() {
            root.volume = Audio.volume;
        }

        function onSourceMutedChanged() {
            root.sourceMuted = Audio.sourceMuted;
        }

        function onSourceVolumeChanged() {
            root.sourceVolume = Audio.sourceVolume;
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged() {
            root.brightness = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
        }

        target: root.monitor
    }

    Timer {
        id: timer

        interval: root.Config.flyouts.hideDelay
        onTriggered: {
            if (!root.hovered)
                root.visibilities.flyouts = false;
        }
    }

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        asynchronous: true
        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            monitor: root.monitor
            visibilities: root.visibilities
            volume: root.volume
            muted: root.muted
            sourceVolume: root.sourceVolume
            sourceMuted: root.sourceMuted
            brightness: root.brightness
            screenCapture: root.screenCapture
        }

    }
}

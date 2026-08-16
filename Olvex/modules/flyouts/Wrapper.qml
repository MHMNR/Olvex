
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

    function show(): void {
        visibilities.flyouts = true;
        timer.restart();
    }

    Component.onCompleted: {
        volume = Audio.volume;
        muted = Audio.muted;
        sourceVolume = Audio.sourceVolume;
        sourceMuted = Audio.sourceMuted;
        brightness = root.monitor?.brightness ?? 0;
    }

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Connections {
        function onMutedChanged(): void {
            if (root.Config.flyouts.enableVolume ?? true)
                root.show();
            root.muted = Audio.muted;
        }

        function onVolumeChanged(): void {
            if (root.Config.flyouts.enableVolume ?? true)
                root.show();
            root.volume = Audio.volume;
        }

        function onSourceMutedChanged(): void {
            if (root.Config.flyouts.enableMicrophone ?? false)
                root.show();
            root.sourceMuted = Audio.sourceMuted;
        }

        function onSourceVolumeChanged(): void {
            if (root.Config.flyouts.enableMicrophone ?? false)
                root.show();
            root.sourceVolume = Audio.sourceVolume;
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            if (root.Config.flyouts.enableBrightness ?? true)
                root.show();
            root.brightness = root.monitor?.brightness ?? 0;
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

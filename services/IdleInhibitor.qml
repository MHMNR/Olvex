pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Olvex.Config

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince

    function applyState(active) {
        waylandInhibitor.enabled = active
        inhibitProcess.running = active
        if (active)
            props.enabledSince = new Date()
    }

    function syncFromConfig() {
        if (props.enabled === GlobalConfig.utilities.keepAwake)
            return
        props.enabled = GlobalConfig.utilities.keepAwake
    }

    function syncToConfig() {
        if (GlobalConfig.utilities.keepAwake === props.enabled)
            return
        GlobalConfig.utilities.keepAwake = props.enabled
    }

    property Process inhibitProcess: Process {
        id: inhibitProcess

        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch:handle-power-key",
            "--who=Olvex",
            "--why=Keep Awake enabled",
            "sleep", "infinity"
        ]
        running: false

        onExited: function (exitCode) {
            if (root.enabled && exitCode !== 0)
                restartTimer.start()
        }
    }

    Timer {
        id: restartTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (root.enabled && !inhibitProcess.running)
                inhibitProcess.running = true
        }
    }

    Component.onCompleted: {
        syncFromConfig()
        applyState(props.enabled)
    }

    onEnabledChanged: {
        syncToConfig()
        applyState(enabled)
    }

    Connections {
        target: GlobalConfig.utilities
        function onKeepAwakeChanged() {
            root.syncFromConfig()
            root.applyState(root.enabled)
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: false
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    IdleInhibitor {
        id: waylandInhibitor

        enabled: false
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"

            anchors {
                right: true
                bottom: true
            }

            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled
        }

        function toggle(): void {
            root.enabled = !root.enabled
        }

        function enable(): void {
            root.enabled = true
        }

        function disable(): void {
            root.enabled = false
        }

        target: "idleInhibitor"
    }
}
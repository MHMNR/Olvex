pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland as QSWayland
import Olvex.Config

Singleton {
    id: root

    property bool enabled: GlobalConfig.utilities.keepAwake
    readonly property alias enabledSince: props.enabledSince

    property Process inhibitProcess: Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch", "--who=Olvex", "--why=Keep Awake enabled", "sleep", "infinity"]
        onExited: {
            if (root.enabled) {
                // Restart if it exited unexpectedly
                restartTimer.start();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: {
            if (root.enabled) inhibitProc.start();
        }
    }

    Component.onCompleted: {
        // Migrate old persistent state if present
        if (props.enabled && !GlobalConfig.utilities.keepAwake) {
            GlobalConfig.utilities.keepAwake = true;
            GlobalConfig.save();
        }

        // Delay startup inhibition slightly to ensure system services are ready
        if (root.enabled) {
            if (!props.enabledSince) props.enabledSince = new Date();
            restartTimer.start();
        }
    }

    onEnabledChanged: {
        if (GlobalConfig.utilities.keepAwake !== enabled) {
            GlobalConfig.utilities.keepAwake = enabled;
            GlobalConfig.save();
        }

        if (enabled) {
            props.enabledSince = new Date();
            inhibitProcess.start();
        } else {
            inhibitProcess.terminate();
        }
    }

    PersistentProperties {
        id: props

        property bool enabled
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    QSWayland.IdleInhibitor {
        enabled: root.enabled
        window: PanelWindow {
            screen: Screens.screens[0]
            visible: root.enabled
            width: 1
            height: 1
            color: "transparent"
            QSWayland.WlrLayershell.exclusionMode: QSWayland.ExclusionMode.Ignore
            
            anchors: Anchor.Top | Anchor.Left
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function enable(): void {
            root.enabled = true;
        }

        function disable(): void {
            root.enabled = false;
        }

        target: "idleInhibitor"
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services

Singleton {
    id: root

    Process {
        id: inhibitProc
        command: [
            "systemd-inhibit",
            "--what=handle-power-key:handle-lid-switch",
            "--who=Olvex",
            "--why=Managed internally via HardwareButtons",
            "--mode=block",
            "sleep", "infinity"
        ]
        running: true
        onExited: function(exitCode) {
            if (exitCode !== 0) restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!inhibitProc.running) inhibitProc.running = true;
        }
    }

    Component.onCompleted: {
        Hypr.dispatch("keyword bindl ,switch:on:Lid Switch,exec,olvex shell hardwareButtons lidClose");
        Hypr.dispatch("keyword bindl ,switch:off:Lid Switch,exec,olvex shell hardwareButtons lidOpen");
        Hypr.dispatch("keyword bind ,XF86PowerOff,exec,olvex shell hardwareButtons powerBtn");
    }

    IpcHandler {
        target: "hardwareButtons"

        function lidClose() {
            const act = GlobalConfig.general.lidAction;
            if (act === "Suspend") {
                Quickshell.execDetached(["systemctl", "suspend"]);
            } else if (act === "Lock screen") {
                Quickshell.execDetached(["loginctl", "lock-session"]);
            } else if (act === "Turn off screen") {
                Hypr.dispatch("dpms off");
            }
        }

        function lidOpen() {
            Hypr.dispatch("dpms on");
        }

        function powerBtn() {
            const act = GlobalConfig.general.powerButtonAction;
            if (act === "Show power menu") {
                Visibilities.getForActive().powermenu = true;
            } else if (act === "Suspend") {
                Quickshell.execDetached(["systemctl", "suspend"]);
            } else if (act === "Shutdown") {
                Quickshell.execDetached(["systemctl", "poweroff"]);
            }
        }
    }
}

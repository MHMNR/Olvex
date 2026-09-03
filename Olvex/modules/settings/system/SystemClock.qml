
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property Session session
    property var appJoin: (list) => (list && list.length) ? list.join(" ") : ""
    property var appSplit: (text) => (text || "").trim() ? (text || "").trim().split(/\s+/) : []
    property var idxOf: (list, val) => {
        const v = (val || "").toLowerCase();
        for (let i = 0; i < (list ? list.length : 0); i++) {
            if (String(list[i]).toLowerCase() === v)
                return i;
        }
        return 0;
    }

    property string currentTz: ""
    property var timezones: []
    
    Process {
        id: tzListProc
        running: true
        command: ["bash", "-c", "timedatectl list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    root.timezones = text.trim().split("\n").filter(t => t.length > 0);
                }
            }
        }
    }
    Process {
        id: tzProc
        running: true
        command: ["bash", "-c", "timedatectl show --property=Timezone --value"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    root.currentTz = text.trim();
                }
            }
        }
    }
    
    Process {
        id: tzSetProc
        onExited: {
            if (exitCode === 0) {
                tzProc.running = true;
            } else {
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Timezone Error"), qsTr("Invalid timezone or permission denied.")]);
                tzProc.running = true;
            }
        }
    }
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: 0

        SettingRow {
            title: qsTr("Clock format")
            description: qsTr("12-hour or 24-hour time")
            divider: true
            Segmented {
                minSegmentWidth: 96
                model: [{
                        label: qsTr("24-hour")
                    }, {
                        label: qsTr("12-hour")
                    }]
                currentIndex: GlobalConfig.services.useTwelveHourClock ? 1 : 0
                onSelected: i => {
                    GlobalConfig.services.useTwelveHourClock = i === 1;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Temperature unit")
            description: qsTr("Units used for weather readouts")
            divider: true
            Segmented {
                model: [{
                        label: "°C"
                    }, {
                        label: "°F"
                    }]
                currentIndex: GlobalConfig.services.useFahrenheit ? 1 : 0
                onSelected: i => {
                    GlobalConfig.services.useFahrenheit = i === 1;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Timezone")
            description: qsTr("System timezone (e.g. Asia/Dhaka or America/New_York)")
            divider: true
            OptionPicker {
                id: tzPicker
                menuMaxHeight: 360
                model: root.timezones
                currentIndex: {
                    const cur = root.currentTz || "";
                    return root.idxOf(tzPicker.model, cur);
                }
                onSelected: i => {
                    if (tzPicker.model && tzPicker.model[i]) {
                        tzSetProc.command = ["timedatectl", "set-timezone", tzPicker.model[i]];
                        tzSetProc.running = true;
                    }
                }
            }
        }
        
        SettingRow {
            title: qsTr("Weather location")
            description: qsTr("City used for the weather widget")
            divider: false
            StyledTextField {
                width: 240
                text: GlobalConfig.services.weatherLocation || ""
                onEditingFinished: {
                    GlobalConfig.services.weatherLocation = text;
                    GlobalConfig.save();
                }
            }
        }
    }
}

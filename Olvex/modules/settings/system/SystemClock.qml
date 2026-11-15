
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
import qs.services

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
    property bool ntpEnabled: true
    property string currentLocale: ""
    property var locales: []
    
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
        onExited: (exitCode) => {
            if (exitCode === 0) {
                tzProc.running = true;
            } else {
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Timezone Error"), qsTr("Invalid timezone or permission denied.")]);
                tzProc.running = true;
            }
        }
    }

    Process {
        id: ntpProc
        running: true
        command: ["bash", "-c", "timedatectl show --property=NTP --value"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = (text || "").trim().toLowerCase();
                if (v === "yes" || v === "true" || v === "1")
                    root.ntpEnabled = true;
                else if (v === "no" || v === "false" || v === "0")
                    root.ntpEnabled = false;
            }
        }
    }

    Process {
        id: ntpSetProc
        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Time Sync Error"), qsTr("Could not change automatic NTP time sync.")]);
            ntpProc.running = true;
        }
    }

    Process {
        id: manualTimeSetProc
        onExited: (exitCode) => {
            if (exitCode === 0)
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", qsTr("Date & Time Updated"), qsTr("System clock updated successfully.")]);
            else
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Date & Time Error"), qsTr("Use YYYY-MM-DD HH:MM:SS format or check permissions.")]);
        }
    }

    Process {
        id: localeListProc
        running: true
        command: ["bash", "-c", "localectl list-locales 2>/dev/null || locale -a 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "")
                    root.locales = text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: localeProc
        running: true
        command: ["bash", "-c", "localectl status 2>/dev/null | sed -n 's/.*LANG=\\([^ ]*\\).*/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "")
                    root.currentLocale = text.trim().split("\n")[0];
            }
        }
    }

    Process {
        id: localeSetProc
        onExited: (exitCode) => {
            if (exitCode === 0)
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", qsTr("Language & Locale"), qsTr("System locale updated. Re-login may be required for all apps.")]);
            else
                Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "critical", qsTr("Locale Error"), qsTr("Could not set system locale.")]);
            localeProc.running = true;
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
        spacing: Tokens.spacing.large

        Section {
            Layout.fillWidth: true
            title: qsTr("Time & Date Format")
            description: qsTr("Display format and system regional time zone")
            icon: "schedule"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Clock format")
                description: qsTr("Choose between 24-hour military or 12-hour AM/PM time")
                Segmented {
                    minSegmentWidth: 96
                    model: [
                        { label: qsTr("24-hour") },
                        { label: qsTr("12-hour") }
                    ]
                    currentIndex: GlobalConfig.services.useTwelveHourClock ? 1 : 0
                    onSelected: i => {
                        GlobalConfig.services.useTwelveHourClock = i === 1;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Timezone")
                description: qsTr("System timezone (e.g. Asia/Dhaka, Europe/London, America/New_York)")
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
                title: qsTr("Automatic time sync (NTP)")
                description: qsTr("Synchronize system date and time automatically over the network")
                StyledSwitch {
                    checked: root.ntpEnabled
                    onToggled: {
                        root.ntpEnabled = checked;
                        ntpSetProc.command = ["timedatectl", "set-ntp", checked ? "true" : "false"];
                        ntpSetProc.running = true;
                    }
                }
            }

            SettingRow {
                visible: !root.ntpEnabled
                title: qsTr("Manual date & time")
                description: qsTr("Format: YYYY-MM-DD HH:MM:SS")
                RowLayout {
                    spacing: Tokens.spacing.small
                    StyledTextField {
                        id: manualTimeField
                        implicitWidth: 190
                        placeholderText: "2026-11-15 23:30:00"
                    }
                    TextButton {
                        text: qsTr("Apply")
                        type: TextButton.Tonal
                        onClicked: {
                            const val = manualTimeField.text.trim();
                            if (val.length > 0) {
                                manualTimeSetProc.command = ["timedatectl", "set-time", val];
                                manualTimeSetProc.running = true;
                            }
                        }
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Language & Locale")
            description: qsTr("System locale for formatting, numbers, and applications")
            icon: "translate"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("System locale")
                description: root.currentLocale ? qsTr("Active: %1").arg(root.currentLocale) : qsTr("Select system language and regional locale")
                OptionPicker {
                    id: localePicker
                    menuMaxHeight: 340
                    model: root.locales
                    currentIndex: root.idxOf(localePicker.model, root.currentLocale)
                    onSelected: i => {
                        if (localePicker.model && localePicker.model[i]) {
                            localeSetProc.command = ["localectl", "set-locale", "LANG=" + localePicker.model[i]];
                            localeSetProc.running = true;
                        }
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Weather & Regional Units")
            description: qsTr("Measurement scale used in widgets and notifications")
            icon: "thermostat"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Temperature unit")
                description: qsTr("Celsius (°C) or Fahrenheit (°F)")
                Segmented {
                    minSegmentWidth: 80
                    model: [
                        { label: "°C" },
                        { label: "°F" }
                    ]
                    currentIndex: GlobalConfig.services.useFahrenheit ? 1 : 0
                    onSelected: i => {
                        GlobalConfig.services.useFahrenheit = i === 1;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
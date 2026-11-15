import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "clock"

    sections: [
        { id: "display", label: qsTr("Displays"), icon: "desktop_windows" },
        { id: "input", label: qsTr("Input Devices"), icon: "mouse" },
        { id: "clock", label: qsTr("Clock & Date"), icon: "schedule" },
        { id: "keybinds", label: qsTr("Keybindings"), icon: "keyboard" },
        { id: "defaults", label: qsTr("Default Apps"), icon: "apps" },
        { id: "startup", label: qsTr("Startup Apps"), icon: "rocket_launch" },
        { id: "privacy", label: qsTr("Privacy & Clipboard"), icon: "shield" },
        { id: "media", label: qsTr("Media Controls"), icon: "play_circle" },
        { id: "advanced", label: qsTr("Advanced"), icon: "build" }
    ]
}

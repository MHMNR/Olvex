import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "clock"

    sections: [
        { id: "display", label: qsTr("Displays"), icon: "desktop_windows" },
        { id: "clock", label: qsTr("Clock & Date"), icon: "schedule" },
        { id: "keybinds", label: qsTr("Keybindings"), icon: "keyboard" },
        { id: "media", label: qsTr("Media Controls"), icon: "play_circle" },
        { id: "advanced", label: qsTr("Advanced"), icon: "build" }
    ]
}

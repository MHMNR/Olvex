import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "output"

    sections: [
        { id: "output", label: qsTr("Output Devices"), icon: "volume_up" },
        { id: "input", label: qsTr("Input Devices"), icon: "mic" },
        { id: "apps", label: qsTr("App Streams"), icon: "equalizer" },
        { id: "uisounds", label: qsTr("UI Sounds"), icon: "music_note" },
        { id: "behavior", label: qsTr("Sound Behavior"), icon: "tune" }
    ]
}

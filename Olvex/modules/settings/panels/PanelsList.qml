import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "dashboard"

    sections: [
        { id: "dashboard", label: qsTr("Dashboard"), icon: "dashboard" },
        { id: "launcher", label: qsTr("Launcher"), icon: "search" },
        { id: "osd", label: qsTr("Flyouts"), icon: "volume_up" }
    ]
}

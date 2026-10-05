import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "wifi"

    sections: [
        { id: "wifi", label: qsTr("Wi-Fi Networks"), icon: "wifi" },
        { id: "bluetooth", label: qsTr("Bluetooth"), icon: "bluetooth" },
        { id: "details", label: qsTr("Ethernet & IP"), icon: "settings_ethernet" }
    ]
}

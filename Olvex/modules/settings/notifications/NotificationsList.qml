import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "behavior"

    sections: [
        { id: "behavior", label: qsTr("DND & General"), icon: "notifications" },
        { id: "toasts", label: qsTr("Toasts"), icon: "campaign" }
    ]
}

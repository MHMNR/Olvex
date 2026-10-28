import ".."
import "../ui"
import "../components"
import QtQuick

SettingsMasterList {
    id: root

    property string activeSection: "behavior"

    sections: [
        { id: "behavior", label: qsTr("Bar & Behavior"), icon: "dock" },
        { id: "quickorb", label: qsTr("Quick Orb"), icon: "adjust" },
        { id: "workspaces", label: qsTr("Workspaces"), icon: "grid_view" },
        { id: "widgets", label: qsTr("Widgets & Tray"), icon: "widgets" },
        { id: "secondaryPanel", label: qsTr("Secondary Panel"), icon: "bottom_panel_open" }
    ]
}

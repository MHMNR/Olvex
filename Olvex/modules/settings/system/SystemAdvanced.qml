
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.utils

Item {
    id: root
    
    property Session session
    property var appJoin
    property var appSplit
    property var idxOf
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
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
            title: qsTr("GPU type")
            description: qsTr("Vendor used for performance monitoring")
            divider: true
            OptionPicker {
                id: gpuPicker
                model: ["", "auto", "amd", "nvidia", "intel"]
                currentIndex: root.idxOf(gpuPicker.model, GlobalConfig.services.gpuType || "")
                onSelected: i => {
                    GlobalConfig.services.gpuType = gpuPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Open config folder")
            description: qsTr("Edit shell.json & shell-tokens.json directly")
            clickable: true
            divider: false
            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.large
            }
            onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
        }
    }
}


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
import qs.services

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
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
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
            title: qsTr("Hardware & Performance")
            description: qsTr("GPU vendor drivers and telemetry monitoring")
            icon: "memory"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("GPU type")
                description: qsTr("Vendor used for performance monitoring and usage stats")
                OptionPicker {
                    id: gpuPicker
                    model: ["auto", "amd", "nvidia", "intel"]
                    currentIndex: {
                        const cur = GlobalConfig.services.gpuType || "auto";
                        const idx = model.indexOf(cur);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: i => {
                        GlobalConfig.services.gpuType = gpuPicker.model[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Configuration Files")
            description: qsTr("Direct access to Olvex JSON configs and monitor tokens")
            icon: "folder"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Open config folder")
                description: qsTr("Edit shell.json & shell-tokens.json directly in file manager")
                clickable: true
                MaterialIcon {
                    text: "open_in_new"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.normal
                }
                onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
            }
        }
    }
}
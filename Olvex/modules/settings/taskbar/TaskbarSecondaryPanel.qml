
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root
    
    property Session session
    
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
            title: qsTr("Secondary Panel & Quick Settings")
            description: qsTr("Auxiliary controls panel below or opposite the main taskbar")
            icon: "view_sidebar"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("Enable Secondary Panel")
                description: qsTr("Show the quick settings and mini-dock panel")
                
                StyledSwitch {
                    checked: (Config.bar.secondaryPanel.enabled !== undefined) ? Config.bar.secondaryPanel.enabled : true
                    onToggled: {
                        GlobalConfig.bar.secondaryPanel.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("Dock Background")
                description: qsTr("Show a container background behind pinned applications")
                enabled: (Config.bar.secondaryPanel.enabled !== undefined) ? Config.bar.secondaryPanel.enabled : true
                
                StyledSwitch {
                    enabled: (Config.bar.secondaryPanel.enabled !== undefined) ? Config.bar.secondaryPanel.enabled : true
                    checked: Visibilities.secondaryPanelDockBackground
                    onToggled: {
                        Visibilities.setSecondaryPanelDockBackground(checked);
                        if (GlobalConfig.bar && GlobalConfig.bar.secondaryPanel) {
                            GlobalConfig.bar.secondaryPanel.dockBackground = checked;
                        }
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("Visibility Mode")
                description: qsTr("Choose auto-hide or persistent state for the secondary panel")
                enabled: (Config.bar.secondaryPanel.enabled !== undefined) ? Config.bar.secondaryPanel.enabled : true
                
                Segmented {
                    enabled: (Config.bar.secondaryPanel.enabled !== undefined) ? Config.bar.secondaryPanel.enabled : true
                    model: [qsTr("Always Show"), qsTr("Auto Hide"), qsTr("Smart Hide")]
                    currentIndex: {
                        const act = Config.bar.secondaryPanel.visibilityMode || "always";
                        if (act === "autohide") return 1;
                        if (act === "smarthide") return 2;
                        return 0;
                    }
                    onSelected: i => {
                        if (i === 0) GlobalConfig.bar.secondaryPanel.visibilityMode = "always";
                        else if (i === 1) GlobalConfig.bar.secondaryPanel.visibilityMode = "autohide";
                        else if (i === 2) GlobalConfig.bar.secondaryPanel.visibilityMode = "smarthide";
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}

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

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Bottom Panel")
            description: qsTr("Quick settings panel below the taskbar")
            icon: "bottom_panel_open"
            divider: true
            
            StyledSwitch {
                checked: Config.bar.bottomPanel.enabled ?? true
                onToggled: {
                    GlobalConfig.bar.bottomPanel.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Dock Background")
            description: qsTr("Show a container background behind pinned apps")
            icon: "view_compact_alt"
            divider: true
            enabled: Config.bar.bottomPanel.enabled ?? true
            opacity: enabled ? 1.0 : 0.38
            Behavior on opacity { Anim { type: Anim.FastEffects } }
            
            StyledSwitch {
                enabled: Config.bar.bottomPanel.enabled ?? true
                checked: Visibilities.bottomPanelDockBackground
                onToggled: {
                    Visibilities.setBottomPanelDockBackground(checked);
                    if (GlobalConfig.bar && GlobalConfig.bar.bottomPanel) {
                        GlobalConfig.bar.bottomPanel.dockBackground = checked;
                    }
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Visibility Mode")
            description: qsTr("When the bottom panel should be shown")
            icon: "visibility"
            divider: false
            enabled: Config.bar.bottomPanel.enabled ?? true
            opacity: enabled ? 1.0 : 0.38
            Behavior on opacity { Anim { type: Anim.FastEffects } }
            
            Segmented {
                enabled: Config.bar.bottomPanel.enabled ?? true
                model: [qsTr("Always Show"), qsTr("Auto Hide"), qsTr("Smart Hide")]
                currentIndex: {
                    const act = Config.bar.bottomPanel.visibilityMode || "always";
                    if (act === "autohide") return 1;
                    if (act === "smarthide") return 2;
                    return 0;
                }
                onSelected: i => {
                    if (i === 0) GlobalConfig.bar.bottomPanel.visibilityMode = "always";
                    else if (i === 1) GlobalConfig.bar.bottomPanel.visibilityMode = "autohide";
                    else if (i === 2) GlobalConfig.bar.bottomPanel.visibilityMode = "smarthide";
                    GlobalConfig.save();
                }
            }
        }
    }
}
